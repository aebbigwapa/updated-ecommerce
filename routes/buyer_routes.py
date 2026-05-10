from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from models.order_model import OrderModel
from models.product_model import ProductModel
from models.user_model import UserModel
from models.notification_model import NotificationModel
from models.review_model import ReviewModel
from services.auth_service import AuthService
from services.order_service import OrderService
from routes.api.api_helpers import api_response, api_error, serialize_product, serialize_cart_item, serialize_order

buyer_bp = Blueprint('buyer', __name__)
order_model = OrderModel()
product_model = ProductModel()
user_model = UserModel()
notification_model = NotificationModel()
review_model = ReviewModel()
auth_service = AuthService()
order_service = OrderService()

def buyer_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user' not in session:
            return redirect(url_for('auth.login'))
        if session['user'].get('role') not in ('buyer', 'seller', 'admin', 'rider'):
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return decorated

@buyer_bp.route('/')
@buyer_required
def dashboard():
    buyer_id = session['user']['id']
    stats = order_service.get_buyer_stats(buyer_id)
    return render_template('buyer/dashboard.html', stats=stats)

# Route functions

@buyer_bp.route('/market')
def market():
    return render_template('buyer/market.html')

@buyer_bp.route('/product')
def product():
    return render_template('buyer/product.html')

@buyer_bp.route('/api/products', methods=['GET'])
def api_buyer_products():
    try:
        category  = request.args.get('category', '').strip()
        search    = request.args.get('search', '').strip().lower()
        min_price = request.args.get('min_price', '').strip()
        max_price = request.args.get('max_price', '').strip()
        sort      = request.args.get('sort', '').strip()

        products = product_model.get_all_active(category=category or None)

        if search:
            products = [p for p in products if search in (p.get('name', '') + ' ' + (p.get('description') or '')).lower()]
        if min_price:
            try:
                products = [p for p in products if float(p.get('price', 0) or 0) >= float(min_price)]
            except ValueError:
                pass
        if max_price:
            try:
                products = [p for p in products if float(p.get('price', 0) or 0) <= float(max_price)]
            except ValueError:
                pass
        if sort == 'price_asc':
            products.sort(key=lambda p: float(p.get('price', 0) or 0))
        elif sort == 'price_desc':
            products.sort(key=lambda p: float(p.get('price', 0) or 0), reverse=True)

        items = [serialize_product(p) for p in products]
        return api_response(
            data={"products": items, "count": len(items)},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch products: {e}", status=500)

@buyer_bp.route('/api/products/<product_id>', methods=['GET'])
def api_buyer_product_detail(product_id):
    try:
        product = product_model.get_by_id(product_id)
        if not product or product.get('status') != 'active':
            return api_error("Product not found", status=404)
        return api_response(
            data={"product": serialize_product(product)},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch product: {e}", status=500)

@buyer_bp.route('/cart')
@buyer_required
def cart():
    buyer_id = session['user']['id']
    cart_items = order_service.get_cart(buyer_id)
    return render_template('buyer/cart.html', cart_items=cart_items)

@buyer_bp.route('/checkout')
@buyer_required
def checkout():
    buyer_id = session['user']['id']
    address = auth_service.get_default_address(buyer_id)
    mode = request.args.get('mode', 'cart')
    return render_template('buyer/checkout.html', address=address, mode=mode)

@buyer_bp.route('/orders')
@buyer_required
def orders():
    return render_template('buyer/orders.html')

@buyer_bp.route('/address_book')
@buyer_required
def address_book():
    return render_template('buyer/address_book.html')

@buyer_bp.route('/order_summary')
@buyer_required
def order_summary():
    return render_template('buyer/order_summary.html')

@buyer_bp.route('/profile')
@buyer_required
def profile():
    user_id = session['user']['id']
    profile_data = user_model.get_by_id(user_id) or {}
    addresses = user_model.get_addresses(user_id) or []
    return render_template('buyer/profile.html', profile=profile_data, addresses=addresses)

@buyer_bp.route('/notifications')
@buyer_required
def notifications():
    return render_template('buyer/notifications.html')

@buyer_bp.route('/wishlist')
@buyer_required
def wishlist():
    return render_template('buyer/wishlist.html')

@buyer_bp.route('/api/notifications/unread-count', methods=['GET'])
@buyer_required
def api_notifications_unread_count():
    """Get the count of unread notifications for the current user."""
    try:
        user_id = session['user']['id']
        count = notification_model.get_unread_count(user_id)
        return api_response(
            data={"count": count},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to get unread count: {e}", status=500)

@buyer_bp.route('/api/notifications', methods=['GET'])
@buyer_required
def api_notifications():
    """Get notifications for the current user."""
    try:
        user_id = session['user']['id']
        unread_only = request.args.get('unread_only', 'false').lower() == 'true'
        limit = int(request.args.get('limit', 50))
        notifications = notification_model.get_all(user_id, limit=limit, unread_only=unread_only)
        return api_response(
            data={"notifications": notifications, "count": len(notifications or [])},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch notifications: {e}", status=500)

@buyer_bp.route('/api/notifications/<notification_id>/read', methods=['POST'])
@buyer_required
def api_mark_notification_as_read(notification_id):
    """Mark a specific notification as read."""
    try:
        user_id = session['user']['id']
        success = notification_model.mark_as_read(notification_id, user_id)
        if success:
            return api_response(
                data={},
                message="Notification marked as read",
                status=200,
            )
        return api_error("Notification not found", status=404)
    except Exception as e:
        return api_error(f"Failed to mark notification as read: {e}", status=500)

@buyer_bp.route('/api/notifications/read-all', methods=['POST'])
@buyer_required
def api_mark_all_as_read():
    """Mark all notifications as read for the current user."""
    try:
        user_id = session['user']['id']
        count = notification_model.mark_all_as_read(user_id)
        return api_response(
            data={"marked_count": count},
            message=f"Marked {count} notifications as read",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to mark all notifications as read: {e}", status=500)

@buyer_bp.route('/api/cart', methods=['GET', 'POST'])
@buyer_required
def api_cart():
    user_id = session['user']['id']
    if request.method == 'GET':
        try:
            items = order_model.get_cart_items(user_id)
            serialized_items = [serialize_cart_item(item) for item in items]
            total = round(sum(item.get('subtotal', 0.0) for item in serialized_items), 2)
            return api_response(
                data={
                    "items": serialized_items,
                    "item_count": sum(item.get('quantity', 0) for item in serialized_items),
                    "total": total,
                },
                message="OK",
                status=200,
            )
        except Exception as e:
            return api_error(f"Failed to fetch cart: {e}", status=500)

    # POST — add to cart with comprehensive stock validation
    try:
        data       = request.get_json() or {}
        product_id = data.get('product_id')
        variant_id = data.get('variant_id')
        quantity   = int(data.get('quantity', 1) or 1)

        if quantity <= 0:
            return api_error("Quantity must be at least 1", status=400)

        product = product_model.get_by_id(product_id)
        if not product or product.get('status') != 'active':
            return api_error("Product not available", status=400)

        # Determine available stock (variant-level if variant selected, else sum all variants)
        variants = product.get('product_variants') or []
        if variant_id:
            variant = next((v for v in variants if v['id'] == variant_id), None)
            if not variant:
                return api_error("Selected variant not found", status=400)
            available = int(variant.get('stock') or 0)
            variant_name = f"{variant.get('variant_type', '')}: {variant.get('value', '')}"
        else:
            # No variant selected — use sum of all variant stocks (source of truth)
            if variants:
                available = sum(int(v.get('stock') or 0) for v in variants)
            else:
                available = int(product.get('total_stock') or 0)
            variant_name = ""

        if available <= 0:
            return api_error(f'This product{(" (" + variant_name + ")" if variant_name else "")} is out of stock', status=400)

        # Check how many the buyer already has in cart
        existing = order_model.find_cart_item(user_id, product_id, variant_id)
        already_in_cart = int((existing or {}).get('quantity') or 0)
        requested_total = already_in_cart + quantity

        if requested_total > available:
            allowed = available - already_in_cart
            if allowed <= 0:
                return api_error(f'Maximum stock reached. You already have {already_in_cart} in your cart (available: {available})', status=400)
            return api_error(f'Only {allowed} more unit(s) available (total stock: {available})', status=400)

        price_snapshot = float(product.get('price', 0) or 0)
        item = order_model.add_or_increment_cart_item(user_id, product_id, variant_id, quantity, price_snapshot)
        if item:
            # Return updated cart
            cart_items = order_model.get_cart_items(user_id)
            serialized_items = [serialize_cart_item(cart_item) for cart_item in cart_items]
            total = round(sum(cart_item.get('subtotal', 0.0) for cart_item in serialized_items), 2)
            return api_response(
                data={
                    "items": serialized_items,
                    "item_count": sum(cart_item.get('quantity', 0) for cart_item in serialized_items),
                    "total": total,
                },
                message=f'Added {quantity} item(s) to cart',
                status=201,
            )
        return api_error("Failed to add item to cart", status=500)
    except Exception as e:
        return api_error(f"Failed to add to cart: {e}", status=500)

@buyer_bp.route('/api/cart/<item_id>', methods=['PUT', 'DELETE'])
@buyer_required
def api_cart_item(item_id):
    user_id = session['user']['id']
    if request.method == 'PUT':
        try:
            data     = request.get_json() or {}
            quantity = int(data.get('quantity', 1) or 1)
            if quantity <= 0:
                order_model.remove_cart_item(user_id, item_id)
                # Return updated cart
                cart_items = order_model.get_cart_items(user_id)
                serialized_items = [serialize_cart_item(cart_item) for cart_item in cart_items]
                total = round(sum(cart_item.get('subtotal', 0.0) for cart_item in serialized_items), 2)
                return api_response(
                    data={
                        "items": serialized_items,
                        "item_count": sum(cart_item.get('quantity', 0) for cart_item in serialized_items),
                        "total": total,
                    },
                    message="Item removed from cart",
                    status=200,
                )

            # Validate new quantity against available stock
            cart_items = order_model.get_cart_items(user_id)
            target = next((i for i in cart_items if i['id'] == item_id), None)
            if target:
                product = target.get('product') or {}
                variant_id = target.get('variant_id')
                if variant_id:
                    variant   = next((v for v in (product.get('product_variants') or []) if v['id'] == variant_id), None)
                    available = int((variant or {}).get('stock') or 0)
                else:
                    available = int(product.get('total_stock') or 0)
                if quantity > available:
                    return api_error(f'Only {available} unit(s) available in stock', status=400)

            updated = order_model.update_cart_item_qty(user_id, item_id, quantity)
            if updated:
                # Return updated cart
                cart_items = order_model.get_cart_items(user_id)
                serialized_items = [serialize_cart_item(cart_item) for cart_item in cart_items]
                total = round(sum(cart_item.get('subtotal', 0.0) for cart_item in serialized_items), 2)
                return api_response(
                    data={
                        "items": serialized_items,
                        "item_count": sum(cart_item.get('quantity', 0) for cart_item in serialized_items),
                        "total": total,
                    },
                    message="Cart updated",
                    status=200,
                )
            return api_error("Cart item not found", status=404)
        except Exception as e:
            return api_error(f"Failed to update cart item: {e}", status=500)
    
    # DELETE method
    try:
        order_model.remove_cart_item(user_id, item_id)
        # Return updated cart
        cart_items = order_model.get_cart_items(user_id)
        serialized_items = [serialize_cart_item(cart_item) for cart_item in cart_items]
        total = round(sum(cart_item.get('subtotal', 0.0) for cart_item in serialized_items), 2)
        return api_response(
            data={
                "items": serialized_items,
                "item_count": sum(cart_item.get('quantity', 0) for cart_item in serialized_items),
                "total": total,
            },
            message="Item removed from cart",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to remove cart item: {e}", status=500)

@buyer_bp.route('/api/buy-now', methods=['POST'])
@buyer_required
def api_buy_now():
    """Store a single product in session for Buy Now checkout (does not touch the cart)."""
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        product_id = data.get('product_id')
        variant_id = data.get('variant_id')
        quantity = int(data.get('quantity', 1) or 1)

        if quantity <= 0:
            return api_error('Quantity must be at least 1', status=400)

        product = product_model.get_by_id(product_id)
        if not product or product.get('status') != 'active':
            return api_error('Product not available', status=400)

        variants = product.get('product_variants') or []
        if variant_id:
            variant = next((v for v in variants if v['id'] == variant_id), None)
            if not variant:
                return api_error('Selected variant not found', status=400)
            available = int(variant.get('stock') or 0)
            unit_price = float(variant.get('final_price') or variant.get('price') or product.get('price') or 0)
            variant_label = f"{variant.get('variant_type', '')}: {variant.get('value', '')}"
        else:
            available = sum(int(v.get('stock') or 0) for v in variants) if variants else int(product.get('total_stock') or 0)
            unit_price = float(product.get('price') or 0)
            variant_label = ''

        if available <= 0:
            return api_error('This product is out of stock', status=400)
        if quantity > available:
            return api_error(f'Only {available} unit(s) available', status=400)

        # Build a minimal cart-item-like structure stored in session
        images = product.get('product_images') or []
        image_url = next((img['image_url'] for img in images if img.get('image_url')), None)

        session['buy_now'] = {
            'product_id': product_id,
            'variant_id': variant_id,
            'quantity': quantity,
            'unit_price': unit_price,
            'product_name': product.get('name', ''),
            'variant_label': variant_label,
            'image': image_url,
            'subtotal': round(unit_price * quantity, 2),
        }
        session.modified = True
        return api_response(data={}, message='Ready for checkout', status=200)
    except Exception as e:
        return api_error(f'Failed to prepare buy now: {str(e)}', status=500)


@buyer_bp.route('/api/buy-now', methods=['GET'])
@buyer_required
def api_get_buy_now():
    """Return the current buy-now session item."""
    item = session.get('buy_now')
    if not item:
        return api_error('No buy-now item in session', status=404)
    return api_response(data={'item': item}, message='OK', status=200)


@buyer_bp.route('/api/buy-now/checkout', methods=['POST'])
@buyer_required
def api_buy_now_checkout():
    """Place an order for the buy-now session item only (never touches the cart)."""
    import traceback
    user_id = session['user']['id']
    item = session.get('buy_now')
    if not item:
        return api_error('No buy-now item found. Please go back and try again.', status=400)

    data = request.get_json() or {}
    address_id = data.get('address_id')
    payment_method = data.get('payment_method', 'cod')
    if payment_method not in ('cod', 'card', 'bank_transfer', 'gcash'):
        payment_method = 'cod'

    address = user_model.get_address_by_id(user_id, address_id)
    if not address:
        return api_error('Invalid delivery address', status=400)

    product_id = item['product_id']
    variant_id = item.get('variant_id')
    quantity = int(item['quantity'])
    unit_price = float(item['unit_price'])

    # Re-validate stock before any DB writes
    if not order_model._check_stock_availability(product_id, variant_id, quantity):
        return api_error('Insufficient stock. Please go back and try again.', status=400)

    total_amount = round(unit_price * quantity, 2)
    order_items = [{
        'product_id': product_id,
        'variant_id': variant_id,
        'quantity': quantity,
        'unit_price': unit_price,
        'total_price': total_amount,
    }]

    try:
        # order_model.create() inserts all items first, then deducts stock.
        # On any failure it rolls back the order row and items — no phantom stock deduction.
        order = order_model.create({
            'buyer_id': user_id,
            'total_amount': total_amount,
            'shipping_address': address,
            'status': 'pending',
            'payment_method': 'bank_transfer' if payment_method == 'gcash' else payment_method,
        }, order_items)
    except Exception as e:
        traceback.print_exc()
        # buy_now session intentionally kept so the user can retry
        return api_error(f'Failed to create order: {str(e)}', status=500)

    # Order fully persisted — safe to clear buy-now session now
    session.pop('buy_now', None)
    session.modified = True

    # Fetch full order for response; fall back to bare order dict if fetch fails
    order_id = order.get('id')
    try:
        full_order = order_model.get_by_id(order_id)
    except Exception:
        full_order = None

    # Send confirmation email (non-blocking)
    try:
        from services.email_service import send_order_confirmation
        buyer = user_model.get_by_id(user_id)
        if buyer and buyer.get('email'):
            send_order_confirmation(
                to_email=buyer['email'],
                buyer_name=f"{buyer.get('first_name','')} {buyer.get('last_name','')}".strip(),
                order=full_order or order,
                items=(full_order or {}).get('order_items') or order_items
            )
    except Exception as mail_err:
        print(f'Buy-now order email error: {mail_err}')

    return api_response(
        data={'order': serialize_order(full_order or order)},
        message='Order placed successfully!',
        status=201,
    )


@buyer_bp.route('/api/cart/select', methods=['POST'])
@buyer_required
def api_cart_select():
    """Toggle selection state of one or all cart items (server-side persistence)."""
    try:
        user_id = session['user']['id']
        data    = request.get_json() or {}
        mode    = data.get('mode')  # 'item' | 'all'

        if mode == 'all':
            selected = bool(data.get('selected', True))
            order_model.set_all_cart_items_selected(user_id, selected)
            return api_response(data={}, message='All items updated', status=200)

        if mode == 'item':
            item_id  = data.get('item_id')
            selected = bool(data.get('selected', True))
            if not item_id:
                return api_error('item_id required', status=400)
            updated = order_model.set_cart_item_selected(user_id, item_id, selected)
            if not updated:
                return api_error('Cart item not found', status=404)
            return api_response(data={}, message='Item updated', status=200)

        return api_error('Invalid mode', status=400)
    except Exception as e:
        return api_error(f'Failed to update selection: {e}', status=500)


@buyer_bp.route('/api/checkout', methods=['POST'])
@buyer_required
def api_checkout():
    try:
        user_id = session['user']['id']
        data    = request.get_json() or {}
        address_id      = data.get('address_id')
        payment_method  = data.get('payment_method', 'cod')
        idempotency_key = data.get('idempotency_key')  # client-generated UUID

        if payment_method not in ('cod', 'card', 'bank_transfer', 'gcash'):
            payment_method = 'cod'

        # --- Idempotency: return previous result immediately ---
        if idempotency_key:
            existing = order_model.find_order_by_idempotency_key(idempotency_key)
            if existing:
                return api_response(
                    data={'order': serialize_order(order_model.get_by_id(existing['id']))},
                    message='Order already placed.',
                    status=200,
                )

        address = user_model.get_address_by_id(user_id, address_id)
        if not address:
            return api_error('Invalid delivery address', status=400)

        # --- Load ONLY selected cart items (server-side selection) ---
        selected_items = order_model.get_selected_cart_items(user_id)
        if not selected_items:
            return api_error('No items selected for checkout. Please select at least one item.', status=400)

        # --- Validate every selected item: ownership, product status, stock ---
        errors      = []
        order_items = []
        total_amount = 0.0

        for ci in selected_items:
            product    = ci.get('product') or {}
            product_id = ci.get('product_id')
            variant_id = ci.get('variant_id')
            qty        = int(ci.get('quantity', 0) or 0)
            name       = product.get('name', 'Unknown product')

            if product.get('status') != 'active':
                errors.append(f'"{name}" is no longer available.')
                continue

            # Recalculate price server-side — never trust client price
            variants = product.get('product_variants') or []
            if variant_id:
                variant    = next((v for v in variants if v['id'] == variant_id), None)
                unit_price = float((variant or {}).get('price') or product.get('price') or 0)
            else:
                unit_price = float(product.get('price') or 0)

            if not order_model._check_stock_availability(product_id, variant_id, qty):
                errors.append(f'Insufficient stock for "{name}".')
                continue

            line_total    = round(unit_price * qty, 2)
            total_amount += line_total
            order_items.append({
                'product_id':  product_id,
                'variant_id':  variant_id,
                'quantity':    qty,
                'unit_price':  unit_price,
                'total_price': line_total,
                '_cart_item_id': ci['id'],   # used for removal, stripped before insert
            })

        # All-or-nothing: if ANY item failed, abort the entire checkout
        if errors:
            return api_error(' | '.join(errors), status=400)

        # Strip internal helper key before DB insert
        cart_item_ids = [item.pop('_cart_item_id') for item in order_items]

        order = order_model.create(
            {
                'buyer_id':         user_id,
                'total_amount':     round(total_amount, 2),
                'shipping_address': address,
                'status':           'pending',
                'payment_method':   'bank_transfer' if payment_method == 'gcash' else payment_method,
            },
            order_items,
            cart_item_ids=cart_item_ids,   # removed atomically inside create()
            idempotency_key=idempotency_key,
        )

        # Fetch full order for response
        order_id = order.get('id')
        try:
            full_order = order_model.get_by_id(order_id)
        except Exception:
            full_order = None

        # Send confirmation email (non-blocking)
        try:
            from services.email_service import send_order_confirmation
            buyer = user_model.get_by_id(user_id)
            if buyer and buyer.get('email'):
                send_order_confirmation(
                    to_email=buyer['email'],
                    buyer_name=f"{buyer.get('first_name','')} {buyer.get('last_name','')}".strip(),
                    order=full_order or order,
                    items=(full_order or {}).get('order_items') or order_items
                )
        except Exception as mail_err:
            print(f'Order email error: {mail_err}')

        return api_response(
            data={'order': serialize_order(full_order or order)},
            message='Order placed successfully!',
            status=201,
        )
    except Exception as e:
        import traceback
        traceback.print_exc()
        return api_error(f'Failed to create order: {str(e)}', status=500)

@buyer_bp.route('/api/orders', methods=['GET', 'POST'])
@buyer_required
def api_orders():
    user_id = session['user']['id']
    if request.method == 'GET':
        try:
            orders = order_model.get_by_buyer(user_id)
            items = [serialize_order(o) for o in (orders or [])]
            return api_response(
                data={"orders": items, "count": len(items)},
                message="OK",
                status=200,
            )
        except Exception as e:
            return api_error(f"Failed to fetch orders: {e}", status=500)
    # Backward-compatible alias: POST /api/orders -> checkout
    return api_checkout()

@buyer_bp.route('/api/orders/<order_id>', methods=['GET'])
@buyer_required
def api_order_detail(order_id):
    try:
        user_id = session['user']['id']
        order = order_model.get_by_id(order_id)
        if not order or order.get('buyer_id') != user_id:
            return api_error("Order not found", status=404)
        return api_response(
            data={"order": serialize_order(order)},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch order: {e}", status=500)

@buyer_bp.route('/api/orders/<order_id>/cancel', methods=['POST'])
@buyer_required
def api_cancel_order(order_id):
    """Cancel an order. Idempotent — returns success if already cancelled."""
    from security import rate_limit as _rl
    from datetime import datetime, timezone
    try:
        user_id = session['user']['id']
        data    = request.get_json() or {}
        reason  = (data.get('reason') or 'Cancelled by buyer')[:200]
        idem_key = data.get('idempotency_key')

        # Idempotency: if this key already produced a cancellation, return it
        if idem_key:
            existing = order_model.supabase.table('orders') \
                .select('*').eq('cancel_idem_key', idem_key).limit(1).execute()
            if existing.data:
                return api_response(
                    data={'order': serialize_order(existing.data[0])},
                    message='Order already cancelled.',
                    status=200,
                )

        # Load order and verify ownership
        order = order_model.supabase.table('orders') \
            .select('*').eq('id', order_id).limit(1).execute()
        if not order.data:
            return api_error('Order not found.', status=404)
        o = order.data[0]

        if o.get('buyer_id') != user_id:
            return api_error('Order not found.', status=404)  # don't leak existence

        # Idempotency: already cancelled
        if o.get('status') == 'cancelled':
            return api_response(
                data={'order': serialize_order(o)},
                message='Order is already cancelled.',
                status=200,
            )

        # Only allow cancellation of pending / processing orders
        CANCELLABLE = {'pending', 'processing'}
        if o.get('status') not in CANCELLABLE:
            return api_error(
                f'This order cannot be cancelled (current status: {o.get("status")}).',
                status=400,
            )

        now_iso = datetime.now(timezone.utc).isoformat()
        update_payload = {
            'status':        'cancelled',
            'cancelled_at':  now_iso,
            'cancel_reason': reason,
        }
        if idem_key:
            update_payload['cancel_idem_key'] = idem_key

        updated = order_model.supabase.table('orders') \
            .update(update_payload).eq('id', order_id).execute()
        if not updated.data:
            return api_error('Failed to cancel order. Please try again.', status=500)

        # Restore stock for all items in this order
        items = order_model.supabase.table('order_items') \
            .select('product_id, variant_id, quantity').eq('order_id', order_id).execute()
        for item in (items.data or []):
            qty        = int(item.get('quantity', 0))
            variant_id = item.get('variant_id')
            product_id = item.get('product_id')
            if variant_id:
                v = order_model.supabase.table('product_variants') \
                    .select('stock').eq('id', variant_id).limit(1).execute()
                if v.data:
                    order_model.supabase.table('product_variants') \
                        .update({'stock': int(v.data[0]['stock']) + qty}) \
                        .eq('id', variant_id).execute()
            # Sync product total_stock
            all_v = order_model.supabase.table('product_variants') \
                .select('stock').eq('product_id', product_id).execute()
            if all_v.data:
                new_total = sum(int(x['stock']) for x in all_v.data)
                order_model.supabase.table('products') \
                    .update({'total_stock': new_total}).eq('id', product_id).execute()

        return api_response(
            data={'order': serialize_order(updated.data[0])},
            message='Order cancelled successfully.',
            status=200,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to cancel order: {str(e)}', status=500)


@buyer_bp.route('/api/orders/<order_id>/confirm-received', methods=['POST'])
@buyer_required
def api_confirm_received(order_id):
    """Buyer confirms they received the order. Idempotent."""
    from datetime import datetime, timezone
    try:
        user_id  = session['user']['id']
        data     = request.get_json() or {}
        idem_key = data.get('idempotency_key')

        order = order_model.supabase.table('orders') \
            .select('*').eq('id', order_id).limit(1).execute()
        if not order.data:
            return api_error('Order not found.', status=404)
        o = order.data[0]

        if o.get('buyer_id') != user_id:
            return api_error('Order not found.', status=404)

        # Idempotency: already confirmed
        if o.get('status') in ('delivered', 'completed'):
            return api_response(
                data={'order': serialize_order(o)},
                message='Order already confirmed as received.',
                status=200,
            )

        # Must be in_transit to confirm
        if o.get('status') != 'in_transit':
            return api_error(
                f'Cannot confirm receipt for an order with status "{o.get("status")}".',
                status=400,
            )

        now_iso = datetime.now(timezone.utc).isoformat()
        updated = order_model.supabase.table('orders') \
            .update({'status': 'delivered', 'confirmed_at': now_iso}) \
            .eq('id', order_id).execute()
        if not updated.data:
            return api_error('Failed to confirm receipt. Please try again.', status=500)

        return api_response(
            data={'order': serialize_order(updated.data[0])},
            message='Order confirmed as received!',
            status=200,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to confirm receipt: {str(e)}', status=500)


@buyer_bp.route('/api/orders/<order_id>/return', methods=['POST'])
@buyer_required
def api_create_return(order_id):
    """Submit a return/refund request. Idempotent via idempotency_key."""
    from datetime import datetime, timezone, timedelta
    from security import sanitise
    RETURN_WINDOW_DAYS = 7
    try:
        user_id = session['user']['id']

        # Support multipart (with images) or JSON
        if request.content_type and 'multipart' in request.content_type:
            data = request.form
            files = request.files.getlist('images')
        else:
            data  = request.get_json() or {}
            files = []

        idem_key    = data.get('idempotency_key') or ''
        reason      = sanitise(data.get('reason', ''), 100)
        description = sanitise(data.get('description', ''), 500)
        items_raw   = data.get('items')  # JSON string when multipart

        if not reason:
            return api_error('Reason is required.', status=400)

        # Idempotency check
        if idem_key:
            existing = order_model.supabase.table('return_requests') \
                .select('*').eq('idempotency_key', idem_key).limit(1).execute()
            if existing.data:
                return api_response(
                    data={'return_request': existing.data[0]},
                    message='Return request already submitted.',
                    status=200,
                )

        # Validate order ownership and status
        order = order_model.supabase.table('orders') \
            .select('*').eq('id', order_id).limit(1).execute()
        if not order.data:
            return api_error('Order not found.', status=404)
        o = order.data[0]
        if o.get('buyer_id') != user_id:
            return api_error('Order not found.', status=404)
        if o.get('status') not in ('delivered', 'completed'):
            return api_error('Returns are only available for delivered orders.', status=400)

        # Check return window
        confirmed_raw = o.get('confirmed_at') or o.get('updated_at')
        if confirmed_raw:
            confirmed_dt = datetime.fromisoformat(confirmed_raw.replace('Z', '+00:00'))
            if datetime.now(timezone.utc) > confirmed_dt + timedelta(days=RETURN_WINDOW_DAYS):
                return api_error(
                    f'The {RETURN_WINDOW_DAYS}-day return window has expired.',
                    status=400,
                )

        # Parse items to return
        import json as _json
        if isinstance(items_raw, str):
            try:
                items_to_return = _json.loads(items_raw)
            except Exception:
                items_to_return = []
        elif isinstance(items_raw, list):
            items_to_return = items_raw
        else:
            items_to_return = []

        # Validate return quantities against order items
        order_items_res = order_model.supabase.table('order_items') \
            .select('*').eq('order_id', order_id).execute()
        order_items_map = {i['id']: i for i in (order_items_res.data or [])}

        validated_items = []
        for ri in items_to_return:
            oi_id = ri.get('order_item_id')
            qty   = int(ri.get('quantity', 1))
            oi    = order_items_map.get(oi_id)
            if not oi:
                return api_error(f'Order item {oi_id} not found in this order.', status=400)
            if qty > int(oi.get('quantity', 0)):
                return api_error(
                    f'Return quantity exceeds ordered quantity for item {oi_id}.',
                    status=400,
                )
            validated_items.append({
                'order_item_id': oi_id,
                'product_id':    oi['product_id'],
                'quantity':      qty,
            })

        # Upload images (max 3, 5 MB each, JPEG/PNG/WebP only)
        from services.file_upload_service import FileUploadService
        fus = FileUploadService()
        image_urls = []
        for f in files[:3]:
            url = fus.save_file(f, subfolder='returns')
            if url:
                image_urls.append(url)

        # Create return request
        rr_payload = {
            'order_id':        order_id,
            'buyer_id':        user_id,
            'reason':          reason,
            'description':     description,
            'status':          'pending_review',
        }
        if idem_key:
            rr_payload['idempotency_key'] = idem_key

        rr_res = order_model.supabase.table('return_requests').insert(rr_payload).execute()
        if not rr_res.data:
            return api_error('Failed to create return request.', status=500)
        rr = rr_res.data[0]
        rr_id = rr['id']

        # Insert return items
        for vi in validated_items:
            order_model.supabase.table('return_request_items').insert({
                'return_request_id': rr_id,
                'order_item_id':     vi['order_item_id'],
                'product_id':        vi['product_id'],
                'quantity':          vi['quantity'],
            }).execute()

        # Insert images
        for url in image_urls:
            order_model.supabase.table('return_request_images').insert({
                'return_request_id': rr_id,
                'image_url':         url,
            }).execute()

        # Mark order as return_requested
        order_model.supabase.table('orders') \
            .update({'status': 'return_requested'}).eq('id', order_id).execute()

        return api_response(
            data={'return_request': rr},
            message='Return request submitted successfully.',
            status=201,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to submit return request: {str(e)}', status=500)


@buyer_bp.route('/api/orders/<order_id>/review', methods=['POST'])
@buyer_required
def api_submit_order_review(order_id):
    """Submit a review for a product in a delivered order. Idempotent."""
    from security import sanitise, rate_limit as _rl
    try:
        user_id = session['user']['id']

        if request.content_type and 'multipart' in request.content_type:
            data  = request.form
            files = request.files.getlist('images')
        else:
            data  = request.get_json() or {}
            files = []

        product_id  = data.get('product_id')
        rating_raw  = data.get('rating')
        comment_raw = data.get('comment', '')
        idem_key    = data.get('idempotency_key') or ''

        if not product_id or rating_raw is None:
            return api_error('product_id and rating are required.', status=400)

        try:
            rating = int(rating_raw)
        except (TypeError, ValueError):
            return api_error('Rating must be an integer 1–5.', status=400)
        if not (1 <= rating <= 5):
            return api_error('Rating must be between 1 and 5.', status=400)

        # Sanitise comment — strip HTML, max 500 chars
        comment = sanitise(comment_raw, 500)

        # Validate order ownership and delivered status
        order = order_model.supabase.table('orders') \
            .select('*').eq('id', order_id).limit(1).execute()
        if not order.data:
            return api_error('Order not found.', status=404)
        o = order.data[0]
        if o.get('buyer_id') != user_id:
            return api_error('Order not found.', status=404)
        if o.get('status') not in ('delivered', 'completed'):
            return api_error('Reviews are only available for delivered orders.', status=400)

        # Validate product was in this order
        oi_res = order_model.supabase.table('order_items') \
            .select('id, is_reviewed').eq('order_id', order_id) \
            .eq('product_id', product_id).limit(1).execute()
        if not oi_res.data:
            return api_error('This product was not part of the order.', status=400)
        oi = oi_res.data[0]

        # Block duplicate reviews
        dup = order_model.supabase.table('reviews') \
            .select('id').eq('user_id', user_id) \
            .eq('product_id', product_id).eq('order_id', order_id).limit(1).execute()
        if dup.data:
            return api_error('You have already reviewed this product for this order.', status=400)

        # Upload images (max 3)
        from services.file_upload_service import FileUploadService
        fus = FileUploadService()
        image_url = None
        for f in files[:3]:
            url = fus.save_file(f, subfolder='reviews')
            if url:
                image_url = url  # store first image in reviews.image_url
                break

        # Create review
        eligibility = review_model.can_review(user_id, product_id, order_id)
        if not eligibility.get('can_review', True) and not idem_key:
            return api_error(eligibility.get('reason', 'Cannot review.'), status=400)

        review = review_model.create_review(
            user_id, product_id, order_id, rating, comment, image_url
        )
        if not review:
            return api_error('Failed to submit review. You may have already reviewed this product.', status=400)

        # Mark order item as reviewed
        order_model.supabase.table('order_items') \
            .update({'is_reviewed': True}).eq('id', oi['id']).execute()

        return api_response(
            data={'review': review},
            message='Review submitted successfully!',
            status=201,
        )
    except Exception as e:
        import traceback; traceback.print_exc()
        return api_error(f'Failed to submit review: {str(e)}', status=500)

@buyer_bp.route('/api/addresses', methods=['GET'])
@buyer_required
def api_addresses():
    try:
        user_id = session['user']['id']
        addresses = user_model.get_addresses(user_id)
        return api_response(
            data={"addresses": addresses or [], "count": len(addresses or [])},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch addresses: {e}", status=500)

@buyer_bp.route('/api/addresses', methods=['POST'])
@buyer_required
def api_create_address():
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        
        # Validate required fields
        required_fields = ['label', 'region', 'city', 'barangay', 'street', 'zip_code']
        missing = [field for field in required_fields if not data.get(field)]
        if missing:
            return api_error(f"Missing required fields: {', '.join(missing)}", status=400)
        
        # Prepare address data
        address_data = {
            'user_id': user_id,
            'label': data['label'],
            'region': data['region'],
            'city': data['city'],
            'barangay': data['barangay'],
            'street': data['street'],
            'zip_code': data['zip_code'],
            'latitude': data.get('latitude'),
            'longitude': data.get('longitude')
        }
        
        # Check if this is the first address (make it default)
        addresses = user_model.get_addresses(user_id)
        if len(addresses) == 0:
            address_data['is_default'] = True
        
        address = user_model.create_address(address_data)
        if address:
            return api_response(
                data={"address": address},
                message="Address created successfully",
                status=201,
            )
        else:
            return api_error("Failed to create address", status=500)
    except Exception as e:
        return api_error(f"Failed to create address: {e}", status=500)

@buyer_bp.route('/api/addresses/<address_id>', methods=['PUT'])
@buyer_required
def api_update_address(address_id):
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        
        # Verify address belongs to user
        address = user_model.get_address_by_id(user_id, address_id)
        if not address:
            return api_error("Address not found", status=404)
        
        # Update address fields
        update_data = {}
        if 'label' in data:
            update_data['label'] = data['label']
        if 'region' in data:
            update_data['region'] = data['region']
        if 'city' in data:
            update_data['city'] = data['city']
        if 'barangay' in data:
            update_data['barangay'] = data['barangay']
        if 'street' in data:
            update_data['street'] = data['street']
        if 'zip_code' in data:
            update_data['zip_code'] = data['zip_code']
        if 'latitude' in data:
            update_data['latitude'] = data['latitude']
        if 'longitude' in data:
            update_data['longitude'] = data['longitude']
        
        if not update_data:
            return api_error("No fields to update", status=400)
        
        updated_address = user_model.update_address(user_id, address_id, update_data)
        if updated_address:
            return api_response(
                data={"address": updated_address},
                message="Address updated successfully",
                status=200,
            )
        else:
            return api_error("Failed to update address", status=500)
    except Exception as e:
        return api_error(f"Failed to update address: {e}", status=500)

@buyer_bp.route('/api/addresses/<address_id>', methods=['DELETE'])
@buyer_required
def api_delete_address(address_id):
    try:
        user_id = session['user']['id']
        
        # Verify address belongs to user
        address = user_model.get_address_by_id(user_id, address_id)
        if not address:
            return api_error("Address not found", status=404)
        
        # Don't allow deletion of default address without setting another as default
        if address.get('is_default'):
            addresses = user_model.get_addresses(user_id)
            if len(addresses) <= 1:
                return api_error("Cannot delete the only address. Please add another address first.", status=400)
        
        success = user_model.delete_address(user_id, address_id)
        if success:
            # If deleted address was default, set another as default
            if address.get('is_default'):
                addresses = user_model.get_addresses(user_id)
                if addresses:
                    user_model.update_address(user_id, addresses[0]['id'], {'is_default': True})
            return api_response(
                data={},
                message="Address deleted successfully",
                status=200,
            )
        else:
            return api_error("Failed to delete address", status=500)
    except Exception as e:
        return api_error(f"Failed to delete address: {e}", status=500)

@buyer_bp.route('/api/addresses/<address_id>/default', methods=['POST'])
@buyer_required
def api_set_default_address(address_id):
    try:
        user_id = session['user']['id']
        
        # Verify address belongs to user
        address = user_model.get_address_by_id(user_id, address_id)
        if not address:
            return api_error("Address not found", status=404)
        
        # Remove default flag from all addresses
        addresses = user_model.get_addresses(user_id)
        for addr in addresses:
            if addr['id'] != address_id:
                user_model.update_address(user_id, addr['id'], {'is_default': False})
        
        # Set this address as default
        updated_address = user_model.update_address(user_id, address_id, {'is_default': True})
        if updated_address:
            return api_response(
                data={"address": updated_address},
                message="Default address set successfully",
                status=200,
            )
        else:
            return api_error("Failed to set default address", status=500)
    except Exception as e:
        return api_error(f"Failed to set default address: {e}", status=500)

@buyer_bp.route('/api/profile', methods=['GET'])
@buyer_required
def api_get_profile():
    try:
        user_id = session['user']['id']
        user = user_model.get_by_id(user_id)
        if not user:
            return api_error('User not found', status=404)
        return api_response(
            data={"user": {
                'id':         user.get('id'),
                'first_name': user.get('first_name', ''),
                'last_name':  user.get('last_name', ''),
                'email':      user.get('email', ''),
                'phone':      user.get('phone', ''),
                'gender':     user.get('gender', ''),
                'role':       user.get('role', ''),
            }},
            message='OK', status=200,
        )
    except Exception as e:
        return api_error(f'Failed to fetch profile: {e}', status=500)

@buyer_bp.route('/api/profile', methods=['PUT'])
@buyer_required
def api_update_profile():
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        from security import sanitise

        update_data = {}
        if 'full_name' in data:
            full_name   = sanitise(data['full_name'], 100)
            name_parts  = full_name.strip().split(' ', 1)
            update_data['first_name'] = name_parts[0]
            update_data['last_name']  = name_parts[1] if len(name_parts) > 1 else ''
        if 'phone' in data:
            update_data['phone'] = sanitise(data['phone'], 20)
        if 'gender' in data and data['gender'] in ('male', 'female', 'other', ''):
            update_data['gender'] = data['gender']

        if not update_data:
            return api_error("No fields to update", status=400)

        updated_user = user_model.update(user_id, update_data)
        if updated_user:
            session['user'].update({
                'first_name': updated_user.get('first_name'),
                'last_name':  updated_user.get('last_name'),
                'phone':      updated_user.get('phone')
            })
            session['user']['name'] = f"{updated_user.get('first_name', '')} {updated_user.get('last_name', '')}".strip()
            return api_response(
                data={"user": updated_user},
                message="Profile updated successfully",
                status=200,
            )
        return api_error("Failed to update profile", status=500)
    except Exception as e:
        return api_error(f"Failed to update profile: {e}", status=500)

@buyer_bp.route('/api/password', methods=['PUT'])
@buyer_required
def api_change_password():
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        from security import validate_password, verify_password, hash_password

        current_password = data.get('current_password', '')
        new_password     = data.get('new_password', '')

        if not current_password or not new_password:
            return api_error('Current password and new password are required', status=400)

        is_valid, error_msg = validate_password(new_password)
        if not is_valid:
            return api_error(error_msg, status=400)

        user = user_model.get_by_id(user_id)
        if not user:
            return api_error('User not found', status=404)

        if not verify_password(current_password, user['password']):
            return api_error('Current password is incorrect', status=400)

        updated_user = user_model.update(user_id, {'password': hash_password(new_password)})
        if updated_user:
            return api_response(
                data={},
                message='Password changed successfully',
                status=200,
            )
        return api_error('Failed to change password', status=500)
    except Exception as e:
        return api_error(f'Failed to change password: {e}', status=500)



@buyer_bp.route('/api/account', methods=['DELETE'])
@buyer_required
def api_delete_account():
    try:
        user_id = session['user']['id']
        # Soft-delete: mark user as inactive rather than hard delete
        updated = user_model.update(user_id, {'role': 'deleted', 'email': f'deleted_{user_id}@deleted.invalid'})
        if updated:
            session.clear()
            return api_response(data={}, message='Account deleted successfully', status=200)
        return api_error('Failed to delete account', status=500)
    except Exception as e:
        return api_error(f'Failed to delete account: {e}', status=500)

@buyer_bp.route('/settings')
@buyer_required
def settings():
    return render_template('buyer/settings.html')

# ============================================
# REVIEW API ENDPOINTS (Flutter-ready)
# ============================================

@buyer_bp.route('/api/reviews', methods=['GET'])
@buyer_required
def api_reviews():
    """
    Get reviews - supports multiple query patterns:
    - GET /api/reviews?product_id=xxx - Get reviews for a product
    - GET /api/reviews?user_id=xxx - Get reviews by a user
    """
    try:
        product_id = request.args.get('product_id')
        user_id = request.args.get('user_id')
        
        if product_id:
            # Get product reviews with stats
            reviews = review_model.get_product_reviews(product_id)
            stats = review_model.get_review_stats(product_id)
            
            # Check if current user has reviewed this product
            current_user_id = session['user']['id']
            has_reviewed = review_model.has_reviewed_product(current_user_id, product_id)
            
            return api_response(
                data={
                    "reviews": reviews,
                    "stats": stats,
                    "has_reviewed": has_reviewed,
                    "count": len(reviews or [])
                },
                message="OK",
                status=200,
            )
        
        if user_id:
            # Get user's reviews (own reviews)
            current_user_id = session['user']['id']
            if user_id != current_user_id:
                return api_error("Unauthorized", status=403)
            
            reviews = review_model.get_user_reviews(user_id)
            return api_response(
                data={"reviews": reviews, "count": len(reviews or [])},
                message="OK",
                status=200,
            )
        
        return api_error("Missing required parameter: product_id or user_id", status=400)
    except Exception as e:
        return api_error(f"Failed to fetch reviews: {e}", status=500)

@buyer_bp.route('/api/reviews', methods=['POST'])
@buyer_required
def api_create_review():
    """Create a new review. Validates order status and eligibility."""
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        
        product_id = data.get('product_id')
        order_id = data.get('order_id')
        rating = data.get('rating')
        comment = data.get('comment', '')
        image_url = data.get('image_url')
        
        # Validate required fields
        if not product_id or not order_id or rating is None:
            return api_error('Missing required fields: product_id, order_id, rating', status=400)
        
        if not isinstance(rating, int) or rating < 1 or rating > 5:
            return api_error('Rating must be an integer between 1 and 5', status=400)
        
        # Check if user can review this product
        eligibility = review_model.can_review(user_id, product_id, order_id)
        if not eligibility['can_review']:
            return api_error(eligibility['reason'], status=400)
        
        # Create the review
        review = review_model.create_review(user_id, product_id, order_id, rating, comment, image_url)
        
        if review:
            return api_response(
                data={"review": review},
                message='Review submitted successfully!',
                status=201,
            )
        
        return api_error('Failed to create review. You may have already reviewed this product.', status=400)
    except Exception as e:
        return api_error(f"Failed to create review: {e}", status=500)

@buyer_bp.route('/api/reviews/<review_id>', methods=['GET'])
@buyer_required
def api_get_review(review_id):
    """Get a specific review."""
    try:
        review = review_model.get_review_by_id(review_id)
        if not review:
            return api_error("Review not found", status=404)
        
        return api_response(
            data={"review": review},
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to fetch review: {e}", status=500)

@buyer_bp.route('/api/reviews/<review_id>', methods=['PUT'])
@buyer_required
def api_update_review(review_id):
    """Update own review."""
    try:
        user_id = session['user']['id']
        data = request.get_json() or {}
        
        rating = data.get('rating')
        comment = data.get('comment')
        image_url = data.get('image_url')
        
        # Validate rating if provided
        if rating is not None and (not isinstance(rating, int) or rating < 1 or rating > 5):
            return api_error('Rating must be an integer between 1 and 5', status=400)
        
        success = review_model.update_review(review_id, user_id, rating, comment, image_url)
        
        if success:
            return api_response(
                data={},
                message='Review updated successfully',
                status=200,
            )
        
        return api_error('Review not found or you do not have permission to update it', status=404)
    except Exception as e:
        return api_error(f"Failed to update review: {e}", status=500)

@buyer_bp.route('/api/reviews/<review_id>', methods=['DELETE'])
@buyer_required
def api_delete_review(review_id):
    """Delete own review."""
    try:
        user_id = session['user']['id']
        success = review_model.delete_review(review_id, user_id)
        
        if success:
            return api_response(
                data={},
                message='Review deleted successfully',
                status=200,
            )
        
        return api_error('Review not found or you do not have permission to delete it', status=404)
    except Exception as e:
        return api_error(f"Failed to delete review: {e}", status=500)

@buyer_bp.route('/api/orders/<order_id>/products/<product_id>/can_review', methods=['GET'])
@buyer_required
def api_can_review(order_id, product_id):
    """Check if user can review a specific product from an order."""
    try:
        user_id = session['user']['id']
        eligibility = review_model.can_review(user_id, product_id, order_id)
        return api_response(
            data=eligibility,
            message="OK",
            status=200,
        )
    except Exception as e:
        return api_error(f"Failed to check review eligibility: {e}", status=500)

