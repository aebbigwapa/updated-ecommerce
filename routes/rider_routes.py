from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from models.order_model import OrderModel
from datetime import datetime, timezone, timedelta
import json
import os

_sb = None
def _get_sb():
    global _sb
    if _sb is None:
        from supabase import create_client
        _sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    return _sb

DECLINE_REASONS = [
    'Too far from my location',
    'Vehicle issue',
    'Already at max capacity',
    'Order details unclear',
    'Other',
]

REPORT_REASONS = [
    'Customer unreachable',
    'Wrong address',
    'Customer refused delivery',
    'Damaged item',
    'Safety concern',
    'Other',
]


def rider_required(f):
    from functools import wraps

    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('auth.login'))
        if session['user'].get('role') != 'rider':
            return redirect(url_for('index'))
        return f(*args, **kwargs)

    return decorated


rider_bp = Blueprint('rider', __name__)
order_model = OrderModel()


@rider_bp.route('/')
@rider_required
def dashboard():
    return render_template('rider/dashboard.html')


@rider_bp.route('/deliveries')
@rider_required
def deliveries():
    return render_template('rider/deliveries.html')


@rider_bp.route('/earnings')
@rider_required
def earnings():
    return render_template('rider/earnings.html')


@rider_bp.route('/profile')
@rider_required
def profile():
    return render_template('rider/profile.html')


@rider_bp.route('/api/deliveries', methods=['GET'])
@rider_required
def api_deliveries():
    rider_id = session['user']['id']
    available = order_model.get_ready_for_pickup_orders()
    assigned = order_model.get_assigned_orders_for_rider(rider_id)
    rows = available + assigned

    for row in rows:
        buyer = row.get('buyer') or {}
        row['customer_name'] = f"{buyer.get('first_name', '')} {buyer.get('last_name', '')}".strip()
        
        # Enhanced address handling with coordinates
        address = row.get('shipping_address') or {}
        if isinstance(address, str):
            try:
                address = json.loads(address)
            except:
                address = {}
        row['address'] = ", ".join(
            [str(x) for x in [address.get('street'), address.get('barangay'), address.get('city'), address.get('region')] if x]
        )
        
        # Add delivery coordinates
        row['delivery_latitude'] = address.get('latitude')
        row['delivery_longitude'] = address.get('longitude')
        row['delivery_full_address'] = {
            'street': address.get('street', ''),
            'barangay': address.get('barangay', ''),
            'city': address.get('city', ''),
            'region': address.get('region', ''),
            'latitude': address.get('latitude'),
            'longitude': address.get('longitude')
        }
        
        # Get seller information and address
        items = row.get('order_items') or []
        if items:
            product = items[0].get('product') or {}
            seller_id = product.get('seller_id')
            row['store_name'] = product.get('name', 'Store')
            
            # Fetch seller address with coordinates
            if seller_id:
                from models.user_model import UserModel
                user_model = UserModel()
                seller_addresses = user_model.get_addresses(seller_id)
                
                # Get default address or first available
                seller_address = None
                for addr in seller_addresses:
                    if addr.get('is_default'):
                        seller_address = addr
                        break
                if not seller_address and seller_addresses:
                    seller_address = seller_addresses[0]
                
                if seller_address:
                    row['pickup_latitude'] = seller_address.get('latitude')
                    row['pickup_longitude'] = seller_address.get('longitude')
                    row['pickup_full_address'] = {
                        'street': seller_address.get('street', ''),
                        'barangay': seller_address.get('barangay', ''),
                        'city': seller_address.get('city', ''),
                        'region': seller_address.get('region', ''),
                        'latitude': seller_address.get('latitude'),
                        'longitude': seller_address.get('longitude')
                    }
                    row['pickup_address'] = ", ".join([
                        str(x) for x in [
                            seller_address.get('street'),
                            seller_address.get('barangay'),
                            seller_address.get('city'),
                            seller_address.get('region')
                        ] if x
                    ])
        else:
            row['store_name'] = 'Store'
    
    return jsonify(rows)


@rider_bp.route('/api/deliveries/<order_id>/accept', methods=['POST'])
@rider_required
def api_accept_delivery(order_id):
    rider_id = session['user']['id']
    updated = order_model.assign_rider(order_id, rider_id)
    if not updated:
        return jsonify({'error': 'Order is no longer available for pickup'}), 400

    buyer_id = updated.get('buyer_id')
    if buyer_id:
        try:
            from models.notification_model import NotificationModel
            notification_model = NotificationModel()
            notification_model.create(
                user_id=buyer_id,
                notif_type='status_update',
                title='Delivery Started',
                message=f'Your order #{order_id[:8].upper()} is now out for delivery.',
                action_url=f'/buyer/orders#{order_id}',
                data_payload={'order_id': order_id, 'new_status': 'in_transit'}
            )
        except Exception as e:
            print(f'Error creating delivery notification: {e}')

    return jsonify({'success': True, 'order': updated})


@rider_bp.route('/api/deliveries/<order_id>/locations', methods=['GET'])
@rider_required
def api_delivery_locations(order_id):
    """Get detailed location information for a specific delivery"""
    order = order_model.get_by_id(order_id)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    
    # Get delivery address (buyer)
    delivery_address = order.get('shipping_address', {})
    if isinstance(delivery_address, str):
        try:
            delivery_address = json.loads(delivery_address)
        except:
            delivery_address = {}
    
    # Get pickup address (seller)
    pickup_address = None
    order_items = order.get('order_items', [])
    
    if order_items:
        product = order_items[0].get('product', {})
        seller_id = product.get('seller_id')
        
        if seller_id:
            from models.user_model import UserModel
            user_model = UserModel()
            seller_addresses = user_model.get_addresses(seller_id)
            
            # Get default address or first available
            for addr in seller_addresses:
                if addr.get('is_default'):
                    pickup_address = addr
                    break
            if not pickup_address and seller_addresses:
                pickup_address = seller_addresses[0]
    
    response_data = {
        'order_id': order_id,
        'pickup_location': {
            'latitude': pickup_address.get('latitude') if pickup_address else None,
            'longitude': pickup_address.get('longitude') if pickup_address else None,
            'address': {
                'street': pickup_address.get('street', '') if pickup_address else '',
                'barangay': pickup_address.get('barangay', '') if pickup_address else '',
                'city': pickup_address.get('city', '') if pickup_address else '',
                'region': pickup_address.get('region', '') if pickup_address else ''
            },
            'formatted_address': ", ".join([
                str(x) for x in [
                    pickup_address.get('street'),
                    pickup_address.get('barangay'),
                    pickup_address.get('city'),
                    pickup_address.get('region')
                ] if x
            ]) if pickup_address else 'Address not available'
        },
        'delivery_location': {
            'latitude': delivery_address.get('latitude'),
            'longitude': delivery_address.get('longitude'),
            'address': {
                'street': delivery_address.get('street', ''),
                'barangay': delivery_address.get('barangay', ''),
                'city': delivery_address.get('city', ''),
                'region': delivery_address.get('region', '')
            },
            'formatted_address': ", ".join([
                str(x) for x in [
                    delivery_address.get('street'),
                    delivery_address.get('barangay'),
                    delivery_address.get('city'),
                    delivery_address.get('region')
                ] if x
            ])
        }
    }
    
    return jsonify(response_data)


@rider_bp.route('/api/dashboard', methods=['GET'])
@rider_required
def api_rider_dashboard():
    """Rider dashboard: stats + earnings + chart + history in one call."""
    rider_id = session['user']['id']
    sb = _get_sb()

    all_assigned = order_model.get_assigned_orders_for_rider(rider_id)
    available    = order_model.get_ready_for_pickup_orders()
    completed    = [o for o in all_assigned if o.get('status') == 'delivered']
    active       = [o for o in all_assigned if o.get('status') == 'in_transit']

    # Fetch earnings with order details in one query
    earnings_rows = sb.table('rider_earnings').select(
        'amount, created_at, order:orders(id, total_amount, payment_method)'
    ).eq('rider_id', rider_id).order('created_at', desc=True).execute()

    now         = datetime.now(timezone.utc)
    today       = now.date()
    week_start  = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)

    total_earn = today_earn = week_earn = month_earn = 0.0
    history = []
    for row in (earnings_rows.data or []):
        amt   = float(row.get('amount', 0))
        total_earn += amt
        order = row.get('order') or {}
        d = _parse_date(row.get('created_at', ''))
        if d:
            if d == today:       today_earn += amt
            if d >= week_start:  week_earn  += amt
            if d >= month_start: month_earn += amt
        history.append({
            'order_id':       (order.get('id') or '')[:8],
            'amount':         amt,
            'order_total':    float(order.get('total_amount', 0)),
            'payment_method': order.get('payment_method', 'cod'),
            'created_at':     row.get('created_at', ''),
        })

    # Daily chart — last 7 days
    raw = earnings_rows.data or []
    chart = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        chart.append({'label': day.strftime('%m/%d'), 'value': sum(
            float(r.get('amount', 0)) for r in raw if _parse_date(r.get('created_at', '')) == day
        )})

    # Rider rate (cached after first fetch)
    settings = sb.table('admin_settings').select('value').eq('key', 'rider_rate').execute()
    rider_rate = float((settings.data or [{}])[0].get('value', 50))

    map_orders = active + available
    recent_deliveries = []
    for o in map_orders:
        address = o.get('shipping_address') or {}
        if isinstance(address, str):
            try:
                address = json.loads(address)
            except:
                address = {}
        buyer = o.get('buyer') or {}
        recent_deliveries.append({
            'id':                 o.get('id'),
            'status':             o.get('status'),
            'address':            ', '.join(str(x) for x in [
                                      address.get('street'), address.get('barangay'),
                                      address.get('city'), address.get('region')
                                  ] if x),
            'delivery_latitude':  address.get('latitude'),
            'delivery_longitude': address.get('longitude'),
            'customer_name':      f"{buyer.get('first_name','')} {buyer.get('last_name','')}".strip(),
            'shipping_address':   address,
        })

    return jsonify({
        'total_deliveries':     len(all_assigned),
        'completed_deliveries': len(completed),
        'active_deliveries':    len(active),
        'available_orders':     len(available),
        'total_earnings':       round(total_earn, 2),
        'today_earnings':       round(today_earn, 2),
        'week_earnings':        round(week_earn, 2),
        'month_earnings':       round(month_earn, 2),
        'rate_per_delivery':    rider_rate,
        'recent_deliveries':    recent_deliveries,
        'chart':                chart,
        'history':              history[:10],
    })


@rider_bp.route('/api/earnings', methods=['GET'])
@rider_required
def api_rider_earnings():
    """Rider earnings history with analytics."""
    rider_id = session['user']['id']
    sb = _get_sb()

    rows = sb.table('rider_earnings').select(
        'amount, created_at, order:orders(id, total_amount, payment_method)'
    ).eq('rider_id', rider_id).order('created_at', desc=True).execute()

    now         = datetime.now(timezone.utc)
    today       = now.date()
    week_start  = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)

    total = today_e = week_e = month_e = 0.0
    history = []
    for row in (rows.data or []):
        amt   = float(row.get('amount', 0))
        total += amt
        order = row.get('order') or {}
        try:
            d = datetime.fromisoformat(row['created_at'].replace('Z', '+00:00')).date()
            if d == today:       today_e += amt
            if d >= week_start:  week_e  += amt
            if d >= month_start: month_e += amt
        except Exception:
            d = None
        history.append({
            'order_id':       (order.get('id') or '')[:8],
            'amount':         amt,
            'order_total':    float(order.get('total_amount', 0)),
            'payment_method': order.get('payment_method', 'cod'),
            'created_at':     row.get('created_at', ''),
        })

    # Daily chart — last 7 days
    chart = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        day_total = sum(
            float(r.get('amount', 0)) for r in (rows.data or [])
            if _parse_date(r.get('created_at', '')) == day
        )
        chart.append({'label': day.strftime('%m/%d'), 'value': day_total})

    return jsonify({
        'total':        round(total, 2),
        'today':        round(today_e, 2),
        'week':         round(week_e, 2),
        'month':        round(month_e, 2),
        'deliveries':   len(history),
        'history':      history,
        'chart':        chart,
    })


def _parse_date(iso):
    try:
        return datetime.fromisoformat(iso.replace('Z', '+00:00')).date()
    except Exception:
        return None


# ── Availability toggle ────────────────────────────────────────
@rider_bp.route('/api/availability', methods=['GET', 'POST'])
@rider_required
def api_availability():
    rider_id = session['user']['id']
    sb = _get_sb()
    if request.method == 'GET':
        row = sb.table('users').select('is_available').eq('id', rider_id).single().execute()
        return jsonify({'is_available': (row.data or {}).get('is_available', True)})
    data = request.get_json() or {}
    sb.table('users').update({'is_available': bool(data.get('is_available', True))}).eq('id', rider_id).execute()
    return jsonify({'success': True, 'is_available': bool(data.get('is_available', True))})


# ── Performance stats ──────────────────────────────────────────
@rider_bp.route('/api/performance', methods=['GET'])
@rider_required
def api_performance():
    rider_id = session['user']['id']
    sb = _get_sb()
    all_assigned = order_model.get_assigned_orders_for_rider(rider_id)
    completed = [o for o in all_assigned if o.get('status') == 'delivered']

    # Ratings from reviews table
    reviews = sb.table('reviews').select('rating').eq('rider_id', rider_id).execute()
    ratings = [float(r['rating']) for r in (reviews.data or []) if r.get('rating')]
    avg_rating = round(sum(ratings) / len(ratings), 1) if ratings else None

    # Acceptance rate: accepted / (accepted + declined)
    declined = sb.table('rider_declines').select('id', count='exact').eq('rider_id', rider_id).execute()
    declined_count = declined.count or 0
    total_offered = len(all_assigned) + declined_count
    acceptance_rate = round((len(all_assigned) / total_offered * 100), 1) if total_offered else None

    return jsonify({
        'avg_rating':      avg_rating,
        'total_deliveries': len(all_assigned),
        'completed':       len(completed),
        'acceptance_rate': acceptance_rate,
        'late_percentage': None,  # extend when ETA tracking is added
    })


# ── Notifications ──────────────────────────────────────────────
@rider_bp.route('/api/notifications', methods=['GET'])
@rider_required
def api_notifications():
    from models.notification_model import NotificationModel
    rider_id = session['user']['id']
    notifs = NotificationModel().get_all(rider_id, limit=30)
    unread = sum(1 for n in notifs if not n.get('is_read'))
    return jsonify({'notifications': notifs, 'unread_count': unread})


@rider_bp.route('/api/notifications/read-all', methods=['POST'])
@rider_required
def api_notifications_read_all():
    from models.notification_model import NotificationModel
    NotificationModel().mark_all_as_read(session['user']['id'])
    return jsonify({'success': True})


# ── Decline order ──────────────────────────────────────────────
@rider_bp.route('/api/deliveries/<order_id>/decline', methods=['POST'])
@rider_required
def api_decline_delivery(order_id):
    rider_id = session['user']['id']
    data = request.get_json() or {}
    reason = data.get('reason', 'Declined')
    note   = data.get('note', '')
    sb = _get_sb()
    sb.table('rider_declines').insert({
        'rider_id': rider_id,
        'order_id': order_id,
        'reason':   reason,
        'note':     note,
    }).execute()
    return jsonify({'success': True})


# ── Report issue ───────────────────────────────────────────────
@rider_bp.route('/api/deliveries/<order_id>/report', methods=['POST'])
@rider_required
def api_report_issue(order_id):
    rider_id = session['user']['id']
    data = request.get_json() or {}
    reason = data.get('reason', 'Issue reported')
    note   = data.get('note', '')
    sb = _get_sb()
    sb.table('rider_reports').insert({
        'rider_id': rider_id,
        'order_id': order_id,
        'reason':   reason,
        'note':     note,
    }).execute()
    # Notify admin
    try:
        from models.notification_model import NotificationModel
        admins = sb.table('users').select('id').eq('role', 'admin').execute()
        nm = NotificationModel()
        for admin in (admins.data or []):
            nm.create(
                user_id=admin['id'],
                notif_type='status_update',
                title='Rider Issue Report',
                message=f'Rider reported an issue on order #{order_id[:8].upper()}: {reason}',
                action_url=f'/admin/orders',
                data_payload={'order_id': order_id, 'rider_id': rider_id}
            )
    except Exception as e:
        print(f'Error notifying admin: {e}')
    return jsonify({'success': True})


# ── Decline/Report reasons ─────────────────────────────────────
@rider_bp.route('/api/decline-reasons', methods=['GET'])
@rider_required
def api_decline_reasons():
    return jsonify({'decline': DECLINE_REASONS, 'report': REPORT_REASONS})


# ── Profile update ─────────────────────────────────────────────
@rider_bp.route('/api/profile', methods=['GET', 'POST'])
@rider_required
def api_profile():
    rider_id = session['user']['id']
    sb = _get_sb()
    if request.method == 'GET':
        row = sb.table('users').select('*').eq('id', rider_id).single().execute()
        u = row.data or {}
        meta = u.get('rider_meta') or {}
        return jsonify({
            'name':     f"{u.get('first_name','')} {u.get('last_name','')}".strip(),
            'email':    u.get('email', ''),
            'phone':    u.get('phone', '') or u.get('contact_number', ''),
            'vehicle':  meta.get('vehicle', {}),
            'license':  meta.get('license', {}),
            'schedule': meta.get('schedule', {}),
        })
    data = request.get_json() or {}
    update = {}
    if 'name' in data:
        parts = data['name'].strip().split(' ', 1)
        update['first_name'] = parts[0]
        update['last_name']  = parts[1] if len(parts) > 1 else ''
    if 'phone' in data:
        update['phone'] = data['phone']
    if 'vehicle' in data or 'license' in data or 'schedule' in data:
        row = sb.table('users').select('rider_meta').eq('id', rider_id).single().execute()
        meta = (row.data or {}).get('rider_meta') or {}
        if 'vehicle'  in data: meta['vehicle']  = data['vehicle']
        if 'license'  in data: meta['license']  = data['license']
        if 'schedule' in data: meta['schedule'] = data['schedule']
        update['rider_meta'] = meta
    if update:
        sb.table('users').update(update).eq('id', rider_id).execute()
        session['user']['name'] = data.get('name', session['user'].get('name', ''))
    return jsonify({'success': True})


@rider_bp.route('/api/deliveries/<order_id>/status', methods=['POST'])
@rider_required
def api_update_delivery_status(order_id):
    rider_id = session['user']['id']
    data = request.get_json() or {}
    status = data.get('status')
    updated = order_model.update_status_for_rider(order_id, rider_id, status)
    if not updated:
        return jsonify({'error': 'Unable to update delivery status'}), 400

    buyer_id = updated.get('buyer_id')
    if buyer_id:
        try:
            from models.notification_model import NotificationModel
            notification_model = NotificationModel()
            notification_model.create(
                user_id=buyer_id,
                notif_type='status_update',
                title='Order Delivered',
                message=f'Your order #{order_id[:8].upper()} has been delivered.',
                action_url=f'/buyer/orders#{order_id}',
                data_payload={'order_id': order_id, 'new_status': 'delivered'}
            )
        except Exception as e:
            print(f'Error creating delivery notification: {e}')

    return jsonify({'success': True, 'order': updated})


@rider_bp.route('/api/deliveries/<order_id>/proof', methods=['POST'])
@rider_required
def api_upload_proof_of_delivery(order_id):
    """Upload proof of delivery photo. Only assigned rider can upload."""
    from services.file_upload_service import FileUploadService
    from datetime import datetime, timezone
    
    rider_id = session['user']['id']
    
    # Verify rider is assigned to this order
    order = order_model.get_by_id(order_id)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    
    if order.get('rider_id') != rider_id:
        return jsonify({'error': 'You are not assigned to this delivery'}), 403
    
    # Only allow upload for in_transit orders
    if order.get('status') != 'in_transit':
        return jsonify({'error': 'Proof can only be uploaded for in-transit deliveries'}), 400
    
    # Check if file is provided
    if 'proof_image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    file = request.files['proof_image']
    if not file or not file.filename:
        return jsonify({'error': 'No image file selected'}), 400
    
    # Upload file
    file_service = FileUploadService()
    image_url = file_service.save_file(file, subfolder=f'deliveries/{order_id}')
    
    if not image_url:
        return jsonify({'error': 'Failed to upload image. Please ensure it is a valid image file (JPEG, PNG, WebP) under 8MB'}), 400
    
    # Update order with proof URL and timestamp
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        updated = order_model.supabase.table('orders').update({
            'proof_of_delivery_url': image_url,
            'proof_uploaded_at': now_iso
        }).eq('id', order_id).eq('rider_id', rider_id).execute()
        
        if not updated.data:
            return jsonify({'error': 'Failed to save proof of delivery'}), 500
        
        # Create notification for buyer
        from models.notification_model import NotificationModel
        notification_model = NotificationModel()
        buyer_id = order.get('buyer_id')
        if buyer_id:
            try:
                notification_model.create(
                    user_id=buyer_id,
                    notif_type='status_update',
                    title='Delivery Proof Uploaded',
                    message='Your rider has uploaded proof of delivery. Please confirm receipt of your order.',
                    action_url=f'/buyer/orders#{order_id}',
                    data_payload={'order_id': order_id, 'new_status': order.get('status'), 'proof_url': image_url}
                )
            except Exception as e:
                print(f"Error creating notification: {e}")

            try:
                from models.message_model import MessageModel
                from routes.messages_routes import _notify_chat_recipient

                msg_model = MessageModel()
                conv = msg_model.get_or_create_conversation(rider_id, buyer_id, order_id)
                if conv:
                    msg = msg_model.send_message(
                        conv['id'], rider_id, buyer_id,
                        'Proof of delivery has been uploaded. Please review the attached photo.',
                        attachment_url=image_url
                    )
                    if msg:
                        _notify_chat_recipient(
                            session['user'], buyer_id, conv['id'], order_id,
                            'Proof of delivery uploaded.'
                        )
            except Exception as e:
                print(f"Error sending proof of delivery chat message: {e}")
        
        return jsonify({
            'success': True,
            'proof_url': image_url,
            'uploaded_at': now_iso,
            'message': 'Proof of delivery uploaded successfully'
        })
    except Exception as e:
        return jsonify({'error': f'Failed to save proof: {str(e)}'}), 500
