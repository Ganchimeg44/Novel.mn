import '../models/novel.dart';

/// ЛОКАЛ ТУРШИЛТЫН ӨГӨГДӨЛ
/// Firebase холбогдоогүй үед апп-аа туршихад ашиглана.
final List<Novel> mockNovels = [
  Novel(
    id: 'novel_1',
    title: 'Сүүдрийн Хаан',
    author: 'Б. Ганбаатар',
    coverImage: 'assets/images/placeholder_cover_1.png',
    description:
        'Эгэл нэгэн охин хүүгийн сэтгэлд хааны цус урсаж байгааг тэр ч мэдэхгүй. '
        'Өвөө авгаараа тангараг өргөж, тэрээр сүүдрээс хүчээ цуглуулж эхэлнэ.',
    genre: const ['Адал явдал', 'Фэнтэзи', 'Эрх мэдэл'],
    rating: 4.8,
    chapters: const [
      Chapter(
        id: 'n1_c1',
        number: 1,
        title: 'Эхлэл',
        content:
            'Салхи хүчтэй үлээж, хар үүлс тэнгэрийг бүрхэн авлаа. Алсын хаа '
            'нэгтээ аянга цахиж, газар чичирхийлнэ.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n1_c2',
        number: 2,
        title: 'Харанхуйд хөл тавихуй',
        content:
            'Тэр зогсож зайгүй алхсаар байсан. Өмнө нь хэзээ ч төсөөлж '
            'байгаагүй хүчийг өөрийн дотор мэдэрч байлаа.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n1_c3',
        number: 3,
        title: 'Нуугдсан хүч',
        content:
            '"Хэрэв би хүчтэй болохгүй бол, бүхнийг алдана." Тэрээр алхаагаа '
            'түргэсгэв.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n1_c4',
        number: 4,
        title: 'Анхны даалгавар',
        content: 'Энэ бүлэг VIP эрхтэй хэрэглэгчдэд нээлттэй.',
        accessLevel: AccessLevel.vip,
      ),
      Chapter(
        id: 'n1_c5',
        number: 5,
        title: 'Туршилт',
        content: 'Энэ бүлэг зөвхөн VVIP эрхтэй хэрэглэгчдэд нээлттэй.',
        accessLevel: AccessLevel.vvip,
      ),
    ],
  ),
  Novel(
    id: 'novel_2',
    title: 'Галын Өв Залгамжлагч',
    author: 'Д. Сарантуяа',
    coverImage: 'assets/images/placeholder_cover_2.png',
    description:
        'Галын овгийн сүүлчийн залгамжлагч эртний хараалыг эвдэхийн тулд '
        'аюултай аянд мордоно.',
    genre: const ['Адал явдал', 'Экшн'],
    rating: 4.6,
    chapters: const [
      Chapter(
        id: 'n2_c1',
        number: 1,
        title: 'Өв залгамжлал',
        content:
            'Овгийн сүүлчийн үр удам гэдгээ мэдсэн өдрөөс түүний амьдрал өөрчлөгдөв.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n2_c2',
        number: 2,
        title: 'Хараалын ул мөр',
        content:
            'Хуучин судар дотроос тэрээр овгийнхоо хараалын тухай олж мэдэв.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n2_c3',
        number: 3,
        title: 'Аюултай зам',
        content: 'Энэ бүлэг VIP эрхтэй хэрэглэгчдэд нээлттэй.',
        accessLevel: AccessLevel.vip,
      ),
      Chapter(
        id: 'n2_c4',
        number: 4,
        title: 'Тулаан',
        content: 'Энэ бүлэг VIP эрхтэй хэрэглэгчдэд нээлттэй.',
        accessLevel: AccessLevel.vip,
      ),
    ],
  ),
  Novel(
    id: 'novel_3',
    title: 'Хугарсан Дэлхий',
    author: 'Ц. Мөнхбат',
    coverImage: 'assets/images/placeholder_cover_3.png',
    description:
        'Дэлхий хуваагдсаны дараах ертөнцөд амьд үлдэхийн төлөө тэмцэх нэгэн '
        'бүлгийн түүх.',
    genre: const ['Постапокалипс', 'Драм'],
    rating: 4.5,
    chapters: const [
      Chapter(
        id: 'n3_c1',
        number: 1,
        title: 'Сүйрлийн дараа',
        content:
            'Хот харанхуйд дүрэгдэж, амьд үлдэгсэд бие биенээ хайж эхлэв.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n3_c2',
        number: 2,
        title: 'Шинэ гэр бүл',
        content:
            'Тэдгээр өөр өөрийн замаар ирсэн хүмүүс аажмаар бие биедээ итгэж эхлэв.',
        accessLevel: AccessLevel.free,
      ),
      Chapter(
        id: 'n3_c3',
        number: 3,
        title: 'Хамгаалалт',
        content: 'Энэ бүлэг VIP эрхтэй хэрэглэгчдэд нээлттэй.',
        accessLevel: AccessLevel.vip,
      ),
    ],
  ),
];