import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import '../models/user_model.dart';

/// Firestore-той шууд харьцаж, `UserModel`-ийг хадгалах/унших, мөн
/// `username` болон `sixDigitId`-ийн ДАВХАРДАХГҮЙ БАЙХ шаардлагыг
/// хариуцна.
///
/// Ашигладаг коллекцууд:
///   users/{uid}              -> UserModel.toMap()
///   usernames/{usernameKey}  -> { 'uid': ..., 'email': ... }  (uniqueness)
///   sixDigitIds/{id}         -> { 'uid': ... }                (uniqueness)
///
/// `usernames` болон `sixDigitIds` нь тусдаа "нөөцлөлтийн" коллекц бөгөөд
/// Firestore transaction ашиглан "баримт байгаа эсэхийг шалгаад, байхгүй
/// бол шууд үүсгэх" ажиллагааг atomic (хуваагдашгүй) байдлаар гүйцэтгэдэг
/// тул хоёр хэрэглэгч зэрэг адилхан username/ID авахыг сэргийлнэ.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  CollectionReference<Map<String, dynamic>> get _sixDigitIds =>
      _db.collection('sixDigitIds');

  String _usernameKey(String username) => username.trim().toLowerCase();

  // ---------------------------------------------------------------------
  // Username: давхардахгүй байдал
  // ---------------------------------------------------------------------

  Future<bool> isUsernameTaken(String username) async {
    final doc = await _usernames.doc(_usernameKey(username)).get();
    return doc.exists;
  }

  /// Username-г тухайн `uid`-д "нөөцөлж" (доод түвшинд Firestore doc
  /// үүсгэж) авна. Хэрэв өмнө нь өөр хэн нэгэн авчихсан бол алдаа шиднэ.
  /// [email] нь дараа нь username-аар нэвтрэхэд (username -> email
  /// хөрвүүлэлт) ашиглагдана; утасны дугаараар л бүртгүүлсэн, имэйл
  /// холбоогүй хэрэглэгчийн хувьд null байж болно.
  Future<void> reserveUsername({
    required String username,
    required String uid,
    String? email,
  }) async {
    final key = _usernameKey(username);
    final docRef = _usernames.doc(key);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        throw StateError('Энэ хэрэглэгчийн нэр аль хэдийн ашиглагдсан байна.');
      }
      transaction.set(docRef, {
        'uid': uid,
        'email': email,
        'createdAt': DateTime.now(),
      });
    });
  }

  /// Username-аар холбогдох имэйлийг олно (username → email нэвтрэлтэд
  /// ашиглана). Тухайн username имэйлгүй (зөвхөн утсаар бүртгүүлсэн)
  /// бол null буцна.
  Future<String?> getEmailForUsername(String username) async {
    final doc = await _usernames.doc(_usernameKey(username)).get();
    if (!doc.exists) return null;
    return doc.data()?['email'] as String?;
  }

  // ---------------------------------------------------------------------
  // 6 оронтой ID: давхардахгүй байдал
  // ---------------------------------------------------------------------

  /// Санамсаргүй 6 оронтой ID үүсгэж, `sixDigitIds` коллекцод байхгүй
  /// (өөрөөр хэлбэл ашиглагдаагүй) хүртэл дахин оролдоно, олдвол шууд
  /// тухайн `uid`-д зориулж transaction-аар нөөцөлнө.
  Future<String> generateAndReserveSixDigitId(String uid) async {
    final random = Random();
    const maxAttempts = 20;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = (100000 + random.nextInt(900000)).toString();
      final docRef = _sixDigitIds.doc(candidate);

      try {
        await _db.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          if (snapshot.exists) {
            throw StateError('taken');
          }
          transaction.set(docRef, {'uid': uid, 'createdAt': DateTime.now()});
        });
        return candidate; // Амжилттай нөөцлөгдсөн ID
      } catch (_) {
        continue; // Энэ дугаар аль хэдийн авагдсан — дараагийнхийг үзье
      }
    }

    throw StateError(
      'Давтагдаагүй 6 оронтой ID үүсгэж чадсангүй — дахин оролдоно уу.',
    );
  }

  // ---------------------------------------------------------------------
  // users/{uid} доc
  // ---------------------------------------------------------------------

  Future<void> createUserProfile(UserModel user) {
    return _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserByUid(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final query = await _users
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return UserModel.fromMap(doc.data(), doc.id);
  }

  /// АНХААРУУЛГА: `birthDate`-г ЭНД зориудаар параметрээр авдаггүй —
  /// хэрэглэгчийн профайлыг шинэчлэх функц ирээдүйд нэмэгдэхэд ч,
  /// төрсөн өдрийг өөрчлөх боломжийг код-ийн түвшинд битгий нээ.
  /// Firestore Security Rules дээр давхар хамгаалалт (birthDate талбар
  /// request.resource.data-д resource.data-тай тэнцүү байхыг шаардах)
  /// нэмэхийг зөвлөж байна.
  Future<void> updateMutableProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) {
    assert(
      !fields.containsKey('birthDate'),
      'birthDate талбарыг бүртгүүлсний дараа өөрчлөхийг зөвшөөрдөггүй.',
    );
    return _users.doc(uid).update(fields);
  }
}