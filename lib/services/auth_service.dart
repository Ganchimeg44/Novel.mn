import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication-той шууд харьцах цорын ганц давхарга.
///
/// UI screen-үүд болон Firestore-той харьцдаг `UserRepository`
/// ЭНЭ классыг шууд импортлохгүй, харин `RegistrationController`
/// (lib/services/registration_controller.dart) дамжуулан ашиглана.
/// Ингэснээр "Auth" болон "Firestore өгөгдөл" гэсэн 2 санаа тус тусдаа,
/// сольж/тест хийхэд хялбар давхаргад хуваагдана.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  String? get currentPhoneNumber => _auth.currentUser?.phoneNumber;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ---------------------------------------------------------------------
  // Имэйл + нууц үг
  // ---------------------------------------------------------------------

  Future<UserCredential> createUserWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Утасны дугаараар бүртгүүлсэн хэрэглэгчид дараа нь имэйл+нууц үгээр
  /// нэвтрэх боломж олгохын тулд, одоо нэвтэрсэн (phone) хэрэглэгчийн
  /// дээр Email/Password credential-ийг НЭМЖ холбоно (link).
  Future<UserCredential> linkEmailPassword({
    required String email,
    required String password,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'linkEmailPassword дуудагдахаас өмнө хэрэглэгч Firebase-т '
        'нэвтэрсэн (жиш. утасны OTP-гоор баталгаажсан) байх ёстой.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    return user.linkWithCredential(credential);
  }

  /// Нууц үгээ мартсан үед имэйл рүү сэргээх холбоос илгээнэ.
  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ---------------------------------------------------------------------
  // Утасны дугаар (OTP)
  // ---------------------------------------------------------------------

  /// Утасны дугаар руу баталгаажуулах код (SMS) илгээнэ.
  /// [onCodeSent] дуудагдахад буцаж ирсэн `verificationId`-г UI-д хадгалж,
  /// хэрэглэгчээс SMS кодыг асуух шаардлагатай.
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        // Зарим Android төхөөрөмж дээр SMS кодыг систем автоматаар
        // танихад дуудагдана. Заавал бус тул callback-г optional-оор авав.
        onAutoVerified?.call(credential);
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  /// Хэрэглэгчийн оруулсан SMS кодоор Firebase-т нэвтрэх/бүртгүүлэх
  /// (шинэ дугаар бол автоматаар шинэ Auth хэрэглэгч үүснэ).
  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  PhoneAuthCredential createPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<void> reauthenticateWithPassword({
    required String password,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      throw StateError('Хэрэглэгчийн бүртгэл олдсонгүй.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Хэрэглэгч нэвтрээгүй байна.');
    }

    await user.updatePassword(newPassword);
  }


  Future<void> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Хэрэглэгч нэвтрээгүй байна.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    await user.updatePhoneNumber(credential);
    await user.reload();

    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      throw StateError('Хэрэглэгчийн бүртгэл олдсонгүй.');
    }

    await refreshedUser.getIdToken(true);
  }

  Future<void> signOut() => _auth.signOut();
}