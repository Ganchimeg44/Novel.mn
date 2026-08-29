import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/mock_novels.dart';
import '../models/novel.dart';
import '../theme/app_theme.dart';
import '../widgets/novel_card.dart';
import 'novel_detail_screen.dart';

/// Нүүр хуудас — greeting, featured banner, "Үргэлжлүүлэн унших" болон
/// "Шинээр нэмэгдсэн" хэсгүүд, доод navigation bar-тай.
/// `Novel` дээр дарахад `NovelDetailScreen` рүү шилждэг.
class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  int _currentTab = 0;

  void _openNovelDetail(BuildContext context, Novel novel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Novel featured = mockNovels.first;
    final continuing = mockNovels; // Одоохондоо бүгдийг "үргэлжлүүлж буй" гэж үзье
    final newlyAdded = mockNovels.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // --- Дээд хэсэг: Greeting + search ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Сайн байна уу?',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- Featured / banner ---
            GestureDetector(
              onTap: () => _openNovelDetail(context, featured),
              child: Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.surface,
                  image: DecorationImage(
                    image: AssetImage(featured.coverImage),
                    fit: BoxFit.cover,
                    onError: (error, stackTrace) {},
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.35),
                      BlendMode.darken,
                    ),
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      featured.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      featured.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // --- Үргэлжлүүлэн унших ---
            _SectionHeader(title: 'Үргэлжлүүлэн унших'),
            const SizedBox(height: 8),
            ...List.generate(continuing.length, (index) {
              final novel = continuing[index];
              // Жишээ прогресс: зохиол бүрд өөр өөр хувь харуулъя
              final progress = 0.3 + (index * 0.2);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ProgressNovelCard(
                  novel: novel,
                  progress: progress.clamp(0.0, 1.0),
                  onTap: () => _openNovelDetail(context, novel),
                ),
              );
            }),

            const SizedBox(height: 20),

            // --- Шинээр нэмэгдсэн ---
            _SectionHeader(title: 'Шинээр нэмэгдсэн'),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: newlyAdded.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final novel = newlyAdded[index];
                  return SizedBox(
                    width: 110,
                    child: NovelPosterCard(
                      novel: novel,
                      onTap: () => _openNovelDetail(context, novel),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
      ),
    );
  }
}

/// Хэсгийн гарчиг ("Үргэлжлүүлэн унших", "Шинээр нэмэгдсэн" гэх мэт)
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }
}

/// Доод navigation bar: Нүүр, Номын сан, Профайл
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Нүүр',
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.menu_book_rounded,
              label: 'Номын сан',
              isActive: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Профайл',
              isActive: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}