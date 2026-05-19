from supabase import create_client
import os

class ProductModel:
    def __init__(self):
        self.supabase = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        )

    def get_homepage_products(self, limit=12, offset=0, category=None):
        select_fields = 'id, name, price, status, category, seller_id, product_images(image_url,is_primary,display_order), product_variants(id,price,stock)'
        query = self.supabase.table('products').select(select_fields).eq('status', 'active')
        if category:
            query = query.eq('category', category)
        query = query.order('created_at', desc=True).range(offset, offset + limit - 1)
        result = query.execute()
        return result.data if result.data else []

    def get_by_id(self, product_id):
        result = self.supabase.table('products').select(
            '*, seller:users!products_seller_id_fkey(id, first_name, last_name), product_variants (*), product_images (*)'
        ).eq('id', product_id).single().execute()
        return result.data if result.data else None

    def get_by_id_and_seller(self, product_id, seller_id):
        result = self.supabase.table('products').select(
            '*, product_variants (*), product_images (*)'
        ).eq('id', product_id).eq('seller_id', seller_id).limit(1).execute()
        return result.data[0] if result.data else None

    def get_by_seller(self, seller_id):
        result = self.supabase.table('products').select(
            '*, product_variants (*), product_images (*)'
        ).eq('seller_id', seller_id).order('created_at', desc=True).execute()
        return result.data if result.data else []

    def get_all_active(self, category=None):
        query = self.supabase.table('products').select(
            '*, seller:users!products_seller_id_fkey(first_name, last_name), product_variants(*), product_images(*)'
        ).eq('status', 'active')
        if category:
            query = query.eq('category', category)
        result = query.order('created_at', desc=True).execute()
        return result.data if result.data else []

    def get_all(self, status=None):
        query = self.supabase.table('products').select(
            '*, seller:users!products_seller_id_fkey(id, first_name, last_name, email, phone), product_variants (*), product_images (*)'
        )
        if status:
            query = query.eq('status', status)
        result = query.order('created_at', desc=True).execute()
        return result.data if result.data else []

    def create(self, product_data):
        result = self.supabase.table('products').insert(product_data).execute()
        return result.data[0] if result.data else None

    def update(self, product_id, seller_id, update_data):
        result = self.supabase.table('products').update(update_data).eq('id', product_id).eq('seller_id', seller_id).execute()
        return result.data[0] if result.data else None

    def update_status(self, product_id, status, reviewed_by=None, reject_reason=None):
        payload = {'status': status}
        payload['reject_reason'] = reject_reason if status == 'rejected' else None
        result = self.supabase.table('products').update(payload).eq('id', product_id).execute()
        return result.data[0] if result.data else None

    def delete(self, product_id, seller_id):
        return self.update(product_id, seller_id, {'status': 'rejected'})

    # Variant methods
    def get_variants(self, product_id):
        result = self.supabase.table('product_variants').select('*').eq('product_id', product_id).execute()
        return result.data if result.data else []

    def create_variant(self, variant_data):
        result = self.supabase.table('product_variants').insert(variant_data).execute()
        return result.data[0] if result.data else None

    def update_variant_stock(self, variant_id, stock_delta):
        result = self.supabase.table('product_variants').select('stock').eq('id', variant_id).single().execute()
        if result.data:
            new_stock = max(0, result.data['stock'] + stock_delta)
            self.supabase.table('product_variants').update({'stock': new_stock}).eq('id', variant_id).execute()
            return new_stock
        return None

    # Image methods
    def get_images(self, product_id):
        result = self.supabase.table('product_images').select('*').eq('product_id', product_id).order('display_order').execute()
        return result.data if result.data else []

    def create_image(self, image_data):
        result = self.supabase.table('product_images').insert(image_data).execute()
        return result.data[0] if result.data else None

    def set_primary_image(self, product_id, image_id):
        self.supabase.table('product_images').update({'is_primary': False}).eq('product_id', product_id).execute()
        self.supabase.table('product_images').update({'is_primary': True}).eq('id', image_id).execute()
