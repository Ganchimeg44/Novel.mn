import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'auth_service.dart';
import 'user_repository.dart';

/// Регистрацийн/нэвтрэлтийн БҮХ бизнес логикийг нэг дор нэгтгэсэн давхарга.
/// UI screen-үүд ЭНЭ классыг л дуудна — `AuthService`,
/// `UserRepository`-г шууд импортлохгүй.
class RegistrationController {
  RegistrationController({
    AuthService? authService,
    UserRepository? userRepository,
  })  : _auth = authService ?? AuthService(),
        _users = userRepository ?? UserRepository();

  final AuthService _auth;
  final UserRepository _users;

  /// Монгол утасны дугаарыг Firebase-д ашиглах нэг стандарт
  /// +976XXXXXXXX хэлбэрт оруулна.
  String normalizePhoneNumber(String value) {
    var phone = value.trim().replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );

    if (phone.startsWith('00976')) {
      phone = '+${phone.substring(2)}';
    } else if (phone.startsWith('976') && !phone.startsWith('+976')) {
      phone = '+$phone';
    } else if (RegExp(r'^\d{8}$').hasMatch(phone)) {
      phone = '+976$phone';
    }

    if (!RegExp(r'^\+976\d{8}$').hasMatch(phone)) {
      throw const FormatException(
        'Монгол утасны дугаараа 8 оронтой эсвэл +976XXXXXXXX хэлбэрээр оруулна уу.',
      );
    }

    return phone;
  }

  // ---------------------------------------------------------------------
  // Бүртгүүлэх — Имэйл (Gmail)
  // ---------------------------------------------------------------------

  Future<UserModel> registerWithEmail({
    required String username,
    required String email,
    required String password,
    required DateTime birthDate,
    required String avatarType,
    String? phoneNumber,
  }) async {
    if (await _users.isUsernameTaken(username)) {
      throw StateError('Энэ хэрэглэгчийн нэр аль хэдийн ашиглагдсан байна.');
    }

    final credential = await _auth.createUserWithEmail(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    return _finishRegistration(
      uid: uid,
      username: username,
      email: email,
      phoneNumber: phoneNumber,
      birthDate: birthDate,
      avatarType: avatarType,
    );
  }

  // ---------------------------------------------------------------------
  // Бүртгүүлэх — Утасны дугаар (OTP)
  // ---------------------------------------------------------------------

  /// 1-р алхам: утас руу баталгаажуулах код илгээнэ.
  Future<void> startPhoneRegistration({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
  }) {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);

    return _auth.sendPhoneVerificationCode(
      phoneNumber: normalizedPhone,
      onCodeSent: onCodeSent,
      onFailed: onFailed,
    );
  }

  /// 2-р алхам: SMS кодыг баталгаажуулаад бүртгэлийг дуусгана.
  /// Firebase-ийн Password provider ИМЭЙЛ шаарддаг тул (утасны дугаараар
  /// л нууц үг үүсгэх боломжгүй) утсаар бүртгүүлсэн хэрэглэгчид ч бас
  /// ИМЭЙЛ+НУУЦ ҮГ-ийг тухайн акаунт дээр НЭМЖ холбоно (`linkWithCredential`).
  /// Ингэснээр тэд дараа нь username/имэйлээр мөн адил нэвтрэх боломжтой
  /// болно.
  Future<UserModel> completePhoneRegistration({
    required String verificationId,
    required String smsCode,
    required String username,
    required String email,
    required String password,
    required DateTime birthDate,
    required String phoneNumber,
    required String avatarType,
  }) async {
    if (await _users.isUsernameTaken(username)) {
      throw StateError('Энэ хэрэглэгчийн нэр аль хэдийн ашиглагдсан байна.');
    }

    final normalizedPhone = normalizePhoneNumber(phoneNumber);

    final phoneCredential = await _auth.signInWithSmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final uid = phoneCredential.user!.uid;

    // Password-оор нэвтрэх боломжтой болгохын тулд имэйл холбоно.
    await _auth.linkEmailPassword(email: email, password: password);

    return _finishRegistration(
      uid: uid,
      username: username,
      email: email,
      phoneNumber: normalizedPhone,
      birthDate: birthDate,
      avatarType: avatarType,
      phoneVerified: true,
    );
  }

  Future<UserModel> _finishRegistration({
    required String uid,
    required String username,
    required String email,
    required String? phoneNumber,
    required DateTime birthDate,
    required String avatarType,
    bool phoneVerified = false,
  }) async {
    if (avatarType != 'male' && avatarType != 'female') {
      throw ArgumentError('Avatar сонголт буруу байна.');
    }

    try {
      final sixDigitId = await _users.generateAndReserveSixDigitId(uid);
      await _users.reserveUsername(username: username, uid: uid, email: email);

      if (phoneVerified && phoneNumber != null && phoneNumber.isNotEmpty) {
        await _users.reservePhoneNumber(
          phoneNumber: phoneNumber,
          uid: uid,
          email: email,
        );
      }

      final user = UserModel(
        uid: uid,
        sixDigitId: sixDigitId,
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        displayName: username,
        birthDate: birthDate,
        createdAt: DateTime.now(),
        avatarType: avatarType,
      );

      await _users.createUserProfile(user);
      return user;
    } catch (error) {
      // Бүртгэлийн алдааны үед хэрэглэгчийн Firebase Auth бүртгэлийг
      // автоматаар устгахгүй. UI-д алдааг буцааж, хэрэглэгч дахин оролдоно.
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Нэвтрэх — Username / Имэйл + нууц үг
  // ---------------------------------------------------------------------

  /// [identifier] нь username, Gmail эсвэл баталгаажсан утасны дугаар
  /// байж болно. Firebase Auth-ийн Email/Password credential ашиглан
  /// нууц үгээр нэвтэрнэ.
  Future<UserModel?> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final value = identifier.trim();
    final looksLikeEmail = value.contains('@');
    final looksLikePhone = RegExp(r'^\d{8}$').hasMatch(value);

    String? email;

    if (looksLikeEmail) {
      email = value;
    } else if (looksLikePhone) {
      final normalizedPhone = normalizePhoneNumber(value);
      email = await _users.getEmailForPhoneNumber(normalizedPhone);
    } else {
      email = await _users.getEmailForUsername(value);
    }

    if (email == null) {
      throw StateError('Бүртгэл олдсонгүй.');
    }

    final credential = await _auth.signInWithEmail(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user!;

    // Хуучин phone хэрэглэгчдийн phoneNumbers lookup байхгүй бол
    // Firebase Auth дээрх баталгаажсан утасны дугаараас автоматаар нөхнө.
    final verifiedPhone = firebaseUser.phoneNumber;
    final authEmail = firebaseUser.email;

    if (verifiedPhone != null &&
        verifiedPhone.isNotEmpty &&
        authEmail != null &&
        authEmail.isNotEmpty) {
      await _users.reservePhoneNumber(
        phoneNumber: verifiedPhone,
        uid: firebaseUser.uid,
        email: authEmail,
      );
    }

    return _users.getUserByUid(firebaseUser.uid);
  }

  // ---------------------------------------------------------------------
  // Утасны дугаар солих
  // ---------------------------------------------------------------------

  Future<void> startPhoneNumberChange({
    required String newPhoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
  }) async {
    final normalizedPhone = normalizePhoneNumber(newPhoneNumber);
    final currentPhone = _auth.currentPhoneNumber;

    if (currentPhone == normalizedPhone) {
      throw const FormatException(
        'Шинэ утасны дугаар одоогийн дугаартай ижил байна.',
      );
    }

    final existingUid =
        await _users.getUidForPhoneNumber(normalizedPhone);

    if (existingUid != null) {
      throw StateError(
        'Энэ утасны дугаар аль хэдийн бүртгэлтэй байна.',
      );
    }

    await _auth.sendPhoneVerificationCode(
      phoneNumber: normalizedPhone,
      onCodeSent: onCodeSent,
      onFailed: onFailed,
    );
  }

  Future<void> completePhoneNumberChange({
    required String newPhoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Хэрэглэгч нэвтрээгүй байна.');
    }

    final uid = user.uid;
    final email = user.email;

    if (email == null || email.isEmpty) {
      throw StateError('Хэрэглэгчийн Gmail бүртгэл олдсонгүй.');
    }

    final normalizedPhone = normalizePhoneNumber(newPhoneNumber);
    final oldPhone = _auth.currentPhoneNumber;

    final existingUid =
        await _users.getUidForPhoneNumber(normalizedPhone);

    if (existingUid != null && existingUid != uid) {
      throw StateError(
        'Энэ утасны дугаар аль хэдийн бүртгэлтэй байна.',
      );
    }

    // SMS credential зөв бол Firebase Auth дээрх утсыг эхэлж шинэчилнэ.
    await _auth.updatePhoneNumber(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    // Шинэ баталгаажсан дугаарын lookup үүсгэнэ.
    await _users.reservePhoneNumber(
      phoneNumber: normalizedPhone,
      uid: uid,
      email: email,
    );

    // Firestore profile дээрх утасны дугаарыг шинэчилнэ.
    await _users.updateMutableProfileFields(
      uid,
      {
        'phoneNumber': normalizedPhone,
      },
    );

    // Хуучин lookup байвал хамгийн сүүлд устгана.
    if (oldPhone != null &&
        oldPhone.isNotEmpty &&
        oldPhone != normalizedPhone) {
      await _users.removePhoneNumber(
        phoneNumber: oldPhone,
        uid: uid,
      );
    }
  }

  // ---------------------------------------------------------------------
  // Нууц үг солих
  // ---------------------------------------------------------------------

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw const FormatException('Хуучин нууц үгээ оруулна уу.');
    }

    if (newPassword.length < 6) {
      throw const FormatException(
        'Шинэ нууц үг хамгийн багадаа 6 тэмдэгт байна.',
      );
    }

    if (newPassword != confirmPassword) {
      throw const FormatException('Шинэ нууц үг таарахгүй байна.');
    }

    if (currentPassword == newPassword) {
      throw const FormatException(
        'Шинэ нууц үг хуучин нууц үгээс өөр байна.',
      );
    }

    await _auth.reauthenticateWithPassword(
      password: currentPassword,
    );

    await _auth.updatePassword(newPassword);
  }

  // ---------------------------------------------------------------------
  // Нууц үг сэргээх — Gmail
  // ---------------------------------------------------------------------

  Future<void> resetPasswordWithEmail(String email) async {
    final value = email.trim();

    if (value.isEmpty || !value.contains('@')) {
      throw const FormatException('Gmail хаягаа шалгана уу.');
    }

    await _auth.sendPasswordResetEmail(email: value);
  }


  Future<void> startPhonePasswordReset({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);

    final uid = await _users.getUidForPhoneNumber(normalizedPhone);
    if (uid == null) {
      throw StateError('Энэ утасны дугаар бүртгэлгүй байна.');
    }

    await _auth.sendPhoneVerificationCode(
      phoneNumber: normalizedPhone,
      onCodeSent: onCodeSent,
      onFailed: onFailed,
    );
  }


  Future<void> completePhonePasswordReset({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
    required String newPassword,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);

    final expectedUid =
        await _users.getUidForPhoneNumber(normalizedPhone);

    if (expectedUid == null) {
      throw StateError('Энэ утасны дугаар бүртгэлгүй байна.');
    }

    final credential = await _auth.signInWithSmsCode(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    final actualUid = credential.user?.uid;

    if (actualUid == null || actualUid != expectedUid) {
      await _auth.signOut();
      throw StateError('Утасны дугаарын баталгаажуулалт таарсангүй.');
    }

    if (newPassword.length < 6) {
      throw const FormatException(
        'Нууц үг хамгийн багадаа 6 тэмдэгт байна.',
      );
    }

    await _auth.updatePassword(newPassword);
  }

  // ---------------------------------------------------------------------
  // Нэвтрэх — Утасны дугаар (OTP)
  // ---------------------------------------------------------------------

  Future<void> startPhoneLogin({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
  }) {
    return _auth.sendPhoneVerificationCode(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onFailed: onFailed,
    );
  }

  Future<UserModel?> completePhoneLogin({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = await _auth.signInWithSmsCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _users.getUserByUid(credential.user!.uid);
  }

  Future<void> signOut() => _auth.signOut();
}