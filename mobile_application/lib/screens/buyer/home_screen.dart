import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/grande_navbar.dart';
import '../../widgets/hero_carousel.dart';
import '../../widgets/category_grid.dart';
import '../../widgets/product_grid.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> featuredProducts = [];
  List<Product> newArrivals = [];
  bool isLoadingFeatured = true;
  bool isLoadingNewArrivals = true;
  String? userName;
  StreamSubscription<void>? _productsSub;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProducts();
    RealtimeService.instance.subscribeProducts();
    _productsSub = RealtimeService.instance.productsStream.listen((_) {
      if (mounted) _loadProducts();
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    RealtimeService.instance.unsubscribeProducts();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Load user data from API or local storage
    final user = await ApiService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        userName = user['first_name'] ?? 'User';
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      // Load featured products
      final featuredResponse = await ApiService.getProducts(limit: 8);
      if (mounted) {
        setState(() {
          featuredProducts = featuredResponse.map((p) => Product.fromJson(p)).toList();
          isLoadingFeatured = false;
        });
      }

      // Load new arrivals
      final newArrivalsResponse = await ApiService.getProducts(
        limit: 8,
        sortBy: 'created_at',
        sortOrder: 'desc',
      );
      if (mounted) {
        setState(() {
          newArrivals = newArrivalsResponse.map((p) => Product.fromJson(p)).toList();
          isLoadingNewArrivals = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingFeatured = false;
          isLoadingNewArrivals = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GrandeNavbar(
        active: 'home',
        userName: userName,
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const HeroCarousel(),
            const CategoryGrid(),
            ProductGrid(
              title: 'Featured Products',
              products: featuredProducts,
              viewAllRoute: '/shop',
              isLoading: isLoadingFeatured,
            ),
            ProductGrid(
              title: 'New Arrivals',
              products: newArrivals,
              viewAllRoute: '/shop?filter=new',
              isLoading: isLoadingNewArrivals,
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: AppTheme.textDark,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.lg, AppTheme.xl, AppTheme.lg, AppTheme.lg,
      ),
      child: Column(
        children: [
          _buildFooterContent(),
          const SizedBox(height: AppTheme.lg),
          _buildFooterBottom(),
        ],
      ),
    );
  }

  Widget _buildFooterContent() {
    return Wrap(
      spacing: AppTheme.lg,
      runSpacing: AppTheme.lg,
      children: [
        _buildFooterColumn(
          title: 'Grande',
          items: const ['Our Story', 'Careers', 'Blog'],
          onTap: (_) {},
        ),
        _buildFooterColumn(
          title: 'Shop',
          items: const ['All Products', 'Dresses & Skirts', 'Shoes & Accessories'],
          onTap: (item) {
            if (item == 'All Products') {
              Navigator.pushNamed(context, '/shop');
            } else {
              Navigator.pushNamed(context, '/shop', arguments: item);
            }
          },
        ),
        _buildFooterColumn(
          title: 'Customer Care',
          items: const ['Contact Us', 'FAQ', 'Shipping Info', 'Returns'],
          onTap: (_) {},
        ),
        _buildFooterColumn(
          title: 'Account',
          items: userName != null
              ? const ['My Profile', 'My Orders', 'Cart', 'Logout']
              : const ['Login', 'Register'],
          onTap: (item) {
            switch (item) {
              case 'My Profile':
                Navigator.pushNamed(context, '/profile');
                break;
              case 'My Orders':
                Navigator.pushNamed(context, '/orders');
                break;
              case 'Cart':
                Navigator.pushNamed(context, '/cart');
                break;
              case 'Logout':
                _showLogoutDialog();
                break;
              case 'Login':
                Navigator.pushNamed(context, '/login');
                break;
              case 'Register':
                Navigator.pushNamed(context, '/register');
                break;
            }
          },
        ),
      ],
    );
  }

  Widget _buildFooterColumn({
    required String title,
    required List<String> items,
    required Function(String) onTap,
  }) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontBody,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () => onTap(item),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontBody,
                      fontSize: 12,
                      color: AppTheme.white,
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialIcon('Instagram'),
        const SizedBox(width: AppTheme.md),
        _buildSocialIcon('Facebook'),
        const SizedBox(width: AppTheme.md),
        _buildSocialIcon('TikTok'),
      ],
    );
  }

  Widget _buildSocialIcon(String platform) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(_getSocialIcon(platform), color: AppTheme.white, size: 18),
    );
  }

  IconData _getSocialIcon(String platform) {
    switch (platform) {
      case 'Instagram':
        return Icons.camera_alt;
      case 'Facebook':
        return Icons.facebook;
      case 'TikTok':
        return Icons.music_note;
      default:
        return Icons.public;
    }
  }

  Widget _buildFooterBottom() {
    return Column(
      children: [
        _buildSocialLinks(),
        const SizedBox(height: AppTheme.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppTheme.sm,
          runSpacing: AppTheme.sm,
          children: [
            const Text(
              'We accept:',
              style: TextStyle(fontSize: 11, color: AppTheme.white),
            ),
            _buildPaymentMethod('Visa'),
            _buildPaymentMethod('MC'),
            _buildPaymentMethod('GCash'),
            _buildPaymentMethod('COD'),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        const Text(
          '© 2026 Grande Marketplace. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppTheme.white),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod(String method) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        method,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ApiService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
