import os
import uuid
from supabase import create_client

# Allowed MIME magic bytes (first bytes of file content)
_MAGIC = {
    b'\xff\xd8\xff':       'jpg',
    b'\x89PNG\r\n\x1a\n': 'png',
    b'RIFF':               'webp',   # checked with offset 8 == WEBP
    b'GIF87a':             'gif',
    b'GIF89a':             'gif',
}

# Bucket configurations with individual size limits
_BUCKET_CONFIG = {
    'products': {'name': 'product-images', 'max_size': 8 * 1024 * 1024},
    'avatars': {'name': 'avatars', 'max_size': 2 * 1024 * 1024},
    'deliveries': {'name': 'delivery-proofs', 'max_size': 5 * 1024 * 1024},
    'returns': {'name': 'return-images', 'max_size': 5 * 1024 * 1024},
    'payments': {'name': 'payment-proofs', 'max_size': 3 * 1024 * 1024},
}


def _detect_mime(header: bytes) -> str | None:
    """Return extension if header matches a known image magic, else None."""
    for magic, ext in _MAGIC.items():
        if header[:len(magic)] == magic:
            # Extra check for WebP: bytes 8-12 must be b'WEBP'
            if ext == 'webp' and header[8:12] != b'WEBP':
                continue
            return ext
    return None


class FileUploadService:
    """
    Uploads files to Supabase Storage and returns public CDN URLs.
    The database stores only the public URL — no local paths.
    """

    def __init__(self):
        self._client = create_client(
            os.getenv('SUPABASE_URL'),
            os.getenv('SUPABASE_SERVICE_ROLE_KEY'),
        )

    # ── Public API ────────────────────────────────────────────

    def save_file(self, file, subfolder: str = 'general', bucket_type: str = 'products') -> str | None:
        """
        Validate, upload to Supabase Storage, and return the public URL.
        Returns None on any failure.

        Args:
            file:      Werkzeug FileStorage object from request.files
            subfolder: Storage path prefix, e.g. 'seller-uuid'
            bucket_type: Type of bucket ('products', 'avatars', 'deliveries', 'returns', 'payments')
        """
        if not file or not file.filename:
            return None

        # Get bucket configuration
        bucket_config = _BUCKET_CONFIG.get(bucket_type, _BUCKET_CONFIG['products'])
        bucket_name = bucket_config['name']
        max_size = bucket_config['max_size']

        # CWE-22: reject path traversal in subfolder
        from security import safe_path_component
        if not safe_path_component(subfolder):
            print(f'[FileUpload] Rejected: path traversal attempt in subfolder {subfolder!r}')
            return None

        # Read file bytes once
        data = file.read()
        if not data:
            return None

        # Optimize image (resize + compress)
        try:
            from services.image_optimizer import ImageOptimizer
            data = ImageOptimizer.optimize(data, max_width=1200, quality=85)
        except Exception as e:
            print(f'[FileUpload] Image optimization skipped: {e}')

        # Enforce size limit
        if len(data) > max_size:
            print(f'[FileUpload] Rejected: file exceeds {max_size // 1024 // 1024} MB')
            return None

        # Validate actual content (magic bytes), not just extension
        ext = _detect_mime(data[:12])
        if ext is None:
            print(f'[FileUpload] Rejected: unrecognised image format for {file.filename!r}')
            return None

        # Build a collision-proof storage path
        storage_path = f"{subfolder.strip('/')}/{uuid.uuid4().hex}.{ext}"

        try:
            self._client.storage.from_(bucket_name).upload(
                path=storage_path,
                file=data,
                file_options={'content-type': f'image/{ext}', 'cache-control': '31536000', 'upsert': 'false'},
            )
            return self._public_url(bucket_name, storage_path)
        except Exception as e:
            print(f'[FileUpload] Upload failed: {e}')
            return None

    def delete_file(self, url: str, bucket_type: str = 'products') -> bool:
        """
        Delete a file from Supabase Storage given its public URL.
        Safe to call with legacy local paths — they are ignored.
        """
        if not url or url.startswith('static/'):
            return False   # legacy local path — skip silently
        try:
            bucket_config = _BUCKET_CONFIG.get(bucket_type, _BUCKET_CONFIG['products'])
            bucket_name = bucket_config['name']
            path = self._storage_path_from_url(url, bucket_name)
            self._client.storage.from_(bucket_name).remove([path])
            return True
        except Exception as e:
            print(f'[FileUpload] Delete failed: {e}')
            return False

    def get_public_url(self, path_or_url: str) -> str:
        """
        Normalise any stored value to a usable URL.
        - Already a full URL  → return as-is
        - Legacy local path   → prepend / so Flask can serve it during dev
        """
        if not path_or_url:
            return ''
        if path_or_url.startswith('http'):
            return path_or_url
        # Legacy local path fallback (dev only)
        return path_or_url if path_or_url.startswith('/') else '/' + path_or_url

    # ── Private helpers ───────────────────────────────────────

    def _public_url(self, bucket_name: str, storage_path: str) -> str:
        res = self._client.storage.from_(bucket_name).get_public_url(storage_path)
        # supabase-py v1 returns a dict; v2 returns a string
        return res if isinstance(res, str) else res.get('publicURL', '')

    def _storage_path_from_url(self, url: str, bucket_name: str) -> str:
        """Extract the storage path from a Supabase public URL."""
        # URL format: https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
        marker = f'/object/public/{bucket_name}/'
        idx = url.find(marker)
        if idx == -1:
            return url
        return url[idx + len(marker):]
