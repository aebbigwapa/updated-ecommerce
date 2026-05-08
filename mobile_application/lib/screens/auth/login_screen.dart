import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../buyer/home_screen.dart';
import '../seller/seller_dashboard_screen.dart';
import '../rider/rider_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool   _isLoading       = false;
  bool   _obscurePassword = true;
  int    _countdown       = 0;
  Timer? _countdownTimer;

  static const List<String> _messages = [
    'Verifying credentials...',
    'Checking your account...',
    'Almost there...',
    'Signing you in...',
  ];
  int _msgIndex = 0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 0; _msgIndex = 0;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _countdown++;
        _msgIndex = (_countdown ~/ 2).clamp(0, _messages.length - 1);
      });
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    if (mounted) setState(() => _countdown = 0);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    _startCountdown();
    try {
      final result = await ApiService.loginFlask(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      _stopCountdown();
      if (!mounted) return;

      if (result['success'] == true) {
        final user = result['user'] is Map
            ? Map<String, dynamic>.from(result['user'] as Map)
            : <String, dynamic>{};
        final role = user['role']?.toString() ?? 'buyer';
        Widget dest;
        switch (role) {
          case 'seller': dest = const SellerDashboardScreen(); break;
          case 'rider':  dest = const RiderDashboardScreen();  break;
          case 'admin':  dest = const AdminDashboardScreen();  break;
          default:       dest = const HomeScreen();
        }
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => dest));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message']?.toString() ?? 'Invalid email or password'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      _stopCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Column(children: [
                        Text('Grande',
                            style: TextStyle(
                              fontFamily: AppTheme.fontDisplay,
                              fontSize: 48, fontWeight: FontWeight.w700,
                              color: AppTheme.white,
                              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 2))],
                            )),
                        Text('MARKETPLACE',
                            style: TextStyle(
                              fontFamily: AppTheme.fontBody,
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: AppTheme.white, letterSpacing: 2.0,
                            )),
                      ]),
                      const SizedBox(height: AppTheme.xxxl),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.xl),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Welcome Back',
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontDisplay,
                                      fontSize: 24, fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark)),
                              const SizedBox(height: AppTheme.lg),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    border: OutlineInputBorder()),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Please enter your email';
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppTheme.md),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Please enter your password';
                                  if (v.length < 8) return 'Password must be at least 8 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppTheme.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: const Text('Forgot Password?',
                                      style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w500)),
                                ),
                              ),
                              const SizedBox(height: AppTheme.md),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryLight,
                                  padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                                ),
                                child: const Text('Login',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: AppTheme.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? ",
                                      style: TextStyle(color: AppTheme.textLight)),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(context, '/register'),
                                    child: const Text('Register',
                                        style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Countdown overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppTheme.xl),
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.xl, horizontal: AppTheme.xl),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80, height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const SizedBox(
                              width: 80, height: 80,
                              child: CircularProgressIndicator(strokeWidth: 5, color: AppTheme.primaryLight),
                            ),
                            Text('${_countdown}s',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.lg),
                      Text(_messages[_msgIndex],
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                      const SizedBox(height: AppTheme.sm),
                      const Text('Please wait...', style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
