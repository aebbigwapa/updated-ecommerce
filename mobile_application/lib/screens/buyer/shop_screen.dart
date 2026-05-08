import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../widgets/grande_navbar.dart';
import '../../services/realtime_service.dart';
import '../buyer/product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

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
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  String _sortBy = 'name';
  final String _sortOrder = 'asc';
  StreamSubscription<void>? _productsSub;

  @override
  void initState() {
    super.initState();
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppTheme.md),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppTheme.md,
                          mainAxisSpacing: AppTheme.md,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildProductCard(product);
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
        );
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
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusLg),
                    topRight: Radius.circular(AppTheme.radiusLg),
                  ),
                  color: AppTheme.grayLight,
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppTheme.radiusLg),
                          topRight: Radius.circular(AppTheme.radiusLg),
                        ),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.accentBeige,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: AppTheme.textLight,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppTheme.grayLight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryLight,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        color: AppTheme.accentBeige,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: AppTheme.textLight,
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      product.sellerName ?? '',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.hasDiscount)
                                Text(
                                  '₱${product.originalPrice?.toStringAsFixed(2) ?? ''}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontBody,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.textLight,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '₱${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontBody,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (product.stock > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              '${product.stock}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontBody,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: const Text(
                              'Out',
                              style: TextStyle(
                                fontFamily: AppTheme.fontBody,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
