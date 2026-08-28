import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/novel.dart';
import '../theme/app_theme.dart';

/// Cover зургийг ачаалж, олдохгүй бол (жишээ нь placeholder зам байгаа ч
/// asset файл бодитоор нэмэгдээгүй үед) орлуулах icon харуулна.
class _CoverImage extends StatelessWidget {
  final String coverImage;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _CoverImage({
    required this.coverImage,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        coverImage,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: AppColors.surface,
          alignment: Alignment.center,
          child: Icon(
            Icons.menu_book_rounded,
            color: AppColors.textSecondary,
            size: width * 0.35,
          ),
        ),
      ),
    );
  }
}

/// "Үргэлжлүүлэн уншиж буй" мөрөнд ашиглах карт — cover, гарчиг, зохиогч,
/// унших явцын хувь болон progress bar-тай.
class ProgressNovelCard extends StatelessWidget {
  final Novel novel;
  final double progress; // 0.0 - 1.0 хооронд, унших явц
  final VoidCallback? onTap;

  const ProgressNovelCard({
    super.key,
    required this.novel,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = constraints.maxWidth * 0.16;
        final cover = coverSize.clamp(48.0, 64.0);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _CoverImage(
                  coverImage: novel.coverImage,
                  width: cover,
                  height: cover,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        novel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        novel.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Жижиг poster хэлбэрийн карт — cover зураг, гарчиг, зохиогч.
/// Хэвтээ жагсаалт (ListView.separated, scrollDirection: horizontal) дотор
/// ашиглахад тохиромжтой, өргөнөө гадны Widget-ээс (жиш. SizedBox) тохируулна.
class NovelPosterCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback? onTap;

  const NovelPosterCard({
    super.key,
    required this.novel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 110.0;
          final coverHeight = width * 1.4;

          return SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CoverImage(
                  coverImage: novel.coverImage,
                  width: width,
                  height: coverHeight,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 6),
                Text(
                  novel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  novel.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}