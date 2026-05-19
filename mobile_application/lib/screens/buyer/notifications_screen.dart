import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/grande_navbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;
  String? _token;
  String? _userId;
  StreamSubscription<void>? _notifSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    RealtimeService.instance.unsubscribeNotifications();
    super.dispose();
  }

  Future<void> _init() async {
    _token = await ApiService.getAuthToken();
    final user = await ApiService.getCurrentUser();
    _userId = user?['id']?.toString();
    await _load();
    if (_userId != null) {
      RealtimeService.instance.subscribeNotifications(userId: _userId!);
      _notifSub = RealtimeService.instance.notificationsStream.listen((_) {
        if (mounted) _load(); // new notification arrived — refresh list
      });
    }
  }

  Future<void> _load() async {
    if (_token == null) {
      _token = await ApiService.getAuthToken();
    }
    if (_token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await ApiService.getBuyerNotifications(_token!);
      if (mounted) {
        setState(() {
          _notifs = List<Map<String, dynamic>>.from(res['notifications'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_token == null) return;
    await ApiService.markBuyerNotifsRead(_token!);
    if (mounted) {
      setState(() {
        for (final n in _notifs) n['is_read'] = true;
      });
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'new_order': return Icons.shopping_bag_outlined;
      case 'status_update': return Icons.local_shipping_outlined;
      case 'payment': return Icons.payment_outlined;
      case 'chat': return Icons.chat_bubble_outline;
      default: return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'new_order': return Colors.green;
      case 'status_update': return Colors.blue;
      case 'payment': return Colors.orange;
      case 'chat': return AppTheme.primaryLight;
      default: return Colors.grey;
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifs.where((n) => n['is_read'] != true).length;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('Notifications'),
          if (unread > 0) ...[ 
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
              child: Text('$unread', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: AppTheme.primaryLight)),
            ),
        ],
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 3),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _token == null
              ? _buildLoginPrompt()
              : _notifs.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final n = _notifs[i];
                          final isRead = n['is_read'] == true;
                          final type = n['notif_type']?.toString();
                          return Container(
                            color: isRead ? Colors.transparent : AppTheme.primaryLight.withValues(alpha: 0.04),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: _colorFor(type).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_iconFor(type), color: _colorFor(type), size: 22),
                              ),
                              title: Text(n['title']?.toString() ?? '',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                      color: AppTheme.textDark)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const SizedBox(height: 2),
                                Text(n['message']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(_timeAgo(n['created_at']?.toString()),
                                    style: TextStyle(fontSize: 11,
                                        color: isRead ? AppTheme.textLight : AppTheme.primaryLight)),
                              ]),
                              trailing: !isRead
                                  ? Container(width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                          color: AppTheme.primaryLight, shape: BoxShape.circle))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmpty() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.notifications_none, size: 64, color: AppTheme.textLight),
      SizedBox(height: 12),
      Text('No notifications yet', style: TextStyle(fontSize: 16, color: AppTheme.textLight)),
      SizedBox(height: 4),
      Text('Order updates and alerts will appear here',
          style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
    ]),
  );

  Widget _buildLoginPrompt() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_outline, size: 48, color: AppTheme.textLight),
      const SizedBox(height: 12),
      const Text('Login to view notifications', style: TextStyle(color: AppTheme.textLight)),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
        child: const Text('Login'),
      ),
    ]),
  );
}
