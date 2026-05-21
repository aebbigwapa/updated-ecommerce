/**
 * Real-time updates for web using Supabase Realtime
 * Provides instant notifications, cart sync, and message updates
 */

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://opusrotqhtkhmeefvydh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wdXNyb3RxaHRraG1lZWZ2eWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NTU3MzMsImV4cCI6MjA5MzEzMTczM30.-Lo362tNRftWbvXK2kds7r5CpDeXb5vYN6K3rBhQlvw';

class RealtimeService {
    constructor() {
        this.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        this.channels = {};
        this.userId = null;
        this.callbacks = {
            notifications: [],
            cart: [],
            orders: [],
            messages: []
        };
    }

    init(userId) {
        this.userId = userId;
        if (userId) {
            this.subscribeNotifications();
            this.subscribeCart();
            this.subscribeOrders();
        }
    }

    subscribeNotifications() {
        if (!this.userId) return;
        
        const channel = this.supabase
            .channel(`notifications_${this.userId}`)
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'notifications',
                filter: `user_id=eq.${this.userId}`
            }, (payload) => {
                console.log('[Realtime] New notification:', payload);
                this.callbacks.notifications.forEach(cb => cb(payload.new));
                this.showNotificationToast(payload.new);
            })
            .subscribe();
        
        this.channels.notifications = channel;
    }

    subscribeCart() {
        if (!this.userId) return;
        
        const channel = this.supabase
            .channel(`cart_${this.userId}`)
            .on('postgres_changes', {
                event: '*',
                schema: 'public',
                table: 'cart_items',
                filter: `user_id=eq.${this.userId}`
            }, (payload) => {
                console.log('[Realtime] Cart update:', payload);
                this.callbacks.cart.forEach(cb => cb(payload));
            })
            .subscribe();
        
        this.channels.cart = channel;
    }

    subscribeOrders() {
        if (!this.userId) return;
        
        const channel = this.supabase
            .channel(`orders_${this.userId}`)
            .on('postgres_changes', {
                event: 'UPDATE',
                schema: 'public',
                table: 'orders',
                filter: `buyer_id=eq.${this.userId}`
            }, (payload) => {
                console.log('[Realtime] Order update:', payload);
                this.callbacks.orders.forEach(cb => cb(payload));
                
                // Show toast for status changes
                if (payload.old.status !== payload.new.status) {
                    this.showOrderStatusToast(payload.new);
                }
            })
            .subscribe();
        
        this.channels.orders = channel;
    }

    subscribeMessages(conversationId) {
        const channel = this.supabase
            .channel(`messages_${conversationId}`)
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'messages',
                filter: `conversation_id=eq.${conversationId}`
            }, (payload) => {
                console.log('[Realtime] New message:', payload);
                this.callbacks.messages.forEach(cb => cb(payload.new));
            })
            .subscribe();
        
        this.channels[`messages_${conversationId}`] = channel;
        return channel;
    }

    unsubscribeMessages(conversationId) {
        const channelKey = `messages_${conversationId}`;
        if (this.channels[channelKey]) {
            this.channels[channelKey].unsubscribe();
            delete this.channels[channelKey];
        }
    }

    onNotification(callback) {
        this.callbacks.notifications.push(callback);
    }

    onCart(callback) {
        this.callbacks.cart.push(callback);
    }

    onOrders(callback) {
        this.callbacks.orders.push(callback);
    }

    onMessages(callback) {
        this.callbacks.messages.push(callback);
    }

    showNotificationToast(notification) {
        const toast = document.createElement('div');
        toast.className = 'realtime-toast';
        toast.innerHTML = `
            <div class="toast-icon">🔔</div>
            <div class="toast-content">
                <div class="toast-title">${this.escapeHtml(notification.title)}</div>
                <div class="toast-message">${this.escapeHtml(notification.message)}</div>
            </div>
        `;
        
        document.body.appendChild(toast);
        
        setTimeout(() => toast.classList.add('show'), 10);
        
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, 5000);
        
        // Update notification badge
        this.updateNotificationBadge();
    }

    showOrderStatusToast(order) {
        const statusMessages = {
            'pending': '⏳ Order is pending',
            'processing': '📦 Order is being processed',
            'ready_for_pickup': '✅ Order is ready for pickup',
            'in_transit': '🚚 Order is out for delivery',
            'delivered': '✨ Order has been delivered',
            'cancelled': '❌ Order has been cancelled'
        };
        
        const message = statusMessages[order.status] || 'Order status updated';
        
        const toast = document.createElement('div');
        toast.className = 'realtime-toast';
        toast.innerHTML = `
            <div class="toast-icon">📦</div>
            <div class="toast-content">
                <div class="toast-title">Order Update</div>
                <div class="toast-message">${message}</div>
            </div>
        `;
        
        document.body.appendChild(toast);
        setTimeout(() => toast.classList.add('show'), 10);
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, 5000);
    }

    async updateNotificationBadge() {
        try {
            const response = await fetch('/buyer/api/notifications/unread-count');
            const data = await response.json();
            const count = data.count || 0;
            
            document.querySelectorAll('.notification-badge, .notif-badge').forEach(badge => {
                badge.textContent = count;
                badge.style.display = count > 0 ? 'flex' : 'none';
            });
        } catch (e) {
            console.error('Failed to update notification badge:', e);
        }
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    unsubscribeAll() {
        Object.values(this.channels).forEach(channel => channel.unsubscribe());
        this.channels = {};
    }
}

// Global instance
window.RealtimeService = new RealtimeService();

// Auto-initialize if user is logged in
document.addEventListener('DOMContentLoaded', () => {
    // Try to get user ID from meta tag or global variable
    const userIdMeta = document.querySelector('meta[name="user-id"]');
    const userId = userIdMeta?.content || window.currentUserId;
    
    if (userId) {
        window.RealtimeService.init(userId);
        console.log('[Realtime] Initialized for user:', userId);
    }
});
