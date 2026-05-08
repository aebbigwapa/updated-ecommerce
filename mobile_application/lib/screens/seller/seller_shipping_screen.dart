import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SellerShippingScreen extends StatefulWidget {
  const SellerShippingScreen({super.key});

  @override
  State<SellerShippingScreen> createState() => _SellerShippingScreenState();
}

class _SellerShippingScreenState extends State<SellerShippingScreen> {
  List<Map<String, dynamic>> _shipments = [];
  bool _isLoading = true;
  String _filter = 'all';

  static const _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': 'awaiting', 'label': 'Awaiting Rider'},
    {'key': 'transit', 'label': 'In Transit'},
    {'key': 'delivered', 'label': 'Delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() => _isLoading = false); return; }
      final res = await ApiService.get('/seller/api/shipping', token: token);
      final data = res is List ? res : (res['shipments'] is List ? res['shipments'] : []);
      if (mounted) {
        setState(() {
          _shipments = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'all' ? _shipments : _shipments.where((s) => s['status'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text('Shipping & Delivery',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(
              children: [
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
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isActive ? AppTheme.white : AppTheme.textDark)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('No active deliveries.', style: TextStyle(color: AppTheme.textLight)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            padding: const EdgeInsets.all(AppTheme.md),
                            itemBuilder: (_, i) => _shipmentTile(_filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _shipmentTile(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? '';
    final colors = {
      'awaiting': Colors.orange, 'transit': Colors.purple,
      'in_transit': Colors.purple, 'delivered': Colors.green,
    };
    final color = colors[status] ?? Colors.grey;
    final orderId = (s['order_id'] ?? '').toString();
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#$shortId', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _infoRow(Icons.person_outline, s['customer_name']?.toString() ?? '—'),
          _infoRow(Icons.location_on_outlined, s['address']?.toString() ?? '—'),
          _infoRow(Icons.delivery_dining_outlined, s['rider_name']?.toString() ?? 'Unassigned'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textLight),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textLight))),
        ],
      ),
    );
  }
}
