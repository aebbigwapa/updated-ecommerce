"""
/api/cart/* — buyer cart management for Flutter.
All endpoints require Bearer token.

Endpoints:
  GET    /api/cart                      -> list cart items + totals
  POST   /api/cart                      -> add item {product_id, variant_id?, quantity}
  PATCH  /api/cart/<uuid:item_id>       -> update qty {quantity}
  DELETE /api/cart/<uuid:item_id>       -> remove item
  DELETE /api/cart                      -> clear cart
"""

from flask import Blueprint, request
from routes.api.api_helpers import (
    api_response, api_error, get_json_body,
    token_required, serialize_cart_item,
)

cart_api_bp = Blueprint('cart_api', __name__)


def _cart_payload(user_id: str):
    from models.order_model import OrderModel
    items_raw = OrderModel().get_cart_items(user_id) or []
    items = [serialize_cart_item(i) for i in items_raw]
    total = round(sum(i.get('subtotal', 0.0) for i in items), 2)
    return {
        "items":      items,
        "item_count": sum(i.get('quantity', 0) for i in items),
        "total":      total,
    }


@cart_api_bp.get('/cart')
@cart_api_bp.get('/cart/')
@token_required
def list_cart():
    user = request.current_user  # type: ignore[attr-defined]
    try:
        return api_response(data=_cart_payload(user['id']), message="OK", status=200)
    except Exception as e:
        return api_error(f"Failed to load cart: {e}", status=500)


@cart_api_bp.post('/cart')
@cart_api_bp.post('/cart/')
@token_required
def add_to_cart():
    user = request.current_user  # type: ignore[attr-defined]
    data = get_json_body()

    product_id = (data.get('product_id') or '').strip()
    variant_id = data.get('variant_id') or None
    try:
        quantity = int(data.get('quantity') or 1)
    except (TypeError, ValueError):
        return api_error("quantity must be an integer", status=400)

    if not product_id:
        return api_error("product_id is required", status=400)
    if quantity < 1:
        return api_error("Quantity must be at least 1", status=400)

    try:
        from models.product_model import ProductModel
        from models.order_model import OrderModel

        product = ProductModel().get_by_id(product_id)
        if not product or product.get('status') != 'active':
            return api_error("Product not available", status=404)

        price_snapshot = float(product.get('price') or 0)
        item = OrderModel().add_or_increment_cart_item(
            user_id=user['id'],
            product_id=product_id,
            variant_id=variant_id,
            quantity=quantity,
            price_snapshot=price_snapshot,
        )
        if not item:
            return api_error("Failed to add item to cart", status=500)

        resp = {"cart": _cart_payload(user['id'])}
        if 'max' in item:
            resp['max'] = item['max']
            return api_response(data=resp, message=f"Only {item['max']} in stock", status=200)
        return api_response(data=resp, message="Item added to cart", status=201)
    except Exception as e:
        return api_error(f"Failed to add to cart: {e}", status=500)


@cart_api_bp.patch('/cart/<uuid:item_id>')
@cart_api_bp.put('/cart/<uuid:item_id>')
@token_required
def update_cart_item(item_id):
    user = request.current_user  # type: ignore[attr-defined]
    data = get_json_body()
    try:
        quantity = int(data.get('quantity'))
    except (TypeError, ValueError):
        return api_error("quantity must be an integer", status=400)
    if quantity < 1:
        return api_error("Quantity must be at least 1", status=400)
    try:
        from models.order_model import OrderModel
        updated = OrderModel().update_cart_item_qty(user['id'], str(item_id), quantity)
        if not updated:
            return api_error("Cart item not found or stock unavailable", status=404)
        resp = {"cart": _cart_payload(user['id'])}
        if 'max' in updated:
            resp['max'] = updated['max']
            return api_response(data=resp, message=f"Only {updated['max']} in stock", status=200)
        return api_response(data=resp, message="Cart updated", status=200)
    except Exception as e:
        return api_error(f"Failed to update cart: {e}", status=500)


@cart_api_bp.delete('/cart/<uuid:item_id>')
@token_required
def delete_cart_item(item_id):
    user = request.current_user  # type: ignore[attr-defined]
    try:
        from models.order_model import OrderModel
        OrderModel().remove_cart_item(user['id'], str(item_id))
        return api_response(
            data={"cart": _cart_payload(user['id'])},
            message="Item removed",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to remove item: {e}", status=500)


@cart_api_bp.delete('/cart')
@cart_api_bp.delete('/cart/')
@cart_api_bp.post('/cart/clear')
@token_required
def clear_cart():
    user = request.current_user  # type: ignore[attr-defined]
    try:
        from models.order_model import OrderModel
        OrderModel().clear_cart(user['id'])
        return api_response(data=_cart_payload(user['id']), message="Cart cleared", status=200)
    except Exception as e:
        return api_error(f"Failed to clear cart: {e}", status=500)


@cart_api_bp.post('/cart/merge')
@token_required
def merge_guest_cart():
    """Merge guest cart (from localStorage) into user's database cart on login."""
    user = request.current_user  # type: ignore[attr-defined]
    data = get_json_body()
    guest_items = data.get('guest_cart', [])
    
    if not isinstance(guest_items, list):
        return api_error("Invalid guest cart format", status=400)
    
    try:
        from models.order_model import OrderModel
        from models.product_model import ProductModel
        
        order_model = OrderModel()
        product_model = ProductModel()
        merged_count = 0
        
        for item in guest_items:
            product_id = item.get('product_id')
            variant_id = item.get('variant_id')
            quantity = int(item.get('quantity', 1))
            
            if not product_id or quantity <= 0:
                continue
            
            # Validate product exists and is active
            product = product_model.get_by_id(product_id)
            if not product or product.get('status') != 'active':
                continue
            
            # Use current price from database (don't trust client)
            price_snapshot = float(product.get('price', 0))
            
            # Add or increment in user's cart
            result = order_model.add_or_increment_cart_item(
                user_id=user['id'],
                product_id=product_id,
                variant_id=variant_id,
                quantity=quantity,
                price_snapshot=price_snapshot
            )
            
            if result:
                merged_count += 1
        
        return api_response(
            data={'cart': _cart_payload(user['id']), 'merged_count': merged_count},
            message=f"Merged {merged_count} item(s) from guest cart",
            status=200
        )
    except Exception as e:
        return api_error(f"Failed to merge cart: {e}", status=500)
