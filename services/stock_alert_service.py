from supabase import create_client
from datetime import datetime, timezone
import os

class StockAlertService:
    """Manage stock alerts for sellers."""
    
    def __init__(self):
        self._client = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY'),
        )
    
    def get_seller_alerts(self, seller_id: str, unresolved_only: bool = True):
        """Get stock alerts for a seller."""
        query = self._client.table('stock_alerts').select(
            '*, product:products(name, image_url), variant:product_variants(color, size)'
        ).eq('seller_id', seller_id)
        
        if unresolved_only:
            query = query.eq('is_resolved', False)
        
        result = query.order('created_at', desc=True).execute()
        return result.data or []
    
    def resolve_alert(self, alert_id: str, seller_id: str) -> bool:
        """Mark an alert as resolved."""
        try:
            self._client.table('stock_alerts').update({
                'is_resolved': True,
                'resolved_at': datetime.now(timezone.utc).isoformat()
            }).eq('id', alert_id).eq('seller_id', seller_id).execute()
            return True
        except Exception as e:
            print(f'[StockAlertService] Error resolving alert: {e}')
            return False
    
    def get_alert_count(self, seller_id: str) -> int:
        """Get count of unresolved alerts."""
        result = self._client.table('stock_alerts').select(
            'id', count='exact'
        ).eq('seller_id', seller_id).eq('is_resolved', False).execute()
        return result.count or 0
    
    def create_alert(self, product_id: str, seller_id: str, variant_id: str = None, 
                    alert_type: str = 'low_stock', current_stock: int = 0, threshold: int = 10):
        """Create a stock alert."""
        try:
            self._client.table('stock_alerts').insert({
                'product_id': product_id,
                'seller_id': seller_id,
                'variant_id': variant_id,
                'alert_type': alert_type,
                'current_stock': current_stock,
                'threshold': threshold
            }).execute()
            return True
        except Exception as e:
            print(f'[StockAlertService] Error creating alert: {e}')
            return False
    
    def check_and_create_alerts(self, product_id: str):
        """Check product stock and create alerts if needed."""
        try:
            # Get product
            product = self._client.table('products').select(
                'id, seller_id, low_stock_threshold, total_stock'
            ).eq('id', product_id).single().execute()
            
            if not product.data:
                return
            
            p = product.data
            threshold = p.get('low_stock_threshold', 10)
            total_stock = p.get('total_stock', 0)
            
            # Check if alert already exists
            existing = self._client.table('stock_alerts').select('id').eq(
                'product_id', product_id
            ).eq('is_resolved', False).execute()
            
            if existing.data:
                return  # Alert already exists
            
            # Create alert if needed
            if total_stock <= 0:
                self.create_alert(
                    product_id, p['seller_id'], 
                    alert_type='out_of_stock',
                    current_stock=total_stock,
                    threshold=threshold
                )
            elif total_stock <= threshold:
                self.create_alert(
                    product_id, p['seller_id'],
                    alert_type='low_stock',
                    current_stock=total_stock,
                    threshold=threshold
                )
        except Exception as e:
            print(f'[StockAlertService] Error checking alerts: {e}')
