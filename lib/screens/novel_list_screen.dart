import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/novel.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'chapter_reader_screen.dart';
import 'novel_detail_screen.dart';
import 'profile_screen.dart';

class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentTab = 0;
  String _searchQuery = '';
  String? _selectedGenre;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  CollectionReference<Map<String, dynamic>> get _novels =>
      _firestore.collection('novels');

  Stream<QuerySnapshot<Map<String, dynamic>>> get _visibleNovelStream {
    return _novels
        .where('isPublished', isEqualTo: true)
        .where('isHidden', isEqualTo: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _ratingsStream {
    return _firestore.collectionGroup('ratings').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _likesStream {
    return _firestore.collectionGroup('likes').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _chapterCatalogStream {
    return _firestore.collectionGroup('chapterCatalog').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Timestamp? _readTimestamp(dynamic value) {
    return value is Timestamp ? value : null;
  }

  AccessLevel _accessLevelFrom(dynamic value) {
    switch (value?.toString().trim().toUpperCase()) {
      case 'VIP':
        return AccessLevel.vip;
      case 'VVIP':
        return AccessLevel.vvip;
      default:
        return AccessLevel.free;
    }
  }

  String _accessLabel(AccessLevel accessLevel) {
    switch (accessLevel) {
      case AccessLevel.free:
        return 'FREE';
      case AccessLevel.vip:
        return 'VIP';
      case AccessLevel.vvip:
        return 'VVIP';
    }
  }

  List<Chapter> _chapterCountPlaceholders(int count) {
    if (count <= 0) return const <Chapter>[];

    return List<Chapter>.generate(
      count,
      (index) => Chapter(
        id: 'placeholder_${index + 1}',
        number: index + 1,
        title: '',
        content: '',
      ),
      growable: false,
    );
  }

  Novel _novelFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    double? ratingOverride,
  }) {
    final data = document.data();
    final chapterCount = _readInt(data['chapterCount']);

    return Novel(
      id: document.id,
      title: (data['title'] ?? 'Нэргүй зохиол').toString(),
      author: (data['author'] ?? '').toString(),
      coverImage: (data['coverUrl'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      genre: _stringList(data['genres']),
      rating: ratingOverride ?? _readDouble(data['ratingAverage']),
      chapters: _chapterCountPlaceholders(chapterCount),
    );
  }

  Map<String, _RatingStats> _ratingStatsFrom(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final totals = <String, int>{};
    final counts = <String, int>{};

    for (final doc in snapshot?.docs ?? const []) {
      final novelRef = doc.reference.parent.parent;
      if (novelRef == null) continue;

      final value = _readInt(doc.data()['rating']);
      if (value < 1 || value > 5) continue;

      totals[novelRef.id] = (totals[novelRef.id] ?? 0) + value;
      counts[novelRef.id] = (counts[novelRef.id] ?? 0) + 1;
    }

    final result = <String, _RatingStats>{};

    for (final entry in counts.entries) {
      final total = totals[entry.key] ?? 0;
      result[entry.key] = _RatingStats(
        average: entry.value == 0 ? 0 : total / entry.value,
        count: entry.value,
      );
    }

    return result;
  }

  Map<String, int> _likeCountsFrom(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final counts = <String, int>{};

    for (final doc in snapshot?.docs ?? const []) {
      final novelRef = doc.reference.parent.parent;
      if (novelRef == null) continue;

      counts[novelRef.id] = (counts[novelRef.id] ?? 0) + 1;
    }

    return counts;
  }

  _ChapterCatalogData _chapterCatalogDataFrom(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    List<Novel> novels,
  ) {
    final novelById = <String, Novel>{
      for (final novel in novels) novel.id: novel,
    };

    final items = <_NewChapterItem>[];
    final chaptersByNovel = <String, List<Chapter>>{};

    for (final doc in snapshot?.docs ?? const []) {
      final novelRef = doc.reference.parent.parent;
      if (novelRef == null) continue;

      final novel = novelById[novelRef.id];
      if (novel == null) continue;

      final data = doc.data();

      if (data['isPublished'] != true) continue;
      if (data['isHidden'] == true) continue;

      final number = _readInt(data['number']);
      if (number <= 0) continue;

      final chapter = Chapter(
        id: doc.id,
        number: number,
        title: (data['title'] ?? '').toString(),
        content: '',
        accessLevel: _accessLevelFrom(data['accessLevel']),
      );

      chaptersByNovel
          .putIfAbsent(novel.id, () => <Chapter>[])
          .add(chapter);

      items.add(
        _NewChapterItem(
          novel: novel,
          chapter: chapter,
          updatedAt:
              _readTimestamp(data['updatedAt']) ??
              _readTimestamp(data['createdAt']),
        ),
      );
    }

    for (final chapters in chaptersByNovel.values) {
      chapters.sort((a, b) => a.number.compareTo(b.number));
    }

    items.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;

      if (aTime == null && bTime == null) {
        final byNovel = a.novel.title.compareTo(b.novel.title);
        if (byNovel != 0) return byNovel;
        return b.chapter.number.compareTo(a.chapter.number);
      }

      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return _ChapterCatalogData(
      items: items,
      chaptersByNovel: chaptersByNovel,
    );
  }

  Future<void> _saveRecentlyViewed(
    BuildContext context,
    String novelId,
  ) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      debugPrint('RECENT ERROR: Firebase user null');
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(firebaseUser.uid);

      final snapshot = await userRef.get();
      final data = snapshot.data() ?? <String, dynamic>{};

      final currentIds = _stringList(data['recentViewedNovelIds']);

      final updatedIds = <String>[
        novelId,
        ...currentIds.where((id) => id != novelId),
      ];

      if (updatedIds.length > 20) {
        updatedIds.removeRange(20, updatedIds.length);
      }

      await userRef.update({
        'recentViewedNovelIds': updatedIds,
      });

      debugPrint('RECENT SUCCESS: $novelId -> $updatedIds');
    } catch (error, stackTrace) {
      debugPrint('RECENT ERROR: $error');
      debugPrint('$stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Сүүлд үзсэн хадгалах алдаа: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openNovelDetail(
    BuildContext context,
    Novel novel,
  ) async {
    if (!context.mounted) return;

    _saveRecentlyViewed(context, novel.id);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NovelDetailScreen(
            novel: novel,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Зохиол нээх үед алдаа гарлаа: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openNewChapter(
    BuildContext context,
    _NewChapterItem item,
    Map<String, List<Chapter>> chaptersByNovel,
  ) async {
    final chapters = chaptersByNovel[item.novel.id] ?? const <Chapter>[];

    final chapterIndex = chapters.indexWhere(
      (chapter) => chapter.id == item.chapter.id,
    );

    if (chapterIndex < 0 || chapters.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бүлгийн мэдээлэл олдсонгүй.'),
        ),
      );
      return;
    }

    final readerNovel = Novel(
      id: item.novel.id,
      title: item.novel.title,
      author: item.novel.author,
      coverImage: item.novel.coverImage,
      description: item.novel.description,
      genre: item.novel.genre,
      rating: item.novel.rating,
      chapters: chapters,
    );

    _saveRecentlyViewed(context, item.novel.id);

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          novel: readerNovel,
          chapterIndex: chapterIndex,
        ),
      ),
    );
  }

  List<String> _allGenresFrom(List<Novel> novels) {
    final genres = <String>{};

    for (final novel in novels) {
      genres.addAll(novel.genre);
    }

    final result = genres.toList();
    result.sort();
    return result;
  }

  List<Novel> _filteredNovelsFrom(List<Novel> novels) {
    final query = _searchQuery.trim().toLowerCase();

    return novels.where((novel) {
      final matchesSearch =
          query.isEmpty ||
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
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _visibleNovelStream,
          builder: (context, novelSnapshot) {
            if (novelSnapshot.hasError) {
              return _buildCatalogError(novelSnapshot.error);
            }

            if (novelSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            final documents = [...?novelSnapshot.data?.docs];

            documents.sort((a, b) {
              final aTime = _readTimestamp(a.data()['updatedAt']);
              final bTime = _readTimestamp(b.data()['updatedAt']);

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _auth.currentUser == null ? null : _ratingsStream,
              builder: (context, ratingSnapshot) {
                final ratingStats = _ratingStatsFrom(ratingSnapshot.data);

                final allNovels = documents.map((document) {
                  final stats = ratingStats[document.id];

                  return _novelFromDocument(
                    document,
                    ratingOverride: stats?.average,
                  );
                }).toList();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _auth.currentUser == null ? null : _likesStream,
                  builder: (context, likeSnapshot) {
                    final likeCounts = _likeCountsFrom(likeSnapshot.data);

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _auth.currentUser == null
                          ? null
                          : _chapterCatalogStream,
                      builder: (context, chapterSnapshot) {
                        if (chapterSnapshot.hasError) {
                          debugPrint(
                            'CHAPTER CATALOG ERROR: ${chapterSnapshot.error}',
                          );
                        }

                        final chapterCatalog = _chapterCatalogDataFrom(
                          chapterSnapshot.data,
                          allNovels,
                        );

                        return IndexedStack(
                          index: _currentTab,
                          children: [
                            _buildHomePage(
                              allNovels,
                              ratingStats,
                              likeCounts,
                              chapterCatalog,
                            ),
                            _buildSearchPage(allNovels),
                            _buildLibraryPage(allNovels),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentTab,
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _buildCatalogError(Object? error) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PremiumCard(
            elevated: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Зохиолын жагсаалт унших үед алдаа гарлаа.',
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: AppTypography.meta(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage(
    List<Novel> allNovels,
    Map<String, _RatingStats> ratingStats,
    Map<String, int> likeCounts,
    _ChapterCatalogData chapterCatalog,
  ) {
    final visibleNovels = _filteredNovelsFrom(allNovels);
    final featured = visibleNovels.isNotEmpty ? visibleNovels.first : null;

    final visibleNovelIds = visibleNovels.map((novel) => novel.id).toSet();

    final visibleNewChapters = chapterCatalog.items
        .where((item) => visibleNovelIds.contains(item.novel.id))
        .toList();

    final topRated = [...visibleNovels]
      ..sort((a, b) {
        final byAverage = b.rating.compareTo(a.rating);
        if (byAverage != 0) return byAverage;

        final aCount = ratingStats[a.id]?.count ?? 0;
        final bCount = ratingStats[b.id]?.count ?? 0;
        return bCount.compareTo(aCount);
      });

    final bestNovels = [...visibleNovels]
      ..sort((a, b) {
        final aLikes = likeCounts[a.id] ?? 0;
        final bLikes = likeCounts[b.id] ?? 0;

        final byLikes = bLikes.compareTo(aLikes);
        if (byLikes != 0) return byLikes;

        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;

        final aRatingCount = ratingStats[a.id]?.count ?? 0;
        final bRatingCount = ratingStats[b.id]?.count ?? 0;
        return bRatingCount.compareTo(aRatingCount);
      });

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
            _buildGenreChips(allNovels),
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
            _buildContinueReading(
              visibleNovels,
              chapterCatalog.chaptersByNovel,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: 'Шилдэг зохиолууд',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildHorizontalCarousel(bestNovels),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: 'Өндөр үнэлгээтэй',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildHorizontalCarousel(topRated),
            const SizedBox(height: AppSpacing.xxxl),
            const SectionHeader(
              title: 'Шинэ бүлгүүд',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildNewChapterCarousel(
              visibleNewChapters,
              chapterCatalog.chaptersByNovel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPage(List<Novel> allNovels) {
    final novels = _filteredNovelsFrom(allNovels);

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
            _buildGenreChips(allNovels),
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

  Widget _buildLibraryPage(List<Novel> allNovels) {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
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
                      Icons.menu_book_outlined,
                      color: AppColors.primaryLight,
                      size: 42,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Нэвтэрсэн байх шаардлагатай',
                      style: AppTypography.sectionTitle(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Сүүлд үзсэн болон таалагдсан зохиолуудаа харахын тулд нэвтэрнэ үү.',
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(firebaseUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 42,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Миний санг унших үед алдаа гарлаа.',
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionTitle(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: AppTypography.meta(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final userData = snapshot.data?.data() ?? <String, dynamic>{};

        final likedNovelIds = _stringList(userData['likedNovelIds']).toSet();

        final recentViewedNovelIds =
            _stringList(userData['recentViewedNovelIds']);

        final novelById = <String, Novel>{
          for (final novel in allNovels) novel.id: novel,
        };

        final recentlyViewedNovels = recentViewedNovelIds
            .map((id) => novelById[id])
            .whereType<Novel>()
            .toList();

        final likedNovels = allNovels
            .where((novel) => likedNovelIds.contains(novel.id))
            .toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .collection('readingProgress')
              .snapshots(),
          builder: (context, progressSnapshot) {
            final chapterNumberByNovel = <String, int>{};

            for (final doc in progressSnapshot.data?.docs ?? const []) {
              final data = doc.data();
              final novelId = (data['novelId'] ?? doc.id).toString();
              final chapterNumber = _readInt(data['chapterNumber']);

              if (novelId.isNotEmpty && chapterNumber > 0) {
                chapterNumberByNovel[novelId] = chapterNumber;
              }
            }

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
                    const SectionHeader(
                      title: 'Сүүлд үзсэн',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (recentlyViewedNovels.isEmpty)
                      PremiumCard(
                        elevated: true,
                        radius: AppRadius.premium,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              color: AppColors.primaryLight,
                              size: 42,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Сүүлд үзсэн зохиол алга',
                              style: AppTypography.sectionTitle(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Зохиол нээхэд энд автоматаар хадгалагдана.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildRecentViewedCarousel(
                        recentlyViewedNovels,
                        chapterNumberByNovel,
                      ),
                    const SizedBox(height: AppSpacing.xxxl),
                    const SectionHeader(
                      title: 'Таалагдсан',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (likedNovels.isEmpty)
                      PremiumCard(
                        elevated: true,
                        radius: AppRadius.premium,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.favorite_border_rounded,
                              color: AppColors.primaryLight,
                              size: 42,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Таалагдсан зохиол алга',
                              style: AppTypography.sectionTitle(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Зохиолын дэлгэрэнгүй дээрх зүрхэн товчийг дарж таалагдсан зохиолдоо нэмээрэй.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildSearchGrid(likedNovels),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                'Зохиолоор аялаарай',
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

  Widget _buildGenreChips(List<Novel> allNovels) {
    final genres = _allGenresFrom(allNovels);

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
          final isAll = index == 0;
          final label = isAll ? 'Бүгд' : genres[index - 1];

          final isSelected =
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
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
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

  Widget _coverImage(
    String source, {
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    double iconSize = 48,
  }) {
    if (source.trim().isEmpty) {
      return Container(
        color: AppColors.surfaceElevated,
        alignment: Alignment.center,
        child: Icon(
          Icons.auto_stories_rounded,
          size: iconSize,
          color: AppColors.textMuted,
        ),
      );
    }

    final isNetwork =
        source.startsWith('http://') || source.startsWith('https://');

    if (isNetwork) {
      return Image.network(
        source,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) {
          return Container(
            color: AppColors.surfaceElevated,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              size: iconSize,
              color: AppColors.textMuted,
            ),
          );
        },
      );
    }

    return Image.asset(
      source,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, __, ___) {
        return Container(
          color: AppColors.surfaceElevated,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            size: iconSize,
            color: AppColors.textMuted,
          ),
        );
      },
    );
  }

  Widget _buildFeaturedHero(Novel novel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final height = wide ? 320.0 : 270.0;

        return GestureDetector(
          onTap: () => _openNovelDetail(context, novel),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.hero),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _coverImage(
                  novel.coverImage,
                  alignment: Alignment.topCenter,
                  iconSize: 72,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: wide ? Alignment.centerLeft : Alignment.topCenter,
                      end: wide ? Alignment.centerRight : Alignment.bottomCenter,
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
                    alignment: wide ? Alignment.centerLeft : Alignment.bottomLeft,
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
                                  color: AppColors.gold.withValues(alpha: 0.16),
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
                            label: const Text('Унших'),
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

  Widget _buildContinueReading(
    List<Novel> novels,
    Map<String, List<Chapter>> chaptersByNovel,
  ) {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return Text(
        'Үргэлжлүүлэн уншихын тулд нэвтэрнэ үү.',
        style: AppTypography.body(),
      );
    }

    final novelById = <String, Novel>{
      for (final novel in novels) novel.id: novel,
    };

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .collection('readingProgress')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Уншсан явц ачаалах үед алдаа гарлаа: ${snapshot.error}',
            style: AppTypography.body(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final items = <_ReadingProgressItem>[];

        for (final doc in snapshot.data?.docs ?? const []) {
          final data = doc.data();
          final novelId = (data['novelId'] ?? doc.id).toString();
          final chapterId = (data['chapterId'] ?? '').toString();
          final chapterNumber = _readInt(data['chapterNumber']);
          final novel = novelById[novelId];
          final chapters = chaptersByNovel[novelId] ?? const <Chapter>[];

          if (novel == null || chapterId.isEmpty || chapterNumber <= 0) {
            continue;
          }

          final chapterIndex = chapters.indexWhere(
            (chapter) => chapter.id == chapterId,
          );

          if (chapterIndex < 0) continue;

          items.add(
            _ReadingProgressItem(
              novel: novel,
              chapter: chapters[chapterIndex],
              updatedAt: _readTimestamp(data['updatedAt']),
            ),
          );
        }

        items.sort((a, b) {
          final aTime = a.updatedAt;
          final bTime = b.updatedAt;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final visibleItems = items.take(3).toList();

        if (visibleItems.isEmpty) {
          return Text(
            'Одоогоор үргэлжлүүлэн унших зохиол алга.',
            style: AppTypography.body(),
          );
        }

        return Column(
          children: List.generate(visibleItems.length, (index) {
            final item = visibleItems[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == visibleItems.length - 1 ? 0 : AppSpacing.md,
              ),
              child: _FirestoreProgressCard(
                novel: item.novel,
                chapterNumber: item.chapter.number,
                imageBuilder: _coverImage,
                onTap: () => _openNewChapter(
                  context,
                  _NewChapterItem(
                    novel: item.novel,
                    chapter: item.chapter,
                    updatedAt: item.updatedAt,
                  ),
                  chaptersByNovel,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildRecentViewedCarousel(
    List<Novel> novels,
    Map<String, int> chapterNumberByNovel,
  ) {
    if (novels.isEmpty) {
      return Text(
        'Одоогоор энэ хэсэгт зохиол алга.',
        style: AppTypography.body(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final tablet = constraints.maxWidth >= 600;

        final cardWidth = desktop
            ? 150.0
            : tablet
                ? 135.0
                : 118.0;

        final listHeight = cardWidth * 2.25;

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
                child: _RecentViewedPosterCard(
                  novel: novel,
                  chapterNumber: chapterNumberByNovel[novel.id],
                  imageBuilder: _coverImage,
                  onTap: () => _openNovelDetail(context, novel),
                ),
              );
            },
          ),
        );
      },
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
        final desktop = constraints.maxWidth >= 900;
        final tablet = constraints.maxWidth >= 600;

        final cardWidth = desktop
            ? 150.0
            : tablet
                ? 135.0
                : 118.0;

        final listHeight = cardWidth * 1.95;

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
                child: _FirestorePosterCard(
                  novel: novel,
                  imageBuilder: _coverImage,
                  onTap: () => _openNovelDetail(context, novel),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewChapterCarousel(
    List<_NewChapterItem> items,
    Map<String, List<Chapter>> chaptersByNovel,
  ) {
    if (items.isEmpty) {
      return Text(
        'Одоогоор шинэ бүлэг алга.',
        style: AppTypography.body(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final tablet = constraints.maxWidth >= 600;

        final cardWidth = desktop
            ? 220.0
            : tablet
                ? 200.0
                : 176.0;

        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) {
              return const SizedBox(width: AppSpacing.md);
            },
            itemBuilder: (context, index) {
              final item = items[index];

              return SizedBox(
                width: cardWidth,
                child: _NewChapterCard(
                  item: item,
                  imageBuilder: _coverImage,
                  accessLabel: _accessLabel(item.chapter.accessLevel),
                  onTap: () => _openNewChapter(
                    context,
                    item,
                    chaptersByNovel,
                  ),
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

            return _FirestorePosterCard(
              novel: novel,
              imageBuilder: _coverImage,
              onTap: () => _openNovelDetail(context, novel),
            );
          },
        );
      },
    );
  }
}

class _RatingStats {
  final double average;
  final int count;

  const _RatingStats({
    required this.average,
    required this.count,
  });
}

class _ChapterCatalogData {
  final List<_NewChapterItem> items;
  final Map<String, List<Chapter>> chaptersByNovel;

  const _ChapterCatalogData({
    required this.items,
    required this.chaptersByNovel,
  });
}

class _ReadingProgressItem {
  final Novel novel;
  final Chapter chapter;
  final Timestamp? updatedAt;

  const _ReadingProgressItem({
    required this.novel,
    required this.chapter,
    required this.updatedAt,
  });
}

class _NewChapterItem {
  final Novel novel;
  final Chapter chapter;
  final Timestamp? updatedAt;

  const _NewChapterItem({
    required this.novel,
    required this.chapter,
    required this.updatedAt,
  });
}

class _NewChapterCard extends StatelessWidget {
  final _NewChapterItem item;
  final Widget Function(
    String source, {
    BoxFit fit,
    Alignment alignment,
    double iconSize,
  }) imageBuilder;
  final String accessLabel;
  final VoidCallback onTap;

  const _NewChapterCard({
    required this.item,
    required this.imageBuilder,
    required this.accessLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      elevated: true,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.premium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 68,
                  height: double.infinity,
                  child: imageBuilder(
                    item.novel.coverImage,
                    alignment: Alignment.topCenter,
                    iconSize: 30,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.novel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Бүлэг ${item.chapter.number}',
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.chapter.title.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.chapter.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta(),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        accessLabel,
                        style: GoogleFonts.poppins(
                          color: AppColors.goldLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirestorePosterCard extends StatelessWidget {
  final Novel novel;
  final Widget Function(
    String source, {
    BoxFit fit,
    Alignment alignment,
    double iconSize,
  }) imageBuilder;
  final VoidCallback onTap;

  const _FirestorePosterCard({
    required this.novel,
    required this.imageBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.premium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.premium),
              child: SizedBox.expand(
                child: imageBuilder(
                  novel.coverImage,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            novel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.gold,
                size: 14,
              ),
              const SizedBox(width: 3),
              Text(
                novel.rating.toStringAsFixed(1),
                style: AppTypography.meta(),
              ),
              const Spacer(),
              Text(
                '${novel.chapters.length}',
                style: AppTypography.meta(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentViewedPosterCard extends StatelessWidget {
  final Novel novel;
  final int? chapterNumber;
  final Widget Function(
    String source, {
    BoxFit fit,
    Alignment alignment,
    double iconSize,
  }) imageBuilder;
  final VoidCallback onTap;

  const _RecentViewedPosterCard({
    required this.novel,
    required this.chapterNumber,
    required this.imageBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.premium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.premium),
              child: SizedBox.expand(
                child: imageBuilder(
                  novel.coverImage,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            novel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.gold,
                size: 14,
              ),
              const SizedBox(width: 3),
              Text(
                novel.rating.toStringAsFixed(1),
                style: AppTypography.meta(),
              ),
              const Spacer(),
              Text(
                '${novel.chapters.length}',
                style: AppTypography.meta(),
              ),
            ],
          ),
          if (chapterNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              'Бүлэг $chapterNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppColors.primaryLight,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirestoreProgressCard extends StatelessWidget {
  final Novel novel;
  final int chapterNumber;
  final Widget Function(
    String source, {
    BoxFit fit,
    Alignment alignment,
    double iconSize,
  }) imageBuilder;
  final VoidCallback onTap;

  const _FirestoreProgressCard({
    required this.novel,
    required this.chapterNumber,
    required this.imageBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      elevated: true,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.premium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 80,
                  child: imageBuilder(
                    novel.coverImage,
                    alignment: Alignment.topCenter,
                    iconSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Бүлэг $chapterNumber',
                      style: AppTypography.meta(),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
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
    final color = active ? AppColors.primaryLight : AppColors.textMuted;

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
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
