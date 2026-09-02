/// Хэрэглэгчийн Firestore-д хадгалагдах өгөгдлийн загвар.
///
/// Firebase Authentication-ийн нууц үг зэрэг мэдээлэл энд хадгалагдахгүй.
/// Энэ класс нь Firestore-ийн `users` collection-ийн профайл,
/// эрх, XP болон тохиргооны мэдээллийг төлөөлнө.
class UserModel {
  /// Firebase Authentication UID
  final String uid;

  /// Апп доторх 6 оронтой хэрэглэгчийн ID
  final String sixDigitId;

  final String username;
  final String email;
  final String? phoneNumber;
  final String displayName;
  final DateTime? birthDate;
  final DateTime createdAt;
  final String? profileImageUrl;

  /// Хэрэглэгчийн сонгосон avatar: `male` эсвэл `female`.
  /// Хуучин хэрэглэгч дээр null байж болох бөгөөд UI ерөнхий avatar харуулна.
  final String? avatarType;

  // ---------------------------------------------------------------------
  // LEGACY эрхийн хоног
  // ---------------------------------------------------------------------
  //
  // Одоохондоо хуучин Firestore өгөгдөлтэй нийцүүлэхийн тулд хадгална.
  // Шинэ системд үндсэн эх сурвалж нь vipExpiresAt / vvipExpiresAt болно.
  //
  final int vipDays;
  final int vvipDays;

  /// +18 тусдаа entitlement биш болсон.
  /// Хуучин хэрэглэгчдийн Firestore data эвдрэхгүй байлгахын тулд
  /// түр хадгалж байна. Цаашид migration хийсний дараа устгаж болно.
  final int adult18Days;

  // ---------------------------------------------------------------------
  // ШИНЭ expiration систем
  // ---------------------------------------------------------------------

  /// VIP эрх дуусах яг огноо/цаг.
  ///
  /// null бол expiration системээр VIP эрх байхгүй гэсэн үг.
  final DateTime? vipExpiresAt;

  /// VVIP эрх дуусах яг огноо/цаг.
  ///
  /// null бол expiration системээр VVIP эрх байхгүй гэсэн үг.
  final DateTime? vvipExpiresAt;

  final int xp;

  final List<String> favoriteGenres;
  final List<String> dislikedGenres;
  final List<String> likedNovelIds;

  /// Төрсөн өдрийн бэлэг авсан сүүлийн жил.
  final int? birthdayGiftClaimedYear;

  final bool isAdmin;
  final bool isTranslator;
  final bool commentsEnabled;

  /// Bookmark өнгө. Жишээ: "#6C5CE7"
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
    this.avatarType,

    // Legacy
    this.vipDays = 0,
    this.vvipDays = 0,
    this.adult18Days = 0,

    // Шинэ expiration
    this.vipExpiresAt,
    this.vvipExpiresAt,

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
  // Эрхийн тооцоолол
  // ---------------------------------------------------------------------

  /// VIP expiration одоо хүчинтэй эсэх.
  bool get hasActiveVipExpiration {
    final expiresAt = vipExpiresAt;

    if (expiresAt == null) {
      return false;
    }

    return expiresAt.isAfter(DateTime.now());
  }

  /// VVIP expiration одоо хүчинтэй эсэх.
  bool get hasActiveVvipExpiration {
    final expiresAt = vvipExpiresAt;

    if (expiresAt == null) {
      return false;
    }

    return expiresAt.isAfter(DateTime.now());
  }

  /// VIP идэвхтэй эсэх.
  ///
  /// Шинэ expiration байгаа бол түүнийг ашиглана.
  /// Хуучин хэрэглэгч дээр expiration байхгүй бол legacy vipDays-ийг
  /// түр fallback болгон ашиглана.
  bool get isVip {
    if (vipExpiresAt != null) {
      return hasActiveVipExpiration;
    }

    return vipDays > 0;
  }

  /// VVIP идэвхтэй эсэх.
  ///
  /// Шинэ expiration байгаа бол түүнийг ашиглана.
  /// Хуучин хэрэглэгч дээр expiration байхгүй бол legacy vvipDays-ийг
  /// түр fallback болгон ашиглана.
  bool get isVvip {
    if (vvipExpiresAt != null) {
      return hasActiveVvipExpiration;
    }

    return vvipDays > 0;
  }

  /// VVIP нь VIP-аас дээш эрх тул premium VIP контентод
  /// VIP эсвэл VVIP аль аль нь нэвтэрч болно.
  bool get hasVipAccess => isVip || isVvip;

  /// +18 контентын эрх.
  ///
  /// +18 нь тусдаа subscription биш.
  /// Насны шалгалтыг тусдаа age logic хийнэ.
  /// Энд зөвхөн VVIP entitlement-ийг шалгана.
  bool get hasAdultAccess => isVvip;

  /// VIP-ийн үлдсэн хоног.
  ///
  /// Expiration байгаа үед тухайн хугацаанаас бодно.
  /// Expiration байхгүй хуучин хэрэглэгч дээр vipDays fallback ашиглана.
  int get remainingVipDays {
    final expiresAt = vipExpiresAt;

    if (expiresAt == null) {
      return vipDays < 0 ? 0 : vipDays;
    }

    return _remainingDays(expiresAt);
  }

  /// VVIP-ийн үлдсэн хоног.
  int get remainingVvipDays {
    final expiresAt = vvipExpiresAt;

    if (expiresAt == null) {
      return vvipDays < 0 ? 0 : vvipDays;
    }

    return _remainingDays(expiresAt);
  }

  /// Expiration хүртэл үлдсэн хоногийг хэрэглэгчид харуулахад ашиглана.
  ///
  /// Жишээ:
  /// 29 хоног 5 цаг үлдсэн бол 30 хоног гэж харуулна.
  ///
  /// Хугацаа дууссан бол 0.
  static int _remainingDays(DateTime expiresAt) {
    final now = DateTime.now();

    if (!expiresAt.isAfter(now)) {
      return 0;
    }

    final remaining = expiresAt.difference(now);

    final fullDays = remaining.inDays;

    final hasPartialDay =
        remaining.inSeconds > fullDays * Duration.secondsPerDay;

    return fullDays + (hasPartialDay ? 1 : 0);
  }

  // ---------------------------------------------------------------------
  // Firestore Timestamp <-> DateTime
  // ---------------------------------------------------------------------

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    try {
      final dynamic dynamicValue = value;
      final DateTime? converted =
          dynamicValue.toDate();

      return converted;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseNullableDateTime(
    dynamic value,
  ) {
    return _parseDateTime(value);
  }

  static DateTime _parseRequiredDateTime(
    dynamic value,
  ) {
    return _parseDateTime(value) ??
        DateTime.now();
  }

  static String? _parseAvatarType(dynamic value) {
    return value == 'male' || value == 'female' ? value as String : null;
  }

  // ---------------------------------------------------------------------
  // Firestore -> UserModel
  // ---------------------------------------------------------------------

  factory UserModel.fromMap(
    Map<String, dynamic> map, [
    String? documentId,
  ]) {
    return UserModel(
      uid:
          (map['uid'] as String?) ??
          documentId ??
          '',
      sixDigitId:
          (map['sixDigitId'] as String?) ??
          '',
      username:
          (map['username'] as String?) ?? '',
      email:
          (map['email'] as String?) ?? '',
      phoneNumber:
          map['phoneNumber'] as String?,
      displayName:
          (map['displayName'] as String?) ??
          '',
      birthDate:
          _parseNullableDateTime(
        map['birthDate'],
      ),
      createdAt:
          _parseRequiredDateTime(
        map['createdAt'],
      ),
      profileImageUrl:
          map['profileImageUrl'] as String?,
      avatarType: _parseAvatarType(map['avatarType']),

      // Legacy
      vipDays:
          (map['vipDays'] as num?)
                  ?.toInt() ??
              0,
      vvipDays:
          (map['vvipDays'] as num?)
                  ?.toInt() ??
              0,
      adult18Days:
          (map['adult18Days'] as num?)
                  ?.toInt() ??
              0,

      // Шинэ expiration
      vipExpiresAt:
          _parseNullableDateTime(
        map['vipExpiresAt'],
      ),
      vvipExpiresAt:
          _parseNullableDateTime(
        map['vvipExpiresAt'],
      ),

      xp:
          (map['xp'] as num?)
                  ?.toInt() ??
              0,

      favoriteGenres:
          List<String>.from(
        map['favoriteGenres'] as List? ??
            [],
      ),

      dislikedGenres:
          List<String>.from(
        map['dislikedGenres'] as List? ??
            [],
      ),

      likedNovelIds:
          List<String>.from(
        map['likedNovelIds'] as List? ??
            [],
      ),

      birthdayGiftClaimedYear:
          (map['birthdayGiftClaimedYear']
                  as num?)
              ?.toInt(),

      isAdmin:
          (map['isAdmin'] as bool?) ??
              false,

      isTranslator:
          (map['isTranslator'] as bool?) ??
              false,

      commentsEnabled:
          (map['commentsEnabled'] as bool?) ??
              true,

      bookmarkColor:
          (map['bookmarkColor'] as String?) ??
              '#6C5CE7',
    );
  }

  // ---------------------------------------------------------------------
  // UserModel -> Firestore
  // ---------------------------------------------------------------------

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
      'avatarType': avatarType,

      // Legacy
      'vipDays': vipDays,
      'vvipDays': vvipDays,
      'adult18Days': adult18Days,

      // Шинэ expiration
      'vipExpiresAt': vipExpiresAt,
      'vvipExpiresAt': vvipExpiresAt,

      'xp': xp,

      'favoriteGenres': favoriteGenres,
      'dislikedGenres': dislikedGenres,
      'likedNovelIds': likedNovelIds,

      'birthdayGiftClaimedYear':
          birthdayGiftClaimedYear,

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
    String? avatarType,

    int? vipDays,
    int? vvipDays,
    int? adult18Days,

    DateTime? vipExpiresAt,
    DateTime? vvipExpiresAt,

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
      sixDigitId:
          sixDigitId ?? this.sixDigitId,
      username:
          username ?? this.username,
      email:
          email ?? this.email,
      phoneNumber:
          phoneNumber ?? this.phoneNumber,
      displayName:
          displayName ?? this.displayName,
      birthDate:
          birthDate ?? this.birthDate,
      createdAt:
          createdAt ?? this.createdAt,
      profileImageUrl:
          profileImageUrl ??
              this.profileImageUrl,
      avatarType:
          avatarType ?? this.avatarType,

      vipDays:
          vipDays ?? this.vipDays,
      vvipDays:
          vvipDays ?? this.vvipDays,
      adult18Days:
          adult18Days ??
              this.adult18Days,

      vipExpiresAt:
          vipExpiresAt ??
              this.vipExpiresAt,
      vvipExpiresAt:
          vvipExpiresAt ??
              this.vvipExpiresAt,

      xp:
          xp ?? this.xp,

      favoriteGenres:
          favoriteGenres ??
              this.favoriteGenres,
      dislikedGenres:
          dislikedGenres ??
              this.dislikedGenres,
      likedNovelIds:
          likedNovelIds ??
              this.likedNovelIds,

      birthdayGiftClaimedYear:
          birthdayGiftClaimedYear ??
              this.birthdayGiftClaimedYear,

      isAdmin:
          isAdmin ?? this.isAdmin,
      isTranslator:
          isTranslator ??
              this.isTranslator,
      commentsEnabled:
          commentsEnabled ??
              this.commentsEnabled,

      bookmarkColor:
          bookmarkColor ??
              this.bookmarkColor,
    );
  }

  @override
  String toString() {
    return 'UserModel('
        'uid: $uid, '
        'sixDigitId: $sixDigitId, '
        'username: $username, '
        'vipExpiresAt: $vipExpiresAt, '
        'vvipExpiresAt: $vvipExpiresAt'
        ')';
  }
}