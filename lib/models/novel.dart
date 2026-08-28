cat > /home/claude/novel_app/lib/models/user_model.dart << 'EOF'
/// Хэрэглэгчийн Firestore-д хадгалагдах өгөгдлийн загвар.
///
/// АНХААРУУЛГА: Энэ класс нэвтрэх (auth) мэдээлэл (нууц үг гэх мэт) огт
/// агуулахгүй — тэдгээрийг Firebase Authentication бие даан удирдана.
/// Энд зөвхөн Firestore-ийн "users" коллекцод хадгалагдах профайл,
/// эрх (VIP/VVIP/+18), тоглоомын (XP) болон тохиргооны өгөгдөл байна.
///
/// Firestore-той шууд холбохдоо (жишээ нь):
///   UserModel.fromMap(docSnapshot.data()!, docSnapshot.id)
///   docRef.set(userModel.toMap())
/// гэж ашиглах боломжтой байхаар бүтээгдсэн. `cloud_firestore` package
/// одоогоор төсөлд нэмэгдээгүй тул энэ файл түүнээс огт хамааралгүй —
/// огноог уншихдаа Firestore-ийн Timestamp объектыг "duck typing"-аар
/// (динамик `toDate()` дуудалтаар) таньж авдаг, бичихдээ энгийн DateTime
/// буцаадаг тул cloud_firestore нэмэгдсэний дараа өөрчлөлт хийх шаардлагагүй.
class UserModel {
  /// Firebase Authentication-с ирэх өвөрмөц ID (auth эрхийн түлхүүр)
  final String uid;

  /// Апп доторх 6 оронтой хэрэглэгчийн дугаар (жиш: "482913"),
  /// хэрэглэгчид харагдах, найз нөхөддөө хуваалцах зориулалттай ID
  final String sixDigitId;

  final String username;
  final String email;
  final String? phoneNumber;
  final String displayName;
  final DateTime? birthDate;
  final DateTime createdAt;
  final String? profileImageUrl;

  /// Эрхийн үлдсэн хоног тоо (0 бол идэвхгүй)
  final int vipDays;
  final int vvipDays;
  final int adult18Days;

  final int xp;

  final List<String> favoriteGenres;
  final List<String> dislikedGenres;
  final List<String> likedNovelIds;

  /// Төрсөн өдрийн бэлэг авсан сүүлийн жил (давхар авахаас сэргийлнэ).
  /// null бол хараахан авч байгаагүй.
  final int? birthdayGiftClaimedYear;

  final bool isAdmin;
  final bool isTranslator;
  final bool commentsEnabled;

  /// Хэрэглэгчийн сонгосон хавчуурга (bookmark)-ийн өнгө, hex код
  /// хэлбэрээр хадгална (жиш: "#6C5CE7")
  final String bookmarkColor;

  const UserModel({
    required this.uid,
    required this.sixDigitId,
    required this.username,
    required this.email,
    this.phoneNumber,
    required this.displayName,
    this.birthDate,
    required this.createdAt,
    this.profileImageUrl,
    this.vipDays = 0,
    this.vvipDays = 0,
    this.adult18Days = 0,
    this.xp = 0,
    this.favoriteGenres = const [],
    this.dislikedGenres = const [],
    this.likedNovelIds = const [],
    this.birthdayGiftClaimedYear,
    this.isAdmin = false,
    this.isTranslator = false,
    this.commentsEnabled = true,
    this.bookmarkColor = '#6C5CE7',
  });

  // ---------------------------------------------------------------------
  // Тооцоолсон (computed) туслах getter-үүд
  // ---------------------------------------------------------------------

  bool get isVip => vipDays > 0;
  bool get isVvip => vvipDays > 0;
  bool get hasAdultAccess => adult18Days > 0;

  // ---------------------------------------------------------------------
  // Firestore Timestamp <-> DateTime хөрвүүлэх туслах функцууд
  // ---------------------------------------------------------------------

  /// Firestore-с ирэх утга нь `Timestamp`, `DateTime`, `int`
  /// (millisecondsSinceEpoch) эсвэл ISO8601 `String` байж болох тул
  /// эдгээр бүх тохиолдлыг зохицуулна. `cloud_firestore` package-ийг
  /// шууд import хийхгүйгээр Timestamp-ийг танихын тулд dynamic
  /// "duck typing" ашиглав (`toDate()` метод байгаа эсэхийг шалгана).
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      // Firestore Timestamp объект бол toDate() методтой байдаг
      final dynamic dynamicValue = value;
      final DateTime? converted = dynamicValue.toDate();
      return converted;
    } catch (_) {
      return null;
    }
  }

  /// `birthDate` шиг null байж болох огноог хөрвүүлнэ
  static DateTime? _parseNullableDateTime(dynamic value) =>
      _parseDateTime(value);

  /// `createdAt` шиг заавал утгатай огноог хөрвүүлж, олдохгүй бол
  /// одоогийн цагийг буцаана (аюулгүй fallback).
  static DateTime _parseRequiredDateTime(dynamic value) =>
      _parseDateTime(value) ?? DateTime.now();

  // ---------------------------------------------------------------------
  // Firestore Map <-> UserModel
  // ---------------------------------------------------------------------

  /// Firestore документын өгөгдлөөс `UserModel` үүсгэнэ.
  /// [documentId] нь ихэвчлэн Firestore документын ID (=== uid) байна;
  /// map дотор `uid` талбар байхгүй тохиолдолд үүнийг ашиглана.
  factory UserModel.fromMap(Map<String, dynamic> map, [String? documentId]) {
    return UserModel(
      uid: (map['uid'] as String?) ?? documentId ?? '',
      sixDigitId: (map['sixDigitId'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      displayName: (map['displayName'] as String?) ?? '',
      birthDate: _parseNullableDateTime(map['birthDate']),
      createdAt: _parseRequiredDateTime(map['createdAt']),
      profileImageUrl: map['profileImageUrl'] as String?,
      vipDays: (map['vipDays'] as num?)?.toInt() ?? 0,
      vvipDays: (map['vvipDays'] as num?)?.toInt() ?? 0,
      adult18Days: (map['adult18Days'] as num?)?.toInt() ?? 0,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      favoriteGenres: List<String>.from(map['favoriteGenres'] as List? ?? []),
      dislikedGenres: List<String>.from(map['dislikedGenres'] as List? ?? []),
      likedNovelIds: List<String>.from(map['likedNovelIds'] as List? ?? []),
      birthdayGiftClaimedYear:
          (map['birthdayGiftClaimedYear'] as num?)?.toInt(),
      isAdmin: (map['isAdmin'] as bool?) ?? false,
      isTranslator: (map['isTranslator'] as bool?) ?? false,
      commentsEnabled: (map['commentsEnabled'] as bool?) ?? true,
      bookmarkColor: (map['bookmarkColor'] as String?) ?? '#6C5CE7',
    );
  }

  /// Firestore-д бичихэд бэлэн Map буцаана.
  /// DateTime талбаруудыг шууд `DateTime` хэлбэрээр буцаадаг бөгөөд
  /// `cloud_firestore` package нэмэгдсэний дараа Firestore SDK эдгээрийг
  /// бичихдээ автоматаар `Timestamp` болгож хөрвүүлнэ (нэмэлт өөрчлөлт
  /// хийх шаардлагагүй).
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'sixDigitId': sixDigitId,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'birthDate': birthDate,
      'createdAt': createdAt,
      'profileImageUrl': profileImageUrl,
      'vipDays': vipDays,
      'vvipDays': vvipDays,
      'adult18Days': adult18Days,
      'xp': xp,
      'favoriteGenres': favoriteGenres,
      'dislikedGenres': dislikedGenres,
      'likedNovelIds': likedNovelIds,
      'birthdayGiftClaimedYear': birthdayGiftClaimedYear,
      'isAdmin': isAdmin,
      'isTranslator': isTranslator,
      'commentsEnabled': commentsEnabled,
      'bookmarkColor': bookmarkColor,
    };
  }

  // ---------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------

  UserModel copyWith({
    String? uid,
    String? sixDigitId,
    String? username,
    String? email,
    String? phoneNumber,
    String? displayName,
    DateTime? birthDate,
    DateTime? createdAt,
    String? profileImageUrl,
    int? vipDays,
    int? vvipDays,
    int? adult18Days,
    int? xp,
    List<String>? favoriteGenres,
    List<String>? dislikedGenres,
    List<String>? likedNovelIds,
    int? birthdayGiftClaimedYear,
    bool? isAdmin,
    bool? isTranslator,
    bool? commentsEnabled,
    String? bookmarkColor,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      sixDigitId: sixDigitId ?? this.sixDigitId,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      vipDays: vipDays ?? this.vipDays,
      vvipDays: vvipDays ?? this.vvipDays,
      adult18Days: adult18Days ?? this.adult18Days,
      xp: xp ?? this.xp,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      dislikedGenres: dislikedGenres ?? this.dislikedGenres,
      likedNovelIds: likedNovelIds ?? this.likedNovelIds,
      birthdayGiftClaimedYear:
          birthdayGiftClaimedYear ?? this.birthdayGiftClaimedYear,
      isAdmin: isAdmin ?? this.isAdmin,
      isTranslator: isTranslator ?? this.isTranslator,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      bookmarkColor: bookmarkColor ?? this.bookmarkColor,
    );
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, sixDigitId: $sixDigitId, username: $username)';
}
EOF
mkdir -p /mnt/user-data/outputs/novel_app/lib/models
cp /home/claude/novel_app/lib/models/user_model.dart /mnt/user-data/outputs/novel_app/lib/models/user_model.dart
echo done
Output

done
