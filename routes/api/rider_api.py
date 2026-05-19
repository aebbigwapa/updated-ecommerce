"""
/api/rider/* — Mobile rider endpoints (Bearer token auth).
"""

from flask import Blueprint, request
from routes.api.api_helpers import api_response, api_error, get_json_body, role_required
import json

rider_api_bp = Blueprint('rider_api', __name__)


def _build_delivery_row(o, seller_info=None):
    """Flatten an order into a full rider delivery row with all map/popup fields."""
    address = o.get('shipping_address') or {}
    if isinstance(address, str):
        try:
            address = json.loads(address)
        except:
            address = {}
    buyer   = o.get('buyer') or {}
    items   = o.get('order_items') or []
    seller  = seller_info or {}

    addr_str = ', '.join(str(x) for x in [
        address.get('street'), address.get('barangay'),
        address.get('city'), address.get('region')
    ] if x)

    return {
        'id':                  o.get('id'),
        'status':              o.get('status'),
        'payment_method':      o.get('payment_method', 'cod'),
        'notes':               o.get('notes') or o.get('delivery_notes') or '',
        'total_amount':        float(o.get('total_amount') or 0),
        'items_count':         sum(int(i.get('quantity', 0) or 0) for i in items),
        # buyer / delivery
        'customer_name':       f"{buyer.get('first_name','')} {buyer.get('last_name','')}".strip(),
        'customer_phone':      buyer.get('phone') or buyer.get('contact_number') or '',
        'address':             addr_str,
        'shipping_address':    address,
        'delivery_latitude':   address.get('latitude'),
        'delivery_longitude':  address.get('longitude'),
        # seller / pickup
        'store_name':          seller.get('store_name', ''),
        'seller_phone':        seller.get('phone', ''),
        'pickup_address':      seller.get('pickup_address', ''),
        'pickup_latitude':     seller.get('pickup_latitude'),
        'pickup_longitude':    seller.get('pickup_longitude'),
        'order_status_label':  seller.get('order_status_label', o.get('status', '')),
    }


def _get_seller_info(items):
    """Fetch seller address + contact from the first order item's product."""
    if not items:
        return {}
    product   = items[0].get('product') or {}
    seller_id = product.get('seller_id')
    if not seller_id:
        return {'store_name': product.get('name', '')}
    try:
        from models.user_model import UserModel
        from supabase import create_client
        import os
        sb    = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
        um    = UserModel()
        addrs = um.get_addresses(seller_id)
        addr  = next((a for a in addrs if a.get('is_default')), addrs[0] if addrs else None)
        user  = sb.table('users').select('first_name,last_name,phone').eq('id', seller_id).single().execute()
        u     = user.data or {}
        store_name = f"{u.get('first_name','')} {u.get('last_name','')}".strip() or product.get('name', '')
        pickup_str = ''
        if addr:
            pickup_str = ', '.join(str(x) for x in [
                addr.get('street'), addr.get('barangay'),
                addr.get('city'), addr.get('region')
            ] if x)
        return {
            'store_name':          store_name,
            'phone':               u.get('phone', ''),
            'pickup_address':      pickup_str,
            'pickup_latitude':     addr.get('latitude') if addr else None,
            'pickup_longitude':    addr.get('longitude') if addr else None,
            'order_status_label':  product.get('status', ''),
        }
    except Exception as e:
        print(f'[_get_seller_info] error: {e}')
        return {'store_name': product.get('name', '')}


@rider_api_bp.get('/rider/dashboard')
@role_required('rider')
def rider_dashboard():
    from supabase import create_client
    from datetime import datetime, timezone, timedelta
    from models.order_model import OrderModel
    import os

    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    om = OrderModel()

    all_assigned = om.get_assigned_orders_for_rider(rider_id)
    available    = om.get_ready_for_pickup_orders()
    completed    = [o for o in all_assigned if o.get('status') == 'delivered']
    active       = [o for o in all_assigned if o.get('status') == 'in_transit']

    # Earnings
    rows = sb.table('rider_earnings').select('amount, created_at').eq('rider_id', rider_id).execute()
    now         = datetime.now(timezone.utc)
    today       = now.date()
    week_start  = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)

    total_earn = today_earn = week_earn = month_earn = 0.0
    for row in (rows.data or []):
        amt = float(row.get('amount', 0))
        total_earn += amt
        try:
            d = datetime.fromisoformat(row['created_at'].replace('Z', '+00:00')).date()
            if d == today:       today_earn += amt
            if d >= week_start:  week_earn  += amt
            if d >= month_start: month_earn += amt
        except Exception:
            pass

    settings   = sb.table('admin_settings').select('key,value').eq('key', 'rider_rate').execute()
    rider_rate = float((settings.data or [{}])[0].get('value', 50))

    # Batch fetch seller info for active + available orders
    map_rows = active + available
    seller_ids = list({
        (item.get('product') or {}).get('seller_id')
        for o in map_rows
        for item in (o.get('order_items') or [])
        if (item.get('product') or {}).get('seller_id')
    })
    seller_users = {}
    seller_addrs = {}
    if seller_ids:
        try:
            ur = sb.table('users').select('id,first_name,last_name,phone').in_('id', seller_ids).execute()
            for u in (ur.data or []):
                seller_users[u['id']] = u
        except Exception: pass
        try:
            ar = sb.table('addresses').select('*').in_('user_id', seller_ids).execute()
            for a in (ar.data or []):
                uid = a['user_id']
                if uid not in seller_addrs or a.get('is_default'):
                    seller_addrs[uid] = a
        except Exception: pass

    def _seller_fast(items):
        if not items: return {}
        product = items[0].get('product') or {}
        sid = product.get('seller_id')
        if not sid: return {'store_name': product.get('name', '')}
        u = seller_users.get(sid, {})
        addr = seller_addrs.get(sid)
        pickup_str = ''
        if addr:
            pickup_str = ', '.join(str(x) for x in [
                addr.get('street'), addr.get('barangay'),
                addr.get('city'), addr.get('region')
            ] if x)
        return {
            'store_name':      f"{u.get('first_name','')} {u.get('last_name','')}".strip() or product.get('name', ''),
            'phone':           u.get('phone', ''),
            'pickup_address':  pickup_str,
            'pickup_latitude':  addr.get('latitude') if addr else None,
            'pickup_longitude': addr.get('longitude') if addr else None,
        }

    recent_deliveries = [
        _build_delivery_row(o, _seller_fast(o.get('order_items') or []))
        for o in active + available
    ]

    return api_response(data={
        'total_deliveries':     len(all_assigned),
        'completed_deliveries': len(completed),
        'active_deliveries':    len(active),
        'available_orders':     len(available),
        'pending_deliveries':   len(available),
        'total_earnings':       round(total_earn, 2),
        'today_earnings':       round(today_earn, 2),
        'week_earnings':        round(week_earn, 2),
        'month_earnings':       round(month_earn, 2),
        'rate_per_delivery':    rider_rate,
        'recent_deliveries':    recent_deliveries,
    })


@rider_api_bp.get('/rider/deliveries')
@role_required('rider')
def rider_deliveries():
    """All deliveries visible to this rider: assigned + available."""
    from models.order_model import OrderModel
    from supabase import create_client
    import os

    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    om = OrderModel()

    available = om.get_ready_for_pickup_orders()
    assigned  = om.get_assigned_orders_for_rider(rider_id)
    rows      = available + assigned

    if not rows:
        return api_response(data={'deliveries': [], 'count': 0})

    # Collect all unique seller_ids in one pass
    seller_ids = list({
        (item.get('product') or {}).get('seller_id')
        for o in rows
        for item in (o.get('order_items') or [])
        if (item.get('product') or {}).get('seller_id')
    })

    # Batch fetch all seller users + addresses in 2 queries total
    seller_users = {}
    seller_addrs = {}
    if seller_ids:
        try:
            users_res = sb.table('users').select('id,first_name,last_name,phone').in_('id', seller_ids).execute()
            for u in (users_res.data or []):
                seller_users[u['id']] = u
        except Exception as e:
            print(f'[rider_deliveries] seller users fetch error: {e}')
        try:
            addrs_res = sb.table('addresses').select('*').in_('user_id', seller_ids).execute()
            for a in (addrs_res.data or []):
                uid = a['user_id']
                if uid not in seller_addrs or a.get('is_default'):
                    seller_addrs[uid] = a
        except Exception as e:
            print(f'[rider_deliveries] seller addrs fetch error: {e}')

    def get_seller_info_fast(items):
        if not items:
            return {}
        product   = items[0].get('product') or {}
        seller_id = product.get('seller_id')
        if not seller_id:
            return {'store_name': product.get('name', '')}
        u    = seller_users.get(seller_id, {})
        addr = seller_addrs.get(seller_id)
        store_name = f"{u.get('first_name','')} {u.get('last_name','')}".strip() or product.get('name', '')
        pickup_str = ''
        if addr:
            pickup_str = ', '.join(str(x) for x in [
                addr.get('street'), addr.get('barangay'),
                addr.get('city'), addr.get('region')
            ] if x)
        return {
            'store_name':      store_name,
            'phone':           u.get('phone', ''),
            'pickup_address':  pickup_str,
            'pickup_latitude':  addr.get('latitude') if addr else None,
            'pickup_longitude': addr.get('longitude') if addr else None,
        }

    result = [_build_delivery_row(o, get_seller_info_fast(o.get('order_items') or [])) for o in rows]
    return api_response(data={'deliveries': result, 'count': len(result)})


@rider_api_bp.post('/rider/deliveries/<order_id>/accept')
@role_required('rider')
def rider_accept_delivery(order_id):
    from models.order_model import OrderModel
    from models.notification_model import NotificationModel
    rider_id = request.current_user['id']
    updated  = OrderModel().assign_rider(order_id, rider_id)
    if not updated:
        return api_error('Order no longer available for pickup', status=400)
    buyer_id = updated.get('buyer_id')
    if buyer_id:
        try:
            NotificationModel().create(
                user_id=buyer_id,
                notif_type='status_update',
                title='Rider On The Way',
                message=f'Your order #{order_id[:8].upper()} has been picked up and is out for delivery.',
                action_url=f'/buyer/orders#{order_id}',
                data_payload={'order_id': order_id, 'new_status': 'in_transit'}
            )
        except Exception as e:
            print(f'Error notifying buyer on accept: {e}')
    # Auto-create rider <-> buyer conversation
    try:
        from models.message_model import MessageModel
        # Resolve seller_id from order items
        items = updated.get('order_items') or []
        seller_id = ((items[0].get('product') or {}).get('seller_id')) if items else None
        MessageModel().ensure_order_conversations(
            order_id=order_id,
            status='in_transit',
            buyer_id=buyer_id,
            seller_id=seller_id,
            rider_id=rider_id,
        )
    except Exception as e:
        print(f'[rider_accept_delivery] chat creation error: {e}')
    return api_response(data={'order_id': order_id, 'status': 'in_transit'}, message='Delivery accepted')


@rider_api_bp.post('/rider/deliveries/<order_id>/delivered')
@role_required('rider')
def rider_mark_delivered(order_id):
    from models.order_model import OrderModel
    rider_id = request.current_user['id']
    updated  = OrderModel().update_status_for_rider(order_id, rider_id, 'delivered')
    if not updated:
        return api_error('Cannot mark as delivered', status=400)
    return api_response(message='Marked as delivered')


@rider_api_bp.post('/rider/deliveries/<order_id>/decline')
@role_required('rider')
def rider_decline_delivery(order_id):
    from supabase import create_client
    import os
    rider_id = request.current_user['id']
    data = get_json_body()
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    sb.table('rider_declines').insert({
        'rider_id': rider_id, 'order_id': order_id,
        'reason': data.get('reason', 'Declined'), 'note': data.get('note', ''),
    }).execute()
    return api_response(message='Order declined')


@rider_api_bp.post('/rider/deliveries/<order_id>/report')
@role_required('rider')
def rider_report_issue(order_id):
    from supabase import create_client
    import os
    rider_id = request.current_user['id']
    data = get_json_body()
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    sb.table('rider_reports').insert({
        'rider_id': rider_id, 'order_id': order_id,
        'reason': data.get('reason', 'Issue reported'), 'note': data.get('note', ''),
    }).execute()
    try:
        from models.notification_model import NotificationModel
        admins = sb.table('users').select('id').eq('role', 'admin').execute()
        nm = NotificationModel()
        for admin in (admins.data or []):
            nm.create(
                user_id=admin['id'], notif_type='status_update',
                title='Rider Issue Report',
                message=f'Rider reported an issue on order #{order_id[:8].upper()}: {data.get("reason","")}',
                action_url='/admin/orders',
                data_payload={'order_id': order_id, 'rider_id': rider_id}
            )
    except Exception as e:
        print(f'Error notifying admin: {e}')
    return api_response(message='Issue reported')


@rider_api_bp.post('/rider/deliveries/<order_id>/proof')
@role_required('rider')
def rider_upload_proof(order_id):
    from services.file_upload_service import FileUploadService
    from models.order_model import OrderModel
    from models.notification_model import NotificationModel
    from datetime import datetime, timezone
    rider_id = request.current_user['id']
    order = OrderModel().get_by_id(order_id)
    if not order:
        return api_error('Order not found', status=404)
    if order.get('rider_id') != rider_id:
        return api_error('Not assigned to this delivery', status=403)
    if order.get('status') != 'in_transit':
        return api_error('Proof can only be uploaded for in-transit deliveries', status=400)
    if 'proof_image' not in request.files:
        return api_error('No image file provided', status=400)
    file = request.files['proof_image']
    if not file or not file.filename:
        return api_error('No image file selected', status=400)
    image_url = FileUploadService().save_file(file, subfolder=f'deliveries/{order_id}')
    if not image_url:
        return api_error('Failed to upload image', status=400)
    from supabase import create_client
    import os
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    now_iso = datetime.now(timezone.utc).isoformat()
    sb.table('orders').update({'proof_of_delivery_url': image_url, 'proof_uploaded_at': now_iso}).eq('id', order_id).eq('rider_id', rider_id).execute()
    buyer_id = order.get('buyer_id')
    if buyer_id:
        try:
            NotificationModel().create(
                user_id=buyer_id, notif_type='status_update',
                title='Delivery Proof Uploaded',
                message='Your rider has uploaded proof of delivery.',
                action_url=f'/buyer/orders#{order_id}',
                data_payload={'order_id': order_id, 'proof_url': image_url}
            )
        except Exception as e:
            print(f'Error creating notification: {e}')

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
                        request.current_user, buyer_id, conv['id'], order_id,
                        'Proof of delivery uploaded.'
                    )
        except Exception as e:
            print(f'Error sending proof of delivery chat message: {e}')

    return api_response(data={'proof_url': image_url, 'uploaded_at': now_iso}, message='Proof uploaded')


@rider_api_bp.get('/rider/decline-reasons')
@role_required('rider')
def rider_decline_reasons():
    return api_response(data={
        'decline': ['Too far from my location', 'Vehicle issue', 'Already at max capacity', 'Order details unclear', 'Other'],
        'report':  ['Customer unreachable', 'Wrong address', 'Customer refused delivery', 'Damaged item', 'Safety concern', 'Other'],
    })


@rider_api_bp.route('/rider/availability', methods=['GET', 'POST'])
@role_required('rider')
def rider_availability():
    from supabase import create_client
    import os
    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    if request.method == 'GET':
        try:
            row = sb.table('users').select('is_available').eq('id', rider_id).single().execute()
            return api_response(data={'is_available': (row.data or {}).get('is_available', True)})
        except Exception:
            return api_response(data={'is_available': True})
    data = get_json_body()
    is_avail = bool(data.get('is_available', True))
    try:
        sb.table('users').update({'is_available': is_avail}).eq('id', rider_id).execute()
    except Exception as e:
        print(f'[rider_availability] column missing: {e}')
    return api_response(data={'is_available': is_avail})


@rider_api_bp.get('/rider/performance')
@role_required('rider')
def rider_performance():
    from supabase import create_client
    from models.order_model import OrderModel
    import os
    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    all_assigned = OrderModel().get_assigned_orders_for_rider(rider_id)
    completed = [o for o in all_assigned if o.get('status') == 'delivered']
    reviews = sb.table('reviews').select('rating').eq('rider_id', rider_id).execute()
    ratings = [float(r['rating']) for r in (reviews.data or []) if r.get('rating')]
    avg_rating = round(sum(ratings) / len(ratings), 1) if ratings else None
    declined = sb.table('rider_declines').select('id', count='exact').eq('rider_id', rider_id).execute()
    declined_count = declined.count or 0
    total_offered = len(all_assigned) + declined_count
    acceptance_rate = round((len(all_assigned) / total_offered * 100), 1) if total_offered else None
    return api_response(data={
        'avg_rating': avg_rating,
        'total_deliveries': len(all_assigned),
        'completed': len(completed),
        'acceptance_rate': acceptance_rate,
        'late_percentage': None,
    })


@rider_api_bp.get('/rider/notifications')
@role_required('rider')
def rider_notifications():
    from models.notification_model import NotificationModel
    rider_id = request.current_user['id']
    notifs = NotificationModel().get_all(rider_id, limit=30)
    unread = sum(1 for n in notifs if not n.get('is_read'))
    return api_response(data={'notifications': notifs, 'unread_count': unread})


@rider_api_bp.post('/rider/notifications/read-all')
@role_required('rider')
def rider_notifications_read_all():
    from models.notification_model import NotificationModel
    NotificationModel().mark_all_as_read(request.current_user['id'])
    return api_response(message='Marked all as read')


@rider_api_bp.route('/rider/profile', methods=['GET', 'POST'])
@role_required('rider')
def rider_profile():
    from supabase import create_client
    import os
    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    if request.method == 'GET':
        row = sb.table('users').select('*').eq('id', rider_id).single().execute()
        u = row.data or {}
        meta = u.get('rider_meta') or {}
        return api_response(data={
            'name':            f"{u.get('first_name','')} {u.get('last_name','')}".strip(),
            'email':           u.get('email', ''),
            'phone':           u.get('phone', '') or u.get('contact_number', ''),
            'profile_picture': u.get('profile_picture') or '',
            'vehicle':         meta.get('vehicle', {}),
            'license':         meta.get('license', {}),
            'schedule':        meta.get('schedule', {}),
        })
    data = get_json_body()
    update = {}
    if 'name' in data:
        parts = data['name'].strip().split(' ', 1)
        update['first_name'] = parts[0]
        update['last_name']  = parts[1] if len(parts) > 1 else ''
    if 'phone' in data:
        update['phone'] = data['phone']
    if any(k in data for k in ('vehicle', 'license', 'schedule')):
        row = sb.table('users').select('rider_meta').eq('id', rider_id).single().execute()
        meta = (row.data or {}).get('rider_meta') or {}
        for k in ('vehicle', 'license', 'schedule'):
            if k in data: meta[k] = data[k]
        update['rider_meta'] = meta
    if update:
        sb.table('users').update(update).eq('id', rider_id).execute()
    return api_response(message='Profile updated')


@rider_api_bp.get('/rider/earnings')
@role_required('rider')
def rider_earnings():
    from supabase import create_client
    from datetime import datetime, timezone, timedelta
    import os

    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))

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

    chart = []
    for i in range(6, -1, -1):
        day = today - timedelta(days=i)
        day_total = sum(
            float(r.get('amount', 0)) for r in (rows.data or [])
            if _parse_date(r.get('created_at', '')) == day
        )
        chart.append({'label': day.strftime('%m/%d'), 'value': day_total})

    return api_response(data={
        'total':       round(total, 2),
        'today':       round(today_e, 2),
        'week':        round(week_e, 2),
        'month':       round(month_e, 2),
        'deliveries':  len(history),
        'history':     history,
        'chart':       chart,
    })


def _parse_date(iso):
    from datetime import datetime, timezone
    try:
        return datetime.fromisoformat(iso.replace('Z', '+00:00')).date()
    except Exception:
        return None
