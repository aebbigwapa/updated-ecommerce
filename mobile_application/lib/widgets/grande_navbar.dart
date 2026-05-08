import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GrandeNavbar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.white,
      elevation: 1,
      shadowColor: AppTheme.border,
      automaticallyImplyLeading: false,
      titleSpacing: AppTheme.md,
      title: ShaderMask(
        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
        child: const Text(
          'Grande',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.white,
          ),
        ),
      ),
      actions: const [],
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
