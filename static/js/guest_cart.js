/**
 * guest_cart.js — Guest cart manager (localStorage-based)
 * Persists cart across page reloads for unauthenticated users
 */

const GUEST_CART_KEY = 'grande_guest_cart';

const GuestCart = {
    get() {
        try {
            return JSON.parse(localStorage.getItem(GUEST_CART_KEY) || '[]');
        } catch {
            return [];
        }
    },

    set(cart) {
        localStorage.setItem(GUEST_CART_KEY, JSON.stringify(cart));
    },

    add(productId, variantId, quantity, productData) {
        const cart = this.get();
        const existing = cart.find(i => i.product_id === productId && i.variant_id === variantId);
        
        if (existing) {
            existing.quantity += quantity;
        } else {
            cart.push({
                product_id: productId,
                variant_id: variantId,
                quantity,
                price_snapshot: productData.price,
                product_name: productData.name,
                image: productData.image,
                variant_value: productData.variant_value
            });
        }
        
        this.set(cart);
        return cart;
    },

    update(productId, variantId, quantity) {
        const cart = this.get();
        const item = cart.find(i => i.product_id === productId && i.variant_id === variantId);
        if (item) {
            if (quantity <= 0) {
                return this.remove(productId, variantId);
            }
            item.quantity = quantity;
            this.set(cart);
        }
        return cart;
    },

    remove(productId, variantId) {
        const cart = this.get().filter(i => !(i.product_id === productId && i.variant_id === variantId));
        this.set(cart);
        return cart;
    },

    clear() {
        localStorage.removeItem(GUEST_CART_KEY);
    },

    count() {
        return this.get().reduce((sum, i) => sum + i.quantity, 0);
    }
};
