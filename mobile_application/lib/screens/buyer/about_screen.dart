import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Grande',
            style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        backgroundColor: AppTheme.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
      ),
      backgroundColor: AppTheme.grayLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.xl, horizontal: AppTheme.lg),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Column(
                children: [
                  const Text('Grande',
                      style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.white)),
                  const SizedBox(height: 4),
                  const Text('MARKETPLACE',
                      style: TextStyle(
                          fontFamily: AppTheme.fontBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.white,
                          letterSpacing: 3.0)),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md, vertical: AppTheme.sm),
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Text(
                      'Connecting Buyers & Sellers Across the Philippines',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.white,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.lg),

            _buildCard(
              title: 'Who We Are',
              content:
                  'Grande is a trusted online marketplace that connects buyers and sellers in a secure, convenient, and user-friendly environment. We are dedicated to empowering local entrepreneurs and providing shoppers with a seamless digital commerce experience.\n\nFounded with the vision of making online trade accessible to everyone, Grande offers a platform where individuals and businesses can buy, sell, and grow — all in one place.',
            ),

            const SizedBox(height: AppTheme.md),

            _buildCard(
              title: '🎯 Our Mission',
              content:
                  'To provide a reliable, secure, and inclusive online marketplace that empowers sellers to grow their businesses and enables buyers to shop with confidence — delivering convenience, trust, and value at every transaction.',
            ),

            const SizedBox(height: AppTheme.md),

            _buildCard(
              title: '🌟 Our Vision',
              content:
                  'To become the leading online marketplace in the Philippines — a platform where every seller has the opportunity to thrive and every buyer enjoys a safe, seamless, and satisfying shopping experience.',
            ),

            const SizedBox(height: AppTheme.md),

            // Core values
            _buildCard(
              title: 'What We Stand For',
              child: Column(
                children: [
                  _buildValueRow('🔒', 'Security',
                      'Every transaction is protected with industry-standard security measures.'),
                  const Divider(height: AppTheme.lg),
                  _buildValueRow('🤝', 'Trust',
                      'We verify sellers and maintain strict quality standards to protect our community.'),
                  const Divider(height: AppTheme.lg),
                  _buildValueRow('⚡', 'Convenience',
                      'Shop or sell anytime, anywhere — on web or mobile.'),
                  const Divider(height: AppTheme.lg),
                  _buildValueRow('🌱', 'Growth',
                      'We support local sellers with tools to manage products, orders, and earnings.'),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.md),

            _buildCard(
              title: 'Our Platform',
              content:
                  'Grande serves three types of users:\n\n• Buyers — Browse thousands of products, add to cart, and checkout securely.\n\n• Sellers — Open your store, list products, manage orders, and track earnings.\n\n• Riders — Deliver orders efficiently and earn through our delivery network.\n\nAll users are verified before gaining full access to ensure a safe and trustworthy marketplace for everyone.',
            ),

            const SizedBox(height: AppTheme.xl),

            Center(
              child: Text(
                '© ${DateTime.now().year} Grande Marketplace. All rights reserved.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textLight),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, String? content, Widget? child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: AppTheme.md),
          if (content != null)
            Text(content,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textDark,
                    height: 1.7)),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildValueRow(String emoji, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark)),
              const SizedBox(height: 4),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textLight, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
