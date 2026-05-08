import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _filter = 'all';
  final _searchCtrl = TextEditingController();
  StreamSubscription<void>? _realtimeSub;
  StreamSubscription<void>? _usersSub;

  static const _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': 'buyer', 'label': 'Buyers'},
    {'key': 'seller', 'label': 'Sellers'},
    {'key': 'rider', 'label': 'Riders'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
    RealtimeService.instance.subscribeApplications();
    RealtimeService.instance.subscribeUsers();
    _realtimeSub = RealtimeService.instance.applicationsStream.listen((_) { if (mounted) _load(); });
    _usersSub = RealtimeService.instance.usersStream.listen((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _realtimeSub?.cancel();
    _usersSub?.cancel();
    RealtimeService.instance.unsubscribeApplications();
    RealtimeService.instance.unsubscribeUsers();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() => _isLoading = false); return; }
      final res = await ApiService.get('/api/admin/applications', token: token);
      final data = res is List ? res : (res['applications'] is List ? res['applications'] : []);
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _filter == 'all' ? _users : _users.where((u) => u['role'] == _filter).toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) =>
        (u['full_name'] ?? '').toString().toLowerCase().contains(q) ||
        (u['email'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.postJson('/api/admin/applications/$id/status', {'status': status}, token: token);
      if (mounted) {
        _showSnackBar(res['success'] == true ? 'Updated successfully.' : (res['error'] ?? 'Failed.'), isError: res['success'] != true);
        if (res['success'] == true) _load();
      }
    } catch (e) { if (mounted) _showSnackBar('Error: $e', isError: true); }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a3e),
        elevation: 0,
        title: const Text('Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppTheme.md),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sm, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _filters.map((f) {
                    final isActive = _filter == f['key'];
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f['key']!),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF1a1a3e) : AppTheme.grayLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(f['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppTheme.textDark)),
                      ),
                    );
                  }).toList()),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No users found.', style: TextStyle(color: AppTheme.textLight)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _userTile(_filtered[i]),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final role = u['role']?.toString() ?? '';
    final status = u['status']?.toString() ?? '';
    final roleColors = {'seller': Colors.orange, 'rider': Colors.purple, 'buyer': Colors.blue};
    final color = roleColors[role] ?? Colors.grey;
    final isApproved = status == 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd), boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(u['email'] ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
        ])),
        TextButton(
          onPressed: () => _updateStatus(u['id'], isApproved ? 'rejected' : 'approved'),
          style: TextButton.styleFrom(foregroundColor: isApproved ? Colors.red : Colors.green),
          child: Text(isApproved ? 'Suspend' : 'Activate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
