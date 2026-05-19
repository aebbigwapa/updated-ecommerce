import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/buyer/home_screen.dart';
import 'screens/buyer/shop_screen.dart';
import 'screens/buyer/product_detail_screen.dart';
import 'screens/buyer/cart_screen.dart';
import 'screens/buyer/checkout_screen.dart';
import 'screens/buyer/orders_screen.dart';
import 'screens/buyer/profile_screen.dart';
 import 'screens/seller/seller_dashboard_screen.dart';
 import 'screens/seller/seller_products_screen.dart';
 import 'screens/seller/seller_add_product_screen.dart';
 import 'screens/seller/seller_edit_product_screen.dart';
 import 'screens/seller/seller_orders_screen.dart';
 import 'screens/seller/seller_earnings_screen.dart';
 import 'screens/seller/seller_store_profile_screen.dart';
 import 'screens/seller/seller_shipping_screen.dart';
 import 'screens/seller/seller_reviews_screen.dart';
import 'screens/buyer/messages_screen.dart';
import 'screens/buyer/notifications_screen.dart';
import 'screens/buyer/wishlist_screen.dart';
import 'screens/buyer/addresses_screen.dart';
import 'screens/buyer/settings_screen.dart';
import 'screens/buyer/order_summary_screen.dart';
import 'screens/rider/rider_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const GrandeMarketplaceApp());
}

class GrandeMarketplaceApp extends StatelessWidget {
  const GrandeMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grande Marketplace',
      theme: AppTheme.theme,
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/shop': (context) {
          final category = ModalRoute.of(context)?.settings.arguments as String?;
          return ShopScreen(initialCategory: category);
        },
        '/product': (context) {
          final productId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return ProductDetailScreen(productId: productId);
        },
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CheckoutScreen(
            cartItems: args?['cartItems'] ?? [],
            totalAmount: args?['totalAmount'] ?? 0.0,
          );
        },
        '/orders': (context) => const OrdersScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/messages': (context) => const MessagesScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/wishlist': (context) => const WishlistScreen(),
        '/addresses': (context) => const AddressesScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/settings/password': (context) => const SettingsScreen(initialSection: 'password'),
        '/order-summary': (context) {
          final orderId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return OrderSummaryScreen(orderId: orderId);
        },
        '/seller-dashboard': (context) => const SellerDashboardScreen(),
       '/seller/products': (context) => const SellerProductsScreen(),
       '/seller/products/add': (context) => const SellerAddProductScreen(),
       '/seller/orders': (context) => const SellerOrdersScreen(),
       '/seller/earnings': (context) => const SellerEarningsScreen(),
       '/seller/store': (context) => const SellerStoreProfileScreen(),
       '/seller/shipping': (context) => const SellerShippingScreen(),
       '/seller/reviews': (context) => const SellerReviewsScreen(),
        '/rider-dashboard': (context) => const RiderDashboardScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('Page not found'),
            ),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Warm up SharedPreferences — no network call needed at startup
      await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Grande',
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                const CircularProgressIndicator(
                  color: AppTheme.white,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Always go to HomeScreen — guests can browse, logged-in users see their data
    // This matches the web app index.html behavior
    return const HomeScreen();
  }
}
