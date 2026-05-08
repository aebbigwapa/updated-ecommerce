import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _authToken;
  String _filter = 'all';
  StreamSubscription<void>? _realtimeSub;

  static const _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'processing', 'label': 'Processing'},
    {'key': 'ready_for_pickup', 'label': 'Ready'},
    {'key': 'in_transit', 'label': 'In Transit'},
    {'key': 'delivered', 'label': 'Delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _initRealtime();
  }

  Future<void> _initRealtime() async {
    final token = await ApiService.getAuthToken();
    if (token == null) return;
    RealtimeService.instance.subscribeOrders();
    _realtimeSub = RealtimeService.instance.ordersStream.listen((_) {
      if (mounted) _loadOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeOrders();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    if (silent && mounted) setState(() => _isSyncing = true);
    try {
      _authToken = await ApiService.getAuthToken();
      if (_authToken == null) {
        if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
        return;
      }
      final orders = await ApiService.sellerGetOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'all' ? _orders : _orders.where((o) => o['status'] == _filter).toList();

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      final res = await ApiService.updateOrderStatus(orderId, newStatus, _authToken!);
      if (res['success'] == true && mounted) {
        _showSnackBar('Order status updated');
        _loadOrders();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text('Orders',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(
              children: [
                // Filter tabs
                Container(
                  color: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final isActive = _filter == f['key'];
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f['key']!),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primaryLight : AppTheme.grayLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(f['label']!,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? AppTheme.white : AppTheme.textDark)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('No orders found', style: TextStyle(color: AppTheme.textLight)))
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            padding: const EdgeInsets.all(AppTheme.md),
                            itemBuilder: (context, index) => _orderTile(_filtered[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _orderTile(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final colors = {
      'pending': Colors.orange, 'processing': Colors.blue,
      'ready_for_pickup': Colors.teal, 'in_transit': Colors.purple,
      'delivered': Colors.green, 'cancelled': Colors.red,
    };
    final color = colors[status] ?? Colors.grey;
    final id = (order['id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final createdAt = order['created_at']?.toString() ?? '';
    final dateStr = createdAt.isNotEmpty ? createdAt.split('T')[0] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$shortId',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if ((order['customer_name'] ?? '').toString().isNotEmpty)
                        Text(order['customer_name'].toString(),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Items: ${order['items_count'] ?? 0}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
            Text('Total: ₱${_fmt(order['total_amount'])}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(dateStr, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ],
            if (status == 'pending' || status == 'processing') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (status == 'pending')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(order['id'], 'processing'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  if (status == 'processing') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(order['id'], 'ready_for_pickup'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Ready for Pickup', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic val) {
    try { return double.parse(val.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }
}
