from supabase import create_client
from datetime import datetime, timedelta
import os

class StorageCleanup:
    """Clean up orphaned files from Supabase Storage."""
    
    def __init__(self):
        self._client = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY'),
        )
    
    def cleanup_orphaned_files(self, bucket_name: str, days_old: int = 7) -> int:
        """
        Remove files not referenced in database.
        
        Args:
            bucket_name: Name of the storage bucket
            days_old: Only delete files older than this many days
        
        Returns:
            Number of files deleted
        """
        try:
            print(f'[StorageCleanup] Scanning {bucket_name}...')
            
            # Get all files from bucket
            files = self._client.storage.from_(bucket_name).list()
            
            # Get all URLs from database based on bucket type
            db_urls = self._get_database_urls(bucket_name)
            
            # Compare and delete orphaned files
            deleted_count = 0
            for file_obj in files:
                if isinstance(file_obj, dict):
                    file_name = file_obj.get('name', '')
                else:
                    continue
                
                # Build full URL
                file_url = self._client.storage.from_(bucket_name).get_public_url(file_name)
                if isinstance(file_url, dict):
                    file_url = file_url.get('publicURL', '')
                
                # Check if URL exists in database
                if file_url not in db_urls:
                    # Check if file is old enough
                    created_at_str = file_obj.get('created_at', '')
                    if created_at_str:
                        try:
                            created_at = datetime.fromisoformat(created_at_str.replace('Z', '+00:00'))
                            age = datetime.now(created_at.tzinfo) - created_at
                            
                            if age > timedelta(days=days_old):
                                self._client.storage.from_(bucket_name).remove([file_name])
                                deleted_count += 1
                                print(f'  Deleted: {file_name} (age: {age.days} days)')
                        except Exception as e:
                            print(f'  Error processing {file_name}: {e}')
            
            print(f'[StorageCleanup] Deleted {deleted_count} orphaned files from {bucket_name}')
            return deleted_count
        except Exception as e:
            print(f'[StorageCleanup] Error cleaning {bucket_name}: {e}')
            return 0
    
    def _get_database_urls(self, bucket_name: str) -> set:
        """Get all file URLs from database for the given bucket."""
        db_urls = set()
        
        try:
            if bucket_name == 'product-images':
                from models.product_model import ProductModel
                products = ProductModel().get_all()
                for p in products:
                    if p.get('image_url'):
                        db_urls.add(p['image_url'])
                    # Add variant images if they exist
                    variants = p.get('variants', [])
                    for v in variants:
                        if v.get('image_url'):
                            db_urls.add(v['image_url'])
            
            elif bucket_name == 'avatars':
                from models.user_model import UserModel
                users = UserModel().get_all()
                for u in users:
                    if u.get('avatar_url'):
                        db_urls.add(u['avatar_url'])
            
            elif bucket_name == 'delivery-proofs':
                from models.order_model import OrderModel
                orders = OrderModel().get_all()
                for o in orders:
                    if o.get('proof_of_delivery_url'):
                        db_urls.add(o['proof_of_delivery_url'])
            
            elif bucket_name == 'return-images':
                # Query return_request_images table
                result = self._client.table('return_request_images').select('image_url').execute()
                for row in result.data:
                    if row.get('image_url'):
                        db_urls.add(row['image_url'])
            
            elif bucket_name == 'payment-proofs':
                from models.order_model import OrderModel
                orders = OrderModel().get_all()
                for o in orders:
                    if o.get('payment_proof_url'):
                        db_urls.add(o['payment_proof_url'])
        
        except Exception as e:
            print(f'[StorageCleanup] Error fetching database URLs: {e}')
        
        return db_urls
    
    def get_bucket_stats(self, bucket_name: str) -> dict:
        """Get statistics for a storage bucket."""
        try:
            files = self._client.storage.from_(bucket_name).list()
            
            total_files = len(files)
            total_size = sum(f.get('metadata', {}).get('size', 0) for f in files if isinstance(f, dict))
            
            return {
                'bucket': bucket_name,
                'total_files': total_files,
                'total_size_mb': round(total_size / (1024 * 1024), 2),
                'total_size_bytes': total_size
            }
        except Exception as e:
            print(f'[StorageCleanup] Error getting stats for {bucket_name}: {e}')
            return {
                'bucket': bucket_name,
                'total_files': 0,
                'total_size_mb': 0,
                'total_size_bytes': 0,
                'error': str(e)
            }
