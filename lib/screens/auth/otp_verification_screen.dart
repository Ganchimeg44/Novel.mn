import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';

enum OtpMode { registration, login }

/// Утасны дугаар руу илгээсэн SMS кодыг баталгаажуулах дэлгэц.
/// Бүртгэл (registration) болон нэвтрэлт (login) хоёуланд нь ашиглана.
class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final OtpMode mode;

  // Зөвхөн mode == registration үед шаардлагатай "хүлээгдэж буй" мэдээлэл
  final String? pendingUsername;
  final String? pendingEmail;
  final String? pendingPassword;
  final DateTime? pendingBirthDate;
  final String? pendingAvatarType;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.mode,
    this.pendingUsername,
    this.pendingEmail,
    this.pendingPassword,
    this.pendingBirthDate,
    this.pendingAvatarType,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _registrationController = RegistrationController();
  final _codeCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_codeCtrl.text.trim().length < 4) {
      setState(() => _errorMessage = 'Кодоо бүрэн оруулна уу.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.mode == OtpMode.registration) {
        await _registrationController.completePhoneRegistration(
          verificationId: widget.verificationId,
          smsCode: _codeCtrl.text.trim(),
          username: widget.pendingUsername!,
          email: widget.pendingEmail!,
          password: widget.pendingPassword!,
          birthDate: widget.pendingBirthDate!,
          phoneNumber: widget.phoneNumber,
          avatarType: widget.pendingAvatarType!,
        );
      } else {
        await _registrationController.completePhoneLogin(
          verificationId: widget.verificationId,
          smsCode: _codeCtrl.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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
        title: Text('Баталгаажуулах код', style: GoogleFonts.poppins()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.phoneNumber} дугаар руу илгээсэн кодыг оруулна уу.',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20),
                decoration: const InputDecoration(labelText: 'SMS код'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirm,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Баталгаажуулах'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}