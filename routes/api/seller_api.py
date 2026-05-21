"""
/api/seller/* — Mobile seller endpoints (token-based auth).
"""

from flask import Blueprint, request
from routes.api.api_helpers import (
    api_response, api_error, get_json_body, token_required, role_required,
)

seller_api_bp = Blueprint('seller_api', __name__)


@seller_api_bp.get('/seller/dashboard')
@role_required('seller')
def seller_dashboard():
    from flask import request as req
    seller_id = req.current_user['id']
    try:
        from models.order_model import OrderModel
        from models.product_model import ProductModel
        stats    = OrderModel().get_seller_stats(seller_id)
        products = ProductModel().get_by_seller(seller_id)
        orders   = OrderModel().get_by_seller(seller_id)
        status_counts = {'pending': 0, 'processing': 0, 'ready_for_pickup': 0, 'in_transit': 0, 'delivered': 0}
        for o in orders:
            s = o.get('status', 'pending')
            if s in status_counts:
                status_counts[s] += 1
        return api_response(data={
            'total_sales':      stats.get('total_revenue', 0),
            'total_orders':     stats.get('total_orders', 0),
            'products_listed':  len(products),
            'active_products':  len([p for p in products if p.get('status') == 'active']),
            'pending_orders':   status_counts['pending'],
            'today_sales':      stats.get('today_revenue', 0),
            'items_sold':       stats.get('items_sold', 0),
            'status_breakdown': status_counts,
        }, message='OK', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.get('/seller/products')
@role_required('seller')
def seller_products():
    seller_id = request.current_user['id']
    try:
        from models.product_model import ProductModel
        from routes.api.api_helpers import serialize_product
        products = ProductModel().get_by_seller(seller_id)
        return api_response(
            data={'products': [serialize_product(p) for p in products], 'count': len(products)},
            message='OK', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.post('/seller/products')
@role_required('seller')
def seller_create_product():
    seller_id = request.current_user['id']
    try:
        from services.product_service import ProductService
        result = ProductService().create_product(seller_id, request.form, request.files)
        if result.get('success'):
            return api_response(data={'product_id': result.get('product_id')},
                                message=result.get('message', 'Product submitted for approval.'),
                                status=201)
        return api_error(result.get('error', 'Failed to create product'), status=400)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.get('/seller/products/<uuid:product_id>')
@role_required('seller')
def seller_get_product(product_id):
    seller_id = request.current_user['id']
    try:
        from models.product_model import ProductModel
        from routes.api.api_helpers import serialize_product
        product = ProductModel().get_by_id_and_seller(str(product_id), seller_id)
        if not product:
            return api_error('Product not found', status=404)
        return api_response(data={'product': serialize_product(product)}, message='OK', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.put('/seller/products/<uuid:product_id>')
@seller_api_bp.patch('/seller/products/<uuid:product_id>')
@role_required('seller')
def seller_update_product(product_id):
    seller_id = request.current_user['id']
    try:
        from services.product_service import ProductService
        result = ProductService().update_product(str(product_id), seller_id, request.form, request.files)
        if result.get('success'):
            return api_response(message=result.get('message', 'Product updated.'), status=200)
        return api_error(result.get('error', 'Failed to update product'), status=400)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.delete('/seller/products/<uuid:product_id>')
@role_required('seller')
def seller_delete_product(product_id):
    seller_id = request.current_user['id']
    try:
        from models.product_model import ProductModel
        ProductModel().delete(str(product_id), seller_id)
        return api_response(message='Product deleted', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.get('/seller/<uuid:seller_id>/store-name')
def seller_store_name(seller_id):
    """Public: get a seller's store name for chat display."""
    try:
        from supabase import create_client
        import os
        sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
        res = sb.table('applications').select('store_name') \
            .eq('user_id', str(seller_id)).eq('role', 'seller').limit(1).execute()
        if res.data:
            return api_response(data={'store_name': res.data[0].get('store_name', '')}, message='OK')
        return api_error('Seller not found', status=404)
    except Exception as e:
        return api_error(str(e), status=500)


@seller_api_bp.get('/seller/category')
@role_required('seller')
def seller_category():
    seller_id = request.current_user['id']
    try:
        from services.auth_service import AuthService
        category = AuthService().get_seller_category(seller_id) or ''
        return api_response(data={'category': category}, message='OK', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.get('/seller/orders')
@role_required('seller')
def seller_orders():
    seller_id = request.current_user['id']
    try:
        from models.order_model import OrderModel
        from routes.api.api_helpers import serialize_order
        orders = OrderModel().get_by_seller(seller_id)
        # Normalize each order so frontend gets consistent id/order_id/total_price fields
        result = []
        for o in orders:
            s = serialize_order(o)
            s['customer_name']          = o.get('customer_name', '')
            s['items_count']            = o.get('items_count', 0)
            s['total_amount']           = o.get('total_amount', 0)
            s['buyer_id']               = o.get('buyer_id', '')
            s['proof_of_delivery_url']  = o.get('proof_of_delivery_url') or ''
            s['proof_uploaded_at']      = o.get('proof_uploaded_at') or ''
            result.append(s)
        return api_response(
            data={'orders': result, 'count': len(result)},
            message='OK', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.post('/seller/orders/<uuid:order_id>/status')
@role_required('seller')
def seller_update_order_status(order_id):
    seller_id = request.current_user['id']
    data   = get_json_body()
    status = data.get('status')
    if status not in ('processing', 'ready_for_pickup'):
        return api_error('Invalid status', status=400)
    try:
        from models.order_model import OrderModel
        from models.notification_model import NotificationModel
        
        updated = OrderModel().update_status_for_seller(str(order_id), seller_id, status)
        if not updated:
            return api_error('Order not found or invalid transition', status=404)
        
        # Create notification for buyer
        buyer_id = updated.get('buyer_id')
        if buyer_id:
            notification_model = NotificationModel()
            status_messages = {
                'processing': 'Your order is being processed',
                'ready_for_pickup': 'Your order is ready for pickup'
            }
            
            try:
                notification_model.create(
                    user_id=buyer_id,
                    notif_type='status_update',
                    title='Order Status Updated',
                    message=status_messages.get(status, f'Order status changed to {status}'),
                    action_url=f'/buyer/orders#{order_id}',
                    data_payload={'order_id': str(order_id), 'new_status': status}
                )
            except Exception as e:
                print(f'[seller_update_order_status] notification error: {e}')
        
        # Auto-create conversation based on new status
        try:
            from models.message_model import MessageModel
            rider_id  = updated.get('rider_id')
            MessageModel().ensure_order_conversations(
                order_id=str(order_id),
                status=status,
                buyer_id=buyer_id,
                seller_id=seller_id,
                rider_id=rider_id,
            )
        except Exception as e:
            print(f'[seller_update_order_status] chat creation error: {e}')
        
        return api_response(message='Status updated', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.get('/seller/notifications')
@role_required('seller')
def seller_notifications():
    """Get seller notifications."""
    seller_id = request.current_user['id']
    try:
        from models.notification_model import NotificationModel
        notifications = NotificationModel().get_by_user(seller_id, limit=50)
        unread_count = sum(1 for n in notifications if not n.get('is_read'))
        return api_response(
            data={'notifications': notifications, 'unread_count': unread_count},
            message='OK',
            status=200
        )
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.post('/seller/notifications/read-all')
@role_required('seller')
def seller_mark_notifications_read():
    """Mark all seller notifications as read."""
    seller_id = request.current_user['id']
    try:
        from models.notification_model import NotificationModel
        NotificationModel().mark_all_read(seller_id)
        return api_response(message='All notifications marked as read', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)


@seller_api_bp.get('/seller/analytics')
@role_required('seller')
def seller_analytics():
    """Get seller sales analytics with monthly breakdown."""
    seller_id = request.current_user['id']
    try:
        from models.order_model import OrderModel
        from datetime import datetime, timedelta
        import os
        from supabase import create_client
        
        sb = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))
        
        # Get all delivered orders for this seller
        orders_response = sb.table('orders').select('*') \
            .eq('seller_id', seller_id) \
            .eq('status', 'delivered') \
            .order('created_at', desc=True) \
            .execute()
        
        orders = orders_response.data if orders_response.data else []
        
        # Calculate monthly sales
        monthly_data = {}
        total_sales = 0
        total_orders = len(orders)
        
        for order in orders:
            created_at = order.get('created_at', '')
            total_amount = float(order.get('total_amount', 0))
            total_sales += total_amount
            
            try:
                dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                month_key = f"{dt.year}-{dt.month:02d}"
                month_name = dt.strftime('%B')
                year = dt.year
                
                if month_key not in monthly_data:
                    monthly_data[month_key] = {
                        'month': month_name,
                        'year': year,
                        'total_sales': 0,
                        'orders_count': 0,
                        'items_sold': 0,
                    }
                
                monthly_data[month_key]['total_sales'] += total_amount
                monthly_data[month_key]['orders_count'] += 1
                
                # Count items
                items_response = sb.table('order_items').select('quantity') \
                    .eq('order_id', order['id']).execute()
                if items_response.data:
                    for item in items_response.data:
                        monthly_data[month_key]['items_sold'] += item.get('quantity', 0)
            except Exception:
                continue
        
        # Convert to sorted list (most recent first)
        monthly_sales = sorted(
            monthly_data.values(),
            key=lambda x: f"{x['year']}-{x['month']}",
            reverse=True
        )[:12]  # Last 12 months
        
        return api_response(
            data={
                'total_sales': total_sales,
                'total_orders': total_orders,
                'monthly_sales': list(reversed(monthly_sales)),  # Oldest to newest for charts
            },
            message='OK',
            status=200
        )
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)
