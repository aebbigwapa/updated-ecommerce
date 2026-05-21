import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions',
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
            _buildHeader(),
            const SizedBox(height: AppTheme.lg),
            _buildSection('1. Acceptance of Terms',
                'By accessing or using the Grande Marketplace platform — whether through our website or mobile application — you agree to be bound by these Terms and Conditions. If you do not agree to any part of these terms, you must discontinue use of the platform immediately.\n\nGrande reserves the right to update or modify these Terms at any time. Continued use of the platform after any changes constitutes your acceptance of the revised Terms.'),
            _buildSection('2. Use of the Platform',
                'Acceptable Use:\n• You may use Grande solely for lawful purposes related to buying, selling, or delivering goods.\n• You agree to provide accurate, complete, and current information during registration and transactions.\n• You are responsible for maintaining the confidentiality of your account credentials.\n\nProhibited Use:\n• Listing counterfeit, illegal, or prohibited goods.\n• Engaging in fraudulent transactions or misrepresenting products.\n• Harassing, threatening, or abusing other users.\n• Attempting to gain unauthorized access to any part of the platform.\n• Using automated tools, bots, or scrapers without prior written consent from Grande.'),
            _buildSection('3. User Accounts',
                'You must be at least 18 years of age to create an account on Grande. By registering, you represent that all information provided is accurate and truthful.\n\nYou are solely responsible for all activities that occur under your account. Grande will not be liable for any loss or damage arising from unauthorized use of your account. You must notify Grande immediately if you suspect any unauthorized access or security breach.\n\nGrande reserves the right to suspend or terminate accounts that violate these Terms or engage in suspicious activity.'),
            _buildSection('4. Product Listings & Information',
                'Sellers are solely responsible for the accuracy, completeness, and legality of their product listings, including descriptions, images, pricing, and availability.\n\nGrande does not warrant the accuracy of any product information provided by sellers. Buyers are encouraged to review product details carefully before placing an order. Grande reserves the right to remove any listing that violates platform policies or applicable laws without prior notice.'),
            _buildSection('5. Orders, Cancellations & Refunds',
                'Orders:\nOnce an order is placed and confirmed, it is considered a binding agreement between the buyer and seller. Buyers are expected to complete payment within the specified timeframe.\n\nCancellations:\nCancellations may be requested before the order is processed or shipped. Once an order has been dispatched, cancellations may no longer be accepted. Sellers reserve the right to cancel orders due to stock unavailability or other valid reasons.\n\nRefunds:\nRefund eligibility is subject to the seller\'s stated return and refund policy. Grande may facilitate dispute resolution between buyers and sellers but does not guarantee refunds in all cases. Refunds, where applicable, will be processed within 7–14 business days.'),
            _buildSection('6. Payment Terms & Security',
                'Grande supports secure payment methods as made available on the platform. All payment transactions are processed through verified and encrypted channels.\n\nBuyers agree to pay the full amount indicated at checkout, including applicable shipping fees. Grande is not responsible for payment failures caused by third-party payment processors, bank issues, or insufficient funds.\n\nSellers acknowledge that payouts are subject to Grande\'s disbursement schedule and verification processes.'),
            _buildSection('7. Account Suspension & Termination',
                'Grande reserves the right to suspend or permanently terminate any account, at its sole discretion, for reasons including but not limited to:\n\n• Violation of these Terms and Conditions.\n• Fraudulent, deceptive, or illegal activity.\n• Repeated negative feedback or unresolved disputes.\n• Inactivity for an extended period.\n\nUpon termination, your access to the platform will be revoked. Any pending transactions will be handled in accordance with Grande\'s policies at the time of termination.'),
            _buildSection('8. Limitation of Liability',
                'Grande provides the platform on an "as is" and "as available" basis. To the fullest extent permitted by law, Grande shall not be liable for:\n\n• Any indirect, incidental, or consequential damages arising from your use of the platform.\n• Loss of data, revenue, or profits.\n• Damages resulting from unauthorized access to your account.\n• Issues arising from third-party services, including payment processors and delivery partners.\n\nGrande\'s total liability, in any case, shall not exceed the amount paid by the user for the specific transaction giving rise to the claim.'),
            _buildSection('9. Changes to These Terms',
                'Grande may revise these Terms and Conditions at any time. Users will be notified of significant changes through the platform or via email. It is your responsibility to review these Terms periodically. Your continued use of Grande following any updates constitutes your acceptance of the revised Terms.\n\nLast Updated: ${DateTime.now().year}'),
            const SizedBox(height: AppTheme.xl),
            Center(
              child: Text(
                '© ${DateTime.now().year} Grande Marketplace. All rights reserved.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Terms & Conditions',
              style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.white)),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Effective Date: January 1, ${DateTime.now().year}\nPlease read these terms carefully before using Grande.',
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.white,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.md),
      child: Container(
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryLight)),
            const SizedBox(height: AppTheme.sm),
            const Divider(),
            const SizedBox(height: AppTheme.sm),
            Text(content,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textDark,
                    height: 1.7)),
          ],
        ),
      ),
    );
  }
}
