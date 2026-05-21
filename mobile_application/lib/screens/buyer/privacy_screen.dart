import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy',
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
            _buildSection('1. Information We Collect',
                'When you register or use Grande, we collect the following types of information:\n\nPersonal Information:\n• Full name (first, middle, last)\n• Email address\n• Contact number\n• Home or delivery address\n• Gender and date of birth (where applicable)\n\nAccount & Transaction Data:\n• Login credentials (stored in encrypted form)\n• Order history and transaction records\n• Payment references and proof of payment\n• Product reviews and ratings\n\nTechnical Data:\n• Device information and IP address\n• Browser type and operating system\n• App usage data and session logs\n• Location data (when permission is granted)'),
            _buildSection('2. How We Use Your Information',
                'Grande uses the information collected for the following purposes:\n\n• Account Management — To create, verify, and manage your account.\n• Order Processing — To facilitate purchases, deliveries, and returns.\n• Communication — To send order confirmations, updates, and support responses.\n• Platform Improvement — To analyze usage patterns and enhance user experience.\n• Security & Fraud Prevention — To detect and prevent unauthorized access or fraudulent activity.\n• Marketing & Notifications — To send relevant promotions and platform updates (you may opt out at any time).\n• Legal Compliance — To comply with applicable laws and regulations.'),
            _buildSection('3. Data Protection & Security',
                'Grande takes the protection of your personal data seriously. We implement the following security measures:\n\n• All passwords are encrypted using industry-standard hashing algorithms.\n• Sensitive data is transmitted over HTTPS/SSL encrypted connections.\n• Access to user data is restricted to authorized personnel only.\n• Regular security audits and vulnerability assessments are conducted.\n• Payment information is handled through verified and PCI-compliant payment processors.\n\nWhile we take every reasonable precaution, no system is completely immune to security risks. We encourage users to use strong passwords and to report any suspicious activity immediately.'),
            _buildSection('4. Sharing of Information',
                'Grande does not sell, rent, or trade your personal information to third parties for marketing purposes.\n\nWe may share your information only in the following circumstances:\n\n• Delivery Partners — Sharing your name and address with riders or logistics providers to fulfill your orders.\n• Payment Processors — Sharing transaction data with payment service providers to process payments securely.\n• Legal Authorities — Disclosing information when required by law, court order, or government regulation.\n• Platform Operations — Sharing with trusted service providers who assist in operating the platform, under strict confidentiality agreements.\n\nAll third parties with whom we share data are required to handle it in accordance with applicable data protection laws.'),
            _buildSection('5. Cookies & Tracking',
                'Grande uses cookies and similar tracking technologies to enhance your experience on our platform.\n\nTypes of cookies we use:\n• Essential Cookies — Required for the platform to function properly (e.g., session management, authentication).\n• Analytical Cookies — Used to understand how users interact with the platform to improve performance.\n• Preference Cookies — Used to remember your settings and preferences.\n\nYou may disable cookies through your browser or device settings; however, doing so may affect the functionality of certain features. By continuing to use Grande, you consent to our use of cookies as described in this policy.'),
            _buildSection('6. Your Rights',
                'As a user of Grande, you have the following rights regarding your personal data:\n\n• Right to Access — You may request a copy of the personal data we hold about you.\n• Right to Correction — You may update or correct inaccurate information through your account settings.\n• Right to Deletion — You may request the deletion of your account and associated data, subject to legal and operational requirements.\n• Right to Withdraw Consent — You may opt out of marketing communications at any time.\n• Right to Data Portability — You may request your data in a structured, machine-readable format.\n\nTo exercise any of these rights, please contact our support team at support@grandemarket.com.'),
            _buildSection('7. Data Retention',
                'Grande retains your personal data for as long as your account is active or as necessary to provide services, comply with legal obligations, resolve disputes, and enforce agreements.\n\nUpon account deletion, your personal data will be removed from our active systems within 30 days, except where retention is required by law.'),
            _buildSection('8. Policy Updates',
                'Grande may update this Privacy Policy from time to time to reflect changes in our practices or applicable laws. Users will be notified of material changes through the platform or via email.\n\nWe encourage you to review this policy periodically. Your continued use of Grande after any updates constitutes your acceptance of the revised Privacy Policy.\n\nLast Updated: ${DateTime.now().year}'),
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
          const Text('Privacy Policy',
              style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.white)),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Effective Date: January 1, ${DateTime.now().year}\nYour privacy matters to us. This policy explains how we collect, use, and protect your data.',
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
