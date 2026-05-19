import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _filter = 'pending';
  StreamSubscription<void>? _realtimeSub;

  static const _filters = [
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'active', 'label': 'Active'},
    {'key': 'rejected', 'label': 'Rejected'},
    {'key': 'all', 'label': 'All'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService.instance.subscribeProducts();
    _realtimeSub = RealtimeService.instance.productsStream.listen((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeProducts();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() => _isLoading = false); return; }
      final status = _filter == 'all' ? '' : _filter;
      final res = await ApiService.get('/api/admin/products${status.isNotEmpty ? '?status=$status' : ''}', token: token);
      final data = res is List ? res : (res['products'] is List ? res['products'] : []);
      if (mounted) setState(() { _products = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _updateStatus(String id, String status, {String reason = ''}) async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.postJson('/api/admin/products/$id/status', {'status': status, 'reason': reason}, token: token);
      if (mounted) {
        _showSnackBar(res['success'] == true ? 'Product ${status == 'active' ? 'approved' : 'rejected'}.' : (res['error'] ?? 'Failed.'), isError: res['success'] != true);
        if (res['success'] == true) _load();
      }
    } catch (e) { if (mounted) _showSnackBar('Error: $e', isError: true); }
  }

  void _showRejectDialog(String id) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reject Product'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason for rejection...'), maxLines: 3),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); _updateStatus(id, 'rejected', reason: ctrl.text.trim()); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Reject'),
        ),
      ],
    ));
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
        title: const Text('Product Moderation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _filters.map((f) {
              final isActive = _filter == f['key'];
              return GestureDetector(
                onTap: () { setState(() { _filter = f['key']!; _isLoading = true; }); _load(); },
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
              : _products.isEmpty
                  ? const Center(child: Text('No products found.', style: TextStyle(color: AppTheme.textLight)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.md),
                        itemCount: _products.length,
                        itemBuilder: (_, i) => _productTile(_products[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _productTile(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? '';
    final statusColors = {'pending': Colors.orange, 'active': Colors.green, 'rejected': Colors.red};
    final color = statusColors[status] ?? Colors.grey;
    final seller = p['seller'] as Map? ?? {};
    final sellerName = '${seller['first_name'] ?? ''} ${seller['last_name'] ?? ''}'.trim();
    final images = p['product_images'] is List ? p['product_images'] as List : [];
    final imageUrl = images.isNotEmpty ? images[0]['image_url']?.toString() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusLg), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imageUrl != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 140, color: AppTheme.grayLight, child: const Icon(Icons.image, size: 48, color: AppTheme.textLight))),
          ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(p['name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
            ]),
            const SizedBox(height: 4),
            Text('${p['category'] ?? '—'} • ₱${_fmt(p['price'])}', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
            if (sellerName.isNotEmpty) Text('Seller: $sellerName', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
            if ((p['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p['description'].toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textLight), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: () => _updateStatus(p['id'], 'active'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: const Text('Approve', style: TextStyle(fontSize: 12)),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  onPressed: () => _showRejectDialog(p['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                )),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  String _fmt(dynamic val) {
    try { return double.parse(val.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }
}
