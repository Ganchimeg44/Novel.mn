import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/novel.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

/// Тухайн бүлэгт хийсэн үгийн bookmark-уудыг session дотор хадгална.
///
/// АНХААРУУЛГА: Firestore/локал storage package (жиш. shared_preferences)
/// одоогоор төсөлд нэмэгдээгүй тул энэ нь зөвхөн APP АЖИЛЛАЖ БАЙХ ХУГАЦААНД
/// (session) л хадгалагддаг санах ойн (in-memory) хувилбар юм. Гэхдээ
/// бусад код (`ChapterReaderScreen`) үүнийг зөвхөн энэ классын нийтийн
/// method-уудаар (`getBookmarks` / `toggleBookmark`) дамжуулан ашигладаг
/// тул дараа нь Firestore нэмэгдэхэд ЗӨВХӨН ЭНЭ классын дотоод
/// хэрэгжилтийг сольж, доор дурдсан method-уудыг Firestore-с
/// унших/бичих болгож өөрчлөхөд хангалттай — дуудагч код (screen)-ыг
/// өөрчлөх шаардлагагүй.
class ChapterWordBookmarkStore {
  ChapterWordBookmarkStore._internal();
  static final ChapterWordBookmarkStore instance =
      ChapterWordBookmarkStore._internal();

  // Түлхүүр: "<novelId>_<chapterId>" -> тухайн бүлэгт bookmark хийсэн
  // үгсийн индексүүд (тухайн бүлгийн content-ийг зайгаар хуваасны дараах
  // үгийн дараалсан дугаар).
  final Map<String, Set<int>> _bookmarksByChapter = {};

  String _keyFor(String novelId, String chapterId) => '${novelId}_$chapterId';

  /// Тухайн бүлэгт өмнө нь хадгалагдсан bookmark-уудыг буцаана.
  /// Дараа Firestore нэмэгдэхэд энд `await` -тай хайлт хийж болно —
  /// дуудагч тал (`ChapterReaderScreen`) өөрчлөгдөх шаардлагагүй.
  Set<int> getBookmarks(String novelId, String chapterId) {
    return _bookmarksByChapter[_keyFor(novelId, chapterId)] ?? <int>{};
  }

  /// Тухайн үгийн bookmark төлөвийг сэлгэнэ (нэмэх/хасах).
  void toggleBookmark(String novelId, String chapterId, int wordIndex) {
    final key = _keyFor(novelId, chapterId);
    final current = _bookmarksByChapter.putIfAbsent(key, () => <int>{});
    if (current.contains(wordIndex)) {
      current.remove(wordIndex);
    } else {
      current.add(wordIndex);
    }
  }
}

/// Нэг бүлгийг уншиж, өмнөх/дараагийн бүлэг рүү шилжих, мөн үг дээр
/// 2 удаа дарж bookmark хийх боломжтой унших дэлгэц.
class ChapterReaderScreen extends StatefulWidget {
  final Novel novel;
  final int chapterIndex; // novel.chapters дотор эхлэх бүлгийн индекс
  final UserModel? user; // bookmark өнгийг тодорхойлоход ашиглана

  const ChapterReaderScreen({
    super.key,
    required this.novel,
    required this.chapterIndex,
    this.user,
  });

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late int _currentIndex;
  late List<String> _words;
  Set<int> _bookmarkedWordIndices = <int>{};

  final ChapterWordBookmarkStore _bookmarkStore =
      ChapterWordBookmarkStore.instance;

  Chapter get _chapter => widget.novel.chapters[_currentIndex];
  bool get _isFirstChapter => _currentIndex == 0;
  bool get _isLastChapter =>
      _currentIndex == widget.novel.chapters.length - 1;

  Color get _bookmarkColor {
    final hex = widget.user?.bookmarkColor;
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      final cleaned = hex.replaceAll('#', '');
      final fullHex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
      return Color(int.parse(fullHex, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.chapterIndex;
    _loadChapter();
  }

  /// Тухайн бүлгийн content-ийг үгээр хуваан, хадгалагдсан bookmark-уудыг
  /// сэргээнэ. Бүлэг солигдох бүрт (өмнөх/дараах товч дарахад) дуудагдана.
  void _loadChapter() {
    _words = _chapter.content.split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    _bookmarkedWordIndices = _bookmarkStore.getBookmarks(
      widget.novel.id,
      _chapter.id,
    );
  }

  void _goToChapter(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.novel.chapters.length) return;
    setState(() {
      _currentIndex = newIndex;
      _loadChapter();
    });
  }

  void _onWordDoubleTap(int wordIndex) {
    setState(() {
      _bookmarkStore.toggleBookmark(
        widget.novel.id,
        _chapter.id,
        wordIndex,
      );
      _bookmarkedWordIndices = _bookmarkStore.getBookmarks(
        widget.novel.id,
        _chapter.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          widget.novel.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Бүлэг ${_chapter.number}',
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _chapter.title,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_chapter.isFree)
                      _LockedChapterNotice(title: _chapter.title)
                    else
                      _BookmarkableParagraph(
                        words: _words,
                        bookmarkedIndices: _bookmarkedWordIndices,
                        bookmarkColor: _bookmarkColor,
                        onWordDoubleTap: _onWordDoubleTap,
                      ),
                  ],
                ),
              ),
            ),
            _ReaderNavBar(
              isFirstChapter: _isFirstChapter,
              isLastChapter: _isLastChapter,
              onPrevious: () => _goToChapter(_currentIndex - 1),
              onNext: () => _goToChapter(_currentIndex + 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bookmark хийх боломжтой, үг тус бүрийг дарж болдог параграф.
class _BookmarkableParagraph extends StatelessWidget {
  final List<String> words;
  final Set<int> bookmarkedIndices;
  final Color bookmarkColor;
  final ValueChanged<int> onWordDoubleTap;

  const _BookmarkableParagraph({
    required this.words,
    required this.bookmarkedIndices,
    required this.bookmarkColor,
    required this.onWordDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontSize: 16,
      height: 1.8,
    );

    return Wrap(
      children: List.generate(words.length, (index) {
        final word = words[index];
        final isBookmarked = bookmarkedIndices.contains(index);

        return Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          child: GestureDetector(
            onDoubleTap: () => onWordDoubleTap(index),
            child: Container(
              padding: isBookmarked
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                  : EdgeInsets.zero,
              decoration: isBookmarked
                  ? BoxDecoration(
                      color: bookmarkColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: bookmarkColor, width: 1),
                    )
                  : null,
              child: Text(
                word,
                style: isBookmarked
                    ? baseStyle.copyWith(
                        color: bookmarkColor,
                        fontWeight: FontWeight.w600,
                      )
                    : baseStyle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Худалдан аваагүй (isFree == false) бүлэгт харуулах мэдэгдэл.
class _LockedChapterNotice extends StatelessWidget {
  final String title;

  const _LockedChapterNotice({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline,
            color: AppColors.textSecondary,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Энэ бүлгийг уншихын тулд худалдаж авах шаардлагатай.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Доод хэсэгт байрлах "Өмнөх / Дараах" навигацийн мөр.
class _ReaderNavBar extends StatelessWidget {
  final bool isFirstChapter;
  final bool isLastChapter;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ReaderNavBar({
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _NavButton(
                icon: Icons.chevron_left_rounded,
                label: 'Өмнөх',
                enabled: !isFirstChapter,
                onTap: onPrevious,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavButton(
                icon: Icons.chevron_right_rounded,
                label: 'Дараах',
                enabled: !isLastChapter,
                onTap: onNext,
                iconTrailing: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool iconTrailing;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.iconTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.textSecondary;
    final children = <Widget>[
      if (!iconTrailing) Icon(icon, color: color, size: 20),
      if (!iconTrailing) const SizedBox(width: 4),
      Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      if (iconTrailing) const SizedBox(width: 4),
      if (iconTrailing) Icon(icon, color: color, size: 20),
    ];

    return Material(
      color: enabled ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}