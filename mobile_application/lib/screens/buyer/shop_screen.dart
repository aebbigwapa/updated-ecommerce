import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/product.dart';
import '../../widgets/grande_navbar.dart';
import '../../services/realtime_service.dart';
import '../buyer/product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? initialCategory;
  const ShopScreen({super.key, this.initialCategory});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Product> _products = [];
  List<Product> _allProducts = [];
  final List<String> _categories = [
    'All',
    'Dresses & Skirts',
    'Tops & Blouses',
    'Activewear & Yoga Pants',
    'Lingerie & Sleepwear',
    'Jackets & Coats',
    'Shoes & Accessories',
  ];
  late String _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;
  String _sortBy = 'name';
  final String _sortOrder = 'asc';
  StreamSubscription<void>? _productsSub;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory != null &&
            _categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : 'All';
    _loadProducts();
    RealtimeService.instance.subscribeProducts();
    _productsSub = RealtimeService.instance.productsStream.listen((_) {
      if (mounted) _loadProducts();
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    RealtimeService.instance.unsubscribeProducts();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    
    try {
      final productsData = await ApiService.getProducts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );
      
      if (mounted) {
        setState(() {
          _allProducts = productsData.map((p) => Product.fromJson(p)).toList();
          _isLoading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      _products = _allProducts.where((product) {
        final matchesSearch = _searchQuery.isEmpty ||
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (product.sellerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return matchesSearch;
      }).toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'Shop',
            style: TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.white,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
            icon: const Icon(Icons.shopping_cart_outlined),
            color: AppTheme.white,
          ),
        ],
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 1),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.white,
              boxShadow: AppTheme.subtleShadow,
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value;
                    });
                    _loadProducts();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                    const PopupMenuItem(value: 'price', child: Text('Sort by Price')),
                    const PopupMenuItem(value: 'created_at', child: Text('Sort by Date')),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.grayLight,
              ),
            ),
          ),
          
          // Category Filter
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Container(
                  margin: const EdgeInsets.only(right: AppTheme.sm),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                      _loadProducts();
                    },
                    backgroundColor: isSelected ? AppTheme.primaryLight : AppTheme.white,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.white : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryLight : AppTheme.border,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Products Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryLight,
                    ),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(height: AppTheme.md),
                            Text(
                              'No products found',
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppTheme.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth =
                              (constraints.maxWidth - AppTheme.sm) / 2;
                          final ratio = cardWidth / (cardWidth + 110);
                          return GridView.builder(
                            padding: const EdgeInsets.all(AppTheme.md),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppTheme.sm,
                              mainAxisSpacing: AppTheme.sm,
                              childAspectRatio: ratio,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) =>
                                _buildProductCard(_products[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: product.id),
          ),
        ).then((_) => setState(() {}));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image — AspectRatio + Stack for wishlist heart
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusLg),
                      topRight: Radius.circular(AppTheme.radiusLg),
                    ),
                    child: SizedBox.expand(
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.accentBeige,
                                child: const Icon(Icons.image_outlined,
                                    size: 36, color: AppTheme.textLight),
                              ),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : Container(
                                          color: AppTheme.grayLight,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: AppTheme.primaryLight,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                            )
                          : Container(
                              color: AppTheme.accentBeige,
                              child: const Icon(Icons.image_outlined,
                                  size: 36, color: AppTheme.textLight),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _WishlistHeart(product: product),
                  ),
                ],
              ),
            ),
            // Info — no Spacer, no fixed height
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product name: 2-line clamp with ellipsis + tooltip on long-press
                  Tooltip(
                    message: product.name,
                    preferBelow: true,
                    triggerMode: TooltipTriggerMode.longPress,
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.sellerName != null &&
                      product.sellerName!.isNotEmpty) ...[  
                    const SizedBox(height: 3),
                    Text(
                      product.sellerName!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.hasDiscount)
                              Text(
                                '₱${product.originalPrice?.toStringAsFixed(2) ?? ''}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              '₱${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontBody,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.stock > 0
                              ? AppTheme.primaryLight.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          product.stock > 0 ? '${product.stock}' : 'Out',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: product.stock > 0
                                ? AppTheme.primaryLight
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heart button overlay on product cards ─────────────────────────────────────
class _WishlistHeart extends StatefulWidget {
  final Product product;
  const _WishlistHeart({required this.product});
  @override
  State<_WishlistHeart> createState() => _WishlistHeartState();
}

class _WishlistHeartState extends State<_WishlistHeart> {
  bool _wishlisted = false;

  @override
  void initState() {
    super.initState();
    WishlistService.isWishlisted(widget.product.id)
        .then((v) { if (mounted) setState(() => _wishlisted = v); });
  }

  Future<void> _toggle() async {
    final added = await WishlistService.toggle({
      'id':           widget.product.id,
      'name':         widget.product.name,
      'price':        widget.product.price,
      'image':        widget.product.imageUrl,
      'seller_name':  widget.product.sellerName ?? '',
      'total_stock':  widget.product.stock,
    });
    if (mounted) setState(() => _wishlisted = added);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added ? '❤️ Added to wishlist!' : 'Removed from wishlist.'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
        ),
        child: Icon(
          _wishlisted ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: _wishlisted ? AppTheme.primaryLight : AppTheme.textLight,
        ),
      ),
    );
  }
}
