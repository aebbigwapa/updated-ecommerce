/**
 * api.js — Centralized REST API layer
 * Responses are automatically unwrapped from {success, data, error} envelope.
 */

// ── Logout confirmation (wired to all logout links on every page) ──
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('a.logout-link, a[href="/logout"]').forEach(link => {
        link.addEventListener('click', e => {
            e.preventDefault();
            const href = link.href || '/logout';
            if (document.getElementById('_logoutModal')) return;
            const overlay = document.createElement('div');
            overlay.id = '_logoutModal';
            overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:9999;display:flex;align-items:center;justify-content:center;padding:16px';
            overlay.innerHTML = `
                <div style="background:#fff;border-radius:18px;padding:28px 24px;width:100%;max-width:340px;text-align:center;box-shadow:0 20px 60px rgba(0,0,0,.18);animation:_lci .2s ease">
                    <div style="font-size:44px;margin-bottom:12px">🚪</div>
                    <div style="font-size:18px;font-weight:700;color:#1a1a3e;margin-bottom:8px">Log out?</div>
                    <div style="font-size:14px;color:#6c757d;margin-bottom:24px">Are you sure you want to log out?</div>
                    <div style="display:flex;gap:10px">
                        <button id="_logoutCancel" style="flex:1;padding:11px;border-radius:10px;border:1.5px solid #e8e8f0;background:#fff;font-size:14px;font-weight:600;color:#1a1a3e;cursor:pointer">Cancel</button>
                        <button id="_logoutConfirm" style="flex:1;padding:11px;border-radius:10px;border:none;background:linear-gradient(135deg,#FF2BAC,#FF6BCE);color:#fff;font-size:14px;font-weight:600;cursor:pointer">Yes, Log out</button>
                    </div>
                </div>
                <style>@keyframes _lci{from{transform:scale(.92);opacity:0}to{transform:scale(1);opacity:1}}</style>
            `;
            document.body.appendChild(overlay);
            document.getElementById('_logoutCancel').onclick  = () => overlay.remove();
            document.getElementById('_logoutConfirm').onclick = () => { window.location.href = href; };
            overlay.addEventListener('click', ev => { if (ev.target === overlay) overlay.remove(); });
        });
    });
});

function _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
}

// Unwrap {success, data, error} envelope — merges data fields to top level
function _unwrap(json) {
    if (!json || typeof json !== 'object') return { success: false, error: 'Invalid response' };
    if (!('success' in json)) return json;
    if (!json.success) return { success: false, error: json.error || json.message || 'Request failed' };
    return { success: true, message: json.message || '', ...(json.data || {}) };
}

function _post(url, body) {
    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _csrfToken() },
        body: JSON.stringify(body),
    }).then(r => r.json()).then(_unwrap).catch(e => ({ success: false, error: e.message }));
}

function _put(url, body) {
    return fetch(url, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _csrfToken() },
        body: JSON.stringify(body),
    }).then(r => r.json()).then(_unwrap).catch(e => ({ success: false, error: e.message }));
}

function _delete(url) {
    return fetch(url, {
        method: 'DELETE',
        headers: { 'X-CSRF-Token': _csrfToken() },
    }).then(r => r.json()).then(_unwrap).catch(e => ({ success: false, error: e.message }));
}

function _get(url) {
    return fetch(url).then(r => r.json()).then(_unwrap).catch(e => ({ success: false, error: e.message }));
}

const API = {

    applications: {
        getAll:       ()                       => _get('/admin/api/applications'),
        getOne:       (id)                     => _get(`/admin/api/applications/${encodeURIComponent(id)}`),
        updateStatus: (id, status, notes = '') => _post(`/admin/api/applications/${encodeURIComponent(id)}/status`, { status, notes }),
    },

    auth: {
        login: (email, password) =>
            fetch('/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _csrfToken() },
                body: JSON.stringify({ email, password }),
            }).then(async r => ({ ok: r.ok, data: await r.json() })),

        register: (formData) => {
            formData.append('csrf_token', _csrfToken());
            return fetch('/register', {
                method: 'POST',
                headers: { 'X-CSRF-Token': _csrfToken() },
                body: formData,
            }).then(async r => ({ ok: r.ok, data: await r.json() }));
        },
    },

    seller: {
        getProducts:       ()           => _get('/seller/api/products'),
        getOrders:         ()           => _get('/seller/api/orders'),
        updateOrderStatus: (id, status) => _post(`/seller/api/orders/${encodeURIComponent(id)}/status`, { status }),
        getEarnings:       ()           => _get('/seller/api/earnings'),
        getShipping:       ()           => _get('/seller/api/shipping'),
        getReviews:        ()           => _get('/seller/api/reviews'),
        getStore:          ()           => _get('/seller/api/store'),
        updateStore:       (data)       => _post('/seller/api/store', data),
        getDashboardSummary: ()         => _get('/seller/api/dashboard-summary'),
        getSalesAnalytics: (period)     => _get(`/seller/api/sales-analytics?period=${encodeURIComponent(period || 'daily')}`),
        getRecentOrders:   (limit)      => _get(`/seller/api/recent-orders?limit=${encodeURIComponent(limit || 10)}`),
        getTopProducts:    (limit)      => _get(`/seller/api/top-products?limit=${encodeURIComponent(limit || 5)}`),
        getLowStock:       (threshold)  => _get(`/seller/api/low-stock?threshold=${encodeURIComponent(threshold || 10)}`),
    },

    buyer: {
        // Returns unwrapped: { success, items, item_count, total }
        getCart:        ()             => _get('/buyer/api/cart'),
        // Returns unwrapped: { success, items, item_count, total }
        addToCart:      (payload)      => _post('/buyer/api/cart', payload),
        // Returns unwrapped: { success, items, item_count, total }
        updateCartItem: (id, quantity) => _put(`/buyer/api/cart/${encodeURIComponent(id)}`, { quantity }),
        // Returns unwrapped: { success, items, item_count, total }
        removeCartItem: (id)           => _delete(`/buyer/api/cart/${encodeURIComponent(id)}`),
        checkout:       (payload)      => _post('/buyer/api/checkout', payload),
        getOrders:      ()             => _get('/buyer/api/orders'),
        getOrder:       (id)           => _get(`/buyer/api/orders/${encodeURIComponent(id)}`),
        getProfile:     ()             => _get('/buyer/api/profile'),
        getAddresses:   ()             => _get('/buyer/api/addresses'),
        createAddress:  (payload)      => _post('/buyer/api/addresses', payload),
        setDefault:     (id)           => _post(`/buyer/api/addresses/${encodeURIComponent(id)}/default`, {}),
        deleteAddress:  (id)           => _delete(`/buyer/api/addresses/${encodeURIComponent(id)}`),
        updateProfile:  (payload)      => _put('/buyer/api/profile', payload),
        changePassword: (payload)      => _put('/buyer/api/password', payload),
    },

    rider: {
        getDeliveries:  ()           => _get('/rider/api/deliveries'),
        acceptDelivery: (id)         => _post(`/rider/api/deliveries/${encodeURIComponent(id)}/accept`, {}),
        declineDelivery:(id, reason, note) => _post(`/rider/api/deliveries/${encodeURIComponent(id)}/decline`, { reason, note }),
        reportIssue:    (id, reason, note) => _post(`/rider/api/deliveries/${encodeURIComponent(id)}/report`, { reason, note }),
        updateStatus:   (id, status) => _post(`/rider/api/deliveries/${encodeURIComponent(id)}/status`, { status }),
        getLocations:   (id)         => _get(`/rider/api/deliveries/${encodeURIComponent(id)}/locations`),
        getDashboard:   ()           => _get('/rider/api/dashboard'),
        getEarnings:    ()           => _get('/rider/api/earnings'),
        getAvailability:()           => _get('/rider/api/availability'),
        setAvailability:(val)        => _post('/rider/api/availability', { is_available: val }),
        getPerformance: ()           => _get('/rider/api/performance'),
        getNotifications:()          => _get('/rider/api/notifications'),
        markNotifsRead: ()           => _post('/rider/api/notifications/read-all', {}),
        getProfile:     ()           => _get('/rider/api/profile'),
        saveProfile:    (data)       => _post('/rider/api/profile', data),
        getDeclineReasons: ()        => _get('/rider/api/decline-reasons'),
    },

    shop: {
        getProducts: (params = '') => _get(`/buyer/api/products${params ? '?' + params : ''}`),
        getProduct:  (id)          => _get(`/buyer/api/products/${encodeURIComponent(id)}`),
    },

    admin: {
        getOrders:         (status = '') => _get(`/admin/api/orders${status ? '?status=' + encodeURIComponent(status) : ''}`),
        updateOrderStatus: (id, status, rider_id = '') => _post(`/admin/api/orders/${encodeURIComponent(id)}/status`, { status, rider_id }),
        getDashboard:      ()            => _get('/admin/api/dashboard'),
        getEarnings:       ()            => _get('/admin/api/earnings'),
        getCommission:     ()            => _get('/admin/api/commission'),
        setCommission:     (data)        => _post('/admin/api/commission', data),
        getSalesAnalytics: (period)      => _get(`/admin/api/sales-analytics?period=${encodeURIComponent(period || 'daily')}`),
        getRecentOrders:   (limit)       => _get(`/admin/api/recent-orders?limit=${encodeURIComponent(limit || 10)}`),
        getEarningsDetail: (params = {}) => _get(`/admin/api/earnings-detail?${new URLSearchParams(params)}`),
        exportEarnings:    (format, params = {}) => {
            params.format = format;
            return `/admin/api/earnings-export?${new URLSearchParams(params)}`;
        },
    },

    adminProducts: {
        getAll:       (status = '')             => _get(`/admin/api/products${status ? '?status=' + encodeURIComponent(status) : ''}`),
        getOne:       (id)                      => _get(`/admin/api/products/${encodeURIComponent(id)}`),
        updateStatus: (id, status, reason = '') => _post(`/admin/api/products/${encodeURIComponent(id)}/status`, { status, reason }),
    },

    messages: {
        getConversations:  ()                        => _get('/messages/api/conversations'),
        startConversation: (userId, orderId = null)  => _post('/messages/api/conversations/start', { user_id: userId, order_id: orderId }),
        findConversation:  (otherId, orderId = null) => _get(`/messages/api/conversations/find?user_id=${encodeURIComponent(otherId)}${orderId ? '&order_id=' + encodeURIComponent(orderId) : ''}`),
        getMessages:       (convId, after = null)    => _get(`/messages/api/conversations/${encodeURIComponent(convId)}/messages${after ? '?after=' + encodeURIComponent(after) : ''}`),
        sendMessage:       (convId, content)         => _post(`/messages/api/conversations/${encodeURIComponent(convId)}/messages`, { content }),
        markRead:          (convId)                  => _post(`/messages/api/conversations/${encodeURIComponent(convId)}/read`, {}),
        getUnreadCount:    ()                        => _get('/messages/api/unread-count'),
        quickMessage:      (otherId, orderId, sendAuto) => _post('/messages/api/quick-message', { other_id: otherId, order_id: orderId, send_auto: sendAuto }),
    },
};
