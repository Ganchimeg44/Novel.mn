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
  int _selectedTab = 0;

  Novel get novel => widget.novel;

  void _openChapter(int index) {
    final chapter = novel.chapters[index];

    if (!chapter.isFree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            'Энэ бүлэг түгжээтэй байна.',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
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
          content: Text('Одоогоор бүлэг нэмэгдээгүй байна.'),
        ),
      );
      return;
    }

    final firstFreeIndex =
        novel.chapters.indexWhere((chapter) => chapter.isFree);

    if (firstFreeIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Унших боломжтой үнэгүй бүлэг алга.'),
        ),
      );
      return;
    }

    _openChapter(firstFreeIndex);
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
              // Favorite backend нэмэгдэх үед энд холбоно.
            },
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () {
              // Share logic дараа нь холбоно.
            },
            icon: const Icon(
              Icons.ios_share_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.xxl),
                _buildDescription(),
                const SizedBox(height: AppSpacing.xxl),
                _buildReadButton(),
                const SizedBox(height: AppSpacing.xxxl),
                _buildTabs(),
                const SizedBox(height: AppSpacing.lg),
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
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(
                  width: 190,
                  height: 270,
                ),
                const SizedBox(width: AppSpacing.xxl),
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
            const SizedBox(height: AppSpacing.xl),
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
        borderRadius: BorderRadius.circular(AppRadius.premium),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.premium),
        child: Image.asset(
          novel.coverImage,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
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
    final crossAxisAlignment =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          novel.title,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: AppTypography.novelTitle(
            fontSize: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          novel.author,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: AppTypography.body(
            color: AppColors.goldLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment:
              centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: novel.genre.map((genre) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                genre,
                style: GoogleFonts.poppins(
                  color: AppColors.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisSize:
              centered ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            _StatItem(
              icon: Icons.star_rounded,
              iconColor: AppColors.gold,
              value: novel.rating.toStringAsFixed(1),
              label: 'Үнэлгээ',
            ),
            const SizedBox(width: AppSpacing.xxl),
            _StatItem(
              icon: Icons.menu_book_rounded,
              iconColor: AppColors.primaryLight,
              value: '${novel.chapters.length}',
              label: 'Бүлэг',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тайлбар',
          style: AppTypography.sectionTitle(),
        ),
        const SizedBox(height: AppSpacing.md),
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
        onPressed: _startReading,
        icon: const Icon(
          Icons.menu_book_rounded,
        ),
        label: const Text(
          'Уншиж эхлэх',
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DetailTab(
              label: 'Бүлгүүд',
              icon: Icons.format_list_numbered_rounded,
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
              icon: Icons.chat_bubble_outline_rounded,
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
        const SizedBox(height: AppSpacing.md),
        ...List.generate(
          novel.chapters.length,
          (index) {
            final chapter = novel.chapters[index];

            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.sm,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openChapter(index),
                  borderRadius:
                      BorderRadius.circular(AppRadius.card),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chapter.isFree
                                ? AppColors.primary.withValues(
                                    alpha: 0.12,
                                  )
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: chapter.isFree
                              ? Text(
                                  '${chapter.number}',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.textMuted,
                                  size: 19,
                                ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Бүлэг ${chapter.number}',
                                style: AppTypography.meta(),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                chapter.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cardTitle(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (chapter.isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Үнэгүй',
                              style: GoogleFonts.poppins(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
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
          const SizedBox(height: AppSpacing.md),
          Text(
            'Сэтгэгдэл',
            style: AppTypography.sectionTitle(),
          ),
          const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
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