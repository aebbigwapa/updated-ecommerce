import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});
  @override
  State<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  List<Map<String, dynamic>> _apps = [];
  bool _isLoading = true;
  String _filter = 'all';
  StreamSubscription<void>? _realtimeSub;

  static const _filters = [
    {'key': 'all', 'label': 'All'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'approved', 'label': 'Approved'},
    {'key': 'rejected', 'label': 'Rejected'},
  ];

  @override
  void initState() { super.initState(); _load(); RealtimeService.instance.subscribeApplications(); _realtimeSub = RealtimeService.instance.applicationsStream.listen((_) { if (mounted) _load(); }); }

  @override
  void dispose() { _realtimeSub?.cancel(); RealtimeService.instance.unsubscribeApplications(); super.dispose(); }

  Future<void> _load() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) { if (mounted) setState(() => _isLoading = false); return; }
      final res = await ApiService.get('/api/admin/applications', token: token);
      final data = res is List ? res : (res['applications'] is List ? res['applications'] : []);
      if (mounted) setState(() { _apps = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'all' ? _apps : _apps.where((a) => a['status'] == _filter).toList();

  int _count(String status) => _apps.where((a) => a['status'] == status).length;

  Future<void> _updateStatus(String id, String status, {String notes = ''}) async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.postJson(
          '/api/admin/applications/$id/status', {'status': status, 'notes': notes}, token: token);
      if (mounted) {
        _showSnackBar(res['success'] == true ? '${status[0].toUpperCase()}${status.substring(1)} successfully.' : (res['error'] ?? 'Failed.'),
            isError: res['success'] != true);
        if (res['success'] == true) _load();
      }
    } catch (e) { if (mounted) _showSnackBar('Error: $e', isError: true); }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green));
  }

  void _showRejectDialog(String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason (optional)'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _updateStatus(id, 'rejected', notes: ctrl.text.trim()); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text('Application Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Divider(),
              _detailRow('Name', a['full_name'] ?? '—'),
              _detailRow('Email', a['email'] ?? '—'),
              _detailRow('Phone', a['phone'] ?? '—'),
              _detailRow('Role', a['role'] ?? '—'),
              _detailRow('Status', a['status'] ?? '—'),
              _detailRow('Applied', (a['created_at'] ?? '').toString().split('T')[0]),
              if (a['role'] == 'seller') ...[
                const Divider(),
                const Text('Store Details', style: TextStyle(fontWeight: FontWeight.w600)),
                _detailRow('Store Name', a['store_name'] ?? '—'),
                _detailRow('Category', a['store_category'] ?? '—'),
                _detailRow('Description', a['store_description'] ?? '—'),
              ],
              if (a['role'] == 'rider') ...[
                const Divider(),
                const Text('Rider Details', style: TextStyle(fontWeight: FontWeight.w600)),
                _detailRow('Vehicle', a['vehicle_type'] ?? '—'),
                _detailRow('License', a['license_number'] ?? '—'),
              ],
              if (a['status'] == 'pending') ...[
                const SizedBox(height: AppTheme.md),
                Row(children: [
                  Expanded(child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _updateStatus(a['id'], 'approved'); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('✅ Approve'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _showRejectDialog(a['id']); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('❌ Reject'),
                  )),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grayLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a3e),
        elevation: 0,
        title: const Text('Applications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : Column(children: [
              // Stats
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppTheme.md),
                child: Row(children: [
                  _statChip('Total', '${_apps.length}', Colors.blue),
                  _statChip('Pending', '${_count('pending')}', Colors.orange),
                  _statChip('Approved', '${_count('approved')}', Colors.green),
                  _statChip('Rejected', '${_count('rejected')}', Colors.red),
                ]),
              ),
              // Filter tabs
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
                    ? const Center(child: Text('No applications found.', style: TextStyle(color: AppTheme.textLight)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.md),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _appTile(_filtered[i]),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _statChip(String label, String value, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
      ]),
    ),
  );

  Widget _appTile(Map<String, dynamic> a) {
    final role = a['role']?.toString() ?? '';
    final status = a['status']?.toString() ?? '';
    final roleColors = {'seller': Colors.orange, 'rider': Colors.purple, 'buyer': Colors.blue};
    final statusColors = {'pending': Colors.orange, 'approved': Colors.green, 'rejected': Colors.red};
    final color = roleColors[role] ?? Colors.grey;
    final sColor = statusColors[status] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd), boxShadow: AppTheme.cardShadow),
      child: ListTile(
        onTap: () => _showDetail(a),
        title: Text(a['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(a['email'] ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: sColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor))),
        ]),
      ),
    );
  }
}
