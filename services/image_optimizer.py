from PIL import Image
from io import BytesIO

class ImageOptimizer:
    """Optimize images before upload to reduce storage and bandwidth."""
    
    @staticmethod
    def optimize(file_data: bytes, max_width: int = 1200, quality: int = 85) -> bytes:
        """
        Resize and compress image.
        
        Args:
            file_data: Original image bytes
            max_width: Maximum width in pixels
            quality: JPEG quality (1-100)
        
        Returns:
            Optimized image bytes
        """
        try:
            img = Image.open(BytesIO(file_data))
            
            # Convert RGBA to RGB if needed (for JPEG compatibility)
            if img.mode in ('RGBA', 'LA', 'P'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'RGBA':
                    background.paste(img, mask=img.split()[-1])
                else:
                    background.paste(img)
                img = background
            
            # Resize if too large
            if img.width > max_width:
                ratio = max_width / img.width
                new_height = int(img.height * ratio)
                img = img.resize((max_width, new_height), Image.Resampling.LANCZOS)
            
            # Compress and save
            output = BytesIO()
            img.save(output, format='JPEG', quality=quality, optimize=True)
            return output.getvalue()
        except Exception as e:
            print(f'[ImageOptimizer] Failed to optimize: {e}')
            return file_data  # Return original on error
    
    @staticmethod
    def create_thumbnail(file_data: bytes, size: tuple = (300, 300)) -> bytes:
        """
        Create a thumbnail version of the image.
        
        Args:
            file_data: Original image bytes
            size: Thumbnail size (width, height)
        
        Returns:
            Thumbnail image bytes
        """
        try:
            img = Image.open(BytesIO(file_data))
            
            # Convert RGBA to RGB if needed
            if img.mode in ('RGBA', 'LA', 'P'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'RGBA':
                    background.paste(img, mask=img.split()[-1])
                else:
                    background.paste(img)
                img = background
            
            # Create thumbnail (maintains aspect ratio)
            img.thumbnail(size, Image.Resampling.LANCZOS)
            
            # Save
            output = BytesIO()
            img.save(output, format='JPEG', quality=80, optimize=True)
            return output.getvalue()
        except Exception as e:
            print(f'[ImageOptimizer] Failed to create thumbnail: {e}')
            return file_data
