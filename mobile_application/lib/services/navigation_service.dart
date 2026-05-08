import 'package:flutter/material.dart';

class NavigationService {
  static void navigateToProduct(BuildContext context, String productId) {
    Navigator.pushNamed(
      context,
      '/product',
      arguments: productId,
    );
  }

  static void navigateToCheckout(BuildContext context, List<Map<String, dynamic>> cartItems, double totalAmount) {
    Navigator.pushNamed(
      context,
      '/checkout',
      arguments: {
        'cartItems': cartItems,
        'totalAmount': totalAmount,
      },
    );
  }

  static void navigateToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  static void navigateToOrders(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/orders',
    );
  }

  static void navigateToProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/profile',
    );
  }

  static void navigateToShop(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/shop',
    );
  }

  static void navigateToCart(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/cart',
    );
  }

  static void navigateToRegister(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/register',
    );
  }
}
