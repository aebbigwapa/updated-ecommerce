import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';

class AdminRidersScreen extends StatefulWidget {
  const AdminRidersScreen({super.key});
  @override
  State<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends State<AdminRidersScreen> {
  List<Map<String, dynamic>> _riders = [];
  bool _isLoading = true;
  StreamSubscription<void>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeService.instance.subscribeApplications();
    _realtimeSub = RealtimeService.instance.applicationsStream.listen((_) { if (mounted) _load(); });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeApplications();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final res = await ApiService.get('/api/admin/applications', token: token);
      final data = res is List ? res : (res['applications'] is List ? res['applications'] : []);
      if (mounted) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(data).where((a) => a['role'] == 'rider').toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status, {String notes = ''}) async {
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final res = await ApiService.postJson('/api/admin/applications/$id/status', {'status': status, 'notes': notes}, token: token);
      if (mounted) {
        _showSnackBar(res['success'] == true ? 'Updated.' : (res['error'] ?? 'Failed.'), isError: res['success'] != true);
        if (res['success'] == true) _load();
      }
    } catch (e) { if (mounted) _showSnackBar('Error: $e', isError: true); }
  }

  void _showRejectDialog(String id) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
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
    ));
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
        title: const Text('Riders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _riders.isEmpty
              ? const Center(child: Text('No riders yet.', style: TextStyle(color: AppTheme.textLight)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.md),
                    itemCount: _riders.length,
                    itemBuilder: (_, i) => _riderTile(_riders[i]),
                  ),
                ),
    );
  }

  Widget _riderTile(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    final statusColors = {'pending': Colors.orange, 'approved': Colors.green, 'rejected': Colors.red};
    final color = statusColors[status] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sm),
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMd), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(r['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
        ]),
        Text(r['email'] ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
        const SizedBox(height: 4),
        Row(children: [
          Text('🏍️ ${r['vehicle_type'] ?? '—'}', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          Text('📋 ${r['license_number'] ?? '—'}', style: const TextStyle(fontSize: 12)),
        ]),
        if (status == 'pending') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => _updateStatus(r['id'], 'approved'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 8)),
              child: const Text('Approve', style: TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () => _showRejectDialog(r['id']),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 8)),
              child: const Text('Reject', style: TextStyle(fontSize: 12)),
            )),
          ]),
        ],
      ]),
    );
  }
}
