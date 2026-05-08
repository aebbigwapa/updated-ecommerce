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
            # Preserve seller-specific fields not in serialize_order
            s['customer_name'] = o.get('customer_name', '')
            s['items_count']   = o.get('items_count', 0)
            s['total_amount']  = o.get('total_amount', 0)
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
        updated = OrderModel().update_status_for_seller(str(order_id), seller_id, status)
        if not updated:
            return api_error('Order not found or invalid transition', status=404)
        return api_response(message='Status updated', status=200)
    except Exception as e:
        return api_error(f'Failed: {e}', status=500)
