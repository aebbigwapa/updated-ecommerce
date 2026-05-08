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


@auth_api_bp.post('/auth/login')
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
        data={'token': token, 'user': user},
        message='Login successful',
        status=200,
    )


@auth_api_bp.post('/auth/login-verify-otp')
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


@auth_api_bp.post('/auth/register')
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


@auth_api_bp.post('/auth/send-otp')
def api_send_otp():
    data  = get_json_body()
    email = str(data.get('email') or '').strip().lower()
    if not email:
        return api_error("Email is required", status=400)

    import secrets, os
    from datetime import datetime, timezone, timedelta
    from supabase import create_client

    sb         = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    otp        = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()

    sb.table('email_otps').upsert({'email': email, 'otp': otp, 'expires_at': expires_at}).execute()

    from services.email_service import send_otp_email
    sent = send_otp_email(email, 'User', otp)

    if sent:
        return api_response(message="OTP sent to your email", status=200)
    return api_error("Failed to send OTP. Please try again.", status=500)


@auth_api_bp.post('/auth/verify-otp')
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

    if datetime.now(timezone.utc) > expires_at:
        return api_error("OTP has expired. Please request a new one.", status=400)

    sb.table('email_otps').delete().eq('email', email).execute()

    return api_response(message="Email verified successfully", status=200)


@auth_api_bp.post('/auth/logout')
def api_logout():
    try:
        session.clear()
    except Exception:
        pass
    return api_response(message="Logged out", status=200)


@auth_api_bp.get('/auth/me')
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
