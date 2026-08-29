import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/novel.dart';
import '../theme/app_theme.dart';

/// Зохиолын дэлгэрэнгүй дэлгэц — тайлбар, бүлгүүдийн жагсаалт.
/// `Novel`/`Chapter` model-ийн одоогийн талбаруудтай (author, coverImage,
/// genre, rating, chapters[].content/isFree) нийцүүлсэн хувилбар.
class NovelDetailScreen extends StatelessWidget {
  final Novel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                novel.coverImage,
                width: 140,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 140,
                  height: 190,
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              novel.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              novel.author,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: novel.genre
                  .map((g) => Chip(
                        label: Text(g, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.surface,
                        labelStyle: const TextStyle(color: AppColors.textPrimary),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  novel.rating.toStringAsFixed(1),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.menu_book, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${novel.chapters.length} бүлэг',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Тайлбар',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            novel.description,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Бүлгүүд',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                'Нийт ${novel.chapters.length} бүлэг',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...novel.chapters.take(5).map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${c.number}. ${c.title}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: c.isFree
                      ? const Text('Үнэгүй',
                          style: TextStyle(color: AppColors.primary))
                      : const Icon(Icons.lock_outline,
                          color: AppColors.textSecondary, size: 18),
                  onTap: () {
                    // Дараа нь энд унших дэлгэц рүү шилжинэ (Navigator.push)
                  },
                ),
              ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Дараа нь энд эхний бүлэг рүү шилжинэ (Navigator.push)
            },
            child: const SizedBox(
              width: double.infinity,
              child: Text('Унших эхлэх', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}