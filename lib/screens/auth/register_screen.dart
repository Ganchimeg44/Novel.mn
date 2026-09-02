import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/registration_controller.dart';
import '../../theme/app_theme.dart';
import 'otp_verification_screen.dart';

/// Бүртгүүлэх дэлгэц: "Имэйл" эсвэл "Утас" гэсэн 2 аргаас сонгоно.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _registrationController = RegistrationController();
  final _formKey = GlobalKey<FormState>();

  bool _useEmail = true; // true = Имэйл tab, false = Утас tab
  bool _isSubmitting = false;
  String? _errorMessage;
  DateTime? _birthDate;
  String? _avatarType;

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      initialDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      setState(() => _errorMessage = 'Төрсөн өдрөө сонгоно уу.');
      return;
    }
    if (_avatarType == null) {
      setState(() => _errorMessage = 'Профайл зургаа сонгоно уу.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_useEmail) {
        await _registrationController.registerWithEmail(
          username: _usernameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          birthDate: _birthDate!,
          avatarType: _avatarType!,
          phoneNumber: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        // Утасны бүртгэл нь эхлээд OTP код авах шаардлагатай тул
        // pending мэдээллийг дараагийн дэлгэц рүү дамжуулна.
        await _registrationController.startPhoneRegistration(
          phoneNumber: _phoneCtrl.text.trim(),
          onCodeSent: (verificationId) {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: _phoneCtrl.text.trim(),
                  mode: OtpMode.registration,
                  pendingUsername: _usernameCtrl.text.trim(),
                  pendingEmail: _emailCtrl.text.trim(),
                  pendingPassword: _passwordCtrl.text,
                  pendingBirthDate: _birthDate,
                  pendingAvatarType: _avatarType,
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
        title: Text('Бүртгүүлэх', style: GoogleFonts.poppins()),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _MethodToggle(
                useEmail: _useEmail,
                onChanged: (value) => setState(() => _useEmail = value),
              ),
              const SizedBox(height: 20),
              _AuthTextField(
                controller: _usernameCtrl,
                label: 'Хэрэглэгчийн нэр',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Заавал бөглөнө үү' : null,
              ),
              const SizedBox(height: 14),
              if (_useEmail)
                _AuthTextField(
                  controller: _emailCtrl,
                  label: 'Gmail хаяг',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Зөв имэйл хаяг оруулна уу'
                      : null,
                )
              else
                _AuthTextField(
                  controller: _phoneCtrl,
                  label: 'Утасны дугаар (+976...)',
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().length < 8) ? 'Дугаараа шалгана уу' : null,
                ),
              const SizedBox(height: 14),
              // Утасны бүртгэлд ч дараа нь username/имэйлээр нэвтрэх
              // боломжтой байхын тулд имэйл заавал шаардана.
              if (!_useEmail) ...[
                _AuthTextField(
                  controller: _emailCtrl,
                  label: 'Gmail хаяг (нэвтрэхэд ашиглана)',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Зөв имэйл хаяг оруулна уу'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              _AuthTextField(
                controller: _passwordCtrl,
                label: 'Нууц үг',
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Хамгийн багадаа 6 тэмдэгт' : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Төрсөн өдөр'),
                  child: Text(
                    _birthDate == null
                        ? 'Сонгох'
                        : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Профайл зураг',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _AvatarSelector(
                selected: _avatarType,
                onChanged: (value) => setState(() => _avatarType = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
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
                    : const Text('Бүртгүүлэх'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodToggle extends StatelessWidget {
  final bool useEmail;
  final ValueChanged<bool> onChanged;

  const _MethodToggle({required this.useEmail, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'Имэйл',
            isSelected: useEmail,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToggleButton(
            label: 'Утас',
            isSelected: !useEmail,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AuthTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _AvatarSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const _AvatarSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AvatarChoice(
            label: 'Эрэгтэй',
            icon: Icons.man_rounded,
            isSelected: selected == 'male',
            onTap: () => onChanged('male'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AvatarChoice(
            label: 'Эмэгтэй',
            icon: Icons.woman_rounded,
            isSelected: selected == 'female',
            onTap: () => onChanged('female'),
          ),
        ),
      ],
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: isSelected ? AppColors.primaryLight : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
