import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class RiderProfileScreen extends StatefulWidget {
  final bool embedded;
  const RiderProfileScreen({super.key, this.embedded = false});
  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();
  final _licenseNumCtrl = TextEditingController();
  final _licenseExpiryCtrl = TextEditingController();
  File? _licenseImage;

  String _vehicleType = 'motorcycle';
  Map<String, dynamic> _perf = {};
  Map<String, bool> _schedule = {
    'Mon': true, 'Tue': true, 'Wed': true, 'Thu': true,
    'Fri': true, 'Sat': true, 'Sun': true,
  };
  bool _loading = true;
  String _token = '';
  String? _profilePicture;
  bool _uploadingPic = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _licenseNumCtrl.dispose();
    _licenseExpiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _token = await ApiService.getAuthToken() ?? '';
    if (_token.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final profile = await ApiService.riderGetProfile(_token);
      final perf = await ApiService.riderGetPerformance(_token);
      if (!mounted) return;
      setState(() {
        _perf = perf;
        _nameCtrl.text = profile['name']?.toString() ?? '';
        _emailCtrl.text = profile['email']?.toString() ?? '';
        _phoneCtrl.text = profile['phone']?.toString() ?? '';
        final v = profile['vehicle'] is Map
            ? Map<String, dynamic>.from(profile['vehicle'] as Map)
            : <String, dynamic>{};
        _vehicleType = v['type']?.toString().isNotEmpty == true ? v['type'].toString() : 'motorcycle';
        _vehiclePlateCtrl.text = v['plate']?.toString() ?? '';
        _vehicleModelCtrl.text = v['model']?.toString() ?? '';
        _vehicleColorCtrl.text = v['color']?.toString() ?? '';
        final l = profile['license'] is Map
            ? Map<String, dynamic>.from(profile['license'] as Map)
            : <String, dynamic>{};
        _licenseNumCtrl.text = l['number']?.toString() ?? '';
        _licenseExpiryCtrl.text = l['expiry']?.toString() ?? '';
        final s = profile['schedule'] is Map
            ? Map<String, dynamic>.from(profile['schedule'] as Map)
            : <String, dynamic>{};
        _schedule = {
          'Mon': s['Mon'] != false, 'Tue': s['Tue'] != false,
          'Wed': s['Wed'] != false, 'Thu': s['Thu'] != false,
          'Fri': s['Fri'] != false, 'Sat': s['Sat'] != false,
          'Sun': s['Sun'] != false,
        };
        _profilePicture = profile['profile_picture'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadPicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPic = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.flaskBaseUrl}/api/profile/picture'),
      );
      req.headers['Authorization'] = 'Bearer $_token';
      req.files.add(await http.MultipartFile.fromPath('photo', picked.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200 && mounted) {
        final url = RegExp(r'"profile_picture"\s*:\s*"([^"]+)"')
            .firstMatch(body)
            ?.group(1);
        if (url != null) setState(() => _profilePicture = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'),
              backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPic = false);
    }
  }

  void _snack(Map<String, dynamic> res) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message']?.toString() ?? (res['success'] == true ? 'Saved' : 'Failed')),
    ));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Yes, Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ApiService.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  Future<void> _savePersonal() async =>
      _snack(await ApiService.riderSaveProfile(_token, {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      }));

  Future<void> _saveVehicle() async =>
      _snack(await ApiService.riderSaveProfile(_token, {
        'vehicle': {
          'type': _vehicleType,
          'plate': _vehiclePlateCtrl.text.trim(),
          'model': _vehicleModelCtrl.text.trim(),
          'color': _vehicleColorCtrl.text.trim(),
        },
      }));

  Future<void> _saveLicense() async =>
      _snack(await ApiService.riderSaveProfile(_token, {
        'license': {
          'number': _licenseNumCtrl.text.trim(),
          'expiry': _licenseExpiryCtrl.text,
        },
      }));

  Future<void> _pickLicenseImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _licenseImage = File(picked.path));
    }
  }

  Future<void> _saveSchedule() async =>
      _snack(await ApiService.riderSaveProfile(_token, {'schedule': _schedule}));

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('👤 Personal Info', [
                  // Avatar upload
                  Center(
                    child: GestureDetector(
                      onTap: _pickAndUploadPicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
                            backgroundImage: _profilePicture != null && _profilePicture!.isNotEmpty
                                ? NetworkImage(_profilePicture!) as ImageProvider
                                : null,
                            child: _profilePicture == null || _profilePicture!.isEmpty
                                ? Text(
                                    _nameCtrl.text.isNotEmpty
                                        ? _nameCtrl.text[0].toUpperCase()
                                        : 'R',
                                    style: const TextStyle(
                                        fontSize: 32, fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryLight),
                                  )
                                : null,
                          ),
                          if (_uploadingPic)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field('Full Name', _nameCtrl),
                  _field('Email', _emailCtrl, type: TextInputType.emailAddress),
                  _field('Phone', _phoneCtrl, type: TextInputType.phone),
                  _saveBtn('Save Personal Info', _savePersonal),
                ]),
                const SizedBox(height: 16),
                _section('⭐ Performance', [
                  Row(children: [
                    _perfTile('${_perf['avg_rating'] ?? '—'}', 'Avg Rating'),
                    _perfTile('${_perf['total_deliveries'] ?? 0}', 'Total Deliveries'),
                    _perfTile(
                      _perf['acceptance_rate'] != null ? '${_perf['acceptance_rate']}%' : '—%',
                      'Accept Rate',
                    ),
                    _perfTile(
                      _perf['late_percentage'] != null ? '${_perf['late_percentage']}%' : '—%',
                      'Late %',
                    ),
                  ]),
                ]),
                const SizedBox(height: 16),
                _section('🏍️ Vehicle Details', [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      value: _vehicleType,
                      decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                      items: ['motorcycle', 'bicycle', 'scooter', 'car']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _vehicleType = v ?? 'motorcycle'),
                    ),
                  ),
                  _field('Plate Number', _vehiclePlateCtrl),
                  _field('Brand / Model', _vehicleModelCtrl),
                  _field('Color', _vehicleColorCtrl),
                  _saveBtn('Save Vehicle', _saveVehicle),
                ]),
                const SizedBox(height: 16),
                _section('📄 License & Documents', [
                  _field('License Number', _licenseNumCtrl),
                  _field('License Expiry (YYYY-MM-DD)', _licenseExpiryCtrl),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickLicenseImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(_licenseImage != null ? Icons.check_circle : Icons.camera_alt, 
                              color: _licenseImage != null ? Colors.green : AppTheme.textLight, size: 32),
                          const SizedBox(height: 8),
                          Text(_licenseImage != null ? 'License photo selected' : 'Tap to upload license photo',
                              style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _saveBtn('Save License', _saveLicense),
                ]),
                const SizedBox(height: 16),
                _section('🗓️ Availability Schedule', [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _schedule.keys.map((day) => FilterChip(
                      label: Text(day),
                      selected: _schedule[day] ?? true,
                      onSelected: (v) => setState(() => _schedule[day] = v),
                      selectedColor: AppTheme.primaryLight.withOpacity(0.2),
                      checkmarkColor: AppTheme.primaryLight,
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  _saveBtn('Save Schedule', _saveSchedule),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Log out',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );

    if (widget.embedded) return SafeArea(child: body);
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: AppTheme.cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  Widget _field(String label, TextEditingController ctrl, {TextInputType type = TextInputType.text}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget _saveBtn(String label, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    ),
  );

  Widget _perfTile(String val, String label) => Expanded(
    child: Column(children: [
      Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight), textAlign: TextAlign.center),
    ]),
  );
}
