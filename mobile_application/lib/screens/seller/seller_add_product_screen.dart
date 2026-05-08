import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SellerAddProductScreen extends StatefulWidget {
  const SellerAddProductScreen({super.key});

  @override
  State<SellerAddProductScreen> createState() => _SellerAddProductScreenState();
}

class _SellerAddProductScreenState extends State<SellerAddProductScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _storeCategory;
  bool _isLoading = false;

  // Predefined colors and sizes matching web app
  static const List<Map<String, String>> _predefinedColors = [
    {'name': 'Black',   'hex': '#000000'},
    {'name': 'White',   'hex': '#FFFFFF'},
    {'name': 'Red',     'hex': '#FF0000'},
    {'name': 'Blue',    'hex': '#0000FF'},
    {'name': 'Green',   'hex': '#008000'},
    {'name': 'Yellow',  'hex': '#FFFF00'},
    {'name': 'Orange',  'hex': '#FFA500'},
    {'name': 'Purple',  'hex': '#800080'},
    {'name': 'Pink',    'hex': '#FFC0CB'},
    {'name': 'Brown',   'hex': '#A52A2A'},
    {'name': 'Gray',    'hex': '#808080'},
    {'name': 'Navy',    'hex': '#000080'},
    {'name': 'Maroon',  'hex': '#800000'},
    {'name': 'Olive',   'hex': '#808000'},
    {'name': 'Teal',    'hex': '#008080'},
    {'name': 'Silver',  'hex': '#C0C0C0'},
  ];

  static const List<String> _predefinedSizes = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', 'One Size',
  ];

  final List<Map<String, dynamic>> _variants = [];
  String _productDiscountType = 'none';
  double _productDiscountValue = 0.0;

  // Variant creator state
  String? _creatorSize;
  bool _creatorUseCustomSize = false;
  final _creatorCustomSizeCtrl = TextEditingController();
  String _creatorColorHex = '#808080';
  final _creatorCustomColorNameCtrl = TextEditingController();


  final Map<int, List<File>> _variantImages = {};
  final ImagePicker _picker = ImagePicker();

  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.get('/api/seller/category', token: token);
      if (mounted) {
        final category = res['category']?.toString() ?? '';
        setState(() => _storeCategory = category.isNotEmpty ? category : null);
      }
    } catch (_) {}
  }

  void _addVariantFromCreator() {
    final size = _creatorUseCustomSize
        ? _creatorCustomSizeCtrl.text.trim()
        : _creatorSize;
    if (size == null || size.isEmpty) {
      _showSnackBar('Please select a size', isError: true);
      return;
    }
    final colorName = _creatorCustomColorNameCtrl.text.trim();
    if (colorName.isEmpty) {
      _showSnackBar('Please select or enter a color', isError: true);
      return;
    }
    // Prevent duplicate size+color
    final key = '$size-$colorName';
    if (_variants.any((v) => '${v['size']}-${v['color']}' == key)) {
      _showSnackBar('A variant with this size and color already exists', isError: true);
      return;
    }
    if (_variants.length >= 10) {
      _showSnackBar('Maximum 10 variants allowed', isError: true);
      return;
    }
    setState(() {
      _variants.add({
        'size': size,
        'color': colorName,
        'hex': _creatorColorHex,
        'price': '',
        'stock': '',
        'discount_type': 'none',
        'discount_value': 0.0,
      });
      // Reset creator
      _creatorSize = null;
      _creatorUseCustomSize = false;
      _creatorCustomSizeCtrl.clear();
      _creatorColorHex = '#808080';
      _creatorCustomColorNameCtrl.clear();
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants.removeAt(index);
      _variantImages.remove(index);
    });
  }

  Future<void> _pickImages(int variantIndex) async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _variantImages[variantIndex] = images.map((img) => File(img.path)).toList();
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick images: $e', isError: true);
    }
  }

  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnackBar('Product name is required', isError: true);
      return false;
    }
    if (_storeCategory == null || _storeCategory!.isEmpty) {
      _showSnackBar('Store category is still loading, please wait...', isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_variants.isEmpty) {
      _showSnackBar('Add at least one variant', isError: true);
      return false;
    }
    for (int i = 0; i < _variants.length; i++) {
      final v = _variants[i];
      if (v['price'] == null || v['price'].toString().trim().isEmpty) {
        _showSnackBar('Variant ${i + 1}: Price is required', isError: true);
        return false;
      }
      final price = double.tryParse(v['price'].toString()) ?? 0;
      if (price <= 0) {
        _showSnackBar('Variant ${i + 1}: Price must be greater than 0', isError: true);
        return false;
      }
      if (v['stock'] == null || v['stock'].toString().trim().isEmpty) {
        _showSnackBar('Variant ${i + 1}: Stock is required', isError: true);
        return false;
      }
    }
    return true;
  }

  bool _validateStep3() {
    for (int i = 0; i < _variants.length; i++) {
      if (!_variantImages.containsKey(i) || _variantImages[i]!.isEmpty) {
        _showSnackBar('Variant ${i + 1}: Please upload at least one image', isError: true);
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 1 && _validateStep1()) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2 && _validateStep2()) {
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3 && _validateStep3()) {
      setState(() => _currentStep = 4);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) setState(() => _currentStep = _currentStep - 1);
  }

  Future<void> _submitProduct() async {
    if (!_validateStep3()) return;
    setState(() => _isLoading = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) throw Exception('User not authenticated');

      final fields = <String, String>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _storeCategory ?? '',
        'discount_type': _productDiscountType,
        'discount_value': _productDiscountValue.toString(),
      };

      // Send variants in the format the backend _parse_variants expects:
      // variants[i][type], variants[i][value], variants[i][price], variants[i][stock]
      for (int i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        fields['variants[$i][type]'] = 'color';
        fields['variants[$i][value]'] = v['color']?.toString().trim() ?? '';
        fields['variants[$i][hex]'] = v['hex']?.toString().trim() ?? '#808080';
        fields['variants[$i][size]'] = v['size']?.toString().trim() ?? 'One Size';
        fields['variants[$i][price]'] = v['price']?.toString() ?? '0';
        fields['variants[$i][stock]'] = v['stock']?.toString() ?? '0';
        fields['variants[$i][discount_type]'] = v['discount_type']?.toString() ?? 'none';
        fields['variants[$i][discount_value]'] = (v['discount_value'] as double? ?? 0).toString();
      }

      // Collect all images; first image of each variant also sent as variant_image_i
      final Map<String, File> namedImages = {};
      final List<File> allImages = [];
      for (int i = 0; i < _variants.length; i++) {
        final imgs = _variantImages[i] ?? [];
        for (int j = 0; j < imgs.length; j++) {
          allImages.add(imgs[j]);
          if (j == 0) namedImages['variant_image_$i'] = imgs[j];
        }
      }

      final res = await ApiService.sellerCreateProduct(
        fields: fields,
        images: namedImages,
        imagesList: allImages,
      );
      if (mounted) {
        if (res['success'] == true) {
          _showSnackBar('Product submitted for approval!');
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pop(context);
        } else {
          _showSnackBar(res['message'] ?? 'Failed to create product', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _creatorCustomSizeCtrl.dispose();
    _creatorCustomColorNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text('Add Product',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () {
            if (_currentStep > 1) {
              _prevStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(
              children: [
                _buildStepIndicator(),
                const SizedBox(height: AppTheme.sm),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.md),
                    child: _buildStepContent(),
                  ),
                ),
                _buildNavigationButtons(),
                const SizedBox(height: AppTheme.md),
              ],
            ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
      color: AppTheme.white,
      child: Row(
        children: [
          _stepCircle(1, 'Basic Info'),
          _stepLine(),
          _stepCircle(2, 'Variants'),
          _stepLine(),
          _stepCircle(3, 'Images'),
          _stepLine(),
          _stepCircle(4, 'Review'),
        ],
      ),
    );
  }

  Widget _stepCircle(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.primaryLight : isCompleted ? Colors.green : Colors.grey[300],
            ),
            child: Center(
              child: Text(
                isCompleted ? '✓' : '$step',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isActive || isCompleted ? AppTheme.primaryLight : AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _stepLine() {
    return Container(
      width: 20,
      height: 2,
      color: Colors.grey[300],
      margin: const EdgeInsets.only(top: 15),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Basic Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: AppTheme.md),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Product Name *',
            border: OutlineInputBorder(),
            hintText: 'e.g. Floral Wrap Dress',
          ),
        ),
        const SizedBox(height: AppTheme.md),
        TextFormField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            hintText: 'Describe your product — material, fit, occasion...',
          ),
          maxLines: 4,
        ),
        const SizedBox(height: AppTheme.md),
        _buildCategoryField(),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.grayLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              if (_storeCategory == null)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                )
              else
                const Icon(Icons.lock_outline, size: 16, color: AppTheme.textLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _storeCategory ?? 'Loading your store category...',
                  style: TextStyle(
                    color: _storeCategory == null ? AppTheme.textLight : AppTheme.textDark,
                    fontSize: 14,
                    fontWeight: _storeCategory != null ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Your store category is fixed based on your registration',
            style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Variants',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 4),
        const Text('Add size and color variants. Each has its own price, stock, and optional discount.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const SizedBox(height: AppTheme.md),
        // Product discount
        _buildProductDiscountSection(),
        const SizedBox(height: AppTheme.md),
        // Variant creator
        _buildVariantCreator(),
        const SizedBox(height: AppTheme.md),
        // Variant list
        if (_variants.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Text('No variants yet. Choose a size and color above.',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
            ),
          )
        else
          ...List.generate(_variants.length, (i) => _buildVariantCard(i)),
        Text('${_variants.length}/10 variants',
            style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
      ],
    );
  }

  Widget _buildProductDiscountSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product Discount (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _productDiscountType,
                decoration: const InputDecoration(
                  labelText: 'Discount Type',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('No Discount')),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                  DropdownMenuItem(value: 'fixed_amount', child: Text('Fixed (₱)')),
                ],
                onChanged: (v) => setState(() => _productDiscountType = v!),
              ),
            ),
            if (_productDiscountType != 'none') ...[
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _productDiscountValue > 0 ? _productDiscountValue.toString() : '',
                  decoration: const InputDecoration(
                    labelText: 'Value',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() => _productDiscountValue = double.tryParse(v) ?? 0),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildVariantCreator() {
    final usedHexes = _variants.map((v) => (v['hex'] as String).toLowerCase()).toSet();
    final usedSizes = _variants.map((v) => v['size'] as String).toSet();

    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Variant',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textDark)),
          const SizedBox(height: 12),
          // Size — dropdown matching web
          const Text('Select Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _creatorUseCustomSize ? 'custom' : _creatorSize,
            decoration: const InputDecoration(
              hintText: 'Choose size...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              ..._predefinedSizes.map((size) => DropdownMenuItem(
                value: size,
                enabled: !usedSizes.contains(size),
                child: Text(
                  usedSizes.contains(size) ? '$size (used)' : size,
                  style: TextStyle(
                    color: usedSizes.contains(size) ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
              )),
              const DropdownMenuItem(value: 'custom', child: Text('Custom Size')),
            ],
            onChanged: (val) => setState(() {
              if (val == 'custom') {
                _creatorUseCustomSize = true;
                _creatorSize = null;
              } else {
                _creatorUseCustomSize = false;
                _creatorSize = val;
              }
            }),
          ),
          if (_creatorUseCustomSize) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _creatorCustomSizeCtrl,
              decoration: const InputDecoration(
                hintText: 'Enter custom size',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Color swatches — clicking auto-fills name (matches web pfSelectCreatorColor)
          const Text('Select Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _predefinedColors.map((c) {
              final hex = c['hex']!.toLowerCase();
              final isUsed = usedHexes.contains(hex);
              final isSelected = _creatorColorHex.toLowerCase() == hex;
              return GestureDetector(
                onTap: isUsed ? null : () => setState(() {
                  // Matches web: pfSelectCreatorColor sets both hex and name fields
                  _creatorColorHex = c['hex']!;
                  _creatorCustomColorNameCtrl.text = c['name']!;
                }),
                child: Stack(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _hexToColor(c['hex']!),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryLight : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: AppTheme.primaryLight.withValues(alpha: 0.4), blurRadius: 4)
                        ] : null,
                      ),
                      child: isUsed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                    if (isUsed)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Custom color — hex input + name field side by side (matches web layout)
          const Text('Custom Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(children: [
            GestureDetector(
              onTap: () async {
                final ctrl = TextEditingController(text: _creatorColorHex);
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Enter Hex Color'),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: '#FF0000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _creatorColorHex = ctrl.text.trim());
                          Navigator.pop(ctx);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _hexToColor(_creatorColorHex),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _creatorCustomColorNameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Color name (e.g. Coral)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_variants.length < 10)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addVariantFromCreator,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add Variant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Text('Maximum 10 variants. Each variant must have size and color.',
              style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 3) {
      return Color(int.parse('FF${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}', radix: 16));
    }
    try { return Color(int.parse('FF${h.padRight(6, '0')}', radix: 16)); }
    catch (_) { return Colors.grey; }
  }

  Widget _buildVariantCard(int index) {
    final v = _variants[index];
    final discountType = v['discount_type'] as String? ?? 'none';
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.md),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                child: Text(
                  '${v['size']} — ${v['color']}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              if (_variants.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeVariant(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const Divider(height: 20),
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
          // Variant discount
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: discountType,
                decoration: const InputDecoration(
                  labelText: 'Variant Discount',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('No Discount')),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                  DropdownMenuItem(value: 'fixed_amount', child: Text('Fixed (₱)')),
                ],
                onChanged: (val) => setState(() => v['discount_type'] = val),
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
            Builder(builder: (ctx) {
              final price = double.tryParse(v['price']?.toString() ?? '') ?? 0;
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
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Product Images',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('Upload at least one image for each variant.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const SizedBox(height: AppTheme.md),
        ...List.generate(_variants.length, (index) => _buildVariantImagesSection(index)),
      ],
    );
  }

  Widget _buildVariantImagesSection(int index) {
    final images = _variantImages[index] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.lg),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Variant ${index + 1}: ${_variants[index]['size']} / ${_variants[index]['color']}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (images.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (ctx, i) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(image: FileImage(images[i]), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _pickImages(index),
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text('Select Images'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.white,
              foregroundColor: AppTheme.primaryLight,
              side: const BorderSide(color: AppTheme.primaryLight),
            ),
          ),
          if (images.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('At least one image required', style: TextStyle(color: Colors.red, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Review & Submit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('Please verify all details before submitting.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const SizedBox(height: AppTheme.md),
        Container(
          padding: const EdgeInsets.all(AppTheme.md),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('Product Name', _nameCtrl.text),
              _reviewRow('Description', _descCtrl.text.isEmpty ? 'N/A' : _descCtrl.text),
              _reviewRow('Category', _storeCategory ?? 'N/A'),
              const Divider(),
              ..._variants.asMap().entries.map((e) => _reviewVariant(e.key, e.value)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _reviewVariant(int index, Map<String, dynamic> v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Variant ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _reviewRow('Size', v['size']?.toString() ?? ''),
        _reviewRow('Color', v['color']?.toString() ?? ''),
        _reviewRow('Price', '₱${_fmt(v['price'])}'),
        _reviewRow('Stock', v['stock']?.toString() ?? ''),
      ],
    );
  }

  String _fmt(dynamic val) {
    try { return double.parse(val.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; }
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md),
      color: AppTheme.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.md),
          child: Row(
            children: [
              if (_currentStep > 1)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _prevStep,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('← Back'),
                  ),
                ),
              if (_currentStep > 1) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_currentStep < 4 ? _nextStep : _submitProduct),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryLight,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2.5),
                        )
                      : Text(_currentStep < 4 ? 'Next →' : 'Submit for Approval'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
