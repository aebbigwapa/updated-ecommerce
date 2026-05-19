import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/grande_navbar.dart';

// ── Role badge colours (matches web role-badge CSS) ──────────────────────────
const _roleBgColors = {
  'buyer':  Color(0xFFE3F2FD),
  'seller': Color(0xFFF3E5F5),
  'rider':  Color(0xFFE8F5E9),
  'admin':  Color(0xFFFFF3E0),
};
const _roleTextColors = {
  'buyer':  Color(0xFF1565C0),
  'seller': Color(0xFF6A1B9A),
  'rider':  Color(0xFF2E7D32),
  'admin':  Color(0xFFE65100),
};

Widget _roleBadge(String role) {
  if (role.isEmpty) return const SizedBox.shrink();
  final bg   = _roleBgColors[role]  ?? const Color(0xFFEEEEEE);
  final text = _roleTextColors[role] ?? const Color(0xFF333333);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(role.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: text)),
  );
}

// ── Conversation list screen ──────────────────────────────────────────────────
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _token;
  String? _userId;
  String? _userRole;
  StreamSubscription<Map<String, dynamic>>? _msgSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    RealtimeService.instance.unsubscribeMessages();
    super.dispose();
  }

  Future<void> _init() async {
    _token = await ApiService.getAuthToken();
    final prefs = await SharedPreferences.getInstance();
    _userId   = prefs.getString('user_id');
    _userRole = prefs.getString('user_role');

    if (_token == null || _userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    await _load();

    RealtimeService.instance.subscribeConversations(userId: _userId!);
    _msgSub = RealtimeService.instance.messagesStream.listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final list = data is List
            ? List<Map<String, dynamic>>.from(
                data.map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        // Admin gets participant_1_data / participant_2_data — normalize to other_user
        if (_userRole == 'admin') {
          for (final c in list) {
            if (c['other_user'] == null) {
              // Pick the non-admin participant as other_user
              final p1 = c['participant_1_data'] as Map?;
              final p2 = c['participant_2_data'] as Map?;
              c['other_user'] = (p1?['role'] != 'admin' ? p1 : p2) ?? p1 ?? p2 ?? {};
            }
          }
        }
        setState(() { _conversations = list; _loading = false; });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 3),
      floatingActionButton: _token != null
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryLight,
              onPressed: _startNewChat,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _token == null
              ? _buildLoginPrompt()
              : _conversations.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) => _ConvTile(
                          conv: _conversations[i],
                          token: _token!,
                          onRefresh: _load,
                        ),
                      ),
                    ),
    );
  }

  Future<void> _startNewChat() async {
    if (_token == null) return;
    // Buyers can only contact support; sellers/admins get a user picker
    if (_userRole == 'buyer') {
      await _openOrCreateChat(null, 'Support', 'admin');
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/users'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 403) {
        await _openOrCreateChat(null, 'Support', 'admin');
        return;
      }
      final users = List<Map<String, dynamic>>.from(
          (jsonDecode(res.body) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => _UserPickerSheet(users: users),
      );
      if (selected == null || !mounted) return;
      final name = '${selected['first_name'] ?? ''} ${selected['last_name'] ?? ''}'.trim();
      final role = selected['role']?.toString() ?? '';
      await _openOrCreateChat(selected['id']?.toString(), name, role);
    } catch (_) {
      if (mounted) await _openOrCreateChat(null, 'Support', 'admin');
    }
  }

  Future<void> _openOrCreateChat(String? otherId, String name, String role) async {
    String? targetId = otherId;
    if (targetId == null) {
      // Find admin user id
      try {
        final res = await http.get(
          Uri.parse('${ApiService.flaskBaseUrl}/messages/api/admin-user-id'),
        ).timeout(const Duration(seconds: 10));
        final body = jsonDecode(res.body);
        targetId = body['admin_id']?.toString();
      } catch (_) {}
    }
    if (targetId == null || !mounted) return;
    try {
      final res = await http.post(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations/start'),
        headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
        body: jsonEncode({'other_id': targetId}),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 200) {
        final conv = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(
            convId: conv['id']?.toString() ?? '',
            otherName: name,
            otherRole: role,
            token: _token!,
          ),
        )).then((_) => _load());
      }
    } catch (_) {}
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.textLight),
          const SizedBox(height: 12),
          const Text('No messages yet',
              style: TextStyle(fontSize: 16, color: AppTheme.textLight)),
          const SizedBox(height: 8),
          const Text('Messages from sellers, riders and support appear here',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _buildLoginPrompt() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline, size: 48, color: AppTheme.textLight),
          const SizedBox(height: 12),
          const Text('Login to view messages',
              style: TextStyle(color: AppTheme.textLight)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
            child: const Text('Login'),
          ),
        ]),
      );
}

// ── Conversation tile ─────────────────────────────────────────────────────────
class _ConvTile extends StatelessWidget {
  final Map<String, dynamic> conv;
  final String token;
  final VoidCallback onRefresh;
  const _ConvTile({required this.conv, required this.token, required this.onRefresh});

  String _displayName(Map other) {
    final role = other['role']?.toString() ?? '';
    if (role == 'seller') {
      final store = other['store_name']?.toString() ?? '';
      if (store.isNotEmpty) return store;
    }
    final name = '${other['first_name'] ?? ''} ${other['last_name'] ?? ''}'.trim();
    return name.isNotEmpty ? name : 'Support';
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final other   = conv['other_user'] as Map? ?? {};
    final name    = _displayName(other);
    final role    = other['role']?.toString() ?? '';
    final lastMsg = conv['last_message']?.toString() ?? '';
    final unread  = (conv['unread_count'] as num? ?? 0).toInt();
    final pic     = other['profile_picture']?.toString();
    final time    = _timeAgo(conv['updated_at']?.toString());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
        backgroundImage: pic != null && pic.isNotEmpty ? NetworkImage(pic) : null,
        child: pic == null || pic.isEmpty
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w700))
            : null,
      ),
      title: Row(children: [
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                color: AppTheme.textDark))),
        const SizedBox(width: 6),
        _roleBadge(role),
      ]),
      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12,
              color: unread > 0 ? AppTheme.textDark : AppTheme.textLight,
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: Text('$unread',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          convId: conv['id']?.toString() ?? '',
          otherName: name,
          otherRole: role,
          token: token,
        ),
      )).then((_) => onRefresh()),
    );
  }
}

class _UserPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  const _UserPickerSheet({required this.users});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Select recipient',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: users.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No users available.',
                          style: TextStyle(color: AppTheme.textLight)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                        final role = user['role']?.toString() ?? '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                          title: Text(name.isNotEmpty ? name : 'Unknown user'),
                          subtitle: role.isNotEmpty ? Text(role) : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(user),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Chat thread screen — REALTIME via Supabase ────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String convId;
  final String otherName;
  final String otherRole;
  final String token;
  const ChatScreen({
    super.key,
    required this.convId,
    required this.otherName,
    required this.otherRole,
    required this.token,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _myId;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService.instance.unsubscribeMessages();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('user_id');
    await _loadMessages();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    // Subscribe to Supabase Realtime for this conversation
    RealtimeService.instance.subscribeMessages(convId: widget.convId);
    _realtimeSub = RealtimeService.instance.messagesStream.listen((record) async {
      if (!mounted) return;
      // Fetch sender info for the new message (record from DB has no joins)
      final senderId = record['sender_id']?.toString();
      Map<String, dynamic>? senderInfo;
      if (senderId != null) {
        try {
          final res = await ApiService.client
              .from('users')
              .select('id, first_name, last_name, role, profile_picture')
              .eq('id', senderId)
              .single();
          senderInfo = Map<String, dynamic>.from(res);
        } catch (_) {}
      }
      final enriched = Map<String, dynamic>.from(record);
      if (senderInfo != null) enriched['sender'] = senderInfo;

      if (mounted) {
        // Only add if not already in list (avoid duplicates from own sends)
        final alreadyExists = _messages.any((m) => m['id'] == enriched['id']);
        if (!alreadyExists) {
          setState(() => _messages.add(enriched));
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations/${widget.convId}/messages'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _messages = data is List
              ? List<Map<String, dynamic>>.from(
                  data.map((e) => Map<String, dynamic>.from(e as Map)))
              : [];
          _loading = false;
        });
        _scrollToBottom();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      final res = await http.post(
        Uri.parse('${ApiService.flaskBaseUrl}/messages/api/flutter/conversations/${widget.convId}/messages'),
        headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'content': text}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 201 && mounted) {
        final msg = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        // Add immediately (Realtime will also fire but duplicate check handles it)
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Flexible(child: Text(widget.otherName, overflow: TextOverflow.ellipsis)),
          if (widget.otherRole.isNotEmpty) ...[
            const SizedBox(width: 8),
            _roleBadge(widget.otherRole),
          ],
        ]),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
              : _messages.isEmpty
                  ? const Center(child: Text('No messages yet. Say hello!',
                        style: TextStyle(color: AppTheme.textLight)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: _messages[i],
                        isMe: _messages[i]['sender_id']?.toString() == _myId,
                      ),
                    ),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildInput() => Container(
        padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1, maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: AppTheme.textLight),
                filled: true, fillColor: AppTheme.grayLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: _sending
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      );
}

// ── Message bubble with sender label ─────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final content    = msg['content']?.toString() ?? '';
    final time       = _formatTime(msg['created_at']?.toString());
    final sender     = msg['sender'] as Map? ?? {};
    final role       = sender['role']?.toString() ?? '';
    final senderName = '${sender['first_name'] ?? ''} ${sender['last_name'] ?? ''}'.trim();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && (senderName.isNotEmpty || role.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (senderName.isNotEmpty)
                    Text(senderName, style: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                  if (senderName.isNotEmpty && role.isNotEmpty) const SizedBox(width: 4),
                  if (role.isNotEmpty) _roleBadge(role),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryLight : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(content, style: TextStyle(fontSize: 14,
                    color: isMe ? Colors.white : AppTheme.textDark)),
                const SizedBox(height: 4),
                Text(time, style: TextStyle(fontSize: 10,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textLight)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
