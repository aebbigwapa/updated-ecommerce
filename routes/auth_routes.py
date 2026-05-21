from flask import Blueprint, render_template, request, redirect, url_for, session, jsonify
from models.user_model import UserModel
from services.auth_service import AuthService
from security import rate_limit, generate_csrf_token, validate_password, check_login_lockout, record_failed_login, clear_login_attempts, get_login_delay, verify_recaptcha
import os
import time

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/debug-test')
def debug_test():
    return jsonify({'message': 'Debug test working'})


def _get_auth_service():
    return AuthService()

def _normalize_field(value):
    if isinstance(value, (list, tuple)):
        value = value[0] if value else ''
    if value is None:
        return ''
    return str(value)

@auth_bp.route('/captcha-page')
def captcha_page():
    """Serves reCAPTCHA v2 page for Flutter mobile WebView."""
    site_key = os.getenv('RECAPTCHA_SITE_KEY', '')
    html = f'''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{ background: #fff; display: flex; justify-content: center;
            align-items: center; min-height: 100vh; padding: 8px; }}
  </style>
</head>
<body>
  <div class="g-recaptcha"
       data-sitekey="{site_key}"
       data-callback="onVerified"
       data-expired-callback="onExpired">
  </div>
  <script src="https://www.google.com/recaptcha/api.js" async defer></script>
  <script>
    function onVerified(token) {{ CaptchaChannel.postMessage(token); }}
    function onExpired()        {{ CaptchaChannel.postMessage('expired'); }}
  </script>
</body>
</html>'''
    from flask import Response
    return Response(html, mimetype='text/html')


@auth_bp.route('/register', methods=['GET', 'POST'])
@rate_limit(max_calls=10, window_seconds=300)
def register():
    if request.method == 'POST':
        return _handle_registration()
    return render_template('auth/register.html', csrf_token=generate_csrf_token())

@auth_bp.route('/login', methods=['GET', 'POST'])
@rate_limit(max_calls=10, window_seconds=60)
def login():
    if request.method == 'POST':
        return _handle_login()
    return render_template('auth/login.html', csrf_token=generate_csrf_token())

@auth_bp.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

@auth_bp.route('/forgot-password', methods=['GET', 'POST'])
@rate_limit(max_calls=5, window_seconds=300)
def forgot_password():
    if request.method == 'GET':
        return render_template('auth/forgot_password.html', csrf_token=generate_csrf_token())

    data  = request.get_json(silent=True) or request.form
    email = _normalize_field(data.get('email')).strip().lower()
    
    if not email:
        return jsonify({'error': 'Email is required'}), 400

    user_model = UserModel()
    user = user_model.get_by_email(email)
    # Always return success to prevent email enumeration
    if not user:
        return jsonify({'success': True, 'message': 'If that email exists, a reset link has been sent.'})

    import uuid, secrets
    from datetime import datetime, timezone, timedelta
    from supabase import create_client
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))

    token      = secrets.token_urlsafe(32)
    expires_at = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    sb.table('password_reset_tokens').insert({
        'user_id':    user['id'],
        'token':      token,
        'expires_at': expires_at
    }).execute()

    reset_url = request.host_url.rstrip('/') + url_for('auth.reset_password', token=token)
    try:
        from services.email_service import send_password_reset
        sent = send_password_reset(
            to_email=email,
            name=f"{user.get('first_name','')} {user.get('last_name','')}".strip() or 'User',
            reset_url=reset_url
        )
        if not sent:
            print(f'Password reset email failed to send to {email}')
    except Exception as e:
        import traceback
        print(f'Password reset email error: {e}')
        traceback.print_exc()

    return jsonify({'success': True, 'message': 'If that email exists, a reset link has been sent.'})


@auth_bp.route('/send-otp', methods=['POST'])
@rate_limit(max_calls=5, window_seconds=60)
def send_otp():
    data = request.get_json(silent=True) or request.form
    email = _normalize_field(data.get('email')).strip().lower()
    if not email:
        return jsonify({'error': 'Email is required'}), 400

    from datetime import datetime, timezone, timedelta
    from supabase import create_client
    import secrets
    import traceback

    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))

    # Check resend count in session
    session_key = f'otp_resend_{email}'
    resend_count = session.get(session_key, 0)
    if resend_count >= 3:
        return jsonify({'error': 'Maximum resend attempts reached. Please wait or contact support.'}), 429

    # Check 60-second cooldown (stored in DB)
    try:
        existing = sb.table('email_otps').select('sent_at').eq('email', email).execute()
        if existing.data:
            sent_at_raw = existing.data[0].get('sent_at')
            if sent_at_raw:
                sent_at = datetime.fromisoformat(sent_at_raw.replace('Z', '+00:00'))
                elapsed = (datetime.now(timezone.utc) - sent_at).total_seconds()
                if elapsed < 60:
                    wait = int(60 - elapsed)
                    return jsonify({'error': f'Please wait {wait}s before requesting a new code.', 'wait': wait}), 429
    except Exception:
        pass  # sent_at column may not exist yet; skip cooldown check

    otp = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
    now_utc = datetime.now(timezone.utc)
    expires_at = (now_utc + timedelta(minutes=1)).isoformat()

    update_payload = {'otp': otp, 'expires_at': expires_at}
    insert_payload = {'email': email, 'otp': otp, 'expires_at': expires_at}
    try:
        update_payload['sent_at'] = now_utc.isoformat()
        insert_payload['sent_at'] = now_utc.isoformat()
    except Exception:
        pass

    # Write OTP to DB — try update first, insert if no existing row
    try:
        result = sb.table('email_otps').update(update_payload).eq('email', email).execute()
        if not result.data:
            sb.table('email_otps').insert(insert_payload).execute()
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': 'Failed to save OTP. Please try again.'}), 500

    # Send email
    try:
        from services.email_service import send_otp_email
        sent = send_otp_email(email, 'User', otp)
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': 'Failed to send OTP email. Please try again.'}), 500

    if sent:
        session[session_key] = resend_count + 1
        return jsonify({'success': True, 'message': 'OTP sent to your email', 'resend_count': resend_count + 1})
    return jsonify({'error': 'Failed to send OTP. Check your email address and try again.'}), 500


@auth_bp.route('/verify-otp', methods=['POST'])
@rate_limit(max_calls=10, window_seconds=60)
def verify_otp():
    data = request.get_json(silent=True) or request.form
    email = _normalize_field(data.get('email')).strip().lower()
    otp = _normalize_field(data.get('otp')).strip()

    if not email or not otp:
        return jsonify({'error': 'Email and OTP are required'}), 400

    from datetime import datetime, timezone
    from supabase import create_client

    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    row = sb.table('email_otps').select('*').eq('email', email).execute()

    if not row.data:
        return jsonify({'error': 'Invalid OTP'}), 400

    record = row.data[0]

    expires_at = datetime.fromisoformat(record['expires_at'].replace('Z', '+00:00'))
    if datetime.now(timezone.utc) > expires_at:
        return jsonify({'error': 'OTP has expired. Please request a new code.'}), 400

    if record['otp'] != otp:
        return jsonify({'error': 'Invalid OTP'}), 400

    sb.table('email_otps').delete().eq('email', email).execute()
    # Clear resend counter on successful verify
    session.pop(f'otp_resend_{email}', None)

    return jsonify({'success': True, 'message': 'Email verified successfully'})


@auth_bp.route('/reset-password/<token>', methods=['GET', 'POST'])
@rate_limit(max_calls=5, window_seconds=60)
def reset_password(token):
    from supabase import create_client
    from datetime import datetime, timezone
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))

    # Validate token
    row = sb.table('password_reset_tokens').select('*').eq('token', token).eq('used', False).limit(1).execute()
    if not row.data:
        return render_template('auth/reset_password.html', token=token, error='This reset link is invalid or has already been used.', csrf_token=generate_csrf_token())

    record = row.data[0]
    expires_at = datetime.fromisoformat(record['expires_at'].replace('Z', '+00:00'))
    if datetime.now(timezone.utc) > expires_at:
        return render_template('auth/reset_password.html', token=token, error='This reset link has expired. Please request a new one.', csrf_token=generate_csrf_token())

    if request.method == 'GET':
        return render_template('auth/reset_password.html', token=token, error=None, csrf_token=generate_csrf_token())

    data         = request.get_json(silent=True) or request.form
    new_password = _normalize_field(data.get('password')).strip()

    from security import hash_password, validate_password
    is_valid, error_msg = validate_password(new_password)
    if not is_valid:
        return jsonify({'error': error_msg}), 400

    user_model = UserModel()
    user_model.update(record['user_id'], {
        'password':       hash_password(new_password),
        'failed_attempts': 0,
        'lock_until':      None
    })
    sb.table('password_reset_tokens').update({'used': True}).eq('token', token).execute()

    return jsonify({'success': True, 'message': 'Password reset successfully. You can now log in.'})


@auth_bp.route('/test-route')
def test_route():
    """Test route to verify blueprint is loading."""
    return jsonify({'success': True, 'message': 'Blueprint is loading'})


@auth_bp.route('/terms-content')
def terms_content():
    """Serve Terms & Conditions content for modal."""
    try:
        return render_template('auth/terms_content.html')
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@auth_bp.route('/privacy-content')
def privacy_content():
    """Serve Privacy Policy content for modal."""
    try:
        return render_template('auth/privacy_content.html')
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def _handle_registration():
    try:
        # Server-side phone validation
        phone_error = _validate_phone_server(request.form)
        if phone_error:
            return jsonify({'error': phone_error}), 400

        result = _get_auth_service().register_user(request.form, request.files)
        if result.get('success'):
            return jsonify({'success': True, 'message': 'Registration successful! Please wait for admin approval.'})
        return jsonify({'error': result.get('error', 'Registration failed')}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# Whitelisted country codes and their allowed digit-length ranges (min, max)
_PHONE_RULES = {
    '+1':   (10, 10), '+44':  (10, 10), '+63':  (10, 10), '+91':  (10, 10),
    '+81':  (10, 10), '+86':  (11, 11), '+61':  (9,  9),  '+49':  (10, 11),
    '+33':  (9,  9),  '+7':   (10, 10), '+55':  (10, 11), '+65':  (8,  8),
    '+60':  (9,  10), '+66':  (9,  9),  '+82':  (9,  10), '+971': (9,  9),
    '+966': (9,  9),
}


def _validate_phone_server(form):
    """Returns an error string or None if valid."""
    import re
    raw_phone = _normalize_field(form.get('phone', '')).strip()
    if not raw_phone:
        return 'Phone number is required.'
    # Must start with + and contain only digits after
    if not re.match(r'^\+\d+$', raw_phone):
        return 'Invalid phone number for the selected country.'
    # Match against whitelisted country codes (longest prefix first)
    matched_code = None
    for code in sorted(_PHONE_RULES.keys(), key=len, reverse=True):
        if raw_phone.startswith(code):
            matched_code = code
            break
    if matched_code is None:
        # Unknown country code — apply safe default range 4–15
        local_digits = raw_phone[1:]  # strip leading +
        if not (4 <= len(local_digits) <= 15):
            return 'Invalid phone number for the selected country.'
        return None
    local_digits = raw_phone[len(matched_code):]
    if not re.match(r'^\d+$', local_digits):
        return 'Invalid phone number for the selected country.'
    min_len, max_len = _PHONE_RULES[matched_code]
    if not (min_len <= len(local_digits) <= max_len):
        return 'Invalid phone number for the selected country.'
    return None

def _handle_login():
    try:
        data = request.get_json(silent=True)
        if data is None:
            data = request.form
        if isinstance(data, (list, tuple)):
            data = data[0] if data else {}
        
        # Normalize email and password to handle tuple/list from form data
        email_raw = data.get('email')
        password_raw = data.get('password')
        
        if isinstance(email_raw, (list, tuple)):
            email_raw = email_raw[0] if email_raw else ''
        if isinstance(password_raw, (list, tuple)):
            password_raw = password_raw[0] if password_raw else ''
        
        email = str(email_raw).strip().lower() if email_raw else ''
        password = str(password_raw) if password_raw else ''
        captcha_response = _normalize_field(data.get('g-recaptcha-response'))
        
        from security import check_login_lockout, verify_recaptcha
        
        is_locked, lockout_msg = check_login_lockout(email)
        if is_locked:
            return jsonify({'error': lockout_msg}), 403
        
        # Skip CAPTCHA for mobile API requests (token-based, no browser session)
        is_api = request.path.startswith('/api/')
        if not is_api:
            is_valid, captcha_error = verify_recaptcha(captcha_response)
            if not is_valid:
                return jsonify({'error': 'CAPTCHA verification failed. Please try again.'}), 400
        
        result = _get_auth_service().authenticate_user(email, password)
        
        # Rest of the function remains the same
        
        if result.get('success'):
            session['user'] = result['user']
            session.permanent = True  # persist across browser restarts
            from security import clear_login_attempts
            clear_login_attempts(email)
            role = result['user'].get('role', 'user')
            if role == 'admin':
                redirect_url = url_for('admin.dashboard')
            elif role == 'seller':
                redirect_url = url_for('seller.dashboard')
            elif role == 'buyer':
                redirect_url = url_for('index')
            elif role == 'rider':
                redirect_url = url_for('rider.dashboard')
            else:
                redirect_url = url_for('index')
            return jsonify({'success': True, 'redirect': redirect_url})
        
        return jsonify({'error': result.get('error', 'Invalid credentials')}), 401
    except Exception as e:
        import traceback
        print('Login error traceback:', traceback.format_exc())
        print('Login error:', str(e))
        return jsonify({'error': str(e)}), 500
