"""
/api/rider/* — Mobile rider endpoints (Bearer token auth).
"""

from flask import Blueprint, request
from routes.api.api_helpers import api_response, api_error, get_json_body, role_required

rider_api_bp = Blueprint('rider_api', __name__)


def _build_delivery_row(o, seller_info=None):
    """Flatten an order into a full rider delivery row with all map/popup fields."""
    address = o.get('shipping_address') or {}
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
        um = UserModel()
        addrs = um.get_addresses(seller_id)
        addr  = next((a for a in addrs if a.get('is_default')), addrs[0] if addrs else None)
        # fetch seller user for phone
        from supabase import create_client
        import os
        sb   = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
        user = sb.table('users').select('first_name,last_name,phone').eq('id', seller_id).single().execute()
        u    = user.data or {}
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
    except Exception:
        return {'store_name': product.get('name', '')}


@rider_api_bp.get('/rider/dashboard')
@role_required('rider')
def rider_dashboard():
    """Dashboard summary + all active/available deliveries for the map."""
    from supabase import create_client
    from datetime import datetime, timezone, timedelta
    from models.order_model import OrderModel
    import os

    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
    om = OrderModel()

    all_assigned = om.get_assigned_orders_for_rider(rider_id)   # in_transit + delivered
    available    = om.get_ready_for_pickup_orders()              # ready_for_pickup, no rider yet
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

    # recent_deliveries = active assigned + all available (for map pins)
    recent_deliveries = [
        _build_delivery_row(o, _get_seller_info(o.get('order_items') or []))
        for o in active + available
    ]

    return api_response(data={
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
    })


@rider_api_bp.get('/rider/deliveries')
@role_required('rider')
def rider_deliveries():
    """All deliveries visible to this rider: assigned + available."""
    from models.order_model import OrderModel

    rider_id = request.current_user['id']
    om = OrderModel()

    available = om.get_ready_for_pickup_orders()
    assigned  = om.get_assigned_orders_for_rider(rider_id)
    rows      = available + assigned

    result = []
    for o in rows:
        seller_info = _get_seller_info(o.get('order_items') or [])
        result.append(_build_delivery_row(o, seller_info))

    return api_response(data={'deliveries': result, 'count': len(result)})


@rider_api_bp.post('/rider/deliveries/<order_id>/accept')
@role_required('rider')
def rider_accept_delivery(order_id):
    from models.order_model import OrderModel
    rider_id = request.current_user['id']
    updated  = OrderModel().assign_rider(order_id, rider_id)
    if not updated:
        return api_error('Order no longer available', status=400)
    return api_response(message='Delivery accepted')


@rider_api_bp.post('/rider/deliveries/<order_id>/delivered')
@role_required('rider')
def rider_mark_delivered(order_id):
    from models.order_model import OrderModel
    rider_id = request.current_user['id']
    updated  = OrderModel().update_status_for_rider(order_id, rider_id, 'delivered')
    if not updated:
        return api_error('Cannot mark as delivered', status=400)
    return api_response(message='Marked as delivered')


@rider_api_bp.get('/rider/earnings')
@role_required('rider')
def rider_earnings():
    from supabase import create_client
    from datetime import datetime, timezone, timedelta
    import os

    rider_id = request.current_user['id']
    sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))

    rows = sb.table('rider_earnings').select(
        'amount, created_at, order:orders(id, total_amount)'
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
            'order_id':    (order.get('id') or '')[:8],
            'amount':      amt,
            'order_total': float(order.get('total_amount', 0)),
            'created_at':  row.get('created_at', ''),
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
