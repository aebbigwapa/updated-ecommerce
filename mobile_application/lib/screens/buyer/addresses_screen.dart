import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

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
  final _label    = TextEditingController();
  final _region   = TextEditingController();
  final _city     = TextEditingController();
  final _barangay = TextEditingController();
  final _street   = TextEditingController();
  final _zip      = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _label.text    = e['label']?.toString()    ?? '';
      _region.text   = e['region']?.toString()   ?? '';
      _city.text     = e['city']?.toString()     ?? '';
      _barangay.text = e['barangay']?.toString() ?? '';
      _street.text   = e['street']?.toString()   ?? '';
      _zip.text      = e['zip_code']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _label.dispose(); _region.dispose(); _city.dispose();
    _barangay.dispose(); _street.dispose(); _zip.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fields = {
      'label': _label.text.trim(), 'region': _region.text.trim(),
      'city': _city.text.trim(), 'barangay': _barangay.text.trim(),
      'street': _street.text.trim(), 'zip_code': _zip.text.trim(),
    };
    if (fields.values.any((v) => v.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all fields.'), backgroundColor: Colors.red));
      return;
    }
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
      if (success) {
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? 'Failed to save address.'), backgroundColor: Colors.red));
      }
    }
  }

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
          _f(_label,    'Label (e.g. Home, Office)'),
          _f(_region,   'Region'),
          _f(_city,     'City / Municipality'),
          _f(_barangay, 'Barangay'),
          _f(_street,   'Street / House No.'),
          _f(_zip,      'ZIP Code', type: TextInputType.number),
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

  Widget _f(TextEditingController ctrl, String label, {TextInputType? type}) =>
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
}
