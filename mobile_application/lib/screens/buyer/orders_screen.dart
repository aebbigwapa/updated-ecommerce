import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/grande_navbar.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  StreamSubscription<void>? _ordersSub;

  static const _statusSteps = ['pending', 'processing', 'ready_for_pickup', 'in_transit', 'delivered'];
  static const _stepLabels  = ['Pending', 'Processing', 'Ready', 'In Transit', 'Delivered'];

  @override
  void initState() {
    super.initState();
    _initRealtime();
    _loadOrders();
  }

  Future<void> _initRealtime() async {
    final user = await ApiService.getCurrentUser();
    final userId = user?['id'] as String?;
    RealtimeService.instance.subscribeOrders(userId: userId);
    _ordersSub = RealtimeService.instance.ordersStream.listen((_) {
      if (mounted) _syncOrders(); // silent sync
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    RealtimeService.instance.unsubscribeOrders();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _fetchOrders();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _syncOrders() async {
    await _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final ordersData = await ApiService.getOrders();
      if (mounted) setState(() => _orders = ordersData);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedStatus == 'all') return _orders;
    return _orders.where((o) => o['status']?.toString().toLowerCase() == _selectedStatus).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':          return Colors.orange;
      case 'processing':       return Colors.blue;
      case 'ready_for_pickup': return Colors.teal;
      case 'in_transit':       return Colors.purple;
      case 'delivered':        return Colors.green;
      case 'cancelled':        return Colors.red;
      default:                 return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':          return 'Pending';
      case 'processing':       return 'Processing';
      case 'ready_for_pickup': return 'Ready for Pickup';
      case 'in_transit':       return 'In Transit';
      case 'delivered':        return 'Delivered';
      case 'cancelled':        return 'Cancelled';
      default:                 return status ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text('My Orders',
              style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 24,
                  fontWeight: FontWeight.w600, color: AppTheme.white)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 2),
      body: Column(
        children: [
          // Status filter chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.sm),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
              itemCount: 7,
              itemBuilder: (context, index) {
                const statuses = ['all', 'pending', 'processing', 'ready_for_pickup', 'in_transit', 'delivered', 'cancelled'];
                const labels  = ['All', 'Pending', 'Processing', 'Ready', 'In Transit', 'Delivered', 'Cancelled'];
                final status = statuses[index];
                final isSelected = status == _selectedStatus;
                return Container(
                  margin: const EdgeInsets.only(right: AppTheme.sm),
                  child: FilterChip(
                    label: Text(labels[index]),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedStatus = status),
                    backgroundColor: isSelected ? AppTheme.primaryLight : AppTheme.white,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.white : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    side: BorderSide(color: isSelected ? AppTheme.primaryLight : AppTheme.border),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
                : _filteredOrders.isEmpty
                    ? const Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.shopping_bag_outlined, size: 64, color: AppTheme.textLight),
                          SizedBox(height: AppTheme.md),
                          Text('No orders found',
                              style: TextStyle(fontSize: 18, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) => _buildOrderCard(_filteredOrders[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await ApiService.cancelOrder(orderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? 'Order cancelled.' : (res['error'] ?? 'Failed to cancel.')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
      if (res['success'] == true) _loadOrders();
    }
  }

  Widget _buildProgressTracker(String status) {
    final idx = _statusSteps.indexOf(status);
    if (idx == -1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: List.generate(_statusSteps.length, (i) {
          final isDone   = i < idx;
          final isActive = i == idx;
          final color = isDone ? Colors.green : isActive ? AppTheme.primaryLight : Colors.grey.shade300;
          return Expanded(
            child: Column(children: [
              Row(children: [
                if (i > 0) Expanded(child: Container(height: 2, color: isDone ? Colors.green : Colors.grey.shade300)),
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone || isActive ? color : Colors.white,
                    border: Border.all(color: color, width: 2),
                    boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryLight.withValues(alpha: 0.3), blurRadius: 4)] : null,
                  ),
                  child: Center(
                    child: Text(isDone ? '✓' : '${i + 1}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                            color: isDone || isActive ? Colors.white : Colors.grey)),
                  ),
                ),
                if (i < _statusSteps.length - 1) Expanded(child: Container(height: 2, color: isDone ? Colors.green : Colors.grey.shade300)),
              ]),
              const SizedBox(height: 4),
              Text(_stepLabels[i],
                  style: TextStyle(fontSize: 8,
                      color: isDone ? Colors.green : isActive ? AppTheme.primaryLight : Colors.grey,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final items = (order['items'] as List<dynamic>?) ?? [];
    final totalAmount = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final orderId = (order['order_id'] ?? order['id'] ?? '').toString();
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final createdAt = order['created_at']?.toString() ?? '';
    final paymentMethod = (order['payment_method'] ?? 'cod').toString().toUpperCase().replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #$shortId',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
              const SizedBox(height: 2),
              Text(createdAt.isNotEmpty ? '${_formatDate(createdAt)} · $paymentMethod' : paymentMethod,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusText.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F8)),
        // Items preview (with image thumbnails)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            ...items.take(3).map((item) {
              final productName = item['product_name']?.toString() ?? 'Product';
              final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
              final price = (item['final_price'] as num?)?.toDouble() ??
                  (item['unit_price'] as num?)?.toDouble() ?? 0.0;
              final imageUrl = item['image']?.toString();
              final colorHex = (item['variant'] as Map?)?['color_hex']?.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  // Thumbnail
                  Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppTheme.grayLight,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 18, color: AppTheme.textLight))
                          : const Icon(Icons.image_outlined, size: 18, color: AppTheme.textLight),
                    ),
                  ),
                  if (colorHex != null)
                    Container(
                      width: 10, height: 10, margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hexToColor(colorHex),
                        border: Border.all(color: AppTheme.border),
                      ),
                    )
                  else
                    const SizedBox(width: 0),
                  Expanded(child: Text(productName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('×$quantity', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  const SizedBox(width: 8),
                  Text('₱${price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
                ]),
              );
            }),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('+${items.length - 3} more item(s)',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ),
          ]),
        ),
        // Progress tracker
        if (status != 'cancelled') _buildProgressTracker(status),
        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusLg)),
            border: Border(top: BorderSide(color: Color(0xFFF0F0F8))),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total: ₱${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
            Row(children: [
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () => _cancelOrder(orderId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ElevatedButton(
                onPressed: () => _viewOrderDetail(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try { return Color(int.parse('FF${h.padRight(6, '0')}', radix: 16)); }
    catch (_) { return Colors.grey; }
  }

  void _viewOrderDetail(Map<String, dynamic> order) {
    final orderId = (order['order_id'] ?? order['id'] ?? '').toString();
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final status = order['status']?.toString() ?? 'pending';
    final items = (order['items'] as List<dynamic>?) ?? [];
    final totalAmount = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final address = order['shipping_address']?.toString() ?? order['delivery_address']?.toString() ?? '—';
    final paymentMethod = (order['payment_method'] ?? 'cod').toString().toUpperCase().replaceAll('_', ' ');
    final notes = order['notes']?.toString() ?? '';
    final proofUrl = order['proof_of_delivery_url']?.toString() ?? '';
    final proofUploadedAt = order['proof_uploaded_at']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Order #$shortId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _getStatusColor(status))),
              ),
            ]),
            const Divider(height: 20),
            if (status != 'cancelled') _buildProgressTracker(status),
            const SizedBox(height: 8),
            _detailRow('Payment', paymentMethod),
            _detailRow('Address', address),
            if (notes.isNotEmpty) _detailRow('Notes', notes),
            const Divider(height: 20),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ...items.map((item) {
              final name = item['product_name']?.toString() ?? 'Product';
              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
              final price = (item['final_price'] as num?)?.toDouble() ??
                  (item['unit_price'] as num?)?.toDouble() ?? 0.0;
              final totalPrice = (item['total_price'] as num?)?.toDouble() ?? price * qty;
              final imageUrl = item['image']?.toString();
              final variant = (item['variant'] as Map?);
              final colorHex = variant?['color_hex']?.toString();
              final size = variant?['size']?.toString() ?? '';
              final color = variant?['color']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 56, height: 56,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.grayLight,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 24, color: AppTheme.textLight))
                          : const Icon(Icons.image_outlined, size: 24, color: AppTheme.textLight),
                    ),
                  ),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (size.isNotEmpty || color.isNotEmpty)
                      Text('${size.isNotEmpty ? size : ''}${size.isNotEmpty && color.isNotEmpty ? ' / ' : ''}${color.isNotEmpty ? color : ''}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    if (colorHex != null)
                      Row(children: [
                        Container(
                          width: 12, height: 12, margin: const EdgeInsets.only(right: 4, top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hexToColor(colorHex),
                            border: Border.all(color: AppTheme.border),
                          ),
                        ),
                      ]),
                    const SizedBox(height: 4),
                    Text('₱${price.toStringAsFixed(2)} × $qty',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  ])),
                  Text('₱${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
                ]),
              );
            }),
            const Divider(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text('₱${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
            ]),
            // Proof of Delivery
            if (proofUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showProofViewer(proofUrl, proofUploadedAt),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Proof of Delivery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green)),
                      Text('Tap to view photo taken by rider', style: TextStyle(fontSize: 11, color: Colors.green)),
                    ])),
                    const Icon(Icons.chevron_right, color: Colors.green),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _showProofViewer(String proofUrl, String uploadedAt) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Proof of Delivery', style: TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open full image',
              onPressed: () async {
                // just show a snackbar since url_launcher may not be configured
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(proofUrl), duration: const Duration(seconds: 4)),
                );
              },
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  proofUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorBuilder: (_, __, ___) => const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                    SizedBox(height: 12),
                    Text('Could not load image', style: TextStyle(color: Colors.white54)),
                  ]),
                ),
              ),
            ),
          ),
          if (uploadedAt.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              child: Text(
                'Uploaded: ${_formatDate(uploadedAt)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ]),
      ),
    ));
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }
}
