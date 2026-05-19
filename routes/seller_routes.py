from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from models.product_model import ProductModel
from models.application_model import ApplicationModel
from services.auth_service import AuthService
from services.product_service import ProductService
from services.file_upload_service import FileUploadService
from routes.api.api_helpers import api_response, api_error, serialize_order

def seller_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('auth.login'))
        if session['user'].get('role') != 'seller':
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return decorated

seller_bp = Blueprint('seller', __name__)
product_model = ProductModel()
app_model = ApplicationModel()
auth_service = AuthService()
product_service = ProductService()
file_service = FileUploadService()

@seller_bp.route('/')
@seller_required
def dashboard():
    seller_id = session['user']['id']
    stats = product_service.get_seller_stats(seller_id)
    return render_template('seller/dashboard.html', stats=stats)

@seller_bp.route('/products')
@seller_required
def products():
    seller_id = session['user']['id']
    products = product_model.get_by_seller(seller_id)
    category = auth_service.get_seller_category(seller_id)
    return render_template('seller/products.html', products=products, category=category)

@seller_bp.route('/api/dashboard-summary', methods=['GET'])
@seller_required
def api_dashboard_summary():
    """Get comprehensive dashboard summary for seller"""
    seller_id = session['user']['id']
    from models.order_model import OrderModel
    from models.product_model import ProductModel
    
    order_model = OrderModel()
    product_model = ProductModel()
    
    # Get seller stats
    stats = order_model.get_seller_stats(seller_id)
    
    # Get product count
    products = product_model.get_by_seller(seller_id)
    total_products = len(products)
    active_products = len([p for p in products if p.get('status') == 'active'])
    
    # Get order status breakdown
    orders = order_model.get_by_seller(seller_id)
    status_counts = {
        'pending': 0,
        'processing': 0,
        'ready_for_pickup': 0,
        'in_transit': 0,
        'delivered': 0
    }
    
    for order in orders:
        status = order.get('status', 'pending')
        if status in status_counts:
            status_counts[status] += 1
    
    return jsonify({
        'total_sales': stats.get('total_revenue', 0),
        'total_orders': stats.get('total_orders', 0),
        'products_listed': total_products,
        'active_products': active_products,
        'pending_orders': status_counts['pending'],
        'completed_orders': status_counts['delivered'],
        'today_sales': stats.get('today_revenue', 0),
        'week_sales': stats.get('week_revenue', 0),
        'month_sales': stats.get('month_revenue', 0),
        'items_sold': stats.get('items_sold', 0),
        'status_breakdown': status_counts
    })

@seller_bp.route('/api/sales-analytics', methods=['GET'])
@seller_required
def api_sales_analytics():
    """Get sales analytics data for charts"""
    seller_id = session['user']['id']
    period = request.args.get('period', 'daily')  # daily, weekly, monthly
    
    from models.order_model import OrderModel
    from datetime import datetime, timedelta
    import calendar
    
    order_model = OrderModel()
    
    # Get all delivered orders for this seller
    orders = order_model.get_by_seller(seller_id)
    delivered_orders = [o for o in orders if o.get('status') == 'delivered']
    
    now = datetime.now()
    analytics_data = []
    
    if period == 'daily':
        # Last 7 days
        for i in range(6, -1, -1):
            date = now - timedelta(days=i)
            date_str = date.strftime('%Y-%m-%d')
            day_orders = [o for o in delivered_orders if o.get('created_at', '').startswith(date_str)]
            total = sum(float(o.get('total_amount', 0)) for o in day_orders)
            analytics_data.append({
                'label': date.strftime('%m/%d'),
                'value': total,
                'orders': len(day_orders)
            })
    
    elif period == 'weekly':
        # Last 8 weeks
        for i in range(7, -1, -1):
            week_start = now - timedelta(weeks=i, days=now.weekday())
            week_end = week_start + timedelta(days=6)
            week_orders = []
            for o in delivered_orders:
                try:
                    order_date = datetime.fromisoformat(o.get('created_at', '').replace('Z', '+00:00'))
                    if week_start <= order_date <= week_end:
                        week_orders.append(o)
                except:
                    continue
            total = sum(float(o.get('total_amount', 0)) for o in week_orders)
            analytics_data.append({
                'label': f"Week {week_start.strftime('%m/%d')}",
                'value': total,
                'orders': len(week_orders)
            })
    
    elif period == 'monthly':
        # Last 6 months
        for i in range(5, -1, -1):
            month_date = now.replace(day=1) - timedelta(days=32*i)
            month_date = month_date.replace(day=1)
            month_str = month_date.strftime('%Y-%m')
            month_orders = [o for o in delivered_orders if o.get('created_at', '').startswith(month_str)]
            total = sum(float(o.get('total_amount', 0)) for o in month_orders)
            analytics_data.append({
                'label': month_date.strftime('%b %Y'),
                'value': total,
                'orders': len(month_orders)
            })
    
    return jsonify({
        'period': period,
        'data': analytics_data
    })

@seller_bp.route('/api/recent-orders', methods=['GET'])
@seller_required
def api_recent_orders():
    """Get recent orders for seller"""
    seller_id = session['user']['id']
    limit = int(request.args.get('limit', 10))
    
    from models.order_model import OrderModel
    order_model = OrderModel()
    
    orders = order_model.get_by_seller(seller_id)
    
    # Sort by created_at and limit
    recent_orders = sorted(orders, key=lambda x: x.get('created_at', ''), reverse=True)[:limit]
    
    # Format for frontend
    formatted_orders = []
    for order in recent_orders:
        formatted_orders.append({
            'id': order.get('id'),
            'order_id': order.get('id', '')[:8],
            'customer_name': order.get('customer_name', 'Unknown'),
            'buyer_id': order.get('buyer_id'),
            'items_count': order.get('items_count', 0),
            'total_amount': order.get('total_amount', 0),
            'status': order.get('status', 'pending'),
            'created_at': order.get('created_at', ''),
            'formatted_date': order.get('created_at', '')[:10] if order.get('created_at') else ''
        })
    
    return jsonify(formatted_orders)

@seller_bp.route('/api/top-products', methods=['GET'])
@seller_required
def api_top_products():
    """Get top selling products for seller"""
    seller_id = session['user']['id']
    limit = int(request.args.get('limit', 5))
    
    from models.order_model import OrderModel
    from models.product_model import ProductModel
    
    order_model = OrderModel()
    product_model = ProductModel()
    
    # Get all products for this seller
    products = product_model.get_by_seller(seller_id)
    
    # Get delivered orders to calculate sales
    orders = order_model.get_by_seller(seller_id)
    delivered_orders = [o for o in orders if o.get('status') == 'delivered']
    
    # Calculate product sales
    product_sales = {}
    for order in delivered_orders:
        for item in order.get('items', []):
            product_id = item.get('product_id')
            if product_id:
                if product_id not in product_sales:
                    product_sales[product_id] = {
                        'quantity': 0,
                        'revenue': 0
                    }
                product_sales[product_id]['quantity'] += int(item.get('quantity', 0))
                product_sales[product_id]['revenue'] += float(item.get('total_price', 0))
    
    # Match with product details and sort by revenue
    top_products = []
    for product in products:
        product_id = product.get('id')
        if product_id in product_sales:
            sales_data = product_sales[product_id]
            top_products.append({
                'id': product_id,
                'name': product.get('name', 'Unknown Product'),
                'quantity_sold': sales_data['quantity'],
                'total_revenue': sales_data['revenue'],
                'price': product.get('price', 0)
            })
    
    # Sort by revenue and limit
    top_products.sort(key=lambda x: x['total_revenue'], reverse=True)
    
    return jsonify(top_products[:limit])

@seller_bp.route('/api/low-stock', methods=['GET'])
@seller_required
def api_low_stock():
    """Get products with low stock"""
    seller_id = session['user']['id']
    threshold = int(request.args.get('threshold', 10))  # Default low stock threshold
    
    from models.product_model import ProductModel
    product_model = ProductModel()
    
    products = product_model.get_by_seller(seller_id)
    
    low_stock_products = []
    for product in products:
        if product.get('status') == 'active':  # Only check active products
            stock = int(product.get('total_stock', 0))
            if stock <= threshold:
                low_stock_products.append({
                    'id': product.get('id'),
                    'name': product.get('name', 'Unknown Product'),
                    'current_stock': stock,
                    'price': product.get('price', 0),
                    'status': 'critical' if stock == 0 else 'low' if stock <= 5 else 'warning'
                })
    
    # Sort by stock level (lowest first)
    low_stock_products.sort(key=lambda x: x['current_stock'])
    
    return jsonify(low_stock_products)

@seller_bp.route('/api/products', methods=['GET'])
@seller_required
def api_seller_products():
    seller_id = session['user']['id']
    products = product_model.get_by_seller(seller_id)
    return jsonify(products)

@seller_bp.route('/products/<product_id>/edit')
@seller_required
def product_edit(product_id):
    return render_template('seller/product-edit.html', product_id=product_id)

@seller_bp.route('/products/add')
@seller_required
def product_add():
    seller_id = session['user']['id']
    category = auth_service.get_seller_category(seller_id)
    return render_template('seller/product-add.html', category=category)

@seller_bp.route('/api/products', methods=['POST'])
@seller_bp.route('/api/seller/products', methods=['POST'])
@seller_required
def api_seller_product_create():
    seller_id = session['user']['id']
    try:
        result = product_service.create_product(seller_id, request.form, request.files)
        if result.get('success'):
            return jsonify(result), 201
        return jsonify({'error': result.get('error', 'Failed to create product')}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@seller_bp.route('/api/products/<product_id>', methods=['GET', 'PUT', 'DELETE'])
@seller_bp.route('/api/seller/products/<product_id>', methods=['GET', 'PUT', 'DELETE'])
@seller_required
def api_seller_product_detail(product_id):
    seller_id = session['user']['id']
    
    if request.method == 'GET':
        product = product_model.get_by_id_and_seller(product_id, seller_id)
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        return jsonify(product)
    
    elif request.method == 'PUT':
        try:
            result = product_service.update_product(product_id, seller_id, request.form, request.files)
            if not result.get('success'):
                return jsonify({'error': result.get('error')}), 400
            # Update variant price/stock if provided
            for key, value in request.form.items():
                if key.startswith('variant_') and '_price' in key:
                    vid = key.split('_')[1]
                    price = float(value or 0)
                    stock_key = f'variant_{vid}_stock'
                    stock = int(request.form.get(stock_key, 0) or 0)
                    product_model.supabase.table('product_variants').update({
                        'price': price, 'stock': stock
                    }).eq('id', vid).execute()
            # Recalculate product price from min variant price
            variants = product_model.get_variants(product_id)
            if variants:
                min_price = min(float(v.get('price', 0)) for v in variants)
                total_stock = sum(int(v.get('stock', 0)) for v in variants)
                product_model.supabase.table('products').update({
                    'price': min_price, 'total_stock': total_stock
                }).eq('id', product_id).execute()
            return jsonify(result)
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    
    elif request.method == 'DELETE':
        try:
            product_model.delete(product_id, seller_id)
            return jsonify({'success': True, 'message': 'Product deleted'})
        except Exception as e:
            return jsonify({'error': str(e)}), 500

@seller_bp.route('/orders')
@seller_required
def orders():
    seller_id = session['user']['id']
    from models.order_model import OrderModel
    order_model = OrderModel()
    orders = order_model.get_by_seller(seller_id)
    return render_template('seller/orders.html', orders=orders)

@seller_bp.route('/orders/<order_id>')
@seller_required
def order_detail(order_id):
    seller_id = session['user']['id']
    from models.order_model import OrderModel
    order_model = OrderModel()
    
    # Get order details
    order = order_model.get_by_id(order_id)
    if not order:
        from flask import abort
        abort(404)
    
    # Verify seller owns at least one product in this order
    product_result = order_model.supabase.table('products').select('id').eq('seller_id', seller_id).execute()
    product_ids = [p.get('id') for p in (product_result.data or [])]
    if not product_ids:
        from flask import abort
        abort(403)
    owned_items = order_model.supabase.table('order_items').select('id').eq('order_id', order_id).in_('product_id', product_ids).limit(1).execute()
    if not owned_items.data:
        from flask import abort
        abort(403)
    
    return render_template('seller/order_detail.html', order=order)

@seller_bp.route('/api/orders/<order_id>', methods=['GET'])
@seller_required
def api_seller_order_detail(order_id):
    seller_id = session['user']['id']
    order_model = OrderModel()
    order = order_model.get_by_id(order_id)
    if not order:
        return jsonify({'error': 'Order not found'}), 404
    # Verify seller owns at least one product in this order
    product_result = order_model.supabase.table('products').select('id').eq('seller_id', seller_id).execute()
    product_ids = [p.get('id') for p in (product_result.data or [])]
    if not product_ids:
        return jsonify({'error': 'Not authorized'}), 403
    owned_items = order_model.supabase.table('order_items').select('id').eq('order_id', order_id).in_('product_id', product_ids).limit(1).execute()
    if not owned_items.data:
        return jsonify({'error': 'Not authorized'}), 403
    return jsonify(order)

@seller_bp.route('/api/orders', methods=['GET'])
@seller_required
def api_seller_orders():
    seller_id = session['user']['id']
    from models.order_model import OrderModel
    order_model = OrderModel()
    orders = order_model.get_by_seller(seller_id)
    # Add buyer_id to each order for the frontend
    for order in orders:
        order['buyer_id'] = order.get('buyer_id')
    return jsonify(orders)

@seller_bp.route('/api/shipping', methods=['GET'])
@seller_required
def api_seller_shipping():
    seller_id = session['user']['id']
    from models.order_model import OrderModel
    order_model = OrderModel()
    orders = order_model.get_by_seller(seller_id)
    shipping_statuses = ['processing', 'ready_for_pickup', 'in_transit', 'delivered']
    filtered_orders = [o for o in orders if o.get('status') in shipping_statuses]
    return jsonify(filtered_orders)

@seller_bp.route('/api/orders/<order_id>/status', methods=['POST'])
@seller_required
def api_seller_update_order_status(order_id):
    seller_id = session['user']['id']
    data = request.get_json() or {}
    status = data.get('status')
    if status not in ('processing', 'ready_for_pickup'):
        return jsonify({'error': 'Invalid status'}), 400
    from models.order_model import OrderModel
    from models.notification_model import NotificationModel
    
    order_model = OrderModel()
    notification_model = NotificationModel()
    
    # Get current order status before updating
    current_order = order_model.get_by_id(order_id)
    if not current_order:
        return jsonify({'error': 'Order not found'}), 404
    
    current_status = current_order.get('status')
    updated = order_model.update_status_for_seller(order_id, seller_id, status)
    
    if not updated:
        return jsonify({'error': 'Order not found or invalid status transition'}), 404
    
    # Create notification when order moves from pending to processing (order approved)
    if current_status == 'pending' and status == 'processing':
        buyer_id = current_order.get('buyer_id')
        if buyer_id:
            try:
                notification_model.create(
                    user_id=buyer_id,
                    notif_type='status_update',
                    title='Order Approved',
                    message='Your order has been accepted by the seller and is now being processed.',
                    action_url=f"/buyer/orders#{order_id}",
                    data_payload={
                        'order_id': order_id,
                        'new_status': status,
                        'timestamp': __import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat()
                    }
                )
            except Exception as e:
                print(f"Error creating notification: {e}")
                # Don't fail the order update if notification fails
    
    return jsonify({'success': True, 'order': updated})

@seller_bp.route('/shipping')
@seller_required
def shipping():
    return render_template('seller/shipping.html')

@seller_bp.route('/earnings')
@seller_required
def earnings():
    return render_template('seller/earnings.html')

@seller_bp.route('/api/earnings', methods=['GET'])
@seller_required
def api_seller_earnings():
    seller_id = session['user']['id']
    from models.order_model import OrderModel
    stats = OrderModel().get_seller_stats(seller_id)
    return jsonify(stats)


@seller_bp.route('/api/seller/<seller_id>/store-name', methods=['GET'])
def api_get_seller_store_name(seller_id):
    """Public endpoint to get seller's store name for chat display"""
    try:
        application = app_model.get_by_user_id(seller_id)
        if application and application.get('store_name'):
            return jsonify({'store_name': application['store_name']})
        return jsonify({'store_name': None}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@seller_bp.route('/store')
@seller_required
def store():
    application = app_model.get_by_user_id(session['user']['id'])
    return render_template('seller/store.html', application=application)

@seller_bp.route('/reviews')
@seller_required
def reviews():
    return render_template('seller/reviews.html')


# ============================================================================
# CANCELLATION ENDPOINTS
# ============================================================================

@seller_bp.route('/api/orders/<order_id>/cancel', methods=['POST'])
@seller_required
def api_seller_cancel_order(order_id):
    """Seller-initiated order cancellation"""
    from models.order_model import OrderModel
    from models.notification_model import NotificationModel
    from datetime import datetime, timezone
    
    try:
        seller_id = session['user']['id']
        data = request.get_json() or {}
        reason = (data.get('reason') or 'Cancelled by seller')[:200]
        
        order_model = OrderModel()
        notification_model = NotificationModel()
        
        # Get order and verify seller owns it
        order = order_model.get_by_id(order_id)
        if not order:
            return api_error('Order not found.', status=404)
        
        # Verify seller owns the products in this order
        product_ids = order_model.supabase.table('order_items') \
            .select('product_id').eq('order_id', order_id).execute()
        if not product_ids.data:
            return api_error('Order not found.', status=404)
        
        seller_product_ids = product_model.supabase.table('products') \
            .select('id').eq('seller_id', seller_id).execute()
        seller_ids = {p['id'] for p in (seller_product_ids.data or [])}
        
        order_product_ids = {p['product_id'] for p in product_ids.data}
        if not order_product_ids.issubset(seller_ids):
            return api_error('Not authorized to cancel this order.', status=403)
        
        # Check eligibility
        eligibility = OrderModel.get_cancellation_eligibility(order, 'seller')
        if not eligibility['canCancel']:
            return api_error(eligibility['message'], status=400)
        
        # If already cancelled
        if order.get('status') == 'cancelled':
            return api_response(
                data={'order': serialize_order(order)},
                message='Order is already cancelled.',
                status=200,
            )
        
        now_iso = datetime.now(timezone.utc).isoformat()
        
        # Instant cancellation (seller doesn't need approval)
        update_payload = {
            'status': 'cancelled',
            'cancelled_at': now_iso,
            'cancel_reason': reason,
        }
        
        updated = order_model.supabase.table('orders') \
            .update(update_payload).eq('id', order_id).execute()
        if not updated.data:
            return api_error('Failed to cancel order.', status=500)
        
        # Restore stock
        order_model.restore_order_stock(order_id)
        
        # Notify buyer
        buyer_id = order.get('buyer_id')
        if buyer_id:
            notification_model.create(
                buyer_id,
                'status_update',
                'Order Cancelled by Seller',
                f'Your order #{order_id[:8].upper()} has been cancelled by the seller. Reason: {reason}',
                f'/buyer/orders/{order_id}',
                data_payload={'order_id': order_id, 'new_status': 'cancelled', 'reason': reason}
            )
        
        return api_response(
            data={'order': serialize_order(updated.data[0])},
            message='Order cancelled successfully.',
            status=200,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to cancel order: {str(e)}', status=500)


@seller_bp.route('/api/cancellation-requests/<request_id>/approve', methods=['POST'])
@seller_required
def api_approve_cancellation_request(request_id):
    """Seller approves a buyer's cancellation request"""
    from models.order_model import OrderModel
    from models.notification_model import NotificationModel
    from datetime import datetime, timezone
    
    try:
        seller_id = session['user']['id']
        data = request.get_json() or {}
        approval_note = (data.get('note') or '')[:200]
        
        order_model = OrderModel()
        notification_model = NotificationModel()
        
        # Get cancellation request
        cancel_req = order_model.supabase.table('cancellation_requests') \
            .select('*').eq('id', request_id).limit(1).execute()
        if not cancel_req.data:
            return api_error('Cancellation request not found.', status=404)
        
        req = cancel_req.data[0]
        order_id = req.get('order_id')
        buyer_id = req.get('requested_by')
        
        # Verify seller owns the order
        order = order_model.get_by_id(order_id)
        if not order:
            return api_error('Order not found.', status=404)
        
        product_ids = order_model.supabase.table('order_items') \
            .select('product_id').eq('order_id', order_id).execute()
        if not product_ids.data:
            return api_error('Order not found.', status=404)
        
        seller_product_ids = product_model.supabase.table('products') \
            .select('id').eq('seller_id', seller_id).execute()
        seller_ids = {p['id'] for p in (seller_product_ids.data or [])}
        
        order_product_ids = {p['product_id'] for p in product_ids.data}
        if not order_product_ids.issubset(seller_ids):
            return api_error('Not authorized.', status=403)
        
        if req.get('status') != 'pending':
            return api_error('Cancellation request already processed.', status=400)
        
        now_iso = datetime.now(timezone.utc).isoformat()
        
        # Update cancellation request to approved
        updated_req = order_model.supabase.table('cancellation_requests') \
            .update({
                'status': 'approved',
                'approved_by': seller_id,
                'approved_at': now_iso,
            }).eq('id', request_id).execute()
        
        if not updated_req.data:
            return api_error('Failed to approve cancellation request.', status=500)
        
        # Cancel the order
        order_update = order_model.supabase.table('orders') \
            .update({
                'status': 'cancelled',
                'cancelled_at': now_iso,
                'cancel_reason': req.get('reason'),
            }).eq('id', order_id).execute()
        
        if not order_update.data:
            return api_error('Failed to cancel order.', status=500)
        
        # Restore stock
        order_model.restore_order_stock(order_id)
        
        # Notify buyer
        if buyer_id:
            notification_model.create(
                buyer_id,
                'cancellation_approved',
                'Cancellation Approved',
                f'Your cancellation request for order #{order_id[:8].upper()} has been approved.',
                f'/buyer/orders/{order_id}',
                data_payload={'order_id': order_id}
            )
        
        return api_response(
            data={'request': updated_req.data[0]},
            message='Cancellation request approved.',
            status=200,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to approve cancellation: {str(e)}', status=500)


@seller_bp.route('/api/cancellation-requests/<request_id>/reject', methods=['POST'])
@seller_required
def api_reject_cancellation_request(request_id):
    """Seller rejects a buyer's cancellation request"""
    from models.order_model import OrderModel
    from models.notification_model import NotificationModel
    from datetime import datetime, timezone
    
    try:
        seller_id = session['user']['id']
        data = request.get_json() or {}
        rejection_reason = (data.get('reason') or 'No reason provided')[:200]
        
        order_model = OrderModel()
        notification_model = NotificationModel()
        
        # Get cancellation request
        cancel_req = order_model.supabase.table('cancellation_requests') \
            .select('*').eq('id', request_id).limit(1).execute()
        if not cancel_req.data:
            return api_error('Cancellation request not found.', status=404)
        
        req = cancel_req.data[0]
        order_id = req.get('order_id')
        buyer_id = req.get('requested_by')
        
        # Verify seller owns the order
        order = order_model.get_by_id(order_id)
        if not order:
            return api_error('Order not found.', status=404)
        
        product_ids = order_model.supabase.table('order_items') \
            .select('product_id').eq('order_id', order_id).execute()
        if not product_ids.data:
            return api_error('Order not found.', status=404)
        
        seller_product_ids = product_model.supabase.table('products') \
            .select('id').eq('seller_id', seller_id).execute()
        seller_ids = {p['id'] for p in (seller_product_ids.data or [])}
        
        order_product_ids = {p['product_id'] for p in product_ids.data}
        if not order_product_ids.issubset(seller_ids):
            return api_error('Not authorized.', status=403)
        
        if req.get('status') != 'pending':
            return api_error('Cancellation request already processed.', status=400)
        
        now_iso = datetime.now(timezone.utc).isoformat()
        
        # Update cancellation request to rejected
        updated_req = order_model.supabase.table('cancellation_requests') \
            .update({
                'status': 'rejected',
                'rejected_reason': rejection_reason,
                'approved_at': now_iso,
            }).eq('id', request_id).execute()
        
        if not updated_req.data:
            return api_error('Failed to reject cancellation request.', status=500)
        
        # Notify buyer
        if buyer_id:
            notification_model.create(
                buyer_id,
                'cancellation_rejected',
                'Cancellation Rejected',
                f'Your cancellation request for order #{order_id[:8].upper()} has been rejected. Reason: {rejection_reason}',
                f'/buyer/orders/{order_id}',
                data_payload={'order_id': order_id, 'reason': rejection_reason}
            )
        
        return api_response(
            data={'request': updated_req.data[0]},
            message='Cancellation request rejected.',
            status=200,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to reject cancellation: {str(e)}', status=500)


@seller_bp.route('/api/cancellation-requests', methods=['GET'])
@seller_required
def api_get_cancellation_requests():
    """Get pending cancellation requests for seller"""
    from models.order_model import OrderModel
    
    try:
        seller_id = session['user']['id']
        status = request.args.get('status', 'pending')  # pending, approved, rejected, all
        
        order_model = OrderModel()
        
        # Get all seller's product IDs
        seller_products = product_model.supabase.table('products') \
            .select('id').eq('seller_id', seller_id).execute()
        seller_product_ids = [p['id'] for p in (seller_products.data or [])]
        
        if not seller_product_ids:
            return api_response(data=[], message='No requests.', status=200)
        
        # Get cancellation requests for orders containing seller's products
        if status == 'all':
            requests = order_model.supabase.table('cancellation_requests') \
                .select('*').execute()
        else:
            requests = order_model.supabase.table('cancellation_requests') \
                .select('*').eq('status', status).execute()
        
        # Filter to only requests for seller's orders
        filtered_requests = []
        for req in (requests.data or []):
            order_id = req.get('order_id')
            order_items = order_model.supabase.table('order_items') \
                .select('product_id').eq('order_id', order_id).execute()
            
            order_product_ids = {item['product_id'] for item in (order_items.data or [])}
            if order_product_ids and order_product_ids.issubset(set(seller_product_ids)):
                filtered_requests.append(req)
        
        return api_response(data=filtered_requests, message='OK', status=200)
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to get cancellation requests: {str(e)}', status=500)

