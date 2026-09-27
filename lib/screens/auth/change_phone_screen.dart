import 'package:flutter/material.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';
import 'change_phone_otp_screen.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _controller = RegistrationController();
  final _phoneCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();

    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      setState(() {
        _errorMessage = 'Утасны дугаараа шалгана уу.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _controller.startPhoneNumberChange(
        newPhoneNumber: phone,
        onCodeSent: (verificationId) {
          if (!mounted) return;

          setState(() => _isSubmitting = false);

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangePhoneOtpScreen(
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
            _errorMessage =
                error.message ?? 'SMS код илгээж чадсангүй.';
          });
        },
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _errorMessage = error.toString();
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
        title: const Text('Утасны дугаар солих'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Шинэ утасны дугаар',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Код авах'),
            ),
          ],
        ),
      ),
    );
  }
}
