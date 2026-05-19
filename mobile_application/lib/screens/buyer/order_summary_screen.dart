import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class OrderSummaryScreen extends StatefulWidget {
  final String orderId;
  const OrderSummaryScreen({super.key, required this.orderId});
  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  static const _steps = ['pending', 'processing', 'ready_for_pickup', 'in_transit', 'delivered'];
  static const _stepLabels = ['Order Placed', 'Processing', 'Ready for Pickup', 'In Transit', 'Delivered'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final order = await ApiService.getOrder(widget.orderId);
    if (mounted) setState(() { _order = order; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _order == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('😕', style: TextStyle(fontSize: 48)),
    const SizedBox(height: 12),
    const Text('Order not found'),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/orders', (_) => false),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
        child: const Text('View My Orders')),
  ]));

  Widget _buildContent() {
    final o = _order!;
    final orderId = (o['order_id'] ?? o['id'] ?? '').toString();
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
    final status = o['status']?.toString() ?? 'pending';
    final total = (o['total_price'] as num? ?? 0).toDouble();
    final items = (o['items'] as List? ?? []);
    final proofUrl = o['proof_of_delivery_url']?.toString() ?? '';
    final createdAt = _fmtDate(o['created_at']?.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Step indicator
        _buildSteps(),
        const SizedBox(height: 16),
        // Success banner
        _card(child: Column(children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          const Text('Order Placed!', style: TextStyle(fontFamily: AppTheme.fontDisplay,
              fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 4),
          const Text('Thank you for your purchase. Your order is being processed.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        ])),
        const SizedBox(height: 12),
        // Order details
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Order Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _row('Order ID', '#$shortId'),
          _row('Date', createdAt),
          _row('Total', '₱${total.toStringAsFixed(2)}', valueColor: AppTheme.primaryLight),
          _row('Status', status.replaceAll('_', ' ').toUpperCase()),
        ])),
        const SizedBox(height: 12),
        // Items
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Order Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...items.map((item) => _buildItem(item as Map)),
        ])),
        // Proof of delivery
        if (proofUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          _card(child: Row(children: [
            const Text('📸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Proof of Delivery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Photo taken by rider upon delivery', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ])),
            ElevatedButton(
              onPressed: () => _showProof(proofUrl),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              child: const Text('View Photo', style: TextStyle(fontSize: 12)),
            ),
          ])),
        ],
        const SizedBox(height: 12),
        // Timeline
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Delivery Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _buildTimeline(status, createdAt),
        ])),
        const SizedBox(height: 20),
        // Action buttons
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/orders', (_) => false),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('View My Orders', style: TextStyle(fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/shop', (_) => false),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryLight),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Continue Shopping',
                style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
          )),
        ]),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildSteps() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _step('✓', 'Cart', done: true),
        _stepLine(),
        _step('✓', 'Checkout', done: true),
        _stepLine(),
        _step('3', 'Confirmation', active: true),
      ]),
    );
  }

  Widget _step(String label, String text, {bool done = false, bool active = false}) {
    final color = done ? Colors.green : active ? AppTheme.primaryLight : Colors.grey.shade300;
    return Column(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: done || active ? color : Colors.transparent,
            border: Border.all(color: color, width: 2)),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: done || active ? Colors.white : color))),
      ),
      const SizedBox(height: 4),
      Text(text, style: TextStyle(fontSize: 10,
          color: done || active ? color : Colors.grey,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
    ]);
  }

  Widget _stepLine() => Container(width: 40, height: 2,
      margin: const EdgeInsets.only(bottom: 18), color: Colors.grey.shade200);

  Widget _buildItem(Map item) {
    final name = item['product_name']?.toString() ?? 'Product';
    final qty  = (item['quantity'] as num? ?? 1).toInt();
    final price = (item['final_price'] as num? ?? item['unit_price'] as num? ?? 0).toDouble();
    final total = (item['total_price'] as num? ?? price * qty).toDouble();
    final img  = item['image']?.toString();
    final variant = item['variant'] as Map?;
    final size  = variant?['size']?.toString() ?? '';
    final color = variant?['color']?.toString() ?? '';
    final variantLabel = [size, color].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFF8F9FA)),
          child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: img != null && img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 20, color: AppTheme.textLight))
                  : const Icon(Icons.image_outlined, size: 20, color: AppTheme.textLight)),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (variantLabel.isNotEmpty)
            Text(variantLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          Text('₱${price.toStringAsFixed(2)} × $qty',
              style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
        ])),
        Text('₱${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
      ]),
    );
  }

  Widget _buildTimeline(String status, String orderDate) {
    final idx = _steps.indexOf(status);
    return Column(children: List.generate(_steps.length, (i) {
      final isDone   = i < idx;
      final isActive = i == idx;
      final color = isDone ? Colors.green : isActive ? AppTheme.primaryLight : Colors.grey.shade300;
      final dateText = i == 0 ? orderDate
          : isDone ? 'Completed'
          : isActive ? 'In Progress'
          : 'Pending';
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: isDone || isActive ? color : Colors.white,
                border: Border.all(color: color, width: 2)),
            child: Center(child: Text(isDone ? '✓' : '${i + 1}',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: isDone || isActive ? Colors.white : Colors.grey))),
          ),
          if (i < _steps.length - 1)
            Container(width: 2, height: 28, color: isDone ? Colors.green : Colors.grey.shade200),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_stepLabels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDone ? Colors.green : isActive ? AppTheme.primaryLight : AppTheme.textLight)),
            Text(dateText, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          ]),
        )),
      ]);
    }));
  }

  void _showProof(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white,
          title: const Text('Proof of Delivery')),
      body: InteractiveViewer(
        child: Center(child: Image.network(url, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64))),
      ),
    )));
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe8e8f0))),
    child: child,
  );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: valueColor ?? AppTheme.textDark)),
    ]),
  );

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return iso; }
  }
}
