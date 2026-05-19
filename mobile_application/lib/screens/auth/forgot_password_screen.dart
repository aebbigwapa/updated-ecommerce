import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl   = TextEditingController();
  final _otpCtrl     = TextEditingController();
  final _newPwCtrl   = TextEditingController();
  final _confPwCtrl  = TextEditingController();

  int _step = 1; // 1=email, 2=otp, 3=new password
  bool _loading = false;
  bool _obscNew = true, _obscConf = true;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _emailCtrl.dispose(); _otpCtrl.dispose();
    _newPwCtrl.dispose(); _confPwCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { if (--_countdown <= 0) t.cancel(); });
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { _toast('Enter your email', error: true); return; }
    setState(() => _loading = true);
    final res = await ApiService.sendOtpFlask(email);
    if (mounted) {
      setState(() => _loading = false);
      if (res['success'] == true) {
        setState(() => _step = 2);
        _startTimer();
        _toast('OTP sent to $email');
      } else {
        _toast(res['message'] ?? 'Failed to send OTP', error: true);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) { _toast('Enter the 6-digit OTP', error: true); return; }
    setState(() => _loading = true);
    final res = await ApiService.verifyOtpFlask(
      _emailCtrl.text.trim(),
      otp,
      purpose: 'password_reset',
    );
    if (mounted) {
      setState(() => _loading = false);
      if (res['success'] == true) {
        setState(() => _step = 3);
      } else {
        _toast(res['message'] ?? 'Invalid OTP', error: true);
      }
    }
  }

  Future<void> _resetPassword() async {
    final pw = _newPwCtrl.text;
    if (pw != _confPwCtrl.text) { _toast('Passwords do not match', error: true); return; }
    if (pw.length < 8) { _toast('Password must be at least 8 characters', error: true); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService.resetPasswordFlask(
        _emailCtrl.text.trim(),
        _otpCtrl.text.trim(),
        pw,
      );
      if (mounted) {
        setState(() => _loading = false);
        if (res['success'] == true) {
          _toast('Password reset successfully!');
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        } else {
          final msg = res['message'] ?? 'Failed to reset password';
          print('Password reset error: $msg');
          _toast(msg, error: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final msg = 'Error: $e';
        print('Password reset exception: $msg');
        _toast(msg, error: true);
      }
    }
  }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('Grande', style: TextStyle(fontFamily: AppTheme.fontDisplay,
                    fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(_stepTitle(), style: const TextStyle(fontFamily: AppTheme.fontDisplay,
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                    const SizedBox(height: 8),
                    Text(_stepSubtitle(), style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
                    const SizedBox(height: 20),
                    if (_step == 1) _buildStep1(),
                    if (_step == 2) _buildStep2(),
                    if (_step == 3) _buildStep3(),
                  ]),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Back to Login',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    if (_step == 2) return 'Enter OTP';
    if (_step == 3) return 'New Password';
    return 'Forgot Password';
  }

  String _stepSubtitle() {
    if (_step == 2) return 'Enter the 6-digit code sent to ${_emailCtrl.text.trim()}';
    if (_step == 3) return 'Create a new password for your account';
    return 'Enter your email to receive a reset code';
  }

  Widget _buildStep1() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
    const SizedBox(height: 16),
    ElevatedButton(
      onPressed: _loading ? null : _sendOtp,
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
          padding: const EdgeInsets.symmetric(vertical: 14)),
      child: _loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Send Reset Code', style: TextStyle(fontWeight: FontWeight.w600)),
    ),
  ]);

  Widget _buildStep2() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
        decoration: const InputDecoration(labelText: 'OTP Code', border: OutlineInputBorder(),
            counterText: '')),
    const SizedBox(height: 8),
    if (_countdown > 0)
      Text('Resend in ${_countdown}s', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.textLight))
    else
      TextButton(onPressed: _loading ? null : _sendOtp,
          child: const Text('Resend OTP', style: TextStyle(color: AppTheme.primaryLight))),
    const SizedBox(height: 16),
    ElevatedButton(
      onPressed: _loading ? null : _verifyOtp,
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
          padding: const EdgeInsets.symmetric(vertical: 14)),
      child: _loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.w600)),
    ),
  ]);

  Widget _buildStep3() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _pwField(_newPwCtrl, 'New Password', _obscNew, (v) => setState(() => _obscNew = v)),
    const SizedBox(height: 12),
    _pwField(_confPwCtrl, 'Confirm Password', _obscConf, (v) => setState(() => _obscConf = v)),
    const SizedBox(height: 16),
    ElevatedButton(
      onPressed: _loading ? null : _resetPassword,
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight,
          padding: const EdgeInsets.symmetric(vertical: 14)),
      child: _loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w600)),
    ),
  ]);

  Widget _pwField(TextEditingController c, String label, bool obscure, ValueChanged<bool> toggle) =>
      TextField(controller: c, obscureText: obscure,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => toggle(!obscure),
              )));
}
