import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SellerStoreProfileScreen extends StatefulWidget {
  const SellerStoreProfileScreen({super.key});

  @override
  State<SellerStoreProfileScreen> createState() => _SellerStoreProfileScreenState();
}

class _SellerStoreProfileScreenState extends State<SellerStoreProfileScreen> {
  Map<String, dynamic>? _application;
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (user != null) {
        final app = await ApiService.getApplication(user['id']);
        if (mounted && app != null) {
          setState(() {
            _application = app;
            _nameCtrl.text = app['store_name'] ?? '';
            _descCtrl.text = app['store_description'] ?? '';
            _isLoading = false;
          });
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.postJson('/seller/api/store', {
        'store_name': _nameCtrl.text.trim(),
        'store_description': _descCtrl.text.trim(),
        'open_time': '${_openTime.hour.toString().padLeft(2, '0')}:${_openTime.minute.toString().padLeft(2, '0')}',
        'close_time': '${_closeTime.hour.toString().padLeft(2, '0')}:${_closeTime.minute.toString().padLeft(2, '0')}',
      }, token: token);
      if (mounted) {
        _showSnackBar(res['success'] == true ? 'Store updated!' : (res['error'] ?? 'Failed to save.'),
            isError: res['success'] != true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _openTime = picked;
        } else {
          _closeTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text('Store Profile',
            style: TextStyle(fontFamily: AppTheme.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Read-only info card
                  _infoCard('Store Category', _application?['store_category'] ?? 'N/A'),
                  const SizedBox(height: AppTheme.md),
                  _infoCard('Status', (_application?['status'] ?? 'N/A').toString().toUpperCase()),
                  const SizedBox(height: AppTheme.md),

                  // Editable form
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Store Info',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                        const SizedBox(height: AppTheme.md),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Store Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppTheme.md),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            hintText: 'Tell customers about your store...',
                          ),
                        ),
                        const SizedBox(height: AppTheme.md),
                        const Text('Operating Hours',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _timePicker('Open', _openTime, () => _pickTime(true))),
                            const SizedBox(width: 12),
                            Expanded(child: _timePicker('Close', _closeTime, () => _pickTime(false))),
                          ],
                        ),
                        const SizedBox(height: AppTheme.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryLight,
                              foregroundColor: AppTheme.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isSaving
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2))
                                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _timePicker(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: AppTheme.textLight),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                Text(time.format(context),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
