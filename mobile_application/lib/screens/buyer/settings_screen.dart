import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final String initialSection;
  const SettingsScreen({super.key, this.initialSection = 'profile'});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sectionTitle()),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 1,
      ),
      body: Row(children: [
        // Sidebar (visible on wide screens, drawer on narrow)
        if (MediaQuery.of(context).size.width >= 600)
          _Sidebar(current: _section, onSelect: (s) => setState(() => _section = s)),
        Expanded(child: _buildSection()),
      ]),
      // Drawer for narrow screens
      drawer: MediaQuery.of(context).size.width < 600
          ? Drawer(child: _Sidebar(current: _section, onSelect: (s) {
              setState(() => _section = s);
              Navigator.pop(context);
            }))
          : null,
    );
  }

  String _sectionTitle() {
    switch (_section) {
      case 'password': return 'Change Password';
      case 'notifications': return 'Notification Preferences';
      case 'security': return 'Security';
      default: return 'Edit Profile';
    }
  }

  Widget _buildSection() {
    switch (_section) {
      case 'password':     return const _PasswordSection();
      case 'notifications': return const _NotificationsSection();
      case 'security':     return const _SecuritySection();
      default:             return const _ProfileSection();
    }
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _Sidebar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: AppTheme.textLight, letterSpacing: 0.8)),
        ),
        _item('profile', Icons.person_outline, 'Profile'),
        _item('password', Icons.lock_outline, 'Password'),
        _item('notifications', Icons.notifications_outlined, 'Notifications'),
        _item('security', Icons.shield_outlined, 'Security'),
      ]),
    );
  }

  Widget _item(String key, IconData icon, String label) {
    final active = current == key;
    return InkWell(
      onTap: () => onSelect(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: active ? AppTheme.primaryLight.withValues(alpha: 0.08) : Colors.transparent,
        child: Row(children: [
          Icon(icon, size: 18, color: active ? AppTheme.primaryLight : AppTheme.textLight),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: active ? AppTheme.primaryLight : AppTheme.textDark)),
        ]),
      ),
    );
  }
}

// ── Profile section ───────────────────────────────────────────────────────────
class _ProfileSection extends StatefulWidget {
  const _ProfileSection();
  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _email = '';
  String _gender = '';
  bool _loading = true, _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final token = await ApiService.getAuthToken() ?? '';
    final res = await ApiService.get('/api/buyer/api/profile', token: token);
    final user = res['user'] as Map? ?? {};
    if (mounted) setState(() {
      _nameCtrl.text  = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
      _phoneCtrl.text = user['phone']?.toString() ?? '';
      _email  = user['email']?.toString() ?? '';
      _gender = user['gender']?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final token = await ApiService.getAuthToken() ?? '';
    final res = await ApiService.postJson('/api/buyer/api/profile',
        {'full_name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()}, token: token);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true ? 'Profile updated!' : (res['error'] ?? 'Failed')),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✏️ Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
        const SizedBox(height: 16),
        _f(_nameCtrl, 'Full Name'),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _email,
          enabled: false,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        _f(_phoneCtrl, 'Phone Number', type: TextInputType.phone),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _gender.isEmpty ? null : _gender,
          decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'male',   child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other',  child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _gender = v ?? ''),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _f(TextEditingController c, String label, {TextInputType? type}) =>
      TextField(controller: c, keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
}

// ── Password section ──────────────────────────────────────────────────────────
class _PasswordSection extends StatefulWidget {
  const _PasswordSection();
  @override
  State<_PasswordSection> createState() => _PasswordSectionState();
}

class _PasswordSectionState extends State<_PasswordSection> {
  final _curCtrl  = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _saving = false;
  bool _obscCur = true, _obscNew = true, _obscConf = true;

  @override
  void dispose() { _curCtrl.dispose(); _newCtrl.dispose(); _confCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_newCtrl.text != _confCtrl.text) {
      _toast('Passwords do not match.', error: true); return;
    }
    setState(() => _saving = true);
    final token = await ApiService.getAuthToken() ?? '';
    final res = await ApiService.postJson('/api/buyer/api/password',
        {'current_password': _curCtrl.text, 'new_password': _newCtrl.text}, token: token);
    if (mounted) {
      setState(() => _saving = false);
      _toast(res['success'] == true ? 'Password changed!' : (res['error'] ?? 'Failed'),
          error: res['success'] != true);
      if (res['success'] == true) { _curCtrl.clear(); _newCtrl.clear(); _confCtrl.clear(); }
    }
  }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔑 Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _pwField(_curCtrl,  'Current Password', _obscCur,  (v) => setState(() => _obscCur  = v)),
        const SizedBox(height: 12),
        _pwField(_newCtrl,  'New Password',     _obscNew,  (v) => setState(() => _obscNew  = v)),
        const SizedBox(height: 12),
        _pwField(_confCtrl, 'Confirm New Password', _obscConf, (v) => setState(() => _obscConf = v)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _pwField(TextEditingController c, String label, bool obscure, ValueChanged<bool> toggle) =>
      TextField(
        controller: c, obscureText: obscure,
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => toggle(!obscure),
          ),
        ),
      );
}

// ── Notifications section ─────────────────────────────────────────────────────
class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();
  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  final _prefs = [true, true, false, true]; // matches web defaults

  static const _items = [
    ('Order Updates',       'Get notified when your order status changes'),
    ('Promotions & Deals',  'Receive exclusive offers and discounts'),
    ('New Arrivals',        'Be the first to know about new products'),
    ('Email Notifications', 'Receive notifications via email'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔔 Notification Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...List.generate(_items.length, (i) => Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_items[i].$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(_items[i].$2, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ])),
            Switch(
              value: _prefs[i],
              onChanged: (v) => setState(() => _prefs[i] = v),
              activeColor: AppTheme.primaryLight,
            ),
          ]),
          if (i < _items.length - 1) const Divider(height: 16),
        ])),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification preferences saved!'),
                    backgroundColor: Colors.green)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Security section ──────────────────────────────────────────────────────────
class _SecuritySection extends StatelessWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🛡️ Security Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _row('Two-Factor Authentication', 'Add an extra layer of security', false, (_) {}),
        const Divider(height: 24),
        _row('Login Alerts', 'Get notified of new logins to your account', true, (_) {}),
        const Divider(height: 24),
        const Text('Active Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Manage devices where you\'re logged in',
            style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFe8e8f0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(children: [
            Icon(Icons.phone_android, size: 18, color: AppTheme.textLight),
            SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current Device', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('Mobile App · Active now', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out All Devices'),
                  content: const Text('You will be logged out from all devices.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('Sign Out All')),
                  ],
                ));
            if (ok == true && context.mounted) {
              await ApiService.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            }
          },
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          child: const Text('Sign Out All Devices'),
        ),
        const Divider(height: 32),
        const Text('Delete Account',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
        const SizedBox(height: 4),
        const Text('Permanently delete your account and all data',
            style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final input = await showDialog<String>(context: context,
                builder: (ctx) {
                  final ctrl = TextEditingController();
                  return AlertDialog(
                    title: const Text('Delete Account'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Type DELETE to confirm permanently deleting your account.'),
                      const SizedBox(height: 12),
                      TextField(controller: ctrl,
                          decoration: const InputDecoration(hintText: 'DELETE', border: OutlineInputBorder())),
                    ]),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text('Delete')),
                    ],
                  );
                });
            if (input != 'DELETE' || !context.mounted) return;
            final token = await ApiService.getAuthToken() ?? '';
            final res = await ApiService.delete('/api/buyer/api/account', token: token);
            if (context.mounted) {
              if (res['success'] == true) {
                await ApiService.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res['error'] ?? 'Failed'), backgroundColor: Colors.red));
              }
            }
          },
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          child: const Text('Delete My Account'),
        ),
      ]),
    );
  }

  Widget _row(String title, String sub, bool val, ValueChanged<bool> onChanged) {
    return StatefulBuilder(builder: (_, set) => Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
      ])),
      Switch(value: val, onChanged: (v) { set(() {}); onChanged(v); }, activeColor: AppTheme.primaryLight),
    ]));
  }
}
