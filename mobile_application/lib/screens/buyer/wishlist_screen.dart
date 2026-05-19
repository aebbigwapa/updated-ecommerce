import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/grande_navbar.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});
  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await WishlistService.getAll();
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  Future<void> _remove(String productId) async {
    await WishlistService.remove(productId);
    if (mounted) {
      setState(() => _items.removeWhere((p) => p['id']?.toString() == productId));
      _showToast('Removed from wishlist.');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final token = await ApiService.getAuthToken();
    if (token == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    final stock = (product['total_stock'] ?? product['stock'] ?? 0) as num;
    if (stock <= 0) {
      _showToast('This item is out of stock.');
      return;
    }
    final result = await ApiService.addToCart(product['id'].toString(), 1);
    if (mounted) {
      final ok = result['success'] == true;
      if (ok) {
        await ApiService.refreshCartCount();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('🛒 Added to cart!'),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ));
      } else {
        _showToast(result['message']?.toString() ?? 'Failed to add to cart');
      }
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('My Wishlist'),
          const SizedBox(width: 8),
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_items.length}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ]),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 3),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _items.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _WishlistCard(
                      product: _items[i],
                      onRemove: () => _remove(_items[i]['id'].toString()),
                      onAddToCart: () => _addToCart(_items[i]),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                              productId: _items[i]['id'].toString()),
                        ),
                      ).then((_) => _load()),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('❤️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Your wishlist is empty ❤️',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('Save items you love to buy them later.',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/shop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Browse Products',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

// ── Wishlist card — matches web wc-* layout ───────────────────────────────────
class _WishlistCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;
  final VoidCallback onTap;

  const _WishlistCard({
    required this.product,
    required this.onRemove,
    required this.onAddToCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name   = product['name']?.toString() ?? '';
    final price  = (product['price'] as num? ?? 0).toDouble();
    final img    = product['image']?.toString();
    final seller = product['seller_name']?.toString() ?? '';
    final stock  = (product['total_stock'] ?? product['stock'] ?? 0) as num;
    final inStock = stock > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe8e8f0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image with remove button overlay
        Stack(children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: img != null && img.isNotEmpty
                    ? Image.network(img, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
          ),
          Positioned(
            top: 6, right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
            ),
          ),
        ]),

        // Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name
              GestureDetector(
                onTap: onTap,
                child: Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
              ),
              // Seller
              if (seller.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('by $seller',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ],
              const SizedBox(height: 4),
              // Price
              Text('₱${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppTheme.primaryLight)),
              const SizedBox(height: 3),
              // Stock badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: inStock
                      ? const Color(0xFFe8f5e9)
                      : const Color(0xFFffebee),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  inStock ? '${stock.toInt()} in stock' : 'Out of stock',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: inStock
                          ? const Color(0xFF2e7d32)
                          : const Color(0xFFc62828)),
                ),
              ),
              const Spacer(),
              // Buttons row — matches web wc-actions
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      onPressed: inStock ? onAddToCart : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      child: Text(
                        inStock ? '🛒 Cart' : 'Out of Stock',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryLight),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('❤️',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF8F9FA),
        child: const Center(child: Text('🛍️', style: TextStyle(fontSize: 36))),
      );
}
