import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/mock_novels.dart';
import '../models/novel.dart';
import '../theme/app_theme.dart';
import '../widgets/novel_card.dart';
import '../widgets/premium_widgets.dart';
import 'novel_detail_screen.dart';
import 'profile_screen.dart';

class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  int _currentTab = 0;
  String _searchQuery = '';
  String? _selectedGenre;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openNovelDetail(BuildContext context, Novel novel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    );
  }

  List<String> get _allGenres {
    final genres = <String>{};

    for (final novel in mockNovels) {
      genres.addAll(novel.genre);
    }

    return genres.toList();
  }

  List<Novel> get _filteredNovels {
    final query = _searchQuery.trim().toLowerCase();

    return mockNovels.where((novel) {
      final matchesSearch = query.isEmpty ||
          novel.title.toLowerCase().contains(query) ||
          novel.author.toLowerCase().contains(query);

      final matchesGenre =
          _selectedGenre == null || novel.genre.contains(_selectedGenre);

      return matchesSearch && matchesGenre;
    }).toList();
  }

  void _onBottomNavTap(int index) {
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
      return;
    }

    setState(() {
      _currentTab = index;
    });

    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            _buildHomePage(),
            _buildSearchPage(),
            _buildLibraryPage(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentTab,
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _buildHomePage() {
    final visibleNovels = _filteredNovels;

    final Novel? featured =
        visibleNovels.isNotEmpty ? visibleNovels.first : null;

    final topRated = [...visibleNovels]
      ..sort((a, b) => b.rating.compareTo(a.rating));

    final newestFirst = visibleNovels.reversed.toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.contentMaxWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            _buildTopBar(),
            const SizedBox(height: AppSpacing.xl),
            _buildSearchBar(),
            const SizedBox(height: AppSpacing.md),
            _buildGenreChips(),
            const SizedBox(height: AppSpacing.xxl),
            if (featured != null) ...[
              _buildFeaturedHero(featured),
              const SizedBox(height: AppSpacing.xxxl),
            ],
            SectionHeader(
              title: 'Үргэлжлүүлэн унших',
              trailingLabel: 'Бүгд',
              onTrailingTap: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            _buildContinueReading(visibleNovels),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: 'Хамгийн их уншсан',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildHorizontalCarousel(visibleNovels),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: 'Өндөр үнэлгээтэй',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildHorizontalCarousel(topRated),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: 'Шинэ бүлэг орсон',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildHorizontalCarousel(newestFirst),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPage() {
    final novels = _filteredNovels;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.contentMaxWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Хайлт',
              style: AppTypography.pageTitle(),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSearchBar(),
            const SizedBox(height: AppSpacing.md),
            _buildGenreChips(),
            const SizedBox(height: AppSpacing.xxl),
            if (novels.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                child: Center(
                  child: Text(
                    'Зохиол олдсонгүй.',
                    style: AppTypography.body(),
                  ),
                ),
              )
            else
              _buildSearchGrid(novels),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryPage() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.contentMaxWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Миний сан',
              style: AppTypography.pageTitle(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PremiumCard(
              elevated: true,
              radius: AppRadius.premium,
              child: Column(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primaryLight,
                    size: 42,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Таны номын сан',
                    style: AppTypography.sectionTitle(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Дуртай болон хадгалсан зохиолууд энд харагдана.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Novel.mn',
                style: AppTypography.appLogo(),
              ),
              const SizedBox(height: 2),
              Text(
                'Унших ертөнц',
                style: AppTypography.meta(),
              ),
            ],
          ),
        ),
        _TopIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () {},
        ),
        const SizedBox(width: AppSpacing.sm),
        _TopIconButton(
          icon: Icons.person_outline_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: GoogleFonts.poppins(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Зохиол, зохиогч хайх...',
        hintStyle: GoogleFonts.poppins(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildGenreChips() {
    final genres = _allGenres;

    if (genres.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: genres.length + 1,
        separatorBuilder: (_, __) {
          return const SizedBox(width: AppSpacing.sm);
        },
        itemBuilder: (context, index) {
          final bool isAll = index == 0;
          final String label = isAll ? 'Бүгд' : genres[index - 1];

          final bool isSelected =
              isAll ? _selectedGenre == null : _selectedGenre == label;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGenre = isAll ? null : label;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedHero(Novel novel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 700;

        final double height = wide ? 320 : 270;

        return GestureDetector(
          onTap: () => _openNovelDetail(context, novel),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.hero),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  novel.coverImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.surfaceElevated,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        size: 72,
                        color: AppColors.textMuted,
                      ),
                    );
                  },
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: wide
                          ? Alignment.centerLeft
                          : Alignment.topCenter,
                      end: wide
                          ? Alignment.centerRight
                          : Alignment.bottomCenter,
                      colors: wide
                          ? [
                              AppColors.background.withValues(alpha: 0.96),
                              AppColors.background.withValues(alpha: 0.82),
                              AppColors.background.withValues(alpha: 0.28),
                            ]
                          : [
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.65),
                              AppColors.background.withValues(alpha: 0.98),
                            ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Align(
                    alignment:
                        wide ? Alignment.centerLeft : Alignment.bottomLeft,
                    child: SizedBox(
                      width: wide ? 480 : double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: novel.genre.take(3).map((genre) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  genre,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.goldLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            novel.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.novelTitle(
                              fontSize: wide ? 30 : 25,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            novel.author,
                            style: AppTypography.meta(
                              color: AppColors.goldLight,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            novel.description,
                            maxLines: wide ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                novel.rating.toStringAsFixed(1),
                                style: AppTypography.meta(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              const Icon(
                                Icons.menu_book_rounded,
                                color: AppColors.textSecondary,
                                size: 17,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${novel.chapters.length} бүлэг',
                                style: AppTypography.meta(),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton.icon(
                            onPressed: () {
                              _openNovelDetail(context, novel);
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Үргэлжлүүлэн унших',
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,
                                vertical: AppSpacing.md,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinueReading(List<Novel> novels) {
    if (novels.isEmpty) {
      return Text(
        'Одоогоор зохиол алга.',
        style: AppTypography.body(),
      );
    }

    final items = novels.take(3).toList();

    return Column(
      children: List.generate(
        items.length,
        (index) {
          final novel = items[index];

          final progress = (0.28 + (index * 0.19)).clamp(
            0.0,
            1.0,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1
                  ? 0
                  : AppSpacing.md,
            ),
            child: ProgressNovelCard(
              novel: novel,
              progress: progress,
              onTap: () {
                _openNovelDetail(context, novel);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalCarousel(List<Novel> novels) {
    if (novels.isEmpty) {
      return Text(
        'Одоогоор энэ хэсэгт зохиол алга.',
        style: AppTypography.body(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = constraints.maxWidth >= 900;
        final bool tablet = constraints.maxWidth >= 600;

        final double cardWidth = desktop
            ? 150
            : tablet
                ? 135
                : 118;

        final double listHeight = cardWidth * 1.85;

        return SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: novels.length,
            separatorBuilder: (_, __) {
              return const SizedBox(width: AppSpacing.md);
            },
            itemBuilder: (context, index) {
              final novel = novels[index];

              return SizedBox(
                width: cardWidth,
                child: NovelPosterCard(
                  novel: novel,
                  onTap: () {
                    _openNovelDetail(context, novel);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchGrid(List<Novel> novels) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 2;

        if (constraints.maxWidth >= 1100) {
          columns = 6;
        } else if (constraints.maxWidth >= 850) {
          columns = 5;
        } else if (constraints.maxWidth >= 650) {
          columns = 4;
        } else if (constraints.maxWidth >= 480) {
          columns = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: novels.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.xl,
            childAspectRatio: 0.52,
          ),
          itemBuilder: (context, index) {
            final novel = novels[index];

            return NovelPosterCard(
              novel: novel,
              onTap: () {
                _openNovelDetail(context, novel);
              },
            );
          },
        );
      },
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Нүүр',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Хайх',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.menu_book_rounded,
                label: 'Миний сан',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Профайл',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppColors.primaryLight : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 10.5,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}