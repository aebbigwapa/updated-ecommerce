import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _notesController = TextEditingController();
  String _paymentMethod = 'cod';
  bool _isPlacingOrder = false;

  List<Map<String, dynamic>> _addresses = [];
  String? _selectedAddressId;
  bool _loadingAddresses = true;

  double get _shipping => widget.totalAmount > 500 ? 0 : 50;
  double get _total => widget.totalAmount + _shipping;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    final addresses = await ApiService.getAddresses();
    if (mounted) {
      setState(() {
        _addresses = addresses;
        // pre-select default address
        final def = addresses.firstWhere(
          (a) => a['is_default'] == true,
          orElse: () => addresses.isNotEmpty ? addresses.first : {},
        );
        _selectedAddressId = def['id'] as String?;
        _loadingAddresses = false;
      });
    }
  }

  String _formatAddress(Map<String, dynamic> a) {
    return [a['street'], a['barangay'], a['city'], a['region'], a['zip_code']]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(', ');
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressId == null && _addresses.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a delivery address first'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Validate stock before placing order
    for (final item in widget.cartItems) {
      final quantity = (item['quantity'] as num? ?? 1).toInt();
      final maxStock = (item['available_stock'] as num? ?? 9999).toInt();
      final productName = item['product_name'] as String? ?? 'Product';
      
      if (quantity > maxStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName: Only $maxStock available. Please update your cart.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() => _isPlacingOrder = true);
    try {
      // Build address string from selected address
      final selectedAddr = _addresses.firstWhere(
        (a) => a['id'] == _selectedAddressId,
        orElse: () => _addresses.first,
      );
      final addressStr = _formatAddress(selectedAddr);

      final result = await ApiService.createOrder(
        address: addressStr,
        addressId: _selectedAddressId,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final orderId = (result['order'] as Map?)?['id']?.toString()
            ?? (result['order'] as Map?)?['order_id']?.toString()
            ?? '';
        if (mounted) {
          // If GCash payment, redirect to upload proof page
          if (_paymentMethod == 'gcash') {
            Navigator.pushNamedAndRemoveUntil(
              context, '/upload-payment-proof',
              (route) => route.settings.name == '/home',
              arguments: {
                'orderId': orderId,
                'totalAmount': _total,
              },
            );
          } else {
            // For other payment methods, go to order summary
            Navigator.pushNamedAndRemoveUntil(
              context, '/order-summary',
              (route) => route.settings.name == '/home',
              arguments: orderId,
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to place order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1a1a3e)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1a1a3e), fontSize: 18, fontWeight: FontWeight.w700,
        ),
      ),
      body: Column(children: [
        // Step indicator (matches web)
        _buildStepIndicator(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left column content
              _buildAddressSection(),
              const SizedBox(height: 16),
              _buildPaymentSection(),
              const SizedBox(height: 16),
              _buildNotesSection(),
              const SizedBox(height: 16),
              // Right column content (summary)
              _buildSummaryBox(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _step('✓', 'Cart', done: true),
        _stepLine(),
        _step('2', 'Checkout', active: true),
        _stepLine(),
        _step('3', 'Confirmation'),
      ]),
    );
  }

  Widget _step(String label, String text, {bool done = false, bool active = false}) {
    final color = done || active ? AppTheme.primaryLight : Colors.grey.shade300;
    final textColor = done || active ? AppTheme.primaryLight : Colors.grey;
    return Column(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppTheme.primaryLight : Colors.transparent,
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: done ? Colors.white : color)),
        ),
      ),
      const SizedBox(height: 4),
      Text(text, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _stepLine() {
    return Container(width: 48, height: 2, margin: const EdgeInsets.only(bottom: 20),
        color: Colors.grey.shade200);
  }

  Widget _buildAddressSection() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📍 Delivery Address',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
        const SizedBox(height: 12),
        if (_loadingAddresses)
          const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight, strokeWidth: 2))
        else if (_addresses.isEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('No saved addresses.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6c757d))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/addresses').then((_) => _loadAddresses()),
              child: const Text('+ Add New Address',
                  style: TextStyle(fontSize: 13, color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
            ),
          ])
        else
          Column(children: [
            ..._addresses.map((a) => _buildAddressCard(a)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/addresses').then((_) => _loadAddresses()),
              child: const Text('+ Add New Address',
                  style: TextStyle(fontSize: 13, color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
            ),
          ]),
      ]),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> a) {
    final isSelected = a['id'] == _selectedAddressId;
    return GestureDetector(
      onTap: () => setState(() => _selectedAddressId = a['id'] as String?),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : const Color(0xFFe8e8f0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(a['label']?.toString() ?? 'Home',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a1a3e))),
                if (a['is_default'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Default',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(_formatAddress(a),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6c757d))),
            ]),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppTheme.primaryLight, size: 20),
        ]),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💳 Payment Method',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
        const SizedBox(height: 12),
        _buildPaymentOption('cod', '💵 Cash on Delivery', 'Pay when your order arrives'),
        _buildPaymentOption('gcash', '📱 GCash', 'Pay via GCash e-wallet'),
        _buildPaymentOption('card', '💳 Credit / Debit Card', 'Visa, Mastercard, etc.'),
      ]),
    );
  }

  Widget _buildPaymentOption(String value, String label, String subtitle) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLight : const Color(0xFFe8e8f0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primaryLight : const Color(0xFFe8e8f0),
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1a1a3e))),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6c757d))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildNotesSection() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: const TextSpan(children: [
          TextSpan(text: '📝 Order Notes ',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
          TextSpan(text: '(optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF6c757d))),
        ])),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Special instructions for your order...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6c757d)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFe8e8f0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFe8e8f0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryLight),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe8e8f0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1a1a3e))),
        const SizedBox(height: 12),
        // Items
        ...widget.cartItems.map((item) => _buildSummaryItem(item)),
        const Divider(color: Color(0xFFe8e8f0), height: 24),
        // Subtotal
        _summaryRow('Subtotal', '₱${widget.totalAmount.toStringAsFixed(2)}'),
        const SizedBox(height: 6),
        _summaryRow(
          'Shipping',
          _shipping == 0 ? 'FREE' : '₱${_shipping.toStringAsFixed(2)}',
          valueColor: _shipping == 0 ? const Color(0xFF10b981) : null,
        ),
        const Divider(color: Color(0xFFe8e8f0), height: 24),
        _summaryRow('Total', '₱${_total.toStringAsFixed(2)}', bold: true, valueColor: AppTheme.primaryLight),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPlacingOrder ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isPlacingOrder
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Place Order →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        const Text('By placing your order, you agree to our Terms of Service.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF6c757d))),
      ]),
    );
  }

  Widget _buildSummaryItem(Map<String, dynamic> item) {
    final name = item['product_name'] as String? ?? 'Product';
    final quantity = (item['quantity'] as num? ?? 1).toInt();
    final subtotal = (item['subtotal'] as num? ?? 0).toDouble();
    final imageUrl = item['image'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFFF8F9FA),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 18, color: Color(0xFF6c757d)))
                : const Icon(Icons.image_outlined, size: 18, color: Color(0xFF6c757d)),
          ),
        ),
        Expanded(
          child: Text('$name × $quantity',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1a1a3e)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text('₱${subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1a1a3e))),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xFF1a1a3e))),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: valueColor ?? const Color(0xFF1a1a3e))),
    ]);
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe8e8f0)),
      ),
      child: child,
    );
  }
}
