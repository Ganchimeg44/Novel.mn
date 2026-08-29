import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

/// Нэвтрэх дэлгэц. Хэрэглэгч Username, Gmail эсвэл утасны дугаараа
/// оруулж болно — утасны дугаар мэт таних тэмдэг илэрвэл нууц үгийн
/// оронд OTP флоу руу шилжинэ.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _registrationController = RegistrationController();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _looksLikePhoneNumber {
    final value = _identifierCtrl.text.trim();
    return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(value);
  }

  Future<void> _submit() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Нэвтрэх мэдээллээ оруулна уу.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_looksLikePhoneNumber) {
        await _registrationController.startPhoneLogin(
          phoneNumber: identifier,
          onCodeSent: (verificationId) {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: identifier,
                  mode: OtpMode.login,
                ),
              ),
            );
          },
          onFailed: (error) {
            setState(() {
              _errorMessage = error.message ?? 'Утас баталгаажуулахад алдаа гарлаа.';
            });
          },
        );
      } else {
        if (_passwordCtrl.text.isEmpty) {
          setState(() => _errorMessage = 'Нууц үгээ оруулна уу.');
          return;
        }
        await _registrationController.loginWithPassword(
          identifier: identifier,
          password: _passwordCtrl.text,
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Нэвтрэх', style: GoogleFonts.poppins()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _identifierCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Username / Gmail / Утасны дугаар',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              if (!_looksLikePhoneNumber)
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Нууц үг'),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_looksLikePhoneNumber ? 'Код авах' : 'Нэвтрэх'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    'Бүртгэлгүй юу? Бүртгүүлэх',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}