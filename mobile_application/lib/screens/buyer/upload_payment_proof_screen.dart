import 'package:flutter/material.dart';

class UploadPaymentProofScreen extends StatelessWidget {
  const UploadPaymentProofScreen({super.key, required this.orderId, required this.totalAmount});

  final String orderId;
  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Payment Proof')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: $orderId'),
            const SizedBox(height: 8),
            Text('Total amount: \$${totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 24),
            const Text('This feature is not available in the current build.'),
          ],
        ),
      ),
    );
  }
}
