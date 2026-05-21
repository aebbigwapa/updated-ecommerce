import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/grande_navbar.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool    _isLoading = true;
  bool    _isLoggedIn = false;
  String  _firstName = '';
  String  _lastName  = '';
  String  _email     = '';
  String  _role      = '';
  String? _profilePicture;
  bool    _uploadingPic = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (!mounted) return;
    if (userId.isEmpty) {
      setState(() { _isLoggedIn = false; _isLoading = false; });
      return;
    }
    setState(() => _isLoggedIn = true);
    await _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await ApiService.getCurrentUser();
      if (data != null && mounted) {
        setState(() {
          _firstName      = data['first_name'] ?? '';
          _lastName       = data['last_name']  ?? '';
          _email          = data['email']      ?? '';
          _role           = data['role']       ?? '';
          _profilePicture = data['profile_picture'] as String?;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPic = true);
    try {
      final token = await ApiService.getAuthToken();
      if (token == null) return;
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.flaskBaseUrl}/api/profile/picture'),
      );
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath('photo', picked.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200 && mounted) {
        // parse url from response
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.logout();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: AppTheme.fontDisplay,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const GrandeBottomNav(currentIndex: 3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : _isLoggedIn
              ? _buildProfile()
              : _buildGuestWall(),
    );
  }

  // ── Guest wall ───────────────────────────────────────────────
  Widget _buildGuestWall() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryLight.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.person_outline, size: 56, color: AppTheme.primaryLight),
            ),
            const SizedBox(height: AppTheme.lg),
            const Text('You\'re not logged in',
                style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
            const SizedBox(height: AppTheme.sm),
            const Text(
              'Login or create an account to view your profile, track orders, and more.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textLight),
            ),
            const SizedBox(height: AppTheme.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
                child: const Text('Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: AppTheme.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryLight),
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
                child: const Text('Create Account',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppTheme.primaryLight)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logged-in profile ────────────────────────────────────────
  Widget _buildProfile() {
    final initials = _firstName.isNotEmpty ? _firstName[0].toUpperCase() : '?';
    final fullName = '$_firstName $_lastName'.trim();
    final roleLabel = _role.isNotEmpty
        ? _role[0].toUpperCase() + _role.substring(1)
        : '';

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: AppTheme.xl, horizontal: AppTheme.lg),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAndUploadPicture,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.white.withValues(alpha: 0.3),
                        backgroundImage: _profilePicture != null && _profilePicture!.isNotEmpty
                            ? NetworkImage(_profilePicture!) as ImageProvider
                            : null,
                        child: _profilePicture == null || _profilePicture!.isEmpty
                            ? Text(initials,
                                style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.w700,
                                    color: AppTheme.white))
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
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.primaryLight, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: AppTheme.primaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.sm),
                Text(fullName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppTheme.white)),
                const SizedBox(height: 4),
                Text(_email,
                    style: const TextStyle(fontSize: 13, color: AppTheme.white)),
                if (roleLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(roleLabel,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppTheme.white)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppTheme.md),

          // Settings menu
          _buildSection('Account', [
            _buildMenuItem(
              icon: Icons.person_outline,
              label: 'Personal Information',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PersonalInfoScreen()),
              ).then((_) => _loadUser()),
            ),
            _buildMenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'My Orders',
              onTap: () => Navigator.pushNamed(context, '/orders'),
            ),
            _buildMenuItem(
              icon: Icons.favorite_border,
              label: 'My Wishlist',
              onTap: () => Navigator.pushNamed(context, '/wishlist'),
            ),
            _buildMenuItem(
              icon: Icons.location_on_outlined,
              label: 'My Addresses',
              onTap: () => Navigator.pushNamed(context, '/addresses'),
            ),
          ]),

          const SizedBox(height: AppTheme.sm),

          _buildSection('More', [
            _buildMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            _buildMenuItem(
              icon: Icons.chat_bubble_outline,
              label: 'Messages',
              onTap: () => Navigator.pushNamed(context, '/messages'),
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
            _buildMenuItem(
              icon: Icons.info_outline,
              label: 'About Grande',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
            _buildMenuItem(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TermsScreen())),
            ),
            _buildMenuItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            ),
          ]),

          const SizedBox(height: AppTheme.md),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.xl),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.md, AppTheme.md, AppTheme.md, AppTheme.xs),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.textLight, letterSpacing: 0.5)),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.md, vertical: AppTheme.md),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.textDark, size: 22),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: color ?? AppTheme.textDark)),
            ),
            Icon(Icons.chevron_right,
                color: color ?? AppTheme.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Personal Information Settings Screen ────────────────────────────────────

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();

  bool _isLoading = true;
  bool _isSaving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getCurrentUser();
      if (data != null && mounted) {
        setState(() {
          _firstNameCtrl.text = data['first_name'] ?? '';
          _lastNameCtrl.text  = data['last_name']  ?? '';
          _emailCtrl.text     = data['email']      ?? '';
          _phoneCtrl.text     = data['phone']      ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final success = await ApiService.updateProfile({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name':  _lastNameCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Profile updated!' : 'Update failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
        if (success) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Update failed'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Information',
            style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 20, fontWeight: FontWeight.w600,
                color: AppTheme.textDark)),
        backgroundColor: AppTheme.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _field(_firstNameCtrl, 'First Name')),
                        const SizedBox(width: AppTheme.md),
                        Expanded(child: _field(_lastNameCtrl, 'Last Name')),
                      ],
                    ),
                    const SizedBox(height: AppTheme.md),
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: AppTheme.md),
                    _field(_phoneCtrl, 'Phone Number',
                        keyboardType: TextInputType.phone,
                        icon: Icons.phone_outlined),
                    const SizedBox(height: AppTheme.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    color: AppTheme.white, strokeWidth: 2))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboardType, IconData? icon}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
