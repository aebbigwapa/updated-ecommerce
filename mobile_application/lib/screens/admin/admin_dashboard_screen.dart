import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import 'admin_applications_screen.dart';
import 'admin_users_screen.dart';
import 'admin_sellers_screen.dart';
import 'admin_riders_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _name = '';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _pendingApps = [];
  bool _isLoading = true;
  StreamSubscription<void>? _ordersSub;
  StreamSubscription<void>? _productsSub;
  StreamSubscription<void>? _appsSub;

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService.instance.subscribeOrders();
    RealtimeService.instance.subscribeProducts();
    RealtimeService.instance.subscribeApplications();
    _ordersSub = RealtimeService.instance.ordersStream.listen((_) { if (mounted) _loadData(); });
    _productsSub = RealtimeService.instance.productsStream.listen((_) { if (mounted) _loadData(); });
    _appsSub = RealtimeService.instance.applicationsStream.listen((_) { if (mounted) _loadData(); });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _productsSub?.cancel();
    _appsSub?.cancel();
    RealtimeService.instance.unsubscribeAll();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('user_first_name') ?? '';
    if (mounted) setState(() => _name = firstName);
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() => _isLoading = false); return; }

      final results = await Future.wait([
        ApiService.get('/api/admin/dashboard', token: token),
        ApiService.get('/api/admin/recent-orders?limit=5', token: token),
        ApiService.get('/api/admin/pending-applications', token: token),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0];
          final ordersRaw = results[1];
          _recentOrders = ordersRaw is List
              ? List<Map<String, dynamic>>.from(ordersRaw as List)
              : (results[1]['orders'] is List
                  ? List<Map<String, dynamic>>.from(results[1]['orders'] as List)
                  : []);
          final appsRaw = results[2];
          _pendingApps = appsRaw is List
              ? List<Map<String, dynamic>>.from(appsRaw as List)
              : (results[2]['applications'] is List
                  ? List<Map<String, dynamic>>.from(results[2]['applications'] as List)
                  : []);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a3e),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Grande Admin',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: AppTheme.md),
                    _buildStatsGrid(),
                    const SizedBox(height: AppTheme.md),
                    _buildManageGrid(),
                    const SizedBox(height: AppTheme.md),
                    _buildPendingApps(),
                    const SizedBox(height: AppTheme.md),
                    _buildRecentOrders(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a3e),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome, $_name 👤',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Admin Control Panel', style: TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(children: [
          _miniStat('Revenue', '₱${_fmt(_stats['total_revenue'])}', Colors.green),
          const SizedBox(width: 8),
          _miniStat('Commission', '₱${_fmt(_stats['admin_commission'])}', AppTheme.primaryLight),
          const SizedBox(width: 8),
          _miniStat('Rate', '${_stats['commission_rate'] ?? 5}%', Colors.amber),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppTheme.sm,
      mainAxisSpacing: AppTheme.sm,
      childAspectRatio: 1.6,
      children: [
        _statCard('Total Users', '${_stats['total_users'] ?? 0}', Icons.people_outline, Colors.blue),
        _statCard('Sellers', '${_stats['total_sellers'] ?? 0}', Icons.storefront_outlined, Colors.orange),
        _statCard('Riders', '${_stats['total_riders'] ?? 0}', Icons.delivery_dining_outlined, Colors.purple),
        _statCard('Total Orders', '${_stats['total_orders'] ?? 0}', Icons.receipt_long_outlined, Colors.teal),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusLg), boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
        ])),
      ]),
    );
  }

  Widget _buildManageGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Manage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
      const SizedBox(height: AppTheme.sm),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppTheme.sm,
        mainAxisSpacing: AppTheme.sm,
        childAspectRatio: 1.4,
        children: [
          _actionCard('📋', 'Applications', () => _push(const AdminApplicationsScreen())),
          _actionCard('👥', 'Users', () => _push(const AdminUsersScreen())),
          _actionCard('🏪', 'Sellers', () => _push(const AdminSellersScreen())),
          _actionCard('🏍️', 'Riders', () => _push(const AdminRidersScreen())),
          _actionCard('📦', 'Products', () => _push(const AdminProductsScreen())),
          _actionCard('🛒', 'Orders', () => _push(const AdminOrdersScreen())),
        ],
      ),
    ]);
  }

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _actionCard(String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd), boxShadow: AppTheme.cardShadow),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        ]),
      ),
    );
  }

  Widget _buildPendingApps() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Pending Applications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        if (_pendingApps.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            child: Text('${_pendingApps.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
      const SizedBox(height: AppTheme.sm),
      if (_pendingApps.isEmpty)
        _emptyState('No pending applications')
      else
        ..._pendingApps.take(5).map((a) => _appTile(a)),
    ]);
  }

  Widget _appTile(Map<String, dynamic> app) {
    final role = app['role']?.toString() ?? '';
    final roleColors = {'seller': Colors.orange, 'rider': Colors.purple, 'buyer': Colors.blue};
    final color = roleColors[role] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd), boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app['full_name']?.toString() ?? app['name']?.toString() ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(app['email']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(role, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildRecentOrders() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Recent Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        TextButton(
          onPressed: () => _push(const AdminOrdersScreen()),
          child: const Text('View All', style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: AppTheme.sm),
      if (_recentOrders.isEmpty)
        _emptyState('No orders yet')
      else
        ..._recentOrders.map((o) => _orderTile(o)),
    ]);
  }

  Widget _orderTile(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final colors = {'pending': Colors.orange, 'processing': Colors.blue, 'ready_for_pickup': Colors.teal, 'in_transit': Colors.purple, 'delivered': Colors.green, 'cancelled': Colors.red};
    final color = colors[status] ?? Colors.grey;
    final id = (order['id'] ?? order['short_id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd), boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Order #$shortId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('₱${_fmt(order['total_amount'])}', style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _emptyState(String msg) => Container(
    padding: const EdgeInsets.all(AppTheme.lg),
    alignment: Alignment.center,
    child: Text(msg, style: const TextStyle(color: AppTheme.textLight)),
  );

  String _fmt(dynamic val) {
    try { return double.parse(val.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }
}
