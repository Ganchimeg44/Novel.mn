import 'package:flutter/material.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';

class ChangePhoneOtpScreen extends StatefulWidget {
  const ChangePhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  final String phoneNumber;
  final String verificationId;

  @override
  State<ChangePhoneOtpScreen> createState() =>
      _ChangePhoneOtpScreenState();
}

class _ChangePhoneOtpScreenState extends State<ChangePhoneOtpScreen> {
  final _controller = RegistrationController();
  final _codeCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Баталгаажуулах кодоо оруулна уу.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _controller.completePhoneNumberChange(
        newPhoneNumber: widget.phoneNumber,
        verificationId: widget.verificationId,
        smsCode: code,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Утасны дугаар амжилттай солигдлоо.'),
        ),
      );

      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
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
        title: const Text('Утас баталгаажуулах'),
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
                  : const Text('Баталгаажуулах'),
            ),
          ],
        ),
      ),
    );
  }
}
