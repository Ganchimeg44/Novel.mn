import 'package:flutter/material.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';

class PhonePasswordResetScreen extends StatefulWidget {
  const PhonePasswordResetScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  final String phoneNumber;
  final String verificationId;

  @override
  State<PhonePasswordResetScreen> createState() =>
      _PhonePasswordResetScreenState();
}

class _PhonePasswordResetScreenState
    extends State<PhonePasswordResetScreen> {
  final _controller = RegistrationController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Баталгаажуулах кодоо оруулна уу.');
      return;
    }

    if (password.length < 6) {
      setState(
        () => _errorMessage = 'Нууц үг хамгийн багадаа 6 тэмдэгт байна.',
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Нууц үг таарахгүй байна.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _controller.completePhonePasswordReset(
        phoneNumber: widget.phoneNumber,
        verificationId: widget.verificationId,
        smsCode: code,
        newPassword: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нууц үг амжилттай шинэчлэгдлээ.'),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Нууц үг сэргээх'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Баталгаажуулах код',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Шинэ нууц үг',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Шинэ нууц үгээ давтан оруулна уу',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Нууц үг шинэчлэх'),
            ),
          ],
        ),
      ),
    );
  }
}
