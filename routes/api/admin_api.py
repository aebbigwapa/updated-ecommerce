"""
/api/admin/* — Mobile admin endpoints (token-based auth).
Mirrors the session-based /admin/api/* routes but uses @role_required('admin').
"""

from flask import Blueprint, request
from routes.api.api_helpers import (
    api_response, api_error, get_json_body, role_required,
)

admin_api_bp = Blueprint('admin_api', __name__)


# ── Dashboard ────────────────────────────────────────────────────────────────

@admin_api_bp.get('/admin/dashboard')
@role_required('admin')
def admin_dashboard():
    try:
        from models.order_model import OrderModel
        from models.user_model import UserModel
        from models.product_model import ProductModel
        import os
        from supabase import create_client

        sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
        settings = sb.table('admin_settings').select('key,value').execute()
        rates = {r['key']: r['value'] for r in (settings.data or [])}
        commission_rate = float(rates.get('commission_rate', 5)) / 100

        all_orders = OrderModel().get_all()
        all_users  = UserModel().get_all()
        delivered  = [o for o in all_orders if o.get('status') == 'delivered']
        total_rev  = sum(float(o.get('total_amount', 0)) for o in delivered)

        status_counts = {}
        for o in all_orders:
            s = o.get('status', 'pending')
            status_counts[s] = status_counts.get(s, 0) + 1

        return api_response(data={
            'total_users':      len(all_users),
            'total_sellers':    len([u for u in all_users if u.get('role') == 'seller']),
            'total_riders':     len([u for u in all_users if u.get('role') == 'rider']),
            'total_buyers':     len([u for u in all_users if u.get('role') == 'buyer']),
            'total_orders':     len(all_orders),
            'delivered_orders': len(delivered),
            'total_revenue':    total_rev,
            'admin_commission': round(total_rev * commission_rate, 2),
            'commission_rate':  float(rates.get('commission_rate', 5)),
            'status_breakdown': status_counts,
        })
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


# ── Applications ─────────────────────────────────────────────────────────────

@admin_api_bp.get('/admin/applications')
@role_required('admin')
def admin_get_applications():
    try:
        from models.application_model import ApplicationModel
        apps = ApplicationModel().get_all()
        return api_response(data=apps)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@admin_api_bp.get('/admin/applications/<app_id>')
@role_required('admin')
def admin_get_application(app_id):
    try:
        from models.application_model import ApplicationModel
        app = ApplicationModel().get_by_id(app_id)
        if not app:
            return api_error('Not found', status=404)
        return api_response(data=app)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@admin_api_bp.post('/admin/applications/<app_id>/status')
@role_required('admin')
def admin_update_application_status(app_id):
    data   = get_json_body()
    status = data.get('status')
    notes  = data.get('notes', '')
    if status not in ('approved', 'rejected'):
        return api_error('Invalid status', status=400)
    try:
        from models.application_model import ApplicationModel
        from models.user_model import UserModel
        app_model  = ApplicationModel()
        application = app_model.get_by_id(app_id)
        if not application:
            return api_error('Application not found', status=404)
        app_model.update_status(app_id, status, reject_reason=notes if status == 'rejected' else None)
        if status == 'approved':
            UserModel().update_role(application['user_id'], application['role'])
            
            # Send welcome email after approval
            try:
                from services.email_service import send_welcome_email
                user = UserModel().get_by_id(application['user_id'])
                if user:
                    email = user.get('email')
                    name = f"{user.get('first_name', '')} {user.get('last_name', '')}".strip()
                    role = application.get('role', 'buyer')
                    send_welcome_email(email, name, role)
                    print(f"[Admin] Welcome email sent to {email} (role: {role})")
            except Exception as e:
                print(f"[Admin] Failed to send welcome email: {e}")
                # Don't fail the approval if email fails
        
        return api_response(message='Status updated')
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


# ── Users ─────────────────────────────────────────────────────────────────────

@admin_api_bp.get('/admin/users')
@role_required('admin')
def admin_get_users():
    try:
        from models.user_model import UserModel
        users = UserModel().get_all()
        return api_response(data=users)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


# ── Products ──────────────────────────────────────────────────────────────────

@admin_api_bp.get('/admin/products')
@role_required('admin')
def admin_get_products():
    status = request.args.get('status', '').strip() or None
    try:
        from models.product_model import ProductModel
        products = ProductModel().get_all(status=status)
        return api_response(data=products)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@admin_api_bp.get('/admin/products/<product_id>')
@role_required('admin')
def admin_get_product(product_id):
    try:
        from models.product_model import ProductModel
        product = ProductModel().get_by_id(product_id)
        if not product:
            return api_error('Product not found', status=404)
        return api_response(data=product)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@admin_api_bp.post('/admin/products/<product_id>/status')
@role_required('admin')
def admin_update_product_status(product_id):
    data   = get_json_body()
    status = data.get('status')
    reason = (data.get('reason') or '').strip() or None
    if status not in ('active', 'rejected'):
        return api_error('Invalid status', status=400)
    try:
        from models.product_model import ProductModel
        admin_id = request.current_user['id']
        updated = ProductModel().update_status(product_id, status, admin_id, reason)
        if not updated:
            return api_error('Product not found', status=404)
        return api_response(message='Product status updated')
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


# ── Orders ────────────────────────────────────────────────────────────────────

@admin_api_bp.get('/admin/orders')
@role_required('admin')
def admin_get_orders():
    status = request.args.get('status', '').strip() or None
    try:
        from models.order_model import OrderModel
        orders = OrderModel().get_all()
        if status:
            orders = [o for o in orders if o.get('status') == status]
        return api_response(data=orders)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@admin_api_bp.post('/admin/orders/<order_id>/status')
@role_required('admin')
def admin_update_order_status(order_id):
    data     = get_json_body()
    status   = data.get('status')
    rider_id = data.get('rider_id')
    if not status:
        return api_error('Status is required', status=400)
    try:
        from models.order_model import OrderModel
        updated = OrderModel().update_status_for_admin(order_id, status, rider_id)
        if not updated:
            return api_error('Order not found or invalid status', status=404)
        return api_response(message='Order status updated')
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


# ── Recent orders ─────────────────────────────────────────────────────────────

@admin_api_bp.get('/admin/recent-orders')
@role_required('admin')
def admin_recent_orders():
    limit = int(request.args.get('limit', 10))
    try:
        from models.order_model import OrderModel
        orders = OrderModel().get_all()
        recent = sorted(orders, key=lambda x: x.get('created_at', ''), reverse=True)[:limit]
        result = []
        for o in recent:
            buyer = o.get('buyer') or {}
            rider = o.get('rider') or {}
            result.append({
                'id':           o.get('id'),
                'short_id':     (o.get('id') or '')[:8],
                'buyer_name':   f"{buyer.get('first_name','')} {buyer.get('last_name','')}".strip() or '—',
                'rider_name':   f"{rider.get('first_name','')} {rider.get('last_name','')}".strip() or 'Unassigned',
                'total_amount': o.get('total_amount', 0),
                'status':       o.get('status', 'pending'),
                'created_at':   o.get('created_at', ''),
                'buyer':        buyer,
                'rider':        rider,
            })
        return api_response(data=result)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


# ── Pending applications (for dashboard) ─────────────────────────────────────

@admin_api_bp.get('/admin/pending-applications')
@role_required('admin')
def admin_pending_applications():
    try:
        from models.application_model import ApplicationModel
        apps = ApplicationModel().get_all()
        pending = [a for a in apps if a.get('status') == 'pending']
        return api_response(data=pending)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)
