import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _expandedIndex;

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I reset my password?',
      'a':
          'Go to the Login screen and tap "Forgot Password?". Enter your registered email address and we will send you a password reset link. Follow the instructions in the email to set a new password.',
    },
    {
      'q': 'I cannot log in to my account. What should I do?',
      'a':
          'Ensure you are using the correct email and password. If you have forgotten your password, use the "Forgot Password?" option. If your account is pending approval or has been suspended, please contact our support team.',
    },
    {
      'q': 'How do I track my order?',
      'a':
          'Go to My Orders from your profile or the navigation menu. Select the order you wish to track to view its current status and delivery updates.',
    },
    {
      'q': 'Can I cancel my order?',
      'a':
          'Orders may be cancelled before they are processed or dispatched. Go to My Orders, select the order, and tap "Cancel Order" if the option is available. Once an order has been shipped, cancellation may no longer be possible.',
    },
    {
      'q': 'What should I do if I received the wrong or missing item?',
      'a':
          'Please contact our support team within 48 hours of receiving your order. Provide your order number, a description of the issue, and photos if applicable. We will coordinate with the seller to resolve the matter promptly.',
    },
    {
      'q': 'My payment was deducted but the order was not confirmed. What do I do?',
      'a':
          'Please wait a few minutes as payment confirmation may be delayed. If the issue persists after 30 minutes, contact our support team with your payment reference number and we will investigate immediately.',
    },
    {
      'q': 'How do I upload proof of payment?',
      'a':
          'After placing an order, go to My Orders and select the relevant order. Tap "Upload Payment Proof" and attach a clear photo or screenshot of your payment receipt.',
    },
    {
      'q': 'How do I apply to become a seller on Grande?',
      'a':
          'During registration, select "Seller" as your role. You will be required to provide your store details and upload the necessary verification documents (Valid ID, Business Permit, DTI/SEC Registration). Your application will be reviewed by our admin team.',
    },
    {
      'q': 'How long does seller verification take?',
      'a':
          'Seller applications are typically reviewed within 1–3 business days. You will receive a notification once your account has been approved or if additional information is required.',
    },
    {
      'q': 'How do I report a seller or a suspicious listing?',
      'a':
          'You may report a seller or product listing by contacting our support team via email at support@grandemarket.com. Provide the seller\'s name, product details, and a description of your concern. All reports are treated confidentially.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support',
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
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.lg),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How can we help you?',
                      style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.white)),
                  SizedBox(height: AppTheme.sm),
                  Text(
                    'Our support team is here to assist you. Browse the topics below or reach out to us directly.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.white,
                        height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.lg),

            // Support topics
            _buildTopicsGrid(),

            const SizedBox(height: AppTheme.lg),

            // FAQ
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: AppTheme.sm),
            ..._faqs.asMap().entries.map((entry) {
              final i = entry.key;
              final faq = entry.value;
              return _buildFaqItem(i, faq['q']!, faq['a']!);
            }),

            const SizedBox(height: AppTheme.lg),

            // Contact
            _buildSectionTitle('Contact Us'),
            const SizedBox(height: AppTheme.sm),
            _buildContactCard(),

            const SizedBox(height: AppTheme.lg),

            // Response time notice
            Container(
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                    color: AppTheme.primaryLight.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time, color: AppTheme.primaryLight, size: 20),
                  SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: Text(
                      'Our support team typically responds within 24–48 hours on business days. We are committed to resolving your concerns as quickly as possible.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

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

  Widget _buildTopicsGrid() {
    final topics = [
      {'icon': Icons.lock_outline, 'label': 'Account & Login'},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Orders & Tracking'},
      {'icon': Icons.payment_outlined, 'label': 'Payments'},
      {'icon': Icons.store_outlined, 'label': 'Seller Support'},
      {'icon': Icons.local_shipping_outlined, 'label': 'Delivery Issues'},
      {'icon': Icons.report_outlined, 'label': 'Report a Problem'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppTheme.sm,
        mainAxisSpacing: AppTheme.sm,
        childAspectRatio: 1.0,
      ),
      itemCount: topics.length,
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(topics[i]['icon'] as IconData,
                  color: AppTheme.primaryLight, size: 28),
              const SizedBox(height: AppTheme.xs),
              Text(
                topics[i]['label'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark));
  }

  Widget _buildFaqItem(int index, String question, String answer) {
    final isExpanded = _expandedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow,
        ),
        child: InkWell(
          onTap: () => setState(
              () => _expandedIndex = isExpanded ? null : index),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(question,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark)),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.primaryLight,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: AppTheme.sm),
                  const Divider(),
                  const SizedBox(height: AppTheme.sm),
                  Text(answer,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark,
                          height: 1.6)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildContactRow(
            icon: Icons.email_outlined,
            label: 'Email Support',
            value: 'support@grandemarket.com',
            onTap: () => launchUrl(
                Uri.parse('mailto:support@grandemarket.com')),
          ),
          const Divider(height: AppTheme.xl),
          _buildContactRow(
            icon: Icons.chat_bubble_outline,
            label: 'Live Chat',
            value: 'Available in-app via Messages',
            onTap: null,
          ),
          const Divider(height: AppTheme.xl),
          _buildContactRow(
            icon: Icons.schedule_outlined,
            label: 'Support Hours',
            value: 'Monday – Saturday, 8:00 AM – 6:00 PM',
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: AppTheme.primaryLight, size: 20),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onTap != null
                            ? AppTheme.primaryLight
                            : AppTheme.textDark)),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right,
                color: AppTheme.textLight, size: 18),
        ],
      ),
    );
  }
}
