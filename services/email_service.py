import smtplib
import os
import secrets
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def _send(to_email: str, subject: str, html_body: str) -> bool:
    """Send an email. Returns True on success, False on failure."""
    try:
        # Priority: SendGrid > Resend > SMTP
        # SendGrid is more lenient with recipient domains
        sendgrid_key = os.getenv('SENDGRID_API_KEY', '')
        resend_key = os.getenv('RESEND_API_KEY', '')
        
        if sendgrid_key:
            return _send_via_sendgrid(to_email, subject, html_body, sendgrid_key)
        elif resend_key:
            return _send_via_resend(to_email, subject, html_body, resend_key)
        else:
            return _send_via_smtp(to_email, subject, html_body)
    except Exception as e:
        print(f'[EmailService] ERROR: {e}')
        import traceback
        traceback.print_exc()
        return False


def _send_via_resend(to_email: str, subject: str, html_body: str, api_key: str) -> bool:
    """Send email via Resend API (easiest option)."""
    try:
        import requests
        
        # Use verified domain or default to onboarding@resend.dev for testing
        verified_domain = os.getenv('RESEND_FROM_EMAIL', 'onboarding@resend.dev')
        
        payload = {
            "from": f"Grande Marketplace <{verified_domain}>",
            "to": [to_email],
            "subject": subject,
            "html": html_body
        }
        
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        print(f'[EmailService] Sending via Resend to {to_email}')
        response = requests.post(
            'https://api.resend.com/emails',
            json=payload,
            headers=headers,
            timeout=10
        )
        
        if response.status_code in (200, 201):
            result = response.json()
            email_id = result.get('id', 'unknown')
            print(f'[EmailService] SUCCESS: sent to {to_email} (ID: {email_id})')
            return True
        else:
            print(f'[EmailService] Resend Error: {response.status_code} - {response.text}')
            return False
    except Exception as e:
        print(f'[EmailService] Resend ERROR: {e}')
        import traceback
        traceback.print_exc()
        return False


def _send_via_sendgrid(to_email: str, subject: str, html_body: str, api_key: str) -> bool:
    """Send email via SendGrid API."""
    try:
        import requests
        sender = os.getenv('EMAIL_ADDRESS', 'noreply@grandemarket.com')
        
        payload = {
            "personalizations": [{"to": [{"email": to_email}]}],
            "from": {"email": sender, "name": "Grande Marketplace"},
            "subject": subject,
            "content": [{"type": "text/html", "value": html_body}]
        }
        
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        print(f'[EmailService] Sending via SendGrid to {to_email}')
        response = requests.post(
            'https://api.sendgrid.com/v3/mail/send',
            json=payload,
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 202:
            print(f'[EmailService] SUCCESS: sent to {to_email}')
            return True
        else:
            print(f'[EmailService] SendGrid Error: {response.status_code} - {response.text}')
            return False
    except Exception as e:
        print(f'[EmailService] SendGrid ERROR: {e}')
        import traceback
        traceback.print_exc()
        return False


def _send_via_smtp(to_email: str, subject: str, html_body: str) -> bool:
    """Send email via SMTP (Gmail). Only works locally or on paid hosting."""
    try:
        server   = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        port     = int(os.getenv('SMTP_PORT', 587))
        sender   = os.getenv('EMAIL_ADDRESS', '')
        password = os.getenv('EMAIL_PASSWORD', '')

        if not sender or not password:
            print('[EmailService] ERROR: EMAIL_ADDRESS or EMAIL_PASSWORD not configured')
            return False

        print(f'[EmailService] Sending to {to_email} via {server}:{port}')

        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From']    = f'Grande Marketplace <{sender}>'
        msg['To']      = to_email
        msg.attach(MIMEText(html_body, 'html'))

        if port == 465:
            with smtplib.SMTP_SSL(server, port, timeout=10) as smtp:
                smtp.login(sender, password)
                smtp.sendmail(sender, to_email, msg.as_string())
        else:
            with smtplib.SMTP(server, port, timeout=10) as smtp:
                smtp.starttls()
                smtp.login(sender, password)
                smtp.sendmail(sender, to_email, msg.as_string())
        
        print(f'[EmailService] SUCCESS: sent to {to_email}')
        return True
    except smtplib.SMTPAuthenticationError as e:
        print(f'[EmailService] AUTH ERROR: {e}')
        print('[EmailService] Check: 1) App password correct, 2) 2-Step Verification enabled')
        return False
    except smtplib.SMTPException as e:
        print(f'[EmailService] SMTP ERROR: {e}')
        return False
    except Exception as e:
        print(f'[EmailService] ERROR: {e}')
        import traceback
        traceback.print_exc()
        return False


def send_order_confirmation(to_email: str, buyer_name: str, order: dict, items: list) -> bool:
    """Send order confirmation email to buyer after checkout."""
    order_id      = (order.get('id') or '')[:8].upper()
    total         = float(order.get('total_amount', 0))
    payment       = (order.get('payment_method') or 'cod').replace('_', ' ').title()
    address       = order.get('shipping_address') or order.get('address') or ''
    
    # Handle address as string or dict
    if isinstance(address, dict):
        address_str = ', '.join(filter(None, [
            address.get('street'), address.get('barangay'),
            address.get('city'),   address.get('region')
        ]))
    else:
        address_str = str(address) if address else 'See account'

    rows = ''
    for item in items:
        product = item.get('product') or {}
        name    = product.get('name', 'Product')
        qty     = item.get('quantity', 1)
        price   = float(item.get('unit_price', 0))
        rows += f'''
        <tr>
            <td style="padding:10px 12px;border-bottom:1px solid #f0f0f0">{name}</td>
            <td style="padding:10px 12px;border-bottom:1px solid #f0f0f0;text-align:center">{qty}</td>
            <td style="padding:10px 12px;border-bottom:1px solid #f0f0f0;text-align:right">&#8369;{price:,.2f}</td>
            <td style="padding:10px 12px;border-bottom:1px solid #f0f0f0;text-align:right">&#8369;{price * qty:,.2f}</td>
        </tr>'''

    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:600px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">

      <!-- Header -->
      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700;letter-spacing:-0.5px">Grande</h1>
        <p style="color:rgba(255,255,255,.85);margin:6px 0 0;font-size:14px">Order Confirmation</p>
      </div>

      <!-- Body -->
      <div style="padding:32px 40px">
        <p style="font-size:16px;color:#1a1a3e;margin:0 0 8px">Hi <strong>{buyer_name}</strong>,</p>
        <p style="font-size:14px;color:#6c757d;margin:0 0 24px">
          Thank you for your order! We've received it and it's now being reviewed by the seller.
        </p>

        <!-- Order Info -->
        <div style="background:#f8f9fa;border-radius:10px;padding:16px 20px;margin-bottom:24px">
          <table style="width:100%;border-collapse:collapse">
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Order ID</td>
              <td style="font-size:13px;font-weight:600;color:#1a1a3e;text-align:right">#{order_id}</td>
            </tr>
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Payment</td>
              <td style="font-size:13px;font-weight:600;color:#1a1a3e;text-align:right">{payment}</td>
            </tr>
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Deliver to</td>
              <td style="font-size:13px;font-weight:600;color:#1a1a3e;text-align:right">{address_str or 'See account'}</td>
            </tr>
          </table>
        </div>

        <!-- Items Table -->
        <table style="width:100%;border-collapse:collapse;margin-bottom:16px">
          <thead>
            <tr style="background:#f8f9fa">
              <th style="padding:10px 12px;text-align:left;font-size:12px;color:#6c757d;font-weight:600;text-transform:uppercase">Item</th>
              <th style="padding:10px 12px;text-align:center;font-size:12px;color:#6c757d;font-weight:600;text-transform:uppercase">Qty</th>
              <th style="padding:10px 12px;text-align:right;font-size:12px;color:#6c757d;font-weight:600;text-transform:uppercase">Price</th>
              <th style="padding:10px 12px;text-align:right;font-size:12px;color:#6c757d;font-weight:600;text-transform:uppercase">Subtotal</th>
            </tr>
          </thead>
          <tbody>{rows}</tbody>
          <tfoot>
            <tr>
              <td colspan="3" style="padding:12px;text-align:right;font-weight:700;font-size:15px;color:#1a1a3e">Total</td>
              <td style="padding:12px;text-align:right;font-weight:700;font-size:15px;color:#FF2BAC">&#8369;{total:,.2f}</td>
            </tr>
          </tfoot>
        </table>

        <p style="font-size:13px;color:#6c757d;margin:0">
          You can track your order status anytime from your
          <a href="#" style="color:#FF2BAC;text-decoration:none;font-weight:600">Orders page</a>.
        </p>
      </div>

      <!-- Footer -->
      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">
          &copy; 2026 Grande Marketplace &mdash; This is an automated email, please do not reply.
        </p>
      </div>
    </div>
    </body>
    </html>'''

    return _send(to_email, f'Order Confirmed #{order_id} — Grande', html)


def send_order_status_update(to_email: str, buyer_name: str, order_id: str, status: str) -> bool:
    """Send order status update email to buyer."""
    status_messages = {
        'pending': {'title': 'Order Received', 'message': 'Your order is pending seller confirmation', 'icon': '⏳'},
        'processing': {'title': 'Order Accepted', 'message': 'The seller is preparing your order', 'icon': '📦'},
        'ready_for_pickup': {'title': 'Ready for Pickup', 'message': 'Your order is ready and waiting for our rider', 'icon': '✅'},
        'in_transit': {'title': 'Out for Delivery', 'message': 'Your order is on the way!', 'icon': '🚚'},
        'delivered': {'title': 'Order Delivered', 'message': 'Your order has been successfully delivered', 'icon': '🎉'},
        'cancelled': {'title': 'Order Cancelled', 'message': 'Your order has been cancelled', 'icon': '❌'},
    }
    
    status_info = status_messages.get(status, status_messages['pending'])
    short_id = order_id[:8].upper() if len(order_id) >= 8 else order_id.upper()
    
    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:600px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">
      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700">Grande</h1>
        <p style="color:rgba(255,255,255,.85);margin:6px 0 0;font-size:14px">Order Status Update</p>
      </div>
      <div style="padding:32px 40px;text-align:center">
        <div style="font-size:64px;margin-bottom:20px">{status_info['icon']}</div>
        <h2 style="color:#FF2BAC;margin:0 0 10px;font-size:24px">{status_info['title']}</h2>
        <p style="font-size:16px;color:#6c757d;margin:0 0 20px">{status_info['message']}</p>
        <p style="font-size:14px;color:#adb5bd">Order #{short_id}</p>
      </div>
      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">
          &copy; 2026 Grande Marketplace &mdash; This is an automated email, please do not reply.
        </p>
      </div>
    </div>
    </body>
    </html>'''
    
    return _send(to_email, f'{status_info["icon"]} {status_info["title"]} - Order #{short_id}', html)


def send_seller_new_order(to_email: str, seller_name: str, order_id: str, customer_name: str, total: float, payment_method: str) -> bool:
    """Send new order notification to seller."""
    short_id = order_id[:8].upper() if len(order_id) >= 8 else order_id.upper()
    payment = payment_method.replace('_', ' ').title()
    
    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:600px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">
      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700">🛍️ New Order!</h1>
        <p style="color:rgba(255,255,255,.85);margin:6px 0 0;font-size:14px">You have received a new order</p>
      </div>
      <div style="padding:32px 40px">
        <p style="font-size:16px;color:#1a1a3e;margin:0 0 8px">Hi <strong>{seller_name}</strong>,</p>
        <p style="font-size:14px;color:#6c757d;margin:0 0 24px">Great news! You have received a new order. Please review and accept it as soon as possible.</p>
        
        <div style="background:#f8f9fa;border-radius:10px;padding:16px 20px;margin-bottom:24px;border-left:4px solid #FF2BAC">
          <table style="width:100%;border-collapse:collapse">
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Order ID</td>
              <td style="font-size:13px;font-weight:600;color:#1a1a3e;text-align:right">#{short_id}</td>
            </tr>
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Customer</td>
              <td style="font-size:13px;font-weight:600;color:#1a1a3e;text-align:right">{customer_name}</td>
            </tr>
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Total Amount</td>
              <td style="font-size:13px;font-weight:600;color:#FF2BAC;text-align:right">&#8369;{total:,.2f}</td>
            </tr>
            <tr>
              <td style="font-size:13px;color:#6c757d;padding:4px 0">Payment</td>
              <td style="font-size:13px;font-weight:600;color:#1a1a3e;text-align:right">{payment}</td>
            </tr>
          </table>
        </div>
        
        <div style="background:#fff3cd;padding:15px;border-radius:8px;border-left:4px solid #ffc107">
          <p style="margin:0;font-size:13px;color:#856404">⚡ <strong>Action Required:</strong> Please login to your seller dashboard to accept and process this order.</p>
        </div>
      </div>
      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">
          &copy; 2026 Grande Marketplace &mdash; This is an automated email, please do not reply.
        </p>
      </div>
    </div>
    </body>
    </html>'''
    
    return _send(to_email, f'🛍️ New Order Received #{short_id}', html)


def send_password_reset(to_email: str, name: str, reset_url: str) -> bool:
    """Send password reset link email."""
    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:520px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">

      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700">Grande</h1>
        <p style="color:rgba(255,255,255,.85);margin:6px 0 0;font-size:14px">Password Reset</p>
      </div>

      <div style="padding:32px 40px">
        <p style="font-size:16px;color:#1a1a3e;margin:0 0 8px">Hi <strong>{name}</strong>,</p>
        <p style="font-size:14px;color:#6c757d;margin:0 0 28px">
          We received a request to reset your password. Click the button below to set a new one.
          This link expires in <strong>1 hour</strong>.
        </p>

        <div style="text-align:center;margin-bottom:28px">
          <a href="{reset_url}"
             style="display:inline-block;background:linear-gradient(135deg,#FF2BAC,#FF6BCE);
                    color:#fff;text-decoration:none;padding:14px 36px;border-radius:10px;
                    font-size:15px;font-weight:700;letter-spacing:.3px">
            Reset My Password
          </a>
        </div>

        <p style="font-size:12px;color:#adb5bd;margin:0">
          If you didn't request this, you can safely ignore this email. Your password won't change.
        </p>
      </div>

      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">
          &copy; 2026 Grande Marketplace &mdash; This is an automated email, please do not reply.
        </p>
      </div>
    </div>
    </body>
    </html>'''

    return _send(to_email, 'Reset Your Password — Grande', html)


def send_otp_email(to_email: str, name: str, otp: str) -> bool:
    """Send OTP verification email."""
    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:520px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">

      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700">Grande</h1>
        <p style="color:rgba(255,255,255,.85);margin:6px 0 0;font-size:14px">Email Verification</p>
      </div>

      <div style="padding:32px 40px">
        <p style="font-size:16px;color:#1a1a3e;margin:0 0 8px">Hi <strong>{name}</strong>,</p>
        <p style="font-size:14px;color:#6c757d;margin:0 0 28px">
          Thank you for registering! Please verify your email address by entering the code below.
          This code expires in <strong>1 minute</strong>.
        </p>

        <div style="text-align:center;margin-bottom:28px">
          <div style="display:inline-block;background:#f8f9fa;border:2px dashed #FF2BAC;border-radius:12px;padding:20px 40px">
            <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:#FF2BAC;font-family:monospace">{otp}</span>
          </div>
        </div>

        <p style="font-size:12px;color:#adb5bd;margin:0">
          If you didn't request this, you can safely ignore this email.
        </p>
      </div>

      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">
          &copy; 2026 Grande Marketplace &mdash; This is an automated email, please do not reply.
        </p>
      </div>
    </div>
    </body>
    </html>'''

    return _send(to_email, 'Your Verification Code — Grande', html)


def send_cart_abandonment(to_email: str, name: str, cart_items: list) -> bool:
    """Send cart abandonment reminder email."""
    items_html = ''
    for item in cart_items[:3]:  # Show max 3 items
        product_name = item.get('name', 'Product')
        price = float(item.get('price', 0))
        items_html += f'''
        <div style="padding:12px 0;border-bottom:1px solid #f0f0f0">
          <p style="margin:0;font-size:14px;color:#1a1a3e;font-weight:600">{product_name}</p>
          <p style="margin:4px 0 0;font-size:13px;color:#FF2BAC;font-weight:600">&#8369;{price:,.2f}</p>
        </div>'''
    
    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:520px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">
      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700">🛒 Your Cart is Waiting!</h1>
      </div>
      <div style="padding:32px 40px">
        <p style="font-size:16px;color:#1a1a3e;margin:0 0 8px">Hi <strong>{name}</strong>,</p>
        <p style="font-size:14px;color:#6c757d;margin:0 0 24px">
          You left some items in your cart. Complete your purchase before they're gone!
        </p>
        {items_html}
        <div style="text-align:center;margin-top:28px">
          <a href="#" style="display:inline-block;background:linear-gradient(135deg,#FF2BAC,#FF6BCE);color:#fff;text-decoration:none;padding:14px 36px;border-radius:10px;font-size:15px;font-weight:700">Complete Purchase</a>
        </div>
      </div>
      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">&copy; 2026 Grande Marketplace</p>
      </div>
    </div>
    </body>
    </html>'''
    
    return _send(to_email, '🛒 Complete Your Purchase — Grande', html)


def send_welcome_email(to_email: str, name: str, user_type: str = 'buyer') -> bool:
    """Send welcome email to new users."""
    role_messages = {
        'buyer': {'title': 'Welcome to Grande!', 'message': 'Start shopping from local sellers in your area.'},
        'seller': {'title': 'Welcome, Seller!', 'message': 'Start listing your products and reach thousands of buyers.'},
        'rider': {'title': 'Welcome, Rider!', 'message': 'Start accepting delivery requests and earn money.'},
    }
    
    role_info = role_messages.get(user_type, role_messages['buyer'])
    
    html = f'''
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:0;background:#f4f4f8;font-family:Inter,Arial,sans-serif">
    <div style="max-width:520px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">
      <div style="background:linear-gradient(135deg,#FF2BAC,#FF6BCE);padding:32px 40px;text-align:center">
        <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700">🎉 {role_info['title']}</h1>
      </div>
      <div style="padding:32px 40px">
        <p style="font-size:16px;color:#1a1a3e;margin:0 0 8px">Hi <strong>{name}</strong>,</p>
        <p style="font-size:14px;color:#6c757d;margin:0 0 24px">
          Welcome to Grande Marketplace! {role_info['message']}
        </p>
        <div style="background:#f8f9fa;border-radius:10px;padding:20px;margin-bottom:24px">
          <p style="margin:0;font-size:13px;color:#6c757d">✅ Account verified</p>
          <p style="margin:8px 0 0;font-size:13px;color:#6c757d">✅ Profile created</p>
          <p style="margin:8px 0 0;font-size:13px;color:#6c757d">✅ Ready to go!</p>
        </div>
        <div style="text-align:center">
          <a href="#" style="display:inline-block;background:linear-gradient(135deg,#FF2BAC,#FF6BCE);color:#fff;text-decoration:none;padding:14px 36px;border-radius:10px;font-size:15px;font-weight:700">Get Started</a>
        </div>
      </div>
      <div style="background:#f8f9fa;padding:20px 40px;text-align:center;border-top:1px solid #f0f0f0">
        <p style="font-size:12px;color:#adb5bd;margin:0">&copy; 2026 Grande Marketplace</p>
      </div>
    </div>
    </body>
    </html>'''
    
    return _send(to_email, f'🎉 {role_info["title"]} — Grande', html)
