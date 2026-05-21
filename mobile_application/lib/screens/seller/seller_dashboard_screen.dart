import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import 'seller_add_product_screen.dart';
import 'seller_notifications_screen.dart';
import 'seller_messages_screen.dart';
import 'seller_analytics_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  String _name = '';
  String _storeName = '';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  StreamSubscription<void>? _ordersSub;
  StreamSubscription<void>? _productsSub;

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService.instance.subscribeOrders();
    RealtimeService.instance.subscribeProducts();
    _ordersSub = RealtimeService.instance.ordersStream.listen((_) {
      if (mounted) _loadStats(silent: true);
    });
    _productsSub = RealtimeService.instance.productsStream.listen((_) {
      if (mounted) _loadStats(silent: true);
    });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _productsSub?.cancel();
    RealtimeService.instance.unsubscribeAll();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('user_first_name') ?? '';
      final lastName  = prefs.getString('user_last_name')  ?? '';
      final userId    = prefs.getString('user_id')         ?? '';
      if (mounted) {
        setState(() => _name = '$firstName $lastName'.trim());
      }
      if (userId.isNotEmpty) {
        final app = await ApiService.getApplication(userId);
        if (app != null && mounted) {
          setState(() => _storeName = app['store_name'] ?? 'My Store');
        }
      }
      await _loadStats();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final results = await Future.wait([
        ApiService.get('/api/seller/dashboard', token: token),
        ApiService.get('/api/seller/orders', token: token),
        ApiService.get('/api/seller/notifications', token: token),
        ApiService.getUnreadMessageCount(token),
      ]);
      if (mounted) {
        final dashboardData = results[0] as Map<String, dynamic>;
        final ordersData = results[1] as Map<String, dynamic>;
        final notificationsData = results[2] as Map<String, dynamic>;
        final unreadCount = results[3] as int;
        
        final orders = ordersData['orders'] is List
            ? List<Map<String, dynamic>>.from(ordersData['orders'] as List)
            : <Map<String, dynamic>>[];
        setState(() {
          _stats = dashboardData;
          _recentOrders = orders.take(5).toList();
          _unreadNotifications = notificationsData['unread_count'] ?? 0;
          _unreadMessages = unreadCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Yes, Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryLight,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRevenueCard(),
                          const SizedBox(height: AppTheme.md),
                          _buildStatsRow(),
                          const SizedBox(height: AppTheme.md),
                          _buildOrderStatusCard(),
                          const SizedBox(height: AppTheme.md),
                          _buildQuickActions(),
                          const SizedBox(height: AppTheme.md),
                          _buildRecentOrders(),
                          const SizedBox(height: AppTheme.md),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1a1a3e),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white70),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: const Text('Grande Seller',
          style: TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerMessagesScreen()),
              ).then((_) => _loadStats(silent: true)),
            ),
            if (_unreadMessages > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerNotificationsScreen()),
              ).then((_) => _loadStats(silent: true)),
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _logout),
      ],
    );
  }

  Widget _buildHeader() {
    final pendingOrders = _stats['pending_orders'] ?? 0;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a3e),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
                child: Text('🏪', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome back,',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity( 0.7))),
            Text(_name.isNotEmpty ? _name : 'Seller',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ])),
          if (pendingOrders > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.notifications_active, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('$pendingOrders new',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        Text(_storeName,
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity( 0.6),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF2BAC), Color(0xFFa855f7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2BAC).withOpacity( 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Revenue',
              style: TextStyle(fontSize: 13, color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Delivered only',
                style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('₱${_fmt(_stats['total_sales'])}',
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        Row(children: [
          _miniStat("Today's", _stats['today_sales']),
          _divider(),
          _miniStat('Items Sold', _stats['items_sold'], isCurrency: false),
          _divider(),
          _miniStat('Orders', _stats['total_orders'], isCurrency: false),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, dynamic value, {bool isCurrency = true}) {
    final display = isCurrency ? '₱${_fmt(value)}' : '${value ?? 0}';
    return Expanded(
      child: Column(children: [
        Text(display,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity( 0.7))),
      ]),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32,
      color: Colors.white.withOpacity( 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _buildStatsRow() {
    return Row(children: [
      _statCard('Products', '${_stats['products_listed'] ?? 0}',
          Icons.inventory_2_outlined, const Color(0xFF6366f1)),
      const SizedBox(width: AppTheme.sm),
      _statCard('Active', '${_stats['active_products'] ?? 0}',
          Icons.check_circle_outline, Colors.green),
      const SizedBox(width: AppTheme.sm),
      _statCard('Pending', '${_stats['pending_orders'] ?? 0}',
          Icons.pending_outlined, Colors.orange),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity( 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppTheme.textDark)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
        ]),
      ),
    );
  }

  Widget _buildOrderStatusCard() {
    final breakdown = _stats['status_breakdown'] as Map? ?? {};
    final statuses = [
      {'key': 'pending',          'label': 'Pending',    'color': const Color(0xFFf59e0b)},
      {'key': 'processing',       'label': 'Processing', 'color': const Color(0xFF3b82f6)},
      {'key': 'ready_for_pickup', 'label': 'Ready',      'color': const Color(0xFFf97316)},
      {'key': 'in_transit',       'label': 'Transit',    'color': const Color(0xFF8b5cf6)},
      {'key': 'delivered',        'label': 'Delivered',  'color': const Color(0xFF22c55e)},
    ];
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity( 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Order Pipeline',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppTheme.textDark)),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/seller/orders'),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('View All →',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(
          children: statuses.map((s) {
            final color = s['color'] as Color;
            final count = breakdown[s['key']] ?? 0;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity( 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: color.withOpacity( 0.2), width: 1),
                ),
                child: Column(children: [
                  Text('$count',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(s['label'] as String,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: AppTheme.textLight),
                      textAlign: TextAlign.center),
                ]),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'emoji': '📦', 'label': 'Products',    'route': '/seller/products', 'special': false},
      {'emoji': '🛒', 'label': 'Orders',      'route': '/seller/orders', 'special': false},
      {'emoji': '💰', 'label': 'Earnings',    'route': '/seller/earnings', 'special': false},
      {'emoji': '📊', 'label': 'Analytics',   'route': '/seller/analytics', 'special': true},
      {'emoji': '🚚', 'label': 'Shipping',    'route': '/seller/shipping', 'special': false},
      {'emoji': '⭐', 'label': 'Reviews',     'route': '/seller/reviews', 'special': false},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppTheme.textDark)),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SellerAddProductScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('Add Product',
                  style: TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: actions.map((a) => _actionCard(
          a['emoji']! as String,
          a['label']! as String,
          () {
            if (a['special'] == true) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerAnalyticsScreen()),
              );
            } else {
              Navigator.pushNamed(context, a['route']! as String);
            }
          },
        )).toList(),
      ),
    ]);
  }

  Widget _actionCard(String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity( 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
        ]),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity( 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Orders',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppTheme.textDark)),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/seller/orders'),
                  child: const Text('View All →',
                      style: TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ]),
        ),
        if (_recentOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Column(children: [
              Text('🛒', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text('No orders yet',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
            ]),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentOrders.length,
            separatorBuilder: (_, a) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _orderTile(_recentOrders[i]),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _orderTile(Map<String, dynamic> o) {
    final status = o['status']?.toString() ?? 'pending';
    final colors = {
      'pending': Colors.orange,
      'processing': Colors.blue,
      'ready_for_pickup': Colors.teal,
      'in_transit': Colors.purple,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };
    final color = colors[status] ?? Colors.grey;
    final id = (o['id'] ?? o['order_id'] ?? '').toString();
    final shortId = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(children: [
        Text('#$shortId',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
      subtitle: Text(
        o['customer_name']?.toString().isNotEmpty == true
            ? o['customer_name'].toString()
            : '—',
        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
      ),
      trailing: Text('₱${_fmt(o['total_amount'])}',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppTheme.primaryLight)),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.white,
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 20, 20, 24),
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity( 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                  child: Text('🏪', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 12),
            Text(_storeName,
                style: const TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(_name,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity( 0.7))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity( 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('👑 Active Seller',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            _drawerItem(Icons.home_outlined, 'Dashboard',
                '/seller-dashboard', isActive: true),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('STORE',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textLight, letterSpacing: 1.2)),
            ),
            _drawerItem(Icons.inventory_2_outlined, 'Products',
                '/seller/products'),
            _drawerItem(Icons.shopping_bag_outlined, 'Orders',
                '/seller/orders'),
            _drawerItem(Icons.local_shipping_outlined, 'Shipping',
                '/seller/shipping'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('FINANCE',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textLight, letterSpacing: 1.2)),
            ),
            _drawerItem(Icons.payments_outlined, 'Earnings',
                '/seller/earnings'),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart, color: AppTheme.textLight, size: 20),
              ),
              title: const Text('Analytics',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                      fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerAnalyticsScreen()),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('PROFILE',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textLight, letterSpacing: 1.2)),
            ),
            _drawerItem(Icons.storefront_outlined, 'Store Profile',
                '/seller/store'),
            _drawerItem(Icons.star_outline, 'Reviews', '/seller/reviews'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('COMMUNICATION',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textLight, letterSpacing: 1.2)),
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.notifications_outlined,
                          color: AppTheme.textLight, size: 20),
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              title: const Text('Notifications',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                      fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerNotificationsScreen()),
                ).then((_) => _loadStats(silent: true));
              },
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.chat_bubble_outline,
                          color: AppTheme.textLight, size: 20),
                    ),
                    if (_unreadMessages > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              title: const Text('Messages',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                      fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerMessagesScreen()),
                ).then((_) => _loadStats(silent: true));
              },
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!))),
          child: SafeArea(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600,
                      fontSize: 14)),
              subtitle: Text(_storeName,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textLight)),
              onTap: _logout,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _drawerItem(IconData icon, String label, String route,
      {bool isActive = false}) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryLight.withOpacity( 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            color: isActive ? AppTheme.primaryLight : AppTheme.textLight,
            size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppTheme.primaryLight : AppTheme.textDark,
              fontSize: 14)),
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
