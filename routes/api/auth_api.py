"""
/api/auth/* — Flutter-friendly authentication.

Endpoints:
  POST /api/auth/login         -> issue token + return user
  POST /api/auth/register      -> full multipart registration (buyer/seller/rider)
  POST /api/auth/send-otp      -> send OTP to email
  POST /api/auth/verify-otp    -> verify OTP
  POST /api/auth/logout        -> stateless OK (client just drops token)
  GET  /api/auth/me            -> current authenticated user
"""

from flask import Blueprint, session, request

from routes.api.api_helpers import (
    api_response, api_error, get_json_body,
    token_required, get_current_user, issue_token,
)

# No url_prefix here — registered with url_prefix='/api' in app.py
# so all routes below are /api/auth/*
auth_api_bp = Blueprint('auth_api', __name__)


@auth_api_bp.route('/auth/login', methods=['POST'])
def api_login():
    data     = get_json_body()
    email    = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    if not email or not password:
        return api_error("Email and password are required", status=400)

    from services.auth_service import AuthService
    try:
        result = AuthService().authenticate_user(email, password)
    except Exception as e:
        return api_error(f"Login failed: {e}", status=500)

    if not result.get('success'):
        return api_error(result.get('error') or "Invalid credentials", status=401)

    user = result.get('user') or {}
    role = user.get('role', 'user')

    # Direct token for all roles (OTP removed)
    token = issue_token(user)
    try:
        session.clear()
        session['user_id']    = user.get('id')
        session['user_email'] = user.get('email')
        session['user_role']  = role
        session['user_name']  = user.get('name', '')
    except Exception:
        pass

    return api_response(
        data={'token': token, 'user': user, 'should_merge_cart': True},
        message='Login successful',
        status=200,
    )


@auth_api_bp.route('/auth/login-verify-otp', methods=['POST'])
def api_login_verify_otp():
    """Step 2 of login: verify OTP then issue token."""
    data  = get_json_body()
    email = (data.get('email') or '').strip().lower()
    otp   = (data.get('otp')   or '').strip()

    if not email or not otp:
        return api_error("Email and OTP are required", status=400)

    import os
    from datetime import datetime, timezone
    from supabase import create_client

    sb  = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    row = sb.table('email_otps').select('*').eq('email', email).eq('otp', otp).execute()

    if not row.data:
        return api_error("Invalid OTP", status=400)

    record     = row.data[0]
    expires_at = datetime.fromisoformat(record['expires_at'].replace('Z', '+00:00'))
    if datetime.now(timezone.utc) > expires_at:
        return api_error("OTP has expired. Please try logging in again.", status=400)

    sb.table('email_otps').delete().eq('email', email).execute()

    # Fetch user and issue token
    from models.user_model import UserModel
    user_data = UserModel().get_by_email(email)
    if not user_data:
        return api_error("User not found", status=404)

    user = {
        'id':         user_data.get('id'),
        'email':      user_data.get('email'),
        'first_name': user_data.get('first_name', ''),
        'last_name':  user_data.get('last_name', ''),
        'phone':      user_data.get('phone', ''),
        'role':       user_data.get('role', 'user'),
        'name':       f"{user_data.get('first_name','')} {user_data.get('last_name','')}".strip(),
    }
    token = issue_token(user)

    try:
        session.clear()
        session['user_id']    = user.get('id')
        session['user_email'] = user.get('email')
        session['user_role']  = user.get('role', 'user')
        session['user_name']  = user.get('name', '')
    except Exception:
        pass

    return api_response(
        data={'token': token, 'user': user},
        message='Login successful',
        status=200,
    )


@auth_api_bp.route('/auth/register', methods=['POST'])
def api_register():
    """
    Full multipart/form-data registration for buyer, seller, and rider.
    Accepts files: valid_id, business_permit, dti_or_sec, driver_license.
    OTP must be verified before calling this endpoint.
    """
    if request.content_type and 'multipart' in request.content_type:
        data  = request.form.to_dict(flat=True)
        files = request.files
    else:
        data  = get_json_body()
        files = {}

    if data.get('otp_verified') != 'true':
        return api_error("Email must be verified with OTP first", status=400)

    required = ['first_name', 'last_name', 'email', 'password', 'phone', 'gender', 'role']
    missing  = [k for k in required if not str(data.get(k) or '').strip()]
    if missing:
        return api_error(
            f"Missing required fields: {', '.join(missing)}",
            status=400,
            data={"missing": missing},
        )

    role = str(data.get('role', 'buyer')).strip()
    if role not in ('buyer', 'seller', 'rider'):
        return api_error("Invalid role. Must be buyer, seller, or rider.", status=400)

    from services.auth_service import AuthService
    try:
        result = AuthService().register_user(data, files)
    except Exception as e:
        return api_error(f"Registration failed: {e}", status=500)

    if not result.get('success'):
        return api_error(result.get('error') or "Registration failed", status=400)

    return api_response(
        data={},
        message=result.get('message') or "Registration successful! Please wait for admin approval.",
        status=201,
    )


@auth_api_bp.route('/auth/send-otp', methods=['POST'])
def api_send_otp():
    data  = get_json_body()
    email = str(data.get('email') or '').strip().lower()
    if not email:
        return api_error("Email is required", status=400)

    try:
        import secrets
        import os
        import traceback
        from datetime import datetime, timezone, timedelta
        from supabase import create_client

        sb         = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
        otp        = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
        expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()
        otp_payload = {'email': email, 'otp': otp, 'expires_at': expires_at}

        # Write OTP to DB — try update first, insert if no existing row
        try:
            result = sb.table('email_otps').update(otp_payload).eq('email', email).execute()
            if not result.data:
                sb.table('email_otps').insert(otp_payload).execute()
        except Exception:
            # Fallback: delete then insert
            try:
                sb.table('email_otps').delete().eq('email', email).execute()
                sb.table('email_otps').insert(otp_payload).execute()
            except Exception as e:
                traceback.print_exc()
                return api_error("Failed to save OTP. Please try again.", status=500)

        from services.email_service import send_otp_email
        sent = send_otp_email(email, 'User', otp)

        if sent:
            return api_response(message="OTP sent to your email", status=200)
        return api_error("Failed to send OTP. Please try again.", status=500)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return api_error("Failed to send OTP. Please try again.", status=500)


@auth_api_bp.route('/auth/verify-otp', methods=['POST'])
def api_verify_otp():
    data  = get_json_body()
    email = str(data.get('email') or '').strip().lower()
    otp   = str(data.get('otp')   or '').strip()

    if not email or not otp:
        return api_error("Email and OTP are required", status=400)

    import os
    from datetime import datetime, timezone
    from supabase import create_client

    sb  = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    row = sb.table('email_otps').select('*').eq('email', email).eq('otp', otp).execute()

    if not row.data:
        return api_error("Invalid OTP", status=400)

    record     = row.data[0]
    expires_at = datetime.fromisoformat(record['expires_at'].replace('Z', '+00:00'))
    purpose    = str(data.get('purpose') or '').strip().lower()

    if datetime.now(timezone.utc) > expires_at:
        return api_error("OTP has expired. Please request a new one.", status=400)

    if purpose != 'password_reset':
        sb.table('email_otps').delete().eq('email', email).execute()

    return api_response(message="Email verified successfully", status=200)


@auth_api_bp.route('/auth/reset-password', methods=['POST'])
def api_reset_password():
    data         = get_json_body()
    email        = str(data.get('email') or '').strip().lower()
    otp          = str(data.get('otp') or '').strip()
    new_password = str(data.get('new_password') or '').strip()

    if not email or not otp or not new_password:
        return api_error("Email, OTP, and new password are required", status=400)

    import os
    from datetime import datetime, timezone
    from supabase import create_client
    from security import validate_password, hash_password
    from models.user_model import UserModel

    is_valid, error_msg = validate_password(new_password)
    if not is_valid:
        return api_error(error_msg, status=400)

    sb  = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    row = sb.table('email_otps').select('*').eq('email', email).eq('otp', otp).execute()
    if not row.data:
        return api_error("Invalid OTP", status=400)

    record     = row.data[0]
    expires_at = datetime.fromisoformat(record['expires_at'].replace('Z', '+00:00'))
    if datetime.now(timezone.utc) > expires_at:
        return api_error("OTP has expired. Please request a new one.", status=400)

    user_data = UserModel().get_by_email(email)
    if not user_data:
        return api_error("User not found", status=404)

    UserModel().update(user_data['id'], {
        'password':       hash_password(new_password),
        'failed_attempts': 0,
        'lock_until':      None,
    })
    sb.table('email_otps').delete().eq('email', email).execute()

    return api_response(message="Password reset successfully", status=200)


@auth_api_bp.route('/auth/reset_password', methods=['POST'])
def api_reset_password_alias():
    return api_reset_password()


@auth_api_bp.route('/auth/logout', methods=['POST'])
def api_logout():
    try:
        session.clear()
    except Exception:
        pass
    return api_response(message="Logged out", status=200)


@auth_api_bp.route('/profile/picture', methods=['POST'])
@token_required
def api_upload_profile_picture():
    """Upload/replace profile picture for any authenticated role."""
    user = get_current_user() or {}
    user_id = user.get('id')
    if not user_id:
        return api_error('Unauthorized', status=401)
    if 'photo' not in request.files:
        return api_error('No file provided', status=400)
    file = request.files['photo']
    if not file or not file.filename:
        return api_error('No file selected', status=400)
    try:
        from services.file_upload_service import FileUploadService
        from models.user_model import UserModel
        url = FileUploadService().save_file(file, subfolder=f'{user_id}', bucket_type='avatars')
        if not url:
            return api_error('Upload failed — invalid file or too large', status=400)
        UserModel().update(user_id, {'profile_picture': url})
        return api_response(data={'profile_picture': url}, message='Profile picture updated', status=200)
    except Exception as e:
        return api_error(f'Upload failed: {e}', status=500)


@auth_api_bp.route('/auth/me', methods=['GET'])
@token_required
def api_me():
    user = get_current_user() or {}
    try:
        from models.user_model import UserModel
        full = UserModel().get_by_id(user.get('id'))
        if full:
            user = {
                "id":              full.get('id'),
                "email":           full.get('email'),
                "first_name":      full.get('first_name'),
                "last_name":       full.get('last_name'),
                "phone":           full.get('phone'),
                "role":            full.get('role', 'user'),
                "profile_picture": full.get('profile_picture'),
                "name": (
                    f"{full.get('first_name', '')} {full.get('last_name', '')}"
                ).strip(),
            }
    except Exception:
        pass
    return api_response(data={"user": user}, message="OK", status=200)
