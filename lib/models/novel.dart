/// Контентын эрхийн төрөл
enum AccessLevel {
  free,
  vip,
  vvip,
}

/// Нэг бүлгийг илэрхийлэх модель
class Chapter {
  final String id;
  final int number;
  final String title;
  final String content;

  /// free  -> бүх хэрэглэгч
  /// vip   -> VIP эсвэл VVIP
  /// vvip  -> зөвхөн VVIP
  final AccessLevel accessLevel;

  const Chapter({
    required this.id,
    required this.number,
    required this.title,
    required this.content,
    this.accessLevel = AccessLevel.free,
  });

  bool get isFree => accessLevel == AccessLevel.free;
  bool get isVip => accessLevel == AccessLevel.vip;
  bool get isVvip => accessLevel == AccessLevel.vvip;
}

/// Нэг зохиолыг илэрхийлэх модель
class Novel {
  final String id;
  final String title;
  final String author;
  final String coverImage;
  final String description;
  final List<String> genre;
  final double rating;
  final List<Chapter> chapters;

  const Novel({
    required this.id,
    required this.title,
    required this.author,
    required this.coverImage,
    required this.description,
    required this.genre,
    required this.rating,
    required this.chapters,
  });
}