"""
/api/orders/* — buyer orders for Flutter.
All endpoints require Bearer token.

Endpoints:
  GET  /api/addresses                       -> list buyer's saved addresses
  GET  /api/orders                          -> list buyer's orders
  GET  /api/orders/<uuid:order_id>          -> single order detail
  POST /api/orders                          -> place order from cart
  POST /api/orders/<uuid:order_id>/cancel   -> cancel pending order
"""

from flask import Blueprint, request
from routes.api.api_helpers import (
    api_response, api_error, get_json_body,
    token_required, serialize_order,
)

orders_api_bp = Blueprint('orders_api', __name__)


@orders_api_bp.get('/addresses')
@orders_api_bp.get('/addresses/')
@token_required
def list_addresses():
    user = request.current_user  # type: ignore[attr-defined]
    try:
        from models.user_model import UserModel
        addresses = UserModel().get_addresses(user['id']) or []
        return api_response(
            data={"addresses": addresses, "count": len(addresses)},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch addresses: {e}", status=500)


@orders_api_bp.get('/orders')
@orders_api_bp.get('/orders/')
@token_required
def list_orders():
    user = request.current_user  # type: ignore[attr-defined]
    try:
        from models.order_model import OrderModel
        orders = OrderModel().get_by_buyer(user['id']) or []
        items = [serialize_order(o) for o in orders]
        return api_response(
            data={"orders": items, "count": len(items)},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch orders: {e}", status=500)


@orders_api_bp.get('/orders/<uuid:order_id>')
@token_required
def get_order(order_id):
    user = request.current_user  # type: ignore[attr-defined]
    try:
        from models.order_model import OrderModel
        order = OrderModel().get_by_id(str(order_id))
        if not order:
            return api_error("Order not found", status=404)
        if order.get('buyer_id') != user['id'] and user.get('role') != 'admin':
            return api_error("Forbidden", status=403)
        return api_response(
            data={"order": serialize_order(order)},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch order: {e}", status=500)


@orders_api_bp.post('/orders')
@orders_api_bp.post('/orders/')
@token_required
def create_order():
    user = request.current_user  # type: ignore[attr-defined]
    data = get_json_body()

    address = (data.get('address') or '').strip()
    payment_method = data.get('payment_method') or 'cod'
    address_id = data.get('address_id')

    # If address_id provided, resolve the full address object
    if address_id:
        try:
            from models.user_model import UserModel
            addr_obj = UserModel().get_address_by_id(user['id'], address_id)
            if addr_obj:
                parts = [addr_obj.get('street'), addr_obj.get('barangay'),
                         addr_obj.get('city'), addr_obj.get('region'), addr_obj.get('zip_code')]
                address = ', '.join(p for p in parts if p)
        except Exception:
            pass

    if not address:
        return api_error("address is required", status=400)

    items = data.get('items')
    try:
        from models.order_model import OrderModel
        from services.order_service import OrderService

        if not items:
            cart_items = OrderModel().get_cart_items(user['id']) or []
            if not cart_items:
                return api_error("Cart is empty", status=400)
            items = [{
                "product_id": ci.get('product_id'),
                "variant_id": ci.get('variant_id'),
                "quantity":   int(ci.get('quantity') or 1),
            } for ci in cart_items]

        if not isinstance(items, list) or len(items) == 0:
            return api_error("items must be a non-empty list", status=400)

        result = OrderService().create_order(
            buyer_id=user['id'],
            items=items,
            address=address,
            payment_method=payment_method,
        )

        if not result.get('success'):
            return api_error(result.get('error') or "Failed to create order", status=400)

        if not data.get('items'):
            try:
                OrderModel().clear_cart(user['id'])
            except Exception:
                pass

        return api_response(
            data={"order": serialize_order(result.get('order') or {})},
            message=result.get('message') or "Order created",
            status=201,
        )
    except Exception as e:
        return api_error(f"Failed to create order: {e}", status=500)


@orders_api_bp.post('/orders/<uuid:order_id>/cancel')
@token_required
def cancel_order(order_id):
    user = request.current_user  # type: ignore[attr-defined]
    try:
        from models.order_model import OrderModel
        result = OrderModel().cancel_order(
            order_id=str(order_id),
            user_id=user['id'],
            is_admin=(user.get('role') == 'admin'),
        )
        if not result:
            return api_error("Order cannot be cancelled", status=400)
        return api_response(
            data={"order": serialize_order(result)},
            message="Order cancelled",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to cancel order: {e}", status=500)
