import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/psgc_service.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ApiService.getAddresses();
    if (mounted) setState(() { _addresses = list; _loading = false; });
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Delete this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final token = await ApiService.getAuthToken() ?? '';
    final res = await ApiService.delete('/api/addresses/$id', token: token);
    if (mounted) {
      _toast(res['success'] == true ? 'Address deleted.' : (res['error'] ?? 'Failed'));
      if (res['success'] == true) _load();
    }
  }

  Future<void> _setDefault(String id) async {
    final token = await ApiService.getAuthToken() ?? '';
    final res = await ApiService.postJson('/api/addresses/$id/default', {}, token: token);
    if (mounted) {
      _toast(res['success'] == true ? 'Default address updated.' : (res['error'] ?? 'Failed'));
      if (res['success'] == true) _load();
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  void _openForm([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddressForm(
        existing: existing,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
        actions: [
          TextButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, color: AppTheme.primaryLight, size: 18),
            label: const Text('Add', style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _addresses.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (_, i) => _AddressCard(
                      address: _addresses[i],
                      onEdit: () => _openForm(_addresses[i]),
                      onDelete: () => _delete(_addresses[i]['id'].toString()),
                      onSetDefault: () => _setDefault(_addresses[i]['id'].toString()),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.location_on_outlined, size: 64, color: AppTheme.textLight),
          const SizedBox(height: 12),
          const Text('No saved addresses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('Add your delivery address to get started.',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
          ),
        ]),
      );
}

// ── Address card ──────────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onEdit, onDelete, onSetDefault;
  const _AddressCard({required this.address, required this.onEdit,
      required this.onDelete, required this.onSetDefault});

  @override
  Widget build(BuildContext context) {
    final isDefault = address['is_default'] == true;
    final label = address['label']?.toString() ?? 'Address';
    final parts = [address['street'], address['barangay'],
      address['city'], address['region'], address['zip_code']]
        .where((p) => p != null && p.toString().isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? AppTheme.primaryLight : const Color(0xFFe8e8f0),
          width: isDefault ? 1.5 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark))),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Default',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(parts, style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          _btn('Edit', Icons.edit_outlined, Colors.grey.shade700, onEdit),
          _btn('Delete', Icons.delete_outline, Colors.red, onDelete),
          if (!isDefault) _btn('Set Default', Icons.check_circle_outline, Colors.green, onSetDefault),
        ]),
      ]),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// ── Add / Edit form ───────────────────────────────────────────────────────────
class _AddressForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _AddressForm({this.existing, required this.onSaved});
  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _label  = TextEditingController();
  final _street = TextEditingController();
  final _zip    = TextEditingController();
  bool _saving = false;

  // PSGC state
  List<Map<String, String>> _regions    = [];
  List<Map<String, String>> _provinces  = [];
  List<Map<String, String>> _cities     = [];
  List<Map<String, String>> _barangays  = [];

  String? _regionCode,    _regionName;
  String? _provinceCode,  _provinceName;
  String? _cityCode,      _cityName;
  String? _barangayCode,  _barangayName;

  bool _loadingRegions   = true;
  bool _loadingProvinces = false;
  bool _loadingCities    = false;
  bool _loadingBarangays = false;
  bool _noProvince       = false; // NCR-style regions

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _label.text  = e['label']?.toString()    ?? '';
      _street.text = e['street']?.toString()   ?? '';
      _zip.text    = e['zip_code']?.toString() ?? '';
    }
    _loadRegions();
  }

  @override
  void dispose() {
    _label.dispose(); _street.dispose(); _zip.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    final data = await PSGService.getRegions();
    if (!mounted) return;
    setState(() { _regions = data; _loadingRegions = false; });
    // Pre-select if editing
    final e = widget.existing;
    if (e != null && e['region'] != null) {
      final saved = e['region'].toString();
      final match = data.firstWhere(
        (r) => r['name']!.toLowerCase() == saved.toLowerCase(),
        orElse: () => {},
      );
      if (match.isNotEmpty) await _onRegionChanged(match['code']!, match['name']!);
    }
  }

  Future<void> _onRegionChanged(String code, String name) async {
    setState(() {
      _regionCode = code; _regionName = name;
      _provinceCode = null; _provinceName = null;
      _cityCode = null; _cityName = null;
      _barangayCode = null; _barangayName = null;
      _provinces = []; _cities = []; _barangays = [];
      _loadingProvinces = true; _noProvince = false;
    });
    final data = await PSGService.getProvinces(code);
    if (!mounted) return;
    if (data.isEmpty) {
      // NCR-style: load cities directly
      setState(() { _noProvince = true; _loadingProvinces = false; _loadingCities = true; });
      final cities = await PSGService.getCitiesByRegion(code);
      if (!mounted) return;
      setState(() { _cities = cities; _loadingCities = false; });
      _tryPreSelectCity();
    } else {
      setState(() { _provinces = data; _loadingProvinces = false; });
      _tryPreSelectProvince();
    }
  }

  void _tryPreSelectProvince() {
    final e = widget.existing;
    if (e == null) return;
    final saved = (e['province'] ?? '').toString();
    if (saved.isEmpty) return;
    final match = _provinces.firstWhere(
      (p) => p['name']!.toLowerCase() == saved.toLowerCase(),
      orElse: () => {},
    );
    if (match.isNotEmpty) _onProvinceChanged(match['code']!, match['name']!);
  }

  Future<void> _onProvinceChanged(String code, String name) async {
    setState(() {
      _provinceCode = code; _provinceName = name;
      _cityCode = null; _cityName = null;
      _barangayCode = null; _barangayName = null;
      _cities = []; _barangays = [];
      _loadingCities = true;
    });
    final data = await PSGService.getCities(code);
    if (!mounted) return;
    setState(() { _cities = data; _loadingCities = false; });
    _tryPreSelectCity();
  }

  void _tryPreSelectCity() {
    final e = widget.existing;
    if (e == null) return;
    final saved = (e['city'] ?? '').toString();
    if (saved.isEmpty) return;
    final match = _cities.firstWhere(
      (c) => c['name']!.toLowerCase() == saved.toLowerCase(),
      orElse: () => {},
    );
    if (match.isNotEmpty) _onCityChanged(match['code']!, match['name']!);
  }

  Future<void> _onCityChanged(String code, String name) async {
    setState(() {
      _cityCode = code; _cityName = name;
      _barangayCode = null; _barangayName = null;
      _barangays = [];
      _loadingBarangays = true;
    });
    final data = await PSGService.getBarangays(code);
    if (!mounted) return;
    setState(() { _barangays = data; _loadingBarangays = false; });
    _tryPreSelectBarangay();
  }

  void _tryPreSelectBarangay() {
    final e = widget.existing;
    if (e == null) return;
    final saved = (e['barangay'] ?? '').toString();
    if (saved.isEmpty) return;
    final match = _barangays.firstWhere(
      (b) => b['name']!.toLowerCase() == saved.toLowerCase(),
      orElse: () => {},
    );
    if (match.isNotEmpty) setState(() { _barangayCode = match['code']; _barangayName = match['name']; });
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) { _err('Label is required.'); return; }
    if (_regionName == null)   { _err('Please select a region.'); return; }
    if (_cityName == null)     { _err('Please select a city/municipality.'); return; }
    if (_barangayName == null) { _err('Please select a barangay.'); return; }
    if (_street.text.trim().isEmpty) { _err('Please enter a street/house no.'); return; }

    final fields = {
      'label':    _label.text.trim(),
      'region':   _regionName!,
      'province': _provinceName ?? '',
      'city':     _cityName!,
      'barangay': _barangayName!,
      'street':   _street.text.trim(),
      'zip_code': _zip.text.trim(),
    };

    setState(() => _saving = true);
    final token = await ApiService.getAuthToken() ?? '';
    bool success = false;
    String? error;
    try {
      if (widget.existing != null) {
        final id = widget.existing!['id'].toString();
        final res = await http.put(
          Uri.parse('${ApiService.flaskBaseUrl}/api/addresses/$id'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(fields),
        ).timeout(const Duration(seconds: 10));
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        success = res.statusCode == 200;
        error = body['error']?.toString();
      } else {
        final res = await ApiService.postJson('/api/addresses', fields, token: token);
        success = res['success'] == true || res['data'] != null;
        error = res['error']?.toString();
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) {
      setState(() => _saving = false);
      if (success) widget.onSaved();
      else _err(error ?? 'Failed to save address.');
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(widget.existing != null ? 'Edit Address' : 'Add New Address',
              style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _textField(_label, 'Label (e.g. Home, Office)'),
          // Region
          _dropdownField<Map<String, String>>(
            label: 'Region',
            loading: _loadingRegions,
            value: _regionCode != null
                ? _regions.firstWhere((r) => r['code'] == _regionCode, orElse: () => {})
                : null,
            items: _regions,
            itemLabel: (r) => r['name']!,
            onChanged: (r) => _onRegionChanged(r!['code']!, r['name']!),
            enabled: !_loadingRegions,
          ),
          // Province (hidden for NCR-style regions)
          if (!_noProvince)
            _dropdownField<Map<String, String>>(
              label: 'Province',
              loading: _loadingProvinces,
              value: _provinceCode != null
                  ? _provinces.firstWhere((p) => p['code'] == _provinceCode, orElse: () => {})
                  : null,
              items: _provinces,
              itemLabel: (p) => p['name']!,
              onChanged: (p) => _onProvinceChanged(p!['code']!, p['name']!),
              enabled: _regionCode != null && !_loadingProvinces && _provinces.isNotEmpty,
            ),
          // City / Municipality
          _dropdownField<Map<String, String>>(
            label: 'City / Municipality',
            loading: _loadingCities,
            value: _cityCode != null
                ? _cities.firstWhere((c) => c['code'] == _cityCode, orElse: () => {})
                : null,
            items: _cities,
            itemLabel: (c) => c['name']!,
            onChanged: (c) => _onCityChanged(c!['code']!, c['name']!),
            enabled: (_noProvince ? _regionCode != null : _provinceCode != null)
                && !_loadingCities && _cities.isNotEmpty,
          ),
          // Barangay
          _dropdownField<Map<String, String>>(
            label: 'Barangay',
            loading: _loadingBarangays,
            value: _barangayCode != null
                ? _barangays.firstWhere((b) => b['code'] == _barangayCode, orElse: () => {})
                : null,
            items: _barangays,
            itemLabel: (b) => b['name']!,
            onChanged: (b) => setState(() { _barangayCode = b!['code']; _barangayName = b['name']; }),
            enabled: _cityCode != null && !_loadingBarangays && _barangays.isNotEmpty,
          ),
          _textField(_street, 'Street / House No.'),
          _textField(_zip, 'ZIP Code', type: TextInputType.number),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.existing != null ? 'Save Changes' : 'Save Address',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, {TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      );

  Widget _dropdownField<T>({
    required String label,
    required bool loading,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    required bool enabled,
  }) {
    // Ensure value is actually in items list (avoid assertion error)
    final safeValue = (value != null && items.contains(value)) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight)))
              : null,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: safeValue,
            isExpanded: true,
            hint: Text(loading ? 'Loading...' : 'Select $label',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            onChanged: enabled ? onChanged : null,
            items: items.map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), style: const TextStyle(fontSize: 14)),
            )).toList(),
          ),
        ),
      ),
    );
  }
}
