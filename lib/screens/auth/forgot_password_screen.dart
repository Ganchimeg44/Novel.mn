import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';
import 'phone_password_reset_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _controller = RegistrationController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _useEmail = true;
  bool _isSubmitting = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    setState(() {
      _isSubmitting = true;
      _message = null;
      _isError = false;
    });

    try {
      await _controller.resetPasswordWithEmail(_emailCtrl.text);

      if (!mounted) return;
      setState(() {
        _message = 'Сэргээх холбоос Gmail рүү илгээгдлээ.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitPhone() async {
    final phone = _phoneCtrl.text.trim();

    if (!RegExp(r'^\d{8}\$').hasMatch(phone)) {
      setState(() {
        _isError = true;
        _message = 'Утасны дугаараа шалгана уу.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
      _isError = false;
    });

    try {
      await _controller.startPhonePasswordReset(
        phoneNumber: phone,
        onCodeSent: (verificationId) {
          if (!mounted) return;

          setState(() => _isSubmitting = false);

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PhonePasswordResetScreen(
                phoneNumber: phone,
                verificationId: verificationId,
              ),
            ),
          );
        },
        onFailed: (error) {
          if (!mounted) return;

          setState(() {
            _isSubmitting = false;
            _isError = true;
            _message = error.message ?? 'SMS код илгээж чадсангүй.';
          });
        },
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _isError = true;
        _message = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Нууц үг сэргээх',
          style: GoogleFonts.poppins(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Gmail'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Утасны дугаар'),
                ),
              ],
              selected: {_useEmail},
              onSelectionChanged: (value) {
                setState(() {
                  _useEmail = value.first;
                  _message = null;
                });
              },
            ),
            const SizedBox(height: 24),
            if (_useEmail)
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Gmail',
                ),
              )
            else
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Утасны дугаар',
                ),
              ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                style: TextStyle(
                  color: _isError ? Colors.redAccent : AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (_useEmail ? _submitEmail : _submitPhone),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Үргэлжлүүлэх'),
            ),
          ],
        ),
      ),
    );
  }
}
