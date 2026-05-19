import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class SellerEarningsScreen extends StatefulWidget {
  const SellerEarningsScreen({super.key});

  @override
  State<SellerEarningsScreen> createState() => _SellerEarningsScreenState();
}

class _SellerEarningsScreenState extends State<SellerEarningsScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  String _storeName = '';
  StreamSubscription<void>? _ordersSub;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
    RealtimeService.instance.subscribeOrders();
    _ordersSub = RealtimeService.instance.ordersStream.listen((_) {
      if (mounted) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    RealtimeService.instance.unsubscribeOrders();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getCurrentUser();
    if (mounted) setState(() => _storeName = user?['store_name'] ?? 'My Store');
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    if (silent && mounted) setState(() => _isSyncing = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) {
        if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
        return;
      }
      final res = await ApiService.getSellerEarnings(token);
      if (mounted) {
        setState(() {
          _stats = res['stats'] is Map ? Map<String, dynamic>.from(res['stats'] as Map) : {};
          _isLoading = false;
          _isSyncing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text('Earnings',
            style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark)),
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
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: AppTheme.md),
                    _buildBreakdownCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppTheme.sm,
      mainAxisSpacing: AppTheme.sm,
      childAspectRatio: 1.5,
      children: [
        _statCard('Total Earnings', '₱${_fmt(_stats['total_earnings'])}', Icons.payments_outlined, Colors.green),
        _statCard("Today's Sales", '₱${_fmt(_stats['today_sales'])}', Icons.today_outlined, Colors.blue),
        _statCard('This Week', '₱${_fmt(_stats['week_sales'])}', Icons.date_range_outlined, Colors.orange),
        _statCard('This Month', '₱${_fmt(_stats['month_sales'])}', Icons.calendar_month_outlined, AppTheme.primaryLight),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earnings Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: AppTheme.md),
          _breakdownRow('Total Orders', '${_stats['total_orders'] ?? 0}'),
          _breakdownRow('Items Sold', '${_stats['items_sold'] ?? 0}'),
          _breakdownRow('Avg. Order Value', '₱${_fmt(_stats['avg_order_value'])}'),
          _breakdownRow('Pending Payout', '₱${_fmt(_stats['pending_payout'])}'),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
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
                          Text('Grande Seller',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontDisplay,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.white)),
                          Text(_storeName,
                              style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF))),
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
                  child: Text('STORE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1.0)),
                ),
                _drawerItem(Icons.inventory_2_outlined, 'Products', '/seller/products'),
                _drawerItem(Icons.shopping_bag_outlined, 'Orders', '/seller/orders'),
                _drawerItem(Icons.local_shipping_outlined, 'Shipping', '/seller/shipping'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('FINANCE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1.0)),
                ),
                _drawerItem(Icons.payments_outlined, 'Earnings', '/seller/earnings', isActive: true),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('PROFILE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1.0)),
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
                        Text('🏪 $_storeName',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Text('Seller Account',
                            style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
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
      title: Text(label,
          style: TextStyle(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppTheme.primaryLight : AppTheme.textDark)),
      onTap: () {
        Navigator.pop(context);
        if (!isActive) Navigator.pushNamed(context, route);
      },
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
