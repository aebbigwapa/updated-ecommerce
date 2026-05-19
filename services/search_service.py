from supabase import create_client
import os

class SearchService:
    """Enhanced product search with filters."""
    
    def __init__(self):
        self._client = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY'),
        )
    
    def search_products(self, query: str = '', filters: dict = None):
        """
        Search products with advanced filters.
        
        Args:
            query: Search text
            filters: {
                'category': str,
                'min_price': float,
                'max_price': float,
                'seller_id': str,
                'in_stock': bool,
                'sort_by': str ('price_asc', 'price_desc', 'newest', 'popular')
            }
        """
        filters = filters or {}
        
        # Base query
        q = self._client.table('products').select(
            '*, seller:users(first_name, last_name), variants:product_variants(*)'
        ).eq('status', 'active')
        
        # Text search
        if query:
            # Search in name and description
            q = q.or_(f'name.ilike.%{query}%,description.ilike.%{query}%')
        
        # Category filter
        if filters.get('category'):
            q = q.eq('category', filters['category'])
        
        # Price range
        if filters.get('min_price') is not None:
            q = q.gte('price', filters['min_price'])
        if filters.get('max_price') is not None:
            q = q.lte('price', filters['max_price'])
        
        # Seller filter
        if filters.get('seller_id'):
            q = q.eq('seller_id', filters['seller_id'])
        
        # In stock filter
        if filters.get('in_stock'):
            q = q.gt('total_stock', 0)
        
        # Sorting
        sort_by = filters.get('sort_by', 'newest')
        if sort_by == 'price_asc':
            q = q.order('price', desc=False)
        elif sort_by == 'price_desc':
            q = q.order('price', desc=True)
        elif sort_by == 'popular':
            # If total_sold column doesn't exist, sort by created_at
            try:
                q = q.order('total_sold', desc=True)
            except:
                q = q.order('created_at', desc=True)
        else:  # newest
            q = q.order('created_at', desc=True)
        
        result = q.execute()
        return result.data or []
    
    def get_search_suggestions(self, query: str, limit: int = 5):
        """Get search suggestions based on partial query."""
        if not query or len(query) < 2:
            return []
        
        result = self._client.table('products').select('name').eq(
            'status', 'active'
        ).ilike('name', f'%{query}%').limit(limit).execute()
        
        return [p['name'] for p in (result.data or [])]
    
    def get_categories(self):
        """Get all product categories."""
        result = self._client.table('products').select('category').eq(
            'status', 'active'
        ).execute()
        
        # Get unique categories
        categories = list(set(p.get('category') for p in (result.data or []) if p.get('category')))
        return sorted(categories)
    
    def get_price_range(self):
        """Get min and max prices for filtering."""
        result = self._client.table('products').select('price').eq(
            'status', 'active'
        ).execute()
        
        prices = [float(p.get('price', 0)) for p in (result.data or [])]
        if not prices:
            return {'min': 0, 'max': 0}
        
        return {
            'min': min(prices),
            'max': max(prices)
        }
