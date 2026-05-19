from supabase import create_client
from datetime import datetime, timedelta, timezone
import os

class AnalyticsService:
    """Basic analytics for dashboard metrics."""
    
    def __init__(self):
        self._client = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY'),
        )
    
    def get_seller_analytics(self, seller_id: str, days: int = 30):
        """Get analytics for seller dashboard."""
        now = datetime.now(timezone.utc)
        start_date = (now - timedelta(days=days)).isoformat()
        
        # Orders
        orders = self._client.table('orders').select(
            'id, total_amount, status, created_at'
        ).eq('seller_id', seller_id).gte('created_at', start_date).execute()
        
        orders_data = orders.data or []
        
        # Calculate metrics
        total_orders = len(orders_data)
        total_revenue = sum(float(o.get('total_amount', 0)) for o in orders_data)
        completed_orders = len([o for o in orders_data if o.get('status') == 'delivered'])
        pending_orders = len([o for o in orders_data if o.get('status') in ('pending', 'processing')])
        
        # Products
        products = self._client.table('products').select(
            'id, total_stock'
        ).eq('seller_id', seller_id).eq('status', 'active').execute()
        
        products_data = products.data or []
        total_products = len(products_data)
        low_stock_products = len([p for p in products_data if p.get('total_stock', 0) < 10])
        
        # Calculate total items sold from order_items
        try:
            order_items = self._client.table('order_items').select(
                'quantity, order:orders!inner(seller_id, status)'
            ).execute()
            total_items_sold = sum(
                item.get('quantity', 0) 
                for item in (order_items.data or []) 
                if item.get('order', {}).get('seller_id') == seller_id 
                and item.get('order', {}).get('status') == 'delivered'
            )
        except:
            total_items_sold = 0
        
        # Daily revenue chart (last 7 days)
        daily_revenue = []
        for i in range(6, -1, -1):
            day = (now - timedelta(days=i)).date()
            day_revenue = sum(
                float(o.get('total_amount', 0)) 
                for o in orders_data 
                if datetime.fromisoformat(o['created_at'].replace('Z', '+00:00')).date() == day
            )
            daily_revenue.append({
                'date': day.strftime('%m/%d'),
                'revenue': round(day_revenue, 2)
            })
        
        return {
            'total_orders': total_orders,
            'total_revenue': round(total_revenue, 2),
            'completed_orders': completed_orders,
            'pending_orders': pending_orders,
            'total_products': total_products,
            'low_stock_products': low_stock_products,
            'total_items_sold': total_items_sold,
            'daily_revenue': daily_revenue,
            'period_days': days
        }
    
    def get_buyer_analytics(self, buyer_id: str):
        """Get analytics for buyer dashboard."""
        # Orders
        orders = self._client.table('orders').select(
            'id, total_amount, status, created_at'
        ).eq('buyer_id', buyer_id).execute()
        
        orders_data = orders.data or []
        
        total_orders = len(orders_data)
        total_spent = sum(float(o.get('total_amount', 0)) for o in orders_data)
        pending_orders = len([o for o in orders_data if o.get('status') in ('pending', 'processing', 'in_transit')])
        completed_orders = len([o for o in orders_data if o.get('status') == 'delivered'])
        
        # Wishlist
        wishlist = self._client.table('wishlist').select('id', count='exact').eq('user_id', buyer_id).execute()
        wishlist_count = wishlist.count or 0
        
        # Cart
        cart = self._client.table('cart_items').select('id', count='exact').eq('user_id', buyer_id).execute()
        cart_count = cart.count or 0
        
        return {
            'total_orders': total_orders,
            'total_spent': round(total_spent, 2),
            'pending_orders': pending_orders,
            'completed_orders': completed_orders,
            'wishlist_count': wishlist_count,
            'cart_count': cart_count
        }
    
    def get_admin_analytics(self):
        """Get analytics for admin dashboard."""
        now = datetime.now(timezone.utc)
        today = now.date()
        
        # Users
        users = self._client.table('users').select('id, role, created_at').execute()
        users_data = users.data or []
        
        total_users = len(users_data)
        buyers = len([u for u in users_data if u.get('role') == 'buyer'])
        sellers = len([u for u in users_data if u.get('role') == 'seller'])
        riders = len([u for u in users_data if u.get('role') == 'rider'])
        
        # Orders
        orders = self._client.table('orders').select('id, total_amount, status, created_at').execute()
        orders_data = orders.data or []
        
        total_orders = len(orders_data)
        total_revenue = sum(float(o.get('total_amount', 0)) for o in orders_data)
        today_orders = len([
            o for o in orders_data 
            if datetime.fromisoformat(o['created_at'].replace('Z', '+00:00')).date() == today
        ])
        
        # Products
        products = self._client.table('products').select('id, status').execute()
        products_data = products.data or []
        
        total_products = len(products_data)
        active_products = len([p for p in products_data if p.get('status') == 'active'])
        pending_products = len([p for p in products_data if p.get('status') == 'pending'])
        
        return {
            'total_users': total_users,
            'buyers': buyers,
            'sellers': sellers,
            'riders': riders,
            'total_orders': total_orders,
            'total_revenue': round(total_revenue, 2),
            'today_orders': today_orders,
            'total_products': total_products,
            'active_products': active_products,
            'pending_products': pending_products
        }
    
    def get_rider_analytics(self, rider_id: str, days: int = 30):
        """Get analytics for rider dashboard."""
        now = datetime.now(timezone.utc)
        start_date = (now - timedelta(days=days)).isoformat()
        
        # Deliveries
        deliveries = self._client.table('orders').select(
            'id, total_amount, status, created_at'
        ).eq('rider_id', rider_id).gte('created_at', start_date).execute()
        
        deliveries_data = deliveries.data or []
        
        total_deliveries = len(deliveries_data)
        completed_deliveries = len([d for d in deliveries_data if d.get('status') == 'delivered'])
        in_transit = len([d for d in deliveries_data if d.get('status') == 'in_transit'])
        
        # Earnings
        earnings = self._client.table('rider_earnings').select(
            'amount, created_at'
        ).eq('rider_id', rider_id).gte('created_at', start_date).execute()
        
        earnings_data = earnings.data or []
        total_earnings = sum(float(e.get('amount', 0)) for e in earnings_data)
        
        return {
            'total_deliveries': total_deliveries,
            'completed_deliveries': completed_deliveries,
            'in_transit': in_transit,
            'total_earnings': round(total_earnings, 2),
            'period_days': days
        }
