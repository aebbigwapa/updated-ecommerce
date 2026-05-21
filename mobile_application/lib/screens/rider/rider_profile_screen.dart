import 'dart:convert';
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

  Map<String, dynamic> _perf = {};
  Map<String, dynamic> _earningsSummary = {};
  bool _loading = true;
  String _token = '';
  String? _profilePicture;
  bool _uploadingPic = false;
  bool _isActive = true;

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
    super.dispose();
  }

  Future<void> _load() async {
    _token = await ApiService.getAuthToken() ?? '';
    if (_token.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.riderGetProfile(_token),
        ApiService.riderGetPerformance(_token),
        _fetchEarningsSummary(),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final perf = results[1] as Map<String, dynamic>;
      final earnings = results[2] as Map<String, dynamic>;
      setState(() {
        _perf = perf;
        _earningsSummary = earnings;
        _nameCtrl.text = profile['name']?.toString() ?? '';
        _emailCtrl.text = profile['email']?.toString() ?? '';
        _phoneCtrl.text = profile['phone']?.toString() ?? '';
        _profilePicture = profile['profile_picture'] as String?;
        _isActive = profile['is_available'] != false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchEarningsSummary() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/api/rider/earnings'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body);
      final data = body['data'];
      return data is Map<String, dynamic> ? data : (data is Map ? Map<String, dynamic>.from(data) : {});
    } catch (_) { return {}; }
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

  String _fmt(dynamic v) { try { return double.parse(v.toString()).toStringAsFixed(2); } catch (_) { return '0.00'; } }

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

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Profile Header ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1a1a3e), Color(0xFF2d2d6e)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    GestureDetector(
                      onTap: _pickAndUploadPicture,
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: _profilePicture != null && _profilePicture!.isNotEmpty
                              ? NetworkImage(_profilePicture!) as ImageProvider
                              : null,
                          child: _profilePicture == null || _profilePicture!.isEmpty
                              ? Text(
                                  _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'R',
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                                )
                              : null,
                        ),
                        if (_uploadingPic)
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                            child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          )),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Rider',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isActive ? Colors.green.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _isActive ? Colors.green : Colors.grey),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 7, height: 7,
                            decoration: BoxDecoration(color: _isActive ? Colors.greenAccent : Colors.grey, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(_isActive ? 'Active' : 'Inactive',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: _isActive ? Colors.greenAccent : Colors.grey.shade300)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Basic Info ──────────────────────────────────
                _section('👤 Basic Information', [
                  _field('Full Name', _nameCtrl),
                  _field('Email', _emailCtrl, type: TextInputType.emailAddress),
                  _field('Phone', _phoneCtrl, type: TextInputType.phone),
                  _saveBtn('Save', _savePersonal),
                ]),
                const SizedBox(height: 16),

                // ── Performance Summary ─────────────────────────
                _section('📊 Performance Summary', [
                  Row(children: [
                    _perfTile('${_perf['avg_rating'] ?? '—'}', 'Avg Rating'),
                    _perfTile('${_perf['total_deliveries'] ?? 0}', 'Deliveries'),
                    _perfTile(_perf['acceptance_rate'] != null ? '${_perf['acceptance_rate']}%' : '—%', 'Accept Rate'),
                    _perfTile(_perf['late_percentage'] != null ? '${_perf['late_percentage']}%' : '—%', 'Late %'),
                  ]),
                ]),
                const SizedBox(height: 16),

                // ── Earnings Overview ───────────────────────────
                _section('💰 Earnings Overview', [
                  Row(children: [
                    _earningTile('Today', '₱${_fmt(_earningsSummary['today'])}', Colors.indigo),
                    const SizedBox(width: 8),
                    _earningTile('This Week', '₱${_fmt(_earningsSummary['week'])}', Colors.teal),
                    const SizedBox(width: 8),
                    _earningTile('This Month', '₱${_fmt(_earningsSummary['month'])}', Colors.orange),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total Earnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      Text('₱${_fmt(_earningsSummary['total'])}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Logout ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Log out',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight), textAlign: TextAlign.center),
    ]),
  );

  Widget _earningTile(String label, String val, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
      ]),
    ),
  );
}
