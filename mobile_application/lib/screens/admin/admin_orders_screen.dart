import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
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

  static const _allStatuses = ['pending', 'processing', 'ready_for_pickup', 'in_transit', 'delivered'];

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService.instance.subscribeOrders();
    _realtimeSub = RealtimeService.instance.ordersStream.listen((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeOrders();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() => _isLoading = false); return; }
      final filterParam = _filter == 'all' ? '' : _filter;
      final res = await ApiService.get('/api/admin/orders${filterParam.isNotEmpty ? '?status=$filterParam' : ''}', token: token);
      final data = res is List ? res : (res['orders'] is List ? res['orders'] : []);
      if (mounted) setState(() { _orders = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'all' ? _orders : _orders.where((o) => o['status'] == _filter).toList();

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.postJson('/api/admin/orders/$orderId/status', {'status': status, 'rider_id': ''}, token: token);
      if (mounted) {
        _showSnackBar(res['success'] == true ? 'Status updated.' : (res['error'] ?? 'Failed.'), isError: res['success'] != true);
        if (res['success'] == true) _load();
      }
    } catch (e) { if (mounted) _showSnackBar('Error: $e', isError: true); }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a3e),
        elevation: 0,
        title: const Text('Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _filters.map((f) {
                    final isActive = _filter == f['key'];
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f['key']!),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF1a1a3e) : AppTheme.grayLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(f['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppTheme.textDark)),
                      ),
                    );
                  }).toList()),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No orders found.', style: TextStyle(color: AppTheme.textLight)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _orderTile(_filtered[i]),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _orderTile(Map<String, dynamic> o) {
    final status = o['status']?.toString() ?? 'pending';
    final colors = {'pending': Colors.orange, 'processing': Colors.blue, 'ready_for_pickup': Colors.teal, 'in_transit': Colors.purple, 'delivered': Colors.green, 'cancelled': Colors.red};
    final color = colors[status] ?? Colors.grey;
    final id = (o['id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final buyer = o['buyer'] as Map? ?? {};
    final rider = o['rider'] as Map? ?? {};
    final buyerName = '${buyer['first_name'] ?? ''} ${buyer['last_name'] ?? ''}'.trim();
    final riderName = '${rider['first_name'] ?? ''} ${rider['last_name'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusLg), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('#$shortId', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 6),
        if (buyerName.isNotEmpty) Text('👤 $buyerName', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
        if (riderName.isNotEmpty) Text('🏍️ $riderName', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
        Text('₱${_fmt(o['total_amount'])}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
        const SizedBox(height: 10),
        // Status override dropdown
        Row(children: [
          const Text('Override: ', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
          Expanded(
            child: DropdownButton<String>(
              value: _allStatuses.contains(status) ? status : null,
              isExpanded: true,
              isDense: true,
              underline: Container(height: 1, color: AppTheme.border),
              items: _allStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (newStatus) { if (newStatus != null && newStatus != status) _updateStatus(o['id'], newStatus); },
            ),
          ),
        ]),
      ]),
    );
  }

  String _fmt(dynamic val) {
    try { return double.parse(val.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }
}
