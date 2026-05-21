import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/product.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  Map<String, dynamic>? _rawProduct;
  int _selectedQuantity = 1;
  String? _selectedVariantId;
  bool _isLoading = true;
  bool _isAddingToCart = false;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  // Color name → hex map (matches web app)
  static const Map<String, String> _colorNames = {
    'black': '#1a1a1a', 'white': '#ffffff', 'red': '#e74c3c', 'pink': '#FF6BCE',
    'blue': '#3498db', 'navy': '#1a2a5e', 'green': '#2ecc71', 'yellow': '#f1c40f',
    'orange': '#e67e22', 'purple': '#9b59b6', 'brown': '#795548', 'gray': '#95a5a6',
    'grey': '#95a5a6', 'beige': '#f5f0e8', 'maroon': '#800000', 'teal': '#009688',
    'lavender': '#e6e6fa', 'coral': '#ff6b6b', 'mint': '#98ff98', 'cream': '#fffdd0',
    'charcoal': '#36454f', 'gold': '#ffd700', 'silver': '#c0c0c0', 'rose': '#ff007f',
  };

  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _resolveColor(ProductVariant variant) {
    final name = (variant.value ?? '').toLowerCase().trim();
    if (variant.colorHex != null && variant.colorHex!.isNotEmpty) {
      return _hexToColor(variant.colorHex!);
    }
    if (_colorNames.containsKey(name)) return _hexToColor(_colorNames[name]!);
    for (final entry in _colorNames.entries) {
      if (name.contains(entry.key)) return _hexToColor(entry.value);
    }
    return Colors.grey.shade300;
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 3) {
      return Color(int.parse('FF${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}', radix: 16));
    }
    return Color(int.parse('FF$h', radix: 16));
  }

  List<String> _getImagesForVariant(String? variantId) {
    final raw = _rawProduct;
    if (raw == null) return _product?.images ?? [];
    final allImages = (raw['product_images'] as List? ?? [])
        .where((img) => img is Map && img['image_url'] != null)
        .toList();
    allImages.sort((a, b) => ((a['display_order'] ?? 0) as int).compareTo((b['display_order'] ?? 0) as int));

    if (variantId != null) {
      final variantImages = allImages
          .where((img) => img['variant_id'] == variantId || img['variant_id'] == null)
          .map<String>((img) => img['image_url'] as String)
          .toList();
      if (variantImages.isNotEmpty) return variantImages;
    }
    final general = allImages
        .where((img) => img['variant_id'] == null)
        .map<String>((img) => img['image_url'] as String)
        .toList();
    return general.isNotEmpty ? general : (allImages.map<String>((img) => img['image_url'] as String).toList());
  }

  int _currentStock() {
    if (_selectedVariantId != null && _product != null) {
      final v = _product!.variants.where((v) => v.id == _selectedVariantId).firstOrNull;
      if (v != null) return v.stock;
    }
    return _product?.stock ?? 0;
  }

  double _currentPrice() {
    if (_selectedVariantId != null && _product != null) {
      final v = _product!.variants.where((v) => v.id == _selectedVariantId).firstOrNull;
      if (v != null) return v.finalPrice > 0 ? v.finalPrice : v.price;
    }
    return _product?.price ?? 0;
  }

  double? _currentOriginalPrice() {
    if (_selectedVariantId != null && _product != null) {
      final v = _product!.variants.where((v) => v.id == _selectedVariantId).firstOrNull;
      if (v != null && v.discountValue > 0 && v.finalPrice < v.price) return v.price;
    }
    return _product?.hasDiscount == true ? _product?.originalPrice : null;
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final productData = await ApiService.getProduct(widget.productId);
      if (mounted && productData != null) {
        final product = Product.fromJson(productData);
        setState(() {
          _product = product;
          _rawProduct = productData;
          if (product.variants.isNotEmpty) {
            _selectedVariantId = product.variants.first.id;
          }
          _isLoading = false;
        });
        // Check wishlist state after product loads
        final wishlisted = await WishlistService.isWishlisted(widget.productId);
        if (mounted) setState(() => _isWishlisted = wishlisted);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToCart() async {
    if (_product == null) return;
    final stock = _currentStock();
    if (stock <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This item is out of stock.'), backgroundColor: Colors.red));
      return;
    }
    if (_selectedQuantity < 1 || _selectedQuantity > stock) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a valid quantity (1–$stock).'), backgroundColor: Colors.red));
      return;
    }

    final token = await ApiService.getAuthToken();
    if (token == null) {
      if (!mounted) return;
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text('Please log in to add items to your cart.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
              child: const Text('Login'),
            ),
          ],
        ),
      );
      if (goLogin == true && mounted) Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      final result = await ApiService.addToCart(
        _product!.id, _selectedQuantity, variantId: _selectedVariantId,
      );
      if (!mounted) return;

      final success = result['success'] == true;
      if (success) {
        await ApiService.refreshCartCount();
        if (!mounted) return;
        _showMiniCartSheet(
          imageUrl: _product!.imageUrl ?? '',
          name: _product!.name,
          variant: _selectedVariantId != null
              ? (_product!.variants.firstWhere((v) => v.id == _selectedVariantId).value ?? '')
              : 'Standard',
          quantity: _selectedQuantity,
          price: _currentPrice(),
          totalCount: ApiService.cartCount.value,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? '🛒 Added to cart!'
              : (result['message']?.toString() ?? 'Failed to add to cart')),
          backgroundColor: success ? AppTheme.success : Colors.red,
          action: success
              ? SnackBarAction(
                  label: 'View Cart',
                  textColor: Colors.white,
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                )
              : null,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to add to cart'), backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Future<void> _buyNow() async {
    if (_product == null) return;
    final stock = _currentStock();
    if (_product!.variants.isNotEmpty && _selectedVariantId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a product variant first.'), backgroundColor: Colors.orange));
      return;
    }
    if (stock <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This item is out of stock.'), backgroundColor: Colors.red));
      return;
    }
    if (_selectedQuantity < 1 || _selectedQuantity > stock) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a valid quantity (1–$stock).'), backgroundColor: Colors.red));
      return;
    }

    final token = await ApiService.getAuthToken();
    if (token == null) {
      if (!mounted) return;
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text('Please log in to proceed to checkout.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
              child: const Text('Login'),
            ),
          ],
        ),
      );
      if (goLogin == true && mounted) Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      // Call backend — server re-validates stock before storing buy-now session
      final res = await ApiService.postJson(
        '/api/buy-now',
        {
          'product_id': _product!.id,
          'variant_id': _selectedVariantId,
          'quantity': _selectedQuantity,
        },
        token: token,
      );
      if (!mounted) return;
      if (res['success'] == true || res['data'] != null) {
        final buyNowItem = {
          'id': 'buynow',
          'product_name': _product!.name,
          'image': _product!.imageUrl ?? '',
          'variant': _selectedVariantId != null
              ? (_product!.variants.firstWhere((v) => v.id == _selectedVariantId).value ?? '')
              : 'Standard',
          'price': _currentPrice(),
          'quantity': _selectedQuantity,
          'subtotal': _currentPrice() * _selectedQuantity,
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutScreen(
              cartItems: [buyNowItem],
              totalAmount: _currentPrice() * _selectedQuantity,
            ),
          ),
        );
      } else {
        final msg = res['error']?.toString() ?? res['message']?.toString() ?? 'Failed to proceed to checkout.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Network error. Please try again.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadRelated() async {
    if (_product == null) return [];
    final related = await ApiService.getProducts(category: _product!.category, limit: 6);
    return related.where((item) => item['id']?.toString() != _product!.id).toList();
  }

  Future<Map<String, dynamic>> _loadReviews() async {
    if (_product == null) return {'reviews': [], 'stats': {'average_rating': 0.0, 'total_reviews': 0}};
    final reviews = await ApiService.getReviews(productId: _product!.id);
    final total = reviews.length;
    final average = total > 0
        ? reviews.fold<double>(0, (sum, item) => sum + ((item['rating'] as num?)?.toDouble() ?? 0)) / total
        : 0.0;
    final formatted = reviews.map((review) {
      final user = review['user'] as Map<String, dynamic>?;
      return {
        ...review,
        'user_name': ((user?['first_name']?.toString() ?? '') + ' ' + (user?['last_name']?.toString() ?? '')).trim(),
      };
    }).toList();
    return {
      'reviews': formatted,
      'stats': {'average_rating': average, 'total_reviews': total},
    };
  }

  void _showMiniCartSheet({
    required String imageUrl,
    required String name,
    required String variant,
    required int quantity,
    required double price,
    required int totalCount,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Added to cart',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('$totalCount item${totalCount != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.grayLight,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 32, color: AppTheme.textLight))
                      : const Icon(Icons.image_outlined, size: 32, color: AppTheme.textLight),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(variant, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                const SizedBox(height: 6),
                Text('Qty $quantity · ₱${(price * quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ])),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/cart');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textDark,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('View Cart', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final cartItems = await ApiService.getCart();
                    final total = cartItems.fold<double>(0, (sum, item) => sum + ((item['subtotal'] as num? ?? 0).toDouble()));
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CheckoutScreen(cartItems: cartItems, totalAmount: total)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1a1a3e)),
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text('Product Details',
              style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20,
                  fontWeight: FontWeight.w600, color: AppTheme.white)),
        ),
        actions: [
          // Wishlist heart button
          if (_product != null)
            IconButton(
              icon: Icon(
                _isWishlisted ? Icons.favorite : Icons.favorite_border,
                color: _isWishlisted ? AppTheme.primaryLight : const Color(0xFF1a1a3e),
              ),
              tooltip: _isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
              onPressed: () async {
                if (_product == null) return;
                final added = await WishlistService.toggle({
                  'id':          _product!.id,
                  'name':        _product!.name,
                  'price':       _product!.price,
                  'image':       _product!.imageUrl,
                  'seller_name': _product!.sellerName ?? '',
                  'total_stock': _product!.stock,
                });
                if (mounted) {
                  setState(() => _isWishlisted = added);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(added ? '❤️ Added to wishlist!' : 'Removed from wishlist.'),
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _product == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('😕', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('Product not found', style: TextStyle(fontSize: 18, color: Color(0xFF1a1a3e), fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
          child: const Text('Go Back'),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    final images = _getImagesForVariant(_selectedVariantId);
    final stock = _currentStock();
    final price = _currentPrice();
    final originalPrice = _currentOriginalPrice();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image carousel
        _buildImageCarousel(images),
        // Thumbnails
        if (images.length > 1) _buildThumbnails(images),
        const SizedBox(height: 12),
        // Info panel
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFe8e8f0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Category
            if (_product!.category.isNotEmpty)
              Text(_product!.category.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.primaryLight, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            // Name
            Text(_product!.name,
                style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 22,
                    fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
            const SizedBox(height: 4),
            // Seller
            if (_product!.sellerName != null && _product!.sellerName!.isNotEmpty)
              Text('by ${_product!.sellerName}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6c757d))),
            const SizedBox(height: 12),
            // Price
            Row(children: [
              Text('₱${price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                      color: AppTheme.primaryLight)),
              if (originalPrice != null) ...[
                const SizedBox(width: 8),
                Text('₱${originalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6c757d),
                        decoration: TextDecoration.lineThrough)),
              ],
            ]),
            const SizedBox(height: 6),
            // Stock
            Row(children: [
              Icon(stock > 0 ? Icons.check_circle : Icons.cancel,
                  size: 14, color: stock > 0 ? const Color(0xFF10b981) : Colors.red),
              const SizedBox(width: 4),
              Text(
                stock > 0 ? 'In Stock ($stock available)' : 'Out of Stock',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: stock > 0 ? const Color(0xFF10b981) : Colors.red),
              ),
            ]),
            // Variants (color swatches)
            if (_product!.variants.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Select Color',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFF1a1a3e), letterSpacing: 0.4)),
              const SizedBox(height: 10),
              _buildColorSwatches(),
            ],
            const SizedBox(height: 16),
            // Quantity
            const Text('Quantity',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a3e), letterSpacing: 0.4)),
            const SizedBox(height: 8),
            _buildQuantitySelector(stock),
            const SizedBox(height: 16),
            // Action buttons
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: stock > 0 && !_isAddingToCart ? _addToCart : null,
                  icon: _isAddingToCart
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('🛒', style: TextStyle(fontSize: 16)),
                  label: Text(_isAddingToCart ? 'Adding...' : 'Add to Cart',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: stock > 0 && !_isAddingToCart ? _buyNow : null,
                  icon: const Text('⚡', style: TextStyle(fontSize: 16)),
                  label: const Text('Buy Now',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a1a3e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              ),
            ]),
            // Description
            const Divider(height: 32, color: Color(0xFFe8e8f0)),
            const Text('DESCRIPTION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF1a1a3e), letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Text(_product!.description.isNotEmpty ? _product!.description : 'No description available.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6c757d), height: 1.7)),
          ]),
        ),
        const SizedBox(height: 16),
        // Related products
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('You May Also Like',
                style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20,
                    fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadRelated(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight, strokeWidth: 2));
                if (snap.data!.isEmpty) return const Text('No related products.', style: TextStyle(color: Color(0xFF6c757d), fontSize: 13));
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72,
                  ),
                  itemCount: snap.data!.length,
                  itemBuilder: (_, i) {
                    final p = snap.data![i];
                    final img = (p['product_images'] as List?)?.isNotEmpty == true
                        ? (p['product_images'] as List).first['image_url']?.toString() : null;
                    return GestureDetector(
                      onTap: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p['id'].toString()))),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFe8e8f0)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: img != null
                                ? Image.network(img, height: 120, width: double.infinity, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(height: 120, color: const Color(0xFFF8F9FA),
                                        child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 32)))))
                                : Container(height: 120, color: const Color(0xFFF8F9FA),
                                    child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 32)))),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('₱${double.tryParse(p['price']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Reviews
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFe8e8f0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Customer Reviews',
                  style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20,
                      fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: _loadReviews(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight, strokeWidth: 2));
                  final reviews = (snap.data!['reviews'] as List? ?? []);
                  final stats = snap.data!['stats'] as Map? ?? {};
                  final avg = (stats['average_rating'] as num?)?.toDouble() ?? 0.0;
                  final total = (stats['total_reviews'] as num?)?.toInt() ?? 0;
                  if (reviews.isEmpty) return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No reviews yet.', style: TextStyle(color: Color(0xFF6c757d)))),
                  );
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: List.generate(5, (i) => Icon(
                          i < avg.round() ? Icons.star : Icons.star_border,
                          size: 16, color: AppTheme.primaryLight,
                        ))),
                        Text('$total review${total != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6c757d))),
                      ]),
                    ]),
                    const Divider(height: 20),
                    ...reviews.take(5).map((r) {
                      final rating = (r['rating'] as num?)?.toInt() ?? 0;
                      final comment = r['comment']?.toString() ?? '';
                      final userName = r['user_name']?.toString() ?? 'Anonymous';
                      final date = r['created_at']?.toString().split('T')[0] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF6c757d))),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: List.generate(5, (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 14, color: AppTheme.primaryLight,
                          ))),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(comment, style: const TextStyle(fontSize: 13, color: Color(0xFF6c757d))),
                          ],
                          const Divider(height: 16),
                        ]),
                      );
                    }),
                  ]);
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    return SizedBox(
      height: 320,
      child: images.isEmpty
          ? Container(
              color: const Color(0xFFF8F9FA),
              child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 80))),
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, st) => Container(
                    color: const Color(0xFFF8F9FA),
                    child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 80))),
                  ),
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFFF8F9FA),
                      child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight, strokeWidth: 2)),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildThumbnails(List<String> images) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final isActive = index == _currentImageIndex;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(index,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              setState(() => _currentImageIndex = index);
            },
            child: Container(
              width: 64, height: 64,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AppTheme.primaryLight : const Color(0xFFe8e8f0),
                  width: isActive ? 2 : 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(images[index], fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => const Center(child: Text('🛍️'))),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorSwatches() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _product!.variants.map((variant) {
        final isSelected = variant.id == _selectedVariantId;
        final color = _resolveColor(variant);
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedVariantId = variant.id;
              _currentImageIndex = 0;
              _selectedQuantity = 1;
            });
            _pageController.jumpToPage(0);
          },
          child: Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryLight : const Color(0xFFe8e8f0),
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppTheme.primaryLight.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1)]
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(variant.value ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6c757d)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildQuantitySelector(int stock) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFe8e8f0), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _qtyButton(Icons.remove, stock <= 0 || _selectedQuantity <= 1
            ? null
            : () => setState(() => _selectedQuantity--)),
        SizedBox(
          width: 48,
          child: Text('$_selectedQuantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        _qtyButton(Icons.add, stock <= 0 || _selectedQuantity >= stock
            ? null
            : () => setState(() => _selectedQuantity++)),
      ]),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        color: const Color(0xFFF8F9FA),
        child: Icon(icon, size: 18,
            color: onTap == null ? Colors.grey.shade300 : const Color(0xFF1a1a3e)),
      ),
    );
  }
}
