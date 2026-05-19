import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SellerEditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const SellerEditProductScreen({super.key, required this.product});

  @override
  State<SellerEditProductScreen> createState() => _SellerEditProductScreenState();
}

class _SellerEditProductScreenState extends State<SellerEditProductScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Variants: each map holds id, size, color, hex, price, stock, discount_type, discount_value
  late List<Map<String, dynamic>> _variants;
  // New images per variant index (null = keep existing)
  final Map<int, List<File>> _newImages = {};

  static const List<Map<String, String>> _predefinedColors = [
    {'name': 'Black',  'hex': '#000000'}, {'name': 'White',  'hex': '#FFFFFF'},
    {'name': 'Red',    'hex': '#FF0000'}, {'name': 'Blue',   'hex': '#0000FF'},
    {'name': 'Green',  'hex': '#008000'}, {'name': 'Yellow', 'hex': '#FFFF00'},
    {'name': 'Orange', 'hex': '#FFA500'}, {'name': 'Purple', 'hex': '#800080'},
    {'name': 'Pink',   'hex': '#FFC0CB'}, {'name': 'Brown',  'hex': '#A52A2A'},
    {'name': 'Gray',   'hex': '#808080'}, {'name': 'Navy',   'hex': '#000080'},
  ];

  static const List<String> _predefinedSizes = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', 'One Size',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.product['name']?.toString() ?? '';
    _descCtrl.text = widget.product['description']?.toString() ?? '';

    // Pre-fill variants from existing product data
    final rawVariants = widget.product['variants'] as List? ??
        widget.product['product_variants'] as List? ?? [];
    _variants = rawVariants.map<Map<String, dynamic>>((v) {
      final m = Map<String, dynamic>.from(v as Map);
      return {
        'id':             m['id']?.toString() ?? '',
        'size':           m['size']?.toString() ?? m['value']?.toString() ?? 'One Size',
        'color':          m['color']?.toString() ?? m['value']?.toString() ?? '',
        'hex':            m['color_hex']?.toString() ?? '#808080',
        'price':          (m['price'] as num?)?.toStringAsFixed(2) ?? '0.00',
        'stock':          (m['stock'] as num?)?.toString() ?? '0',
        'discount_type':  m['discount_type']?.toString() ?? 'none',
        'discount_value': (m['discount_value'] as num?)?.toDouble() ?? 0.0,
        // Keep existing image URLs for display
        'existing_image': null as String?,
      };
    }).toList();

    // Pull first image per variant from product_images if available
    final images = widget.product['product_images'] as List? ?? [];
    for (int i = 0; i < _variants.length; i++) {
      final variantId = _variants[i]['id'];
      final match = images.cast<Map>().firstWhere(
        (img) => img['variant_id']?.toString() == variantId,
        orElse: () => images.isNotEmpty ? images.first as Map : {},
      );
      if (match.isNotEmpty) {
        _variants[i]['existing_image'] = match['image_url']?.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages(int index) async {
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() => _newImages[index] = picked.map((x) => File(x.path)).toList());
      }
    } catch (e) {
      _snack('Failed to pick images: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Product name is required', isError: true);
      return;
    }
    for (int i = 0; i < _variants.length; i++) {
      final v = _variants[i];
      if ((double.tryParse(v['price'].toString()) ?? 0) <= 0) {
        _snack('Variant ${i + 1}: price must be greater than 0', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final fields = <String, String>{
        'name':        _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      };

      for (int i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        if (v['id'].toString().isNotEmpty) fields['variants[$i][id]'] = v['id'].toString();
        fields['variants[$i][type]']           = 'color';
        fields['variants[$i][value]']          = v['color'].toString();
        fields['variants[$i][hex]']            = v['hex'].toString();
        fields['variants[$i][size]']           = v['size'].toString();
        fields['variants[$i][price]']          = v['price'].toString();
        fields['variants[$i][stock]']          = v['stock'].toString();
        fields['variants[$i][discount_type]']  = v['discount_type'].toString();
        fields['variants[$i][discount_value]'] = (v['discount_value'] as double).toString();
      }

      final Map<String, File> namedImages = {};
      final List<File> allImages = [];
      for (int i = 0; i < _variants.length; i++) {
        final imgs = _newImages[i] ?? [];
        for (int j = 0; j < imgs.length; j++) {
          allImages.add(imgs[j]);
          if (j == 0) namedImages['variant_image_$i'] = imgs[j];
        }
      }

      final productId = widget.product['id']?.toString() ?? '';
      final res = await ApiService.sellerUpdateProduct(
        productId,
        fields: fields,
        images: namedImages,
        imagesList: allImages,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        _snack('Product updated successfully!');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true); // true = refresh list
      } else {
        _snack(res['message'] ?? 'Failed to update product', isError: true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try { return Color(int.parse('FF${h.padRight(6, '0')}', radix: 16)); }
    catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        title: const Text('Edit Product',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20,
                fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('Save', style: TextStyle(color: AppTheme.primaryLight,
                fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Basic info ──────────────────────────────────────
                _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Basic Information',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ])),
                const SizedBox(height: AppTheme.md),

                // ── Variants ────────────────────────────────────────
                const Text('Variants',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                const SizedBox(height: 8),
                ...List.generate(_variants.length, (i) => _buildVariantCard(i)),

                const SizedBox(height: AppTheme.lg),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: AppTheme.md),
              ]),
            ),
    );
  }

  Widget _buildVariantCard(int index) {
    final v = _variants[index];
    final discountType = v['discount_type'] as String? ?? 'none';
    final existingImage = v['existing_image'] as String?;
    final newImgs = _newImages[index] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _hexToColor(v['hex'] as String? ?? '#808080'),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${v['size']} — ${v['color']}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ]),
        const Divider(height: 20),

        // Size
        DropdownButtonFormField<String>(
          value: _predefinedSizes.contains(v['size']) ? v['size'] as String : 'One Size',
          decoration: const InputDecoration(
            labelText: 'Size',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _predefinedSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() => v['size'] = val ?? v['size']),
        ),
        const SizedBox(height: 12),

        // Color swatches
        const Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textLight)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _predefinedColors.map((c) {
            final isSelected = (v['hex'] as String).toLowerCase() == c['hex']!.toLowerCase();
            return GestureDetector(
              onTap: () => setState(() {
                v['hex'] = c['hex']!;
                v['color'] = c['name']!;
              }),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _hexToColor(c['hex']!),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryLight : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Price + Stock
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: v['price']?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Price (₱)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) => v['price'] = val,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: v['stock']?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => v['stock'] = val,
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Discount
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: discountType,
              decoration: const InputDecoration(
                labelText: 'Discount',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No Discount')),
                DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                DropdownMenuItem(value: 'fixed_amount', child: Text('Fixed (₱)')),
              ],
              onChanged: (val) => setState(() => v['discount_type'] = val ?? 'none'),
            ),
          ),
          if (discountType != 'none') ...[
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: (v['discount_value'] as double? ?? 0) > 0
                    ? v['discount_value'].toString() : '',
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => setState(() => v['discount_value'] = double.tryParse(val) ?? 0),
              ),
            ),
          ],
        ]),

        // Discount preview
        if (discountType != 'none') ...[
          const SizedBox(height: 6),
          Builder(builder: (_) {
            final price = double.tryParse(v['price'].toString()) ?? 0;
            final dv = v['discount_value'] as double? ?? 0;
            if (price > 0 && dv > 0) {
              final final_ = discountType == 'percentage'
                  ? price * (1 - dv / 100)
                  : (price - dv).clamp(0, double.infinity);
              return Text('Final price: ₱${final_.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green));
            }
            return const SizedBox.shrink();
          }),
        ],
        const SizedBox(height: 12),

        // Images
        const Text('Images', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textLight)),
        const SizedBox(height: 6),
        // Show new picks or existing image
        if (newImgs.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: newImgs.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.only(right: 8),
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(image: FileImage(newImgs[i]), fit: BoxFit.cover),
                ),
              ),
            ),
          )
        else if (existingImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(existingImage, height: 80, width: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 32, color: AppTheme.textLight)),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickImages(index),
          icon: const Icon(Icons.photo_library, size: 16),
          label: Text(newImgs.isNotEmpty ? 'Change Images' : 'Replace Images'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryLight,
            side: const BorderSide(color: AppTheme.primaryLight),
          ),
        ),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(AppTheme.md),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      boxShadow: AppTheme.cardShadow,
    ),
    child: child,
  );
}
