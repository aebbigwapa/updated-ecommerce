import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import 'seller_add_product_screen.dart';
import 'seller_edit_product_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  String _filter = 'all';
  bool _isLoading = true;
  bool _isSyncing = false;
  String _storeName = '';
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<void>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadUser();
    _searchCtrl.addListener(() => setState(() {}));
    RealtimeService.instance.subscribeProducts();
    _realtimeSub = RealtimeService.instance.productsStream.listen((_) {
      if (mounted) _loadProducts(silent: true);
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeProducts();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getCurrentUser();
    if (mounted) {
      setState(() {
        _storeName = user?['store_name'] ?? 'My Store';
      });
    }
  }

  Future<void> _loadProducts({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    if (silent && mounted) setState(() => _isSyncing = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.getSellerProducts(token);
      if (mounted) {
        setState(() {
          _products = res;
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  void _setFilter(String filter) {
    setState(() => _filter = filter);
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var filtered = _products;
    
    if (_filter != 'all') {
      filtered = filtered.where((p) => p['status'] == _filter).toList();
    }
    
    if (_searchCtrl.text.isNotEmpty) {
      final query = _searchCtrl.text.toLowerCase();
      filtered = filtered.where((p) => 
        (p['name'] ?? '').toString().toLowerCase().contains(query)
      ).toList();
    }
    
    return filtered;
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await ApiService.sellerDeleteProduct(productId);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted'), backgroundColor: Colors.green),
      );
      _loadProducts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to delete'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        title: const Text(
          'Products',
          style: TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight))),
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.md),
                  color: AppTheme.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SellerAddProductScreen())),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
                  child: Row(
                    children: [
                      _filterTab('All', 'all'),
                      const SizedBox(width: 8),
                      _filterTab('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _filterTab('Active', 'active'),
                      const SizedBox(width: 8),
                      _filterTab('Rejected', 'rejected'),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(child: Text('No products found', style: TextStyle(color: AppTheme.textLight)))
                      : ListView.builder(
                          itemCount: _filteredProducts.length,
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemBuilder: (context, index) {
                            final p = _filteredProducts[index];
                            return _productTile(p);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('🏪', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grande Seller',
                            style: TextStyle(
                              fontFamily: AppTheme.fontDisplay,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.white,
                            ),
                          ),
                          Text(
                            _storeName,
                            style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.home_outlined, 'Dashboard', '/seller-dashboard'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('STORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1.0)),
                ),
                _drawerItem(Icons.inventory_2_outlined, 'Products', '/seller/products', isActive: true),
                _drawerItem(Icons.shopping_bag_outlined, 'Orders', '/seller/orders'),
                _drawerItem(Icons.local_shipping_outlined, 'Shipping', '/seller/shipping'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('FINANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1.0)),
                ),
                _drawerItem(Icons.payments_outlined, 'Earnings', '/seller/earnings'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('PROFILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1.0)),
                ),
                _drawerItem(Icons.storefront_outlined, 'Store Profile', '/seller/store'),
                _drawerItem(Icons.star_outline, 'Reviews', '/seller/reviews'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🏪 $_storeName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Text('Seller Account', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await ApiService.logout();
                      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                    },
                    icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                    label: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, String route, {bool isActive = false}) {
    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.primaryLight : AppTheme.textDark, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive ? AppTheme.primaryLight : AppTheme.textDark,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (!isActive) Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _filterTab(String label, String filter) {
    final isActive = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFilter(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppTheme.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'pending';
    final colors = {
      'pending': Colors.orange,
      'active': Colors.green,
      'rejected': Colors.red,
    };
    final color = colors[status] ?? Colors.grey;
    final images = p['product_images'] is List ? p['product_images'] : [];
    final imageUrl = images.isNotEmpty && images[0]['image_url'] != null ? images[0]['image_url'] : null;
    final variants = p['variants'] is List ? p['variants'] : [];
    final stock = p['total_stock'] ?? 0;
    final price = p['price'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(
                  height: 160,
                  color: AppTheme.grayLight,
                  child: const Icon(Icons.image, size: 48, color: AppTheme.textLight),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] ?? 'Unnamed Product',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${_fmt(price)} • Stock: $stock',
                  style: TextStyle(fontSize: 13, color: AppTheme.textLight),
                ),
                if (variants.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${variants.length} variant(s)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerEditProductScreen(product: p),
                            ),
                          );
                          if (updated == true) _loadProducts();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryLight,
                          side: const BorderSide(color: AppTheme.primaryLight),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _deleteProduct(p['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(AppTheme.md, 0, AppTheme.md, AppTheme.md),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    try {
      return double.parse(val.toString()).toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }
}