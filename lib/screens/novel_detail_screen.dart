import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/novel.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'chapter_reader_screen.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;

  const NovelDetailScreen({
    super.key,
    required this.novel,
  });

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedTab = 0;

  bool _loadingAccess = true;
  bool _hasVip = false;
  bool _hasVvip = false;

  Novel get novel => widget.novel;

  @override
  void initState() {
    super.initState();
    _loadUserAccess();
  }

  Future<void> _loadUserAccess() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      if (!mounted) return;

      setState(() {
        _hasVip = false;
        _hasVvip = false;
        _loadingAccess = false;
      });

      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final data = snapshot.data() ?? <String, dynamic>{};

      final now = DateTime.now();

      bool hasActiveAccess({
        required String expiresField,
        required String legacyDaysField,
      }) {
        final expiresAt = data[expiresField];

        if (expiresAt is Timestamp) {
          return expiresAt.toDate().isAfter(now);
        }

        final legacyValue = data[legacyDaysField];

        int legacyDays = 0;

        if (legacyValue is int) {
          legacyDays = legacyValue;
        } else if (legacyValue is num) {
          legacyDays = legacyValue.toInt();
        } else {
          legacyDays =
              int.tryParse(legacyValue?.toString() ?? '') ?? 0;
        }

        return legacyDays > 0;
      }

      var vip = hasActiveAccess(
        expiresField: 'vipExpiresAt',
        legacyDaysField: 'vipDays',
      );

      var vvip = hasActiveAccess(
        expiresField: 'vvipExpiresAt',
        legacyDaysField: 'vvipDays',
      );

      // Админ бүх контентыг шалгах боломжтой.
      if (data['isAdmin'] == true) {
        vip = true;
        vvip = true;
      }

      if (!mounted) return;

      setState(() {
        _hasVip = vip;
        _hasVvip = vvip;
        _loadingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _hasVip = false;
        _hasVvip = false;
        _loadingAccess = false;
      });
    }
  }

  bool _canAccessChapter(Chapter chapter) {
    switch (chapter.accessLevel) {
      case AccessLevel.free:
        return true;

      case AccessLevel.vip:
        return _hasVip || _hasVvip;

      case AccessLevel.vvip:
        return _hasVvip;
    }
  }

  String _chapterAccessName(Chapter chapter) {
    switch (chapter.accessLevel) {
      case AccessLevel.free:
        return 'Үнэгүй';

      case AccessLevel.vip:
        return 'VIP';

      case AccessLevel.vvip:
        return 'VVIP';
    }
  }

  Color _chapterAccessColor(Chapter chapter) {
    switch (chapter.accessLevel) {
      case AccessLevel.free:
        return AppColors.success;

      case AccessLevel.vip:
        return AppColors.vipAccent;

      case AccessLevel.vvip:
        return AppColors.vvipAccent;
    }
  }

  void _showLockedMessage(Chapter chapter) {
    String message;

    switch (chapter.accessLevel) {
      case AccessLevel.free:
        return;

      case AccessLevel.vip:
        message =
            'Энэ бүлгийг уншихын тулд VIP эсвэл VVIP эрх шаардлагатай.';
        break;

      case AccessLevel.vvip:
        message =
            'Энэ бүлгийг уншихын тулд VVIP эрх шаардлагатай.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _openChapter(int index) {
    if (_loadingAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Эрхийн мэдээлэл шалгаж байна...'),
        ),
      );
      return;
    }

    final chapter = novel.chapters[index];

    if (!_canAccessChapter(chapter)) {
      _showLockedMessage(chapter);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          novel: novel,
          chapterIndex: index,
        ),
      ),
    );
  }

  void _startReading() {
    if (novel.chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Одоогоор бүлэг нэмэгдээгүй байна.',
          ),
        ),
      );
      return;
    }

    if (_loadingAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Эрхийн мэдээлэл шалгаж байна...',
          ),
        ),
      );
      return;
    }

    final firstAccessibleIndex = novel.chapters.indexWhere(
      _canAccessChapter,
    );

    if (firstAccessibleIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Танд унших боломжтой бүлэг алга.',
          ),
        ),
      );
      return;
    }

    _openChapter(firstAccessibleIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(),
        actions: [
          IconButton(
            onPressed: () {
              // Favorite backend дараа холбоно.
            },
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () {
              // Share logic дараа холбоно.
            },
            icon: const Icon(
              Icons.ios_share_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 920,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              children: [
                _buildHero(),
                const SizedBox(
                  height: AppSpacing.xxl,
                ),
                _buildDescription(),
                const SizedBox(
                  height: AppSpacing.xxl,
                ),
                _buildReadButton(),
                const SizedBox(
                  height: AppSpacing.xxxl,
                ),
                _buildTabs(),
                const SizedBox(
                  height: AppSpacing.lg,
                ),
                if (_selectedTab == 0)
                  _buildChapterList()
                else
                  _buildCommentsPlaceholder(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;

        if (isWide) {
          return PremiumCard(
            elevated: true,
            radius: AppRadius.premium,
            padding: const EdgeInsets.all(
              AppSpacing.xl,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildCover(
                  width: 190,
                  height: 270,
                ),
                const SizedBox(
                  width: AppSpacing.xxl,
                ),
                Expanded(
                  child: _buildNovelInfo(
                    centered: false,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildCover(
              width: 160,
              height: 230,
            ),
            const SizedBox(
              height: AppSpacing.xl,
            ),
            _buildNovelInfo(
              centered: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCover({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          AppRadius.premium,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(
              alpha: 0.16,
            ),
            blurRadius: 28,
            offset: const Offset(
              0,
              12,
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppRadius.premium,
        ),
        child: Image.asset(
          novel.coverImage,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              color: AppColors.surfaceElevated,
              alignment: Alignment.center,
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.textMuted,
                size: 56,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNovelInfo({
    required bool centered,
  }) {
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          novel.title,
          textAlign: centered
              ? TextAlign.center
              : TextAlign.left,
          style: AppTypography.novelTitle(
            fontSize: 28,
          ),
        ),
        const SizedBox(
          height: AppSpacing.xs,
        ),
        Text(
          novel.author,
          textAlign: centered
              ? TextAlign.center
              : TextAlign.left,
          style: AppTypography.body(
            color: AppColors.goldLight,
          ),
        ),
        const SizedBox(
          height: AppSpacing.md,
        ),
        Wrap(
          alignment: centered
              ? WrapAlignment.center
              : WrapAlignment.start,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: novel.genre.map(
            (genre) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        AppColors.primary.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
                child: Text(
                  genre,
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              );
            },
          ).toList(),
        ),
        const SizedBox(
          height: AppSpacing.xl,
        ),
        Row(
          mainAxisSize: centered
              ? MainAxisSize.min
              : MainAxisSize.max,
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            _StatItem(
              icon: Icons.star_rounded,
              iconColor: AppColors.gold,
              value:
                  novel.rating.toStringAsFixed(1),
              label: 'Үнэлгээ',
            ),
            const SizedBox(
              width: AppSpacing.xxl,
            ),
            _StatItem(
              icon: Icons.menu_book_rounded,
              iconColor:
                  AppColors.primaryLight,
              value:
                  '${novel.chapters.length}',
              label: 'Бүлэг',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Тайлбар',
          style: AppTypography.sectionTitle(),
        ),
        const SizedBox(
          height: AppSpacing.md,
        ),
        Text(
          novel.description,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildReadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
            _loadingAccess ? null : _startReading,
        icon: _loadingAccess
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.menu_book_rounded,
              ),
        label: Text(
          _loadingAccess
              ? 'Эрх шалгаж байна...'
              : 'Уншиж эхлэх',
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          AppRadius.button,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DetailTab(
              label: 'Бүлгүүд',
              icon:
                  Icons.format_list_numbered_rounded,
              selected: _selectedTab == 0,
              onTap: () {
                setState(() {
                  _selectedTab = 0;
                });
              },
            ),
          ),
          Expanded(
            child: _DetailTab(
              label: 'Сэтгэгдэл',
              icon:
                  Icons.chat_bubble_outline_rounded,
              selected: _selectedTab == 1,
              onTap: () {
                setState(() {
                  _selectedTab = 1;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    if (novel.chapters.isEmpty) {
      return PremiumCard(
        child: Center(
          child: Text(
            'Одоогоор бүлэг нэмэгдээгүй байна.',
            style: AppTypography.body(),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Text(
              'Нийт ${novel.chapters.length} бүлэг',
              style: AppTypography.meta(),
            ),
          ],
        ),
        const SizedBox(
          height: AppSpacing.md,
        ),
        ...List.generate(
          novel.chapters.length,
          (index) {
            final chapter =
                novel.chapters[index];

            final canAccess =
                !_loadingAccess &&
                    _canAccessChapter(chapter);

            final accessColor =
                _chapterAccessColor(chapter);

            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.sm,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      _openChapter(index),
                  borderRadius:
                      BorderRadius.circular(
                    AppRadius.card,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(
                      AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(
                        AppRadius.card,
                      ),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment:
                              Alignment.center,
                          decoration:
                              BoxDecoration(
                            color: canAccess
                                ? accessColor
                                    .withValues(
                                    alpha: 0.12,
                                  )
                                : AppColors
                                    .surfaceElevated,
                            borderRadius:
                                BorderRadius
                                    .circular(12),
                          ),
                          child: canAccess
                              ? Text(
                                  '${chapter.number}',
                                  style: GoogleFonts
                                      .poppins(
                                    color:
                                        accessColor,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .lock_outline_rounded,
                                  color: AppColors
                                      .textMuted,
                                  size: 19,
                                ),
                        ),
                        const SizedBox(
                          width: AppSpacing.md,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Бүлэг ${chapter.number}',
                                style:
                                    AppTypography
                                        .meta(),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                chapter.title,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    AppTypography
                                        .cardTitle(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color: accessColor
                                .withValues(
                              alpha: 0.12,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(10),
                          ),
                          child: Text(
                            _chapterAccessName(
                              chapter,
                            ),
                            style:
                                GoogleFonts.poppins(
                              color: accessColor,
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!canAccess) ...[
                          const SizedBox(
                            width: AppSpacing.sm,
                          ),
                          const Icon(
                            Icons.lock_rounded,
                            color:
                                AppColors.textMuted,
                            size: 17,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentsPlaceholder() {
    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primaryLight,
            size: 40,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            'Сэтгэгдэл',
            style: AppTypography.sectionTitle(),
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          Text(
            'Сэтгэгдлийн системийг Firestore-той холбоход энэ хэсэгт '
            'уншигчдын сэтгэгдэл харагдана.',
            textAlign: TextAlign.center,
            style: AppTypography.body(),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
        const SizedBox(
          width: AppSpacing.sm,
        ),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: AppTypography.meta(),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DetailTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
            const SizedBox(
              width: AppSpacing.sm,
            ),
            Flexible(
              child: Text(
                label,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: selected
                      ? Colors.white
                      : AppColors
                          .textSecondary,
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}