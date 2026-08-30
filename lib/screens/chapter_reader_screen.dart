import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/novel.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class ChapterWordBookmarkStore {
  ChapterWordBookmarkStore._internal();

  static final ChapterWordBookmarkStore instance =
      ChapterWordBookmarkStore._internal();

  final Map<String, Set<int>> _bookmarksByChapter = {};

  String _keyFor(String novelId, String chapterId) =>
      '${novelId}_$chapterId';

  Set<int> getBookmarks(String novelId, String chapterId) {
    return Set<int>.from(
      _bookmarksByChapter[_keyFor(novelId, chapterId)] ?? <int>{},
    );
  }

  void toggleBookmark(
    String novelId,
    String chapterId,
    int wordIndex,
  ) {
    final key = _keyFor(novelId, chapterId);
    final current =
        _bookmarksByChapter.putIfAbsent(key, () => <int>{});

    if (current.contains(wordIndex)) {
      current.remove(wordIndex);
    } else {
      current.add(wordIndex);
    }
  }
}

class ChapterReaderScreen extends StatefulWidget {
  final Novel novel;
  final int chapterIndex;
  final UserModel? user;

  const ChapterReaderScreen({
    super.key,
    required this.novel,
    required this.chapterIndex,
    this.user,
  });

  @override
  State<ChapterReaderScreen> createState() =>
      _ChapterReaderScreenState();
}

class _ChapterReaderScreenState
    extends State<ChapterReaderScreen> {
  late int _currentIndex;
  late List<String> _words;

  Set<int> _bookmarkedWordIndices = <int>{};

  final ChapterWordBookmarkStore _bookmarkStore =
      ChapterWordBookmarkStore.instance;

  double _fontSize = 18;

  Chapter get _chapter =>
      widget.novel.chapters[_currentIndex];

  bool get _isFirstChapter => _currentIndex == 0;

  bool get _isLastChapter =>
      _currentIndex == widget.novel.chapters.length - 1;

  double get _chapterProgress {
    if (widget.novel.chapters.isEmpty) return 0;

    return (_currentIndex + 1) /
        widget.novel.chapters.length;
  }

  Color get _bookmarkColor {
    final hex = widget.user?.bookmarkColor;

    if (hex == null || hex.isEmpty) {
      return AppColors.primary;
    }

    try {
      final cleaned = hex.replaceAll('#', '');
      final fullHex =
          cleaned.length == 6 ? 'FF$cleaned' : cleaned;

      return Color(
        int.parse(fullHex, radix: 16),
      );
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

  void _loadChapter() {
    _words = _chapter.content
        .split(RegExp(r'\s+'))
      ..removeWhere(
        (word) => word.isEmpty,
      );

    _bookmarkedWordIndices =
        _bookmarkStore.getBookmarks(
      widget.novel.id,
      _chapter.id,
    );
  }

  void _goToChapter(int newIndex) {
    if (newIndex < 0 ||
        newIndex >= widget.novel.chapters.length) {
      return;
    }

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

      _bookmarkedWordIndices =
          _bookmarkStore.getBookmarks(
        widget.novel.id,
        _chapter.id,
      );
    });
  }

  void _showFontSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.readerBackground,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Үсгийн хэмжээ',
                      style: GoogleFonts.poppins(
                        color: AppColors.readerText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'A',
                          style: GoogleFonts.lora(
                            color: AppColors.readerText,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 14,
                            max: 28,
                            divisions: 7,
                            activeColor: AppColors.primary,
                            inactiveColor:
                                AppColors.readerMuted
                                    .withValues(
                              alpha: 0.25,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _fontSize = value;
                              });

                              setSheetState(() {});
                            },
                          ),
                        ),
                        Text(
                          'A',
                          style: GoogleFonts.lora(
                            color: AppColors.readerText,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fontSize.round()} px',
                      style: GoogleFonts.poppins(
                        color: AppColors.readerMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.readerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.readerBackground,
        foregroundColor: AppColors.readerText,
        elevation: 0,
        leading: const BackButton(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.novel.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.readerText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Бүлэг ${_chapter.number}',
              style: GoogleFonts.poppins(
                color: AppColors.readerMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _showFontSettings,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.readerText,
            ),
            child: Text(
              'Aa',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.readerText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.readerMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildChapterHeader(),
                        const SizedBox(height: 30),
                        if (!_chapter.isFree)
                          _LockedChapterNotice(
                            title: _chapter.title,
                          )
                        else
                          _BookmarkableParagraph(
                            words: _words,
                            bookmarkedIndices:
                                _bookmarkedWordIndices,
                            bookmarkColor:
                                _bookmarkColor,
                            fontSize: _fontSize,
                            onWordDoubleTap:
                                _onWordDoubleTap,
                          ),
                        const SizedBox(height: 40),
                        _buildEndDivider(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _ReaderNavBar(
              isFirstChapter: _isFirstChapter,
              isLastChapter: _isLastChapter,
              onPrevious: () =>
                  _goToChapter(_currentIndex - 1),
              onNext: () =>
                  _goToChapter(_currentIndex + 1),
              chapterNumber: _chapter.number,
              totalChapters:
                  widget.novel.chapters.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _chapterProgress,
          minHeight: 3,
          backgroundColor:
              AppColors.readerMuted.withValues(
            alpha: 0.15,
          ),
          valueColor:
              const AlwaysStoppedAnimation<Color>(
            AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildChapterHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'БҮЛЭГ ${_chapter.number}',
          style: GoogleFonts.poppins(
            color: AppColors.readerMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _chapter.title,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.readerText,
            fontWeight: FontWeight.w700,
            fontSize: 30,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 46,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildEndDivider() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 50,
            height: 1,
            color:
                AppColors.readerMuted.withValues(
              alpha: 0.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isLastChapter
                ? 'Төгсөв'
                : 'Бүлгийн төгсгөл',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.readerMuted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkableParagraph
    extends StatelessWidget {
  final List<String> words;
  final Set<int> bookmarkedIndices;
  final Color bookmarkColor;
  final double fontSize;
  final ValueChanged<int> onWordDoubleTap;

  const _BookmarkableParagraph({
    required this.words,
    required this.bookmarkedIndices,
    required this.bookmarkColor,
    required this.fontSize,
    required this.onWordDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.lora(
      color: AppColors.readerText,
      fontSize: fontSize,
      height: 1.9,
      fontWeight: FontWeight.w400,
    );

    return Wrap(
      children: List.generate(
        words.length,
        (index) {
          final word = words[index];
          final isBookmarked =
              bookmarkedIndices.contains(index);

          return Padding(
            padding: const EdgeInsets.only(
              right: 5,
              bottom: 3,
            ),
            child: GestureDetector(
              onDoubleTap: () =>
                  onWordDoubleTap(index),
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 150),
                padding: isBookmarked
                    ? const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      )
                    : EdgeInsets.zero,
                decoration: isBookmarked
                    ? BoxDecoration(
                        color:
                            bookmarkColor.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius:
                            BorderRadius.circular(4),
                        border: Border(
                          bottom: BorderSide(
                            color: bookmarkColor,
                            width: 2,
                          ),
                        ),
                      )
                    : null,
                child: Text(
                  word,
                  style: isBookmarked
                      ? baseStyle.copyWith(
                          color:
                              AppColors.readerText,
                          fontWeight:
                              FontWeight.w600,
                        )
                      : baseStyle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LockedChapterNotice
    extends StatelessWidget {
  final String title;

  const _LockedChapterNotice({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.32,
        ),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              AppColors.readerMuted.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.readerMuted,
            size: 38,
          ),
          const SizedBox(height: 14),
          Text(
            'Энэ бүлэг түгжээтэй байна',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.readerText,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Уншихын тулд шаардлагатай эрхийг идэвхжүүлнэ.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.readerMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderNavBar extends StatelessWidget {
  final bool isFirstChapter;
  final bool isLastChapter;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final int chapterNumber;
  final int totalChapters;

  const _ReaderNavBar({
    required this.isFirstChapter,
    required this.isLastChapter,
    required this.onPrevious,
    required this.onNext,
    required this.chapterNumber,
    required this.totalChapters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE0CA),
        border: Border(
          top: BorderSide(
            color:
                AppColors.readerMuted.withValues(
              alpha: 0.18,
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _NavButton(
                icon:
                    Icons.chevron_left_rounded,
                label: 'Өмнөх',
                enabled: !isFirstChapter,
                onTap: onPrevious,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              child: Text(
                '$chapterNumber / $totalChapters',
                style: GoogleFonts.poppins(
                  color: AppColors.readerMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: _NavButton(
                icon:
                    Icons.chevron_right_rounded,
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
    final color = enabled
        ? AppColors.readerText
        : AppColors.readerMuted.withValues(
            alpha: 0.40,
          );

    return Material(
      color: enabled
          ? Colors.white.withValues(
              alpha: 0.25,
            )
          : Colors.transparent,
      borderRadius:
          BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 11,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              if (!iconTrailing) ...[
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (iconTrailing) ...[
                const SizedBox(width: 3),
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}