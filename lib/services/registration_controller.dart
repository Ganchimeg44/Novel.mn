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
    return _auth.sendPhoneVerificationCode(
      phoneNumber: phoneNumber,
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
      phoneNumber: phoneNumber,
      birthDate: birthDate,
      avatarType: avatarType,
    );
  }

  Future<UserModel> _finishRegistration({
    required String uid,
    required String username,
    required String email,
    required String? phoneNumber,
    required DateTime birthDate,
    required String avatarType,
  }) async {
    if (avatarType != 'male' && avatarType != 'female') {
      throw ArgumentError('Avatar сонголт буруу байна.');
    }

    try {
      final sixDigitId = await _users.generateAndReserveSixDigitId(uid);
      await _users.reserveUsername(username: username, uid: uid, email: email);

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

  /// [identifier] нь username эсвэл имэйл байж болно; username бол
  /// эхлээд холбогдох имэйлийг Firestore-с олж, дараа нь тэр имэйлээр
  /// Firebase Auth руу нэвтэрнэ.
  Future<UserModel?> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final looksLikeEmail = identifier.contains('@');
    final email = looksLikeEmail
        ? identifier
        : await _users.getEmailForUsername(identifier);

    if (email == null) {
      throw StateError(
        'Энэ хэрэглэгчийн нэртэй, имэйл холбогдсон бүртгэл олдсонгүй.',
      );
    }

    final credential = await _auth.signInWithEmail(
      email: email,
      password: password,
    );
    return _users.getUserByUid(credential.user!.uid);
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