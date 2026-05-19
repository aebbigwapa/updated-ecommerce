import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/grande_navbar.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isSyncing = false; // silent background sync flag
  double _totalAmount = 0.0;
  StreamSubscription<void>? _cartSub;

  @override
  void initState() {
    super.initState();
    _initRealtime();
    _loadCart();
  }

  Future<void> _initRealtime() async {
    final prefs = await ApiService.getAuthToken();
    // Get userId for scoped subscription
    final user = await ApiService.getCurrentUser();
    final userId = user?['id'] as String?;
    RealtimeService.instance.subscribeCart(userId: userId);
    _cartSub = RealtimeService.instance.cartStream.listen((_) {
      if (mounted) _syncCart(); // silent sync, no spinner
    });
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    RealtimeService.instance.unsubscribeCart();
    super.dispose();
  }

  Future<void> _loadCart() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _fetchCart();
    if (mounted) setState(() => _isLoading = false);
  }

  // Silent background sync triggered by realtime — no loading spinner
  Future<void> _syncCart() async {
    if (_isSyncing) return;
    _isSyncing = true;
    await _fetchCart();
    _isSyncing = false;
  }

  Future<void> _fetchCart() async {
    try {
      final cartData = await ApiService.getCart();
      if (mounted) {
        setState(() {
          _cartItems = cartData;
          _calculateTotal();
        });
      }
    } catch (_) {}
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      return sum + (item['subtotal'] as num? ?? 0).toDouble();
    });
  }

  double get _shipping => _totalAmount >= 500 ? 0 : 50;
  double get _grandTotal => _totalAmount + _shipping;

  Future<void> _clearAll() async {
    if (_cartItems.isEmpty) return;
    // Optimistic update
    setState(() { _cartItems.clear(); _calculateTotal(); });
    // Remove all items via individual calls (no bulk clear endpoint on mobile)
    final token = await ApiService.getAuthToken();
    if (token == null) return;
    try {
      final res = await ApiService.postJson('/api/cart/clear', {}, token: token);
      if (res['success'] != true) {
        // Fallback: reload from server
        _loadCart();
      }
    } catch (_) {
      _loadCart();
    }
  }

  Future<void> _updateQuantity(String itemId, int quantity) async {
    if (quantity < 1) { await _removeItem(itemId); return; }
    final idx = _cartItems.indexWhere((i) => i['id'] == itemId);
    if (idx == -1) return;
    final maxStock = ((_cartItems[idx]['available_stock'] ?? 9999) as num).toInt();
    if (quantity > maxStock) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only $maxStock in stock'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    // Optimistic update
    setState(() {
      _cartItems[idx]['quantity'] = quantity;
      _cartItems[idx]['subtotal'] = quantity * (_cartItems[idx]['price'] as num).toDouble();
      _calculateTotal();
    });
    final success = await ApiService.updateCartItem(itemId, quantity);
    if (!success && mounted) {
      // Revert on failure
      _loadCart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update quantity'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeItem(String itemId) async {
    // Optimistic update
    setState(() {
      _cartItems.removeWhere((i) => i['id'] == itemId);
      _calculateTotal();
    });
    final success = await ApiService.removeFromCart(itemId);
    if (!success && mounted) {
      _loadCart(); // revert
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item'), backgroundColor: Colors.red),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item removed'), backgroundColor: Colors.green),
      );
    }
  }

  void _proceedToCheckout() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty'), backgroundColor: Colors.orange),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          cartItems: _cartItems,
          totalAmount: _totalAmount,
        ),
      ),
    ).then((_) => _loadCart());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 2),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _cartItems.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.textLight),
                          const SizedBox(height: AppTheme.md),
                          const Text('Your cart is empty',
                              style: TextStyle(fontSize: 18, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                          const SizedBox(height: AppTheme.md),
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/shop'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
                            child: const Text('Continue Shopping'),
                          ),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCart,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemCount: _cartItems.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppTheme.sm),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''} in your cart',
                                        style: const TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                                    TextButton(
                                      onPressed: _clearAll,
                                      child: const Text('🗑 Clear all', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return _buildCartItem(_cartItems[index - 1]);
                          },
                        ),
                      ),
          ),
          if (_cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                color: AppTheme.white,
                boxShadow: AppTheme.cardShadow,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusLg),
                  topRight: Radius.circular(AppTheme.radiusLg),
                ),
              ),
              child: Column(children: [
                Builder(builder: (_) {
                  final progress = (_totalAmount / 500).clamp(0.0, 1.0);
                  final isFree = _totalAmount >= 500;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isFree ? '🎉 You\'ve unlocked free shipping!' : 'Add ₱${(500 - _totalAmount).toStringAsFixed(2)} more for free shipping',
                      style: TextStyle(fontSize: 12, color: isFree ? const Color(0xFF10b981) : AppTheme.textLight, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ]);
                }),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Subtotal:', style: TextStyle(fontSize: 14, color: AppTheme.textLight)),
                  Text('₱${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Shipping:', style: TextStyle(fontSize: 14, color: AppTheme.textLight)),
                  Text(_shipping == 0 ? 'FREE' : '₱${_shipping.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: _shipping == 0 ? const Color(0xFF10b981) : AppTheme.textDark)),
                ]),
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total:',
                      style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20,
                          fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                  Text('₱${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20,
                          fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
                ]),
                const SizedBox(height: AppTheme.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _proceedToCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: const Text('Proceed to Checkout →',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('🔒 Secure checkout · Free shipping over ₱500',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final name = item['product_name'] as String? ?? 'Product';
    final imageUrl = item['image'] as String?;
    final variant = item['variant'] as String?;
    final quantity = (item['quantity'] as num? ?? 1).toInt();
    final price = (item['price'] as num? ?? 0).toDouble();
    final subtotal = (item['subtotal'] as num? ?? 0).toDouble();
    final maxStock = (item['available_stock'] as num? ?? 9999).toInt();
    final atMax = quantity >= maxStock;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        // Product image
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            color: AppTheme.grayLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 32, color: AppTheme.textLight),
                  )
                : const Icon(Icons.image_outlined, size: 32, color: AppTheme.textLight),
          ),
        ),
        const SizedBox(width: AppTheme.md),
        // Details
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (variant != null && variant.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Variant: $variant',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ],
            const SizedBox(height: 4),
            Text('₱${price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
            if (atMax)
              Text('Max stock reached ($maxStock)',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
          ]),
        ),
        // Qty + subtotal + delete
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _qtyBtn(Icons.remove, quantity > 1
                  ? () => _updateQuantity(item['id'] as String, quantity - 1) : null),
              SizedBox(
                width: 36,
                child: Text('$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              _qtyBtn(Icons.add, atMax ? null : () => _updateQuantity(item['id'] as String, quantity + 1)),
            ]),
          ),
          const SizedBox(height: 6),
          Text('₱${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
          IconButton(
            onPressed: () => _removeItem(item['id'] as String),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: onTap == null ? Colors.grey.shade300 : AppTheme.textDark),
      ),
    );
  }
}
