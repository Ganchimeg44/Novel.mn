import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/novel.dart';
import '../models/user_model.dart';
import '../services/reading_settings_service.dart';
import '../theme/app_theme.dart';

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

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late int _currentIndex;

  String _chapterContent = '';

  final ReadingSettingsService _readingSettingsService =
      ReadingSettingsService();

  String _fontFamily = 'Noto Sans';
  double _fontSize = 18;
  double _lineHeight = 1.9;

  bool _accessLoading = true;
  bool _chapterLoading = false;

  bool _isAdmin = false;
  bool _hasVip = false;
  bool _hasVvip = false;

  String? _chapterError;

  Chapter get _chapter => widget.novel.chapters[_currentIndex];

  bool get _isFirstChapter => _currentIndex == 0;

  bool get _isLastChapter =>
      _currentIndex == widget.novel.chapters.length - 1;

  double get _chapterProgress {
    if (widget.novel.chapters.isEmpty) {
      return 0;
    }

    return (_currentIndex + 1) / widget.novel.chapters.length;
  }

  bool get _canReadCurrentChapter {
    if (_isAdmin) {
      return true;
    }

    switch (_chapter.accessLevel) {
      case AccessLevel.free:
        return true;

      case AccessLevel.vip:
        return _hasVip || _hasVvip;

      case AccessLevel.vvip:
        return _hasVvip;
    }
  }

  String get _requiredAccessLabel {
    switch (_chapter.accessLevel) {
      case AccessLevel.free:
        return 'FREE';

      case AccessLevel.vip:
        return 'VIP';

      case AccessLevel.vvip:
        return 'VVIP';
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.novel.chapters.isEmpty) {
      _currentIndex = 0;
      _accessLoading = false;
      _chapterError = 'Энэ зохиолд бүлэг байхгүй байна.';
      return;
    }

    if (widget.chapterIndex < 0) {
      _currentIndex = 0;
    } else if (widget.chapterIndex >= widget.novel.chapters.length) {
      _currentIndex = widget.novel.chapters.length - 1;
    } else {
      _currentIndex = widget.chapterIndex;
    }

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadAccess(),
      _loadReadingSettings(),
    ]);

    if (!mounted) {
      return;
    }

    await _loadCurrentChapter();
  }

  Future<void> _loadReadingSettings() async {
    final settings = await _readingSettingsService.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _fontFamily = settings.fontFamily;
      _fontSize = settings.fontSize;
      _lineHeight = settings.lineHeight;
    });
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _hasActiveExpiration(dynamic value) {
    if (value is! Timestamp) {
      return false;
    }

    return value.toDate().isAfter(DateTime.now());
  }

  Future<void> _loadAccess() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _accessLoading = false;
        _isAdmin = false;
        _hasVip = false;
        _hasVvip = false;
      });

      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final data = snapshot.data() ?? <String, dynamic>{};

      final isAdmin = data['isAdmin'] == true;

      final legacyVipDays = _readInt(data['vipDays']);
      final legacyVvipDays = _readInt(data['vvipDays']);

      final hasVvip =
          isAdmin ||
          _hasActiveExpiration(data['vvipExpiresAt']) ||
          (data['vvipExpiresAt'] == null && legacyVvipDays > 0);

      final hasVip =
          isAdmin ||
          hasVvip ||
          _hasActiveExpiration(data['vipExpiresAt']) ||
          (data['vipExpiresAt'] == null && legacyVipDays > 0);

      if (!mounted) {
        return;
      }

      setState(() {
        _isAdmin = isAdmin;
        _hasVip = hasVip;
        _hasVvip = hasVvip;
        _accessLoading = false;
      });
    } catch (error) {
      debugPrint('READER ACCESS ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isAdmin = false;
        _hasVip = false;
        _hasVvip = false;
        _accessLoading = false;
      });
    }
  }

  Future<void> _loadCurrentChapter() async {
    if (widget.novel.chapters.isEmpty) {
      return;
    }

    final chapter = _chapter;

    if (!_canReadCurrentChapter) {
      if (!mounted) {
        return;
      }

      setState(() {
        _chapterLoading = false;
        _chapterError = null;
        _chapterContent = '';
      });

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _chapterLoading = true;
      _chapterError = null;
      _chapterContent = '';
    });

    try {
      final snapshot = await _firestore
          .collection('novels')
          .doc(widget.novel.id)
          .collection('chapters')
          .doc(chapter.id)
          .get();

      if (!snapshot.exists) {
        if (!mounted) {
          return;
        }

        setState(() {
          _chapterLoading = false;
          _chapterError = 'Бүлгийн мэдээлэл олдсонгүй.';
          _chapterContent = '';
        });

        return;
      }

      final data = snapshot.data() ?? <String, dynamic>{};

      final content = data['content']?.toString() ?? '';

      if (!mounted) {
        return;
      }

      if (_chapter.id != chapter.id) {
        return;
      }

      setState(() {
        _chapterContent = content;
        _chapterLoading = false;

        if (content.trim().isEmpty) {
          _chapterError = 'Энэ бүлгийн текст хоосон байна.';
        }
      });

      if (content.trim().isNotEmpty) {
        await _saveReadingProgress(chapter);
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'READER FIRESTORE ERROR: '
        '${error.code} ${error.message}',
      );

      if (!mounted) {
        return;
      }

      if (_chapter.id != chapter.id) {
        return;
      }

      setState(() {
        _chapterLoading = false;
        _chapterContent = '';

        if (error.code == 'permission-denied') {
          _chapterError =
              'Энэ бүлгийг унших эрх хүрэлцэхгүй байна.';
        } else {
          _chapterError =
              'Бүлгийг ачаалж чадсангүй. Дахин оролдоно уу.';
        }
      });
    } catch (error) {
      debugPrint('READER CHAPTER ERROR: $error');

      if (!mounted) {
        return;
      }

      if (_chapter.id != chapter.id) {
        return;
      }

      setState(() {
        _chapterLoading = false;
        _chapterContent = '';
        _chapterError =
            'Бүлгийг ачаалж чадсангүй. Дахин оролдоно уу.';
      });
    }
  }

  Future<void> _saveReadingProgress(Chapter chapter) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return;
    }

    if (!_canReadCurrentChapter) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .collection('readingProgress')
          .doc(widget.novel.id)
          .set(
        <String, dynamic>{
          'novelId': widget.novel.id,
          'chapterId': chapter.id,
          'chapterNumber': chapter.number,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'READING PROGRESS FIRESTORE ERROR: '
        '${error.code} ${error.message}',
      );
    } catch (error) {
      debugPrint('READING PROGRESS ERROR: $error');
    }
  }

  Future<void> _goToChapter(int newIndex) async {
    if (newIndex < 0 ||
        newIndex >= widget.novel.chapters.length ||
        newIndex == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = newIndex;
      _chapterContent = '';
      _chapterError = null;
    });

    await _loadCurrentChapter();
  }

  void _showFontSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.readerBackground,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> updateSettings({
              String? fontFamily,
              double? fontSize,
              double? lineHeight,
            }) async {
              final nextFontFamily = fontFamily ?? _fontFamily;
              final nextFontSize = fontSize ?? _fontSize;
              final nextLineHeight = lineHeight ?? _lineHeight;

              setState(() {
                _fontFamily = nextFontFamily;
                _fontSize = nextFontSize;
                _lineHeight = nextLineHeight;
              });

              setSheetState(() {});

              await _readingSettingsService.save(
                ReadingSettings(
                  fontFamily: nextFontFamily,
                  fontSize: nextFontSize,
                  lineHeight: nextLineHeight,
                ),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Унших тохиргоо',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.readerText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Фонт',
                        style: GoogleFonts.poppins(
                          color: AppColors.readerText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ReadingSettingsService.availableFonts
                            .map(
                              (font) => ChoiceChip(
                                label: Text(
                                  font,
                                  style: _readerTextStyle(
                                    fontFamily: font,
                                    fontSize: 14,
                                    lineHeight: 1.2,
                                  ),
                                ),
                                selected: _fontFamily == font,
                                onSelected: (_) {
                                  updateSettings(
                                    fontFamily: font,
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Үсгийн хэмжээ',
                            style: GoogleFonts.poppins(
                              color: AppColors.readerText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_fontSize.round()} px',
                            style: GoogleFonts.poppins(
                              color: AppColors.readerMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Text(
                            'A',
                            style: _readerTextStyle(
                              fontSize: 14,
                              lineHeight: 1.2,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _fontSize,
                              min: 14,
                              max: 28,
                              divisions: 14,
                              activeColor: AppColors.primary,
                              inactiveColor:
                                  AppColors.readerMuted.withValues(
                                alpha: 0.25,
                              ),
                              onChanged: (value) {
                                updateSettings(
                                  fontSize: value,
                                );
                              },
                            ),
                          ),
                          Text(
                            'A',
                            style: _readerTextStyle(
                              fontSize: 28,
                              lineHeight: 1.2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Мөр хоорондын зай',
                            style: GoogleFonts.poppins(
                              color: AppColors.readerText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _lineHeight.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              color: AppColors.readerMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Slider(
                        value: _lineHeight,
                        min: 1.2,
                        max: 2.4,
                        divisions: 12,
                        activeColor: AppColors.primary,
                        inactiveColor:
                            AppColors.readerMuted.withValues(
                          alpha: 0.25,
                        ),
                        onChanged: (value) {
                          updateSettings(
                            lineHeight: value,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.readerMuted.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Энэ бол унших тохиргооны жишээ текст. '
                          'Фонт, үсгийн хэмжээ болон мөр хоорондын '
                          'зайг өөрчлөөд хараарай.',
                          style: _readerTextStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  TextStyle _readerTextStyle({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
  }) {
    final family = fontFamily ?? _fontFamily;

    final baseStyle = TextStyle(
      color: AppColors.readerText,
      fontSize: fontSize ?? _fontSize,
      height: lineHeight ?? _lineHeight,
      fontWeight: FontWeight.w400,
    );

    switch (family) {
      case 'Noto Serif':
        return GoogleFonts.notoSerif(
          textStyle: baseStyle,
        );

      case 'Roboto':
        return GoogleFonts.roboto(
          textStyle: baseStyle,
        );

      case 'PT Serif':
        return GoogleFonts.ptSerif(
          textStyle: baseStyle,
        );

      case 'Noto Sans':
      default:
        return GoogleFonts.notoSans(
          textStyle: baseStyle,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.novel.chapters.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.readerBackground,
        appBar: AppBar(
          backgroundColor: AppColors.readerBackground,
          foregroundColor: AppColors.readerText,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Энэ зохиолд бүлэг байхгүй байна.',
            style: GoogleFonts.poppins(
              color: AppColors.readerMuted,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildChapterHeader(),
                        const SizedBox(height: 30),
                        _buildChapterBody(),
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
              onPrevious: () {
                _goToChapter(_currentIndex - 1);
              },
              onNext: () {
                _goToChapter(_currentIndex + 1);
              },
              chapterNumber: _chapter.number,
              totalChapters: widget.novel.chapters.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterBody() {
    if (_accessLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 40,
          ),
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (!_canReadCurrentChapter) {
      return _LockedChapterNotice(
        requiredAccess: _requiredAccessLabel,
      );
    }

    if (_chapterLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 40,
          ),
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_chapterError != null) {
      return _ChapterLoadError(
        message: _chapterError!,
        onRetry: _loadCurrentChapter,
      );
    }

    return Text(
      _chapterContent,
      style: _readerTextStyle(),
    );
  }

  Widget _buildProgressBar() {
    return LinearProgressIndicator(
      value: _chapterProgress,
      minHeight: 3,
      backgroundColor: AppColors.readerMuted.withValues(
        alpha: 0.15,
      ),
      valueColor: const AlwaysStoppedAnimation<Color>(
        AppColors.primary,
      ),
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
            borderRadius: BorderRadius.circular(10),
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
            color: AppColors.readerMuted.withValues(
              alpha: 0.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isLastChapter ? 'Төгсөв' : 'Бүлгийн төгсгөл',
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

class _ChapterLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ChapterLoadError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.readerMuted.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.readerMuted,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.readerMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              onRetry();
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text('Дахин оролдох'),
          ),
        ],
      ),
    );
  }
}

class _LockedChapterNotice extends StatelessWidget {
  final String requiredAccess;

  const _LockedChapterNotice({
    required this.requiredAccess,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.readerMuted.withValues(
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
            '$requiredAccess эрх шаардлагатай.',
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
            color: AppColors.readerMuted.withValues(
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
                icon: Icons.chevron_left_rounded,
                label: 'Өмнөх',
                enabled: !isFirstChapter,
                onTap: onPrevious,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 11,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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