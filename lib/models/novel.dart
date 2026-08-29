/// Нэг бүлгийг илэрхийлэх модель
class Chapter {
  final String id;
  final int number;
  final String title;
  final String content; // Бүлгийн бүтэн текст (унших дэлгэцэд ашиглана)
  final bool isFree; // true бол үнэгүй, false бол худалдан авах шаардлагатай

  const Chapter({
    required this.id,
    required this.number,
    required this.title,
    required this.content,
    this.isFree = true,
  });
}

/// Нэг зохиолыг илэрхийлэх модель
class Novel {
  final String id;
  final String title;
  final String author;
  final String coverImage; // Одоогоор зурагны URL (локал болон сүлжээний аль алинд ажиллана)
  final String description;
  final List<String> genre; // Жишээ нь: ['Адал явдал', 'Фэнтэзи', 'Эрх мэдэл']
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