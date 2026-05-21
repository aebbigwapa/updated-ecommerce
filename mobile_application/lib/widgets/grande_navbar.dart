import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/wishlist_service.dart';

class GrandeNavbar extends StatefulWidget implements PreferredSizeWidget {
  final String active;
  final String? userName;

  const GrandeNavbar({
    super.key,
    required this.active,
    this.userName,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  State<GrandeNavbar> createState() => _GrandeNavbarState();
}

class _GrandeNavbarState extends State<GrandeNavbar> {
  int _cartCount  = 0;
  int _notifCount = 0;
  int _msgCount   = 0;
  int _wishCount  = 0;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<void>? _notifSub;
  VoidCallback? _cartCountListener;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Poll cart + wishlist every 30s
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _cartCountListener = () {
      if (!mounted) return;
      setState(() => _cartCount = ApiService.cartCount.value);
    };
    ApiService.cartCount.addListener(_cartCountListener!);
    // Realtime: message badge updates instantly on new message
    _msgSub = RealtimeService.instance.messagesStream.listen((_) async {
      final token = await ApiService.getAuthToken();
      if (token != null && mounted) {
        final count = await ApiService.getUnreadMessageCount(token);
        if (mounted) setState(() => _msgCount = count);
      }
    });
    // Realtime: notification badge updates instantly on new notification
    _notifSub = RealtimeService.instance.notificationsStream.listen((_) async {
      final token = await ApiService.getAuthToken();
      if (token != null && mounted) {
        final res = await ApiService.getBuyerNotifications(token);
        if (mounted) setState(() => _notifCount = res['unread_count'] as int? ?? 0);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgSub?.cancel();
    _notifSub?.cancel();
    if (_cartCountListener != null) {
      ApiService.cartCount.removeListener(_cartCountListener!);
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = await ApiService.getAuthToken();
    if (token == null || !mounted) return;
    await Future.wait([_loadCart(token), _loadNotifs(token), _loadMessages(token), _loadWishlist()]);
  }

  Future<void> _loadCart(String token) async {
    try {
      final items = await ApiService.getCart();
      final total = items.fold<int>(0, (sum, i) => sum + ((i['quantity'] as num?)?.toInt() ?? 1));
      if (mounted) setState(() => _cartCount = total);
    } catch (_) {}
  }

  Future<void> _loadWishlist() async {
    try {
      final list = await WishlistService.getAll();
      if (mounted) setState(() => _wishCount = list.length);
    } catch (_) {}
  }

  Future<void> _loadMessages(String token) async {
    try {
      final count = await ApiService.getUnreadMessageCount(token);
      if (mounted) setState(() => _msgCount = count);
    } catch (_) {}
  }

  Future<void> _loadNotifs(String token) async {
    try {
      final res = await ApiService.getBuyerNotifications(token);
      if (mounted) setState(() => _notifCount = res['unread_count'] as int? ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.white,
      elevation: 1,
      shadowColor: AppTheme.border,
      automaticallyImplyLeading: false,
      titleSpacing: AppTheme.md,
      title: Image.asset(
        'assets/logo.png',
        height: 40,
        fit: BoxFit.contain,
      ),
      actions: [
        // Notifications
        _NavIconBtn(
          icon: Icons.notifications_outlined,
          badge: _notifCount,
          tooltip: 'Notifications',
          onTap: () => Navigator.pushNamed(context, '/notifications').then((_) => _refresh()),
        ),
        // Messages
        _NavIconBtn(
          icon: Icons.chat_bubble_outline,
          badge: _msgCount,
          tooltip: 'Messages',
          onTap: () => Navigator.pushNamed(context, '/messages').then((_) => _refresh()),
        ),
        // Wishlist — matches web navbar order: Notifications → Messages → Wishlist → Cart
        _NavIconBtn(
          icon: Icons.favorite_border,
          badge: _wishCount,
          tooltip: 'Wishlist',
          color: _wishCount > 0 ? AppTheme.primaryLight : null,
          onTap: () => Navigator.pushNamed(context, '/wishlist').then((_) => _refresh()),
        ),
        // Cart
        _NavIconBtn(
          icon: Icons.shopping_cart_outlined,
          badge: _cartCount,
          tooltip: 'Cart',
          onTap: () => Navigator.pushNamed(context, '/cart').then((_) => _refresh()),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

}

class _NavIconBtn extends StatelessWidget {
  final IconData icon;
  final int badge;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _NavIconBtn({
    required this.icon,
    required this.badge,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Stack(clipBehavior: Clip.none, children: [
            Icon(icon, size: 24, color: color ?? AppTheme.textDark),
            if (badge > 0)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Shopee-style Bottom Navigation Bar ──────────────────────────────────────

class GrandeBottomNav extends StatelessWidget {
  final int currentIndex;

  const GrandeBottomNav({super.key, required this.currentIndex});

  static const List<String> _routes = ['/home', '/shop', '/orders', '/profile'];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          _routes[index],
          (route) => false,
        );
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.white,
      selectedItemColor: AppTheme.primaryLight,
      unselectedItemColor: AppTheme.textLight,
      selectedLabelStyle: const TextStyle(
        fontFamily: AppTheme.fontBody,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: AppTheme.fontBody,
        fontSize: 11,
      ),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront),
          label: 'Shop',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
