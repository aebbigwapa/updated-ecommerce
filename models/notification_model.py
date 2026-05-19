"""
Notification Model
Handles all database operations for buyer notifications using Supabase.
"""

from supabase import create_client
import os
from typing import Optional
from datetime import datetime, timedelta, timezone


class NotificationModel:
    def __init__(self):
        self.supabase = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        )

    def get_unread_count(self, user_id: str) -> int:
        """Get count of unread notifications for a user."""
        result = self.supabase.table('notifications').select('id', count='exact').eq('user_id', user_id).eq('is_read', False).execute()
        return result.count if result.count is not None else 0

    def get_all(self, user_id: str, limit: int = 50, unread_only: bool = False) -> list:
        """Get notifications for a user, optionally filtered to unread only."""
        query = self.supabase.table('notifications').select('*').eq('user_id', user_id).order('created_at', desc=True).limit(limit)
        
        if unread_only:
            query = query.eq('is_read', False)
        
        result = query.execute()
        
        notifications = []
        for row in (result.data or []):
            notifications.append(self._format_notification(row))
        return notifications

    def mark_as_read(self, notification_id: str, user_id: str) -> bool:
        """Mark a specific notification as read."""
        result = self.supabase.table('notifications').update({'is_read': True}).eq('id', notification_id).eq('user_id', user_id).execute()
        return len(result.data or []) > 0

    def mark_all_as_read(self, user_id: str) -> int:
        """Mark all notifications as read for a user. Returns number of rows updated."""
        result = self.supabase.table('notifications').update({'is_read': True}).eq('user_id', user_id).eq('is_read', False).execute()
        # Supabase doesn't return count directly, so we return success
        return 1 if result.data else 0

    def create(self, user_id: str, notif_type: str, title: str, message: str, action_url: Optional[str] = None, order_id: Optional[str] = None, product_id: Optional[str] = None, product_name: Optional[str] = None, product_image: Optional[str] = None, data_payload: Optional[dict] = None) -> dict:
        """Create a new notification with optional product information and flexible data payload.
        
        Args:
            user_id: Target user ID
            notif_type: Type of notification ('new_order', 'status_update', 'cancellation_request', 'cancellation_approved', 'cancellation_rejected', 'chat')
            title: Notification title
            message: Notification message
            action_url: Optional URL to navigate to when clicked
            order_id: Optional order ID (legacy, prefer data_payload)
            product_id: Optional product ID (legacy, prefer data_payload)
            product_name: Optional product name (legacy, prefer data_payload)
            product_image: Optional product image URL (legacy, prefer data_payload)
            data_payload: Optional dict with flexible data (e.g., {'order_id': '...', 'conversation_id': '...', 'reason': '...'})
        """
        notification_data = {
            'user_id': user_id,
            'type': notif_type,
            'title': title,
            'message': message,
        }
        
        if action_url:
            notification_data['action_url'] = action_url
        
        # Build data payload (new way - flexible JSON)
        payload = data_payload or {}
        
        # Legacy fields - add to payload if provided
        if order_id:
            payload['order_id'] = order_id
        if product_id:
            payload['product_id'] = product_id
        if product_name:
            payload['product_name'] = product_name
        if product_image:
            payload['product_image'] = product_image
        
        # Only set data field if payload has content
        if payload:
            notification_data['data'] = payload
        
        result = self.supabase.table('notifications').insert(notification_data).execute()
        
        if result.data and len(result.data) > 0:
            row = result.data[0]
            return self._format_notification(row)
        return {}
    
    def _format_notification(self, row: dict) -> dict:
        """Format a notification row from database into response dict."""
        payload = row.get('data') or {}
        return {
            'id': row['id'],
            'type': row['type'],
            'title': row['title'],
            'message': row['message'],
            'is_read': row['is_read'],
            'action_url': row.get('action_url'),
            # Support both old column structure and new data payload
            'order_id': row.get('order_id') or payload.get('order_id'),
            'product_id': row.get('product_id') or payload.get('product_id'),
            'product_name': row.get('product_name') or payload.get('product_name'),
            'product_image': row.get('product_image') or payload.get('product_image'),
            'conversation_id': payload.get('conversation_id'),
            'cancellation_id': payload.get('cancellation_id'),
            'reason': payload.get('reason'),
            'new_status': payload.get('new_status'),
            'created_at': row['created_at'],
            'data': payload
        }

    def delete(self, notification_id: str, user_id: str) -> bool:
        """Delete a notification."""
        result = self.supabase.table('notifications').delete().eq('id', notification_id).eq('user_id', user_id).execute()
        return len(result.data or []) > 0

    def delete_old(self, user_id: str, days_old: int = 30) -> int:
        """Delete notifications older than specified days."""
        cutoff_date = (datetime.now(timezone.utc) - timedelta(days=days_old)).isoformat()
        result = self.supabase.table('notifications').delete().eq('user_id', user_id).lt('created_at', cutoff_date).execute()
        return len(result.data or [])

    def create_order_notification(self, user_id: str, order_id: str, title: str, message: str, action_url: Optional[str] = None) -> dict:
        """Create an order notification with product information automatically fetched."""
        try:
            # Get order details with product information
            order_result = self.supabase.table('orders').select(
                'id, order_items(*, product:products(id, name, product_images(*)))'
            ).eq('id', order_id).limit(1).execute()
            
            if not order_result.data:
                # Fallback to basic notification if order not found
                return self.create(user_id, 'order', title, message, action_url, order_id)
            
            order = order_result.data[0]
            order_items = order.get('order_items', [])
            
            # Get the first product for the notification image
            if order_items:
                first_item = order_items[0]
                product = first_item.get('product', {})
                product_id = product.get('id')
                product_name = product.get('name', 'Product')
                
                # Get product image (primary first, then any image)
                product_images = product.get('product_images', [])
                product_image = None
                
                if product_images:
                    # Try to find primary image first
                    primary_image = next((img for img in product_images if img.get('is_primary')), None)
                    if primary_image:
                        product_image = primary_image.get('image_url')
                    else:
                        # Use first available image
                        product_image = product_images[0].get('image_url')
                
                # Normalize image URL
                if product_image and not product_image.startswith('http') and not product_image.startswith('/'):
                    product_image = '/' + product_image
                
                # If multiple items, adjust product name
                if len(order_items) > 1:
                    product_name = f"{product_name} (+{len(order_items) - 1} more)"
                
                return self.create(
                    user_id=user_id,
                    notif_type='order',
                    title=title,
                    message=message,
                    action_url=action_url,
                    order_id=order_id,
                    product_id=product_id,
                    product_name=product_name,
                    product_image=product_image
                )
            else:
                # No items in order, create basic notification
                return self.create(user_id, 'order', title, message, action_url, order_id)
                
        except Exception as e:
            print(f"Error creating order notification: {e}")
            # Fallback to basic notification
            return self.create(user_id, 'order', title, message, action_url, order_id)