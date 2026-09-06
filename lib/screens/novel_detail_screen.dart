import 'dart:async';

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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _chapterCatalogSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _ratingSubscription;

  int _selectedTab = 0;

  bool _loadingAccess = true;
  bool _hasVip = false;
  bool _hasVvip = false;

  bool _loadingChapters = true;
  bool _openingChapter = false;
  String? _chapterLoadError;

  bool _isLiked = false;
  bool _updatingLike = false;

  bool _loadingRatings = true;
  bool _updatingRating = false;
  double _averageRating = 0;
  int _ratingCount = 0;
  int _myRating = 0;
  String? _ratingLoadError;

  final TextEditingController _commentController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _comments =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  bool _loadingComments = true;
  bool _sendingComment = false;
  String? _commentLoadError;

  List<Chapter> _chapters = <Chapter>[];

  Novel get novel => widget.novel;

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection('novels').doc(novel.id).collection('ratings');

  CollectionReference<Map<String, dynamic>> get _likes =>
      _firestore.collection('novels').doc(novel.id).collection('likes');

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _firestore.collection('novels').doc(novel.id).collection('comments');

  @override
  void initState() {
    super.initState();
    _loadUserAccess();
    _loadLikeStatus();
    _listenToChapterCatalog();
    _listenToRatings();
    _listenToComments();
  }

  @override
  void dispose() {
    _chapterCatalogSubscription?.cancel();
    _ratingSubscription?.cancel();
    _commentSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  AccessLevel _accessLevelFromString(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'vip':
        return AccessLevel.vip;
      case 'vvip':
        return AccessLevel.vvip;
      case 'free':
      default:
        return AccessLevel.free;
    }
  }

  void _listenToChapterCatalog() {
    _chapterCatalogSubscription = _firestore
        .collection('novels')
        .doc(novel.id)
        .collection('chapterCatalog')
        .snapshots()
        .listen(
      (snapshot) {
        final chapters = snapshot.docs
            .map((document) {
              final data = document.data();

              if (data['isPublished'] != true || data['isHidden'] == true) {
                return null;
              }

              final numberValue = data['number'];
              final number = numberValue is num
                  ? numberValue.toInt()
                  : int.tryParse(numberValue?.toString() ?? '') ?? 0;

              return Chapter(
                id: document.id,
                number: number,
                title: (data['title'] ?? '').toString(),
                content: '',
                accessLevel: _accessLevelFromString(data['accessLevel']),
              );
            })
            .whereType<Chapter>()
            .toList();

        chapters.sort((a, b) => a.number.compareTo(b.number));

        if (!mounted) return;

        setState(() {
          _chapters = chapters;
          _loadingChapters = false;
          _chapterLoadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _loadingChapters = false;
          _chapterLoadError = error.toString();
        });
      },
    );
  }

  void _listenToRatings() {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      if (!mounted) return;

      setState(() {
        _loadingRatings = false;
        _averageRating = 0;
        _ratingCount = 0;
        _myRating = 0;
        _ratingLoadError = null;
      });
      return;
    }

    _ratingSubscription = _ratings.snapshots().listen(
      (snapshot) {
        var total = 0;
        var count = 0;
        var myRating = 0;

        for (final document in snapshot.docs) {
          final data = document.data();
          final rawRating = data['rating'];

          final rating = rawRating is num
              ? rawRating.toInt()
              : int.tryParse(rawRating?.toString() ?? '');

          if (rating == null || rating < 1 || rating > 5) {
            continue;
          }

          total += rating;
          count += 1;

          if (document.id == firebaseUser.uid) {
            myRating = rating;
          }
        }

        if (!mounted) return;

        setState(() {
          _averageRating = count == 0 ? 0 : total / count;
          _ratingCount = count;
          _myRating = myRating;
          _loadingRatings = false;
          _ratingLoadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _loadingRatings = false;
          _ratingLoadError = error.toString();
        });
      },
    );
  }

  Future<void> _submitRating(int rating) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Үнэлгээ өгөхийн тулд нэвтэрсэн байх шаардлагатай.'),
        ),
      );
      return;
    }

    if (_updatingRating) return;
    if (rating < 1 || rating > 5) return;

    setState(() {
      _updatingRating = true;
    });

    try {
      final ratingRef = _ratings.doc(firebaseUser.uid);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ratingRef);

        if (snapshot.exists) {
          transaction.update(ratingRef, {
            'rating': rating,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(ratingRef, {
            'userUid': firebaseUser.uid,
            'rating': rating,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$rating одны үнэлгээ хадгалагдлаа.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Үнэлгээ хадгалах үед алдаа гарлаа: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Үнэлгээ хадгалах үед алдаа гарлаа: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRating = false;
        });
      }
    }
  }

  Future<void> _removeRating() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null || _myRating == 0 || _updatingRating) {
      return;
    }

    setState(() {
      _updatingRating = true;
    });

    try {
      await _ratings.doc(firebaseUser.uid).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Таны үнэлгээг устгалаа.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Үнэлгээ устгах үед алдаа гарлаа: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Үнэлгээ устгах үед алдаа гарлаа: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRating = false;
        });
      }
    }
  }

  void _listenToComments() {
    _commentSubscription = _commentsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        setState(() {
          _comments = snapshot.docs;
          _loadingComments = false;
          _commentLoadError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _loadingComments = false;
          _commentLoadError = error.toString();
        });
      },
    );
  }

  Future<String> _currentUsername() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return 'Хэрэглэгч';
    }

    final snapshot =
        await _firestore.collection('users').doc(firebaseUser.uid).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    final username = (data['username'] ?? '').toString().trim();
    final displayName = (data['displayName'] ?? '').toString().trim();

    if (username.isNotEmpty) return username;
    if (displayName.isNotEmpty) return displayName;
    if ((firebaseUser.displayName ?? '').trim().isNotEmpty) {
      return firebaseUser.displayName!.trim();
    }

    return 'Хэрэглэгч';
  }

  Future<void> _sendComment() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сэтгэгдэл бичихийн тулд нэвтэрсэн байх шаардлагатай.'),
        ),
      );
      return;
    }

    final text = _commentController.text.trim();

    if (text.isEmpty || _sendingComment) return;

    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сэтгэгдэл 2000 тэмдэгтээс урт байж болохгүй.'),
        ),
      );
      return;
    }

    setState(() {
      _sendingComment = true;
    });

    try {
      final username = await _currentUsername();

      await _commentsRef.add({
        'userUid': firebaseUser.uid,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сэтгэгдэл нэмэгдлээ.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сэтгэгдэл хадгалах үед алдаа гарлаа: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сэтгэгдэл хадгалах үед алдаа гарлаа: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingComment = false;
        });
      }
    }
  }

  Future<void> _editComment(
    QueryDocumentSnapshot<Map<String, dynamic>> comment,
  ) async {
    final firebaseUser = _auth.currentUser;
    final data = comment.data();

    if (firebaseUser == null || data['userUid'] != firebaseUser.uid) {
      return;
    }

    final controller = TextEditingController(
      text: (data['text'] ?? '').toString(),
    );

    final editedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Сэтгэгдэл засах'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Сэтгэгдлээ бичнэ үү',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Болих'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Хадгалах'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (editedText == null || editedText.isEmpty) return;

    try {
      await comment.reference.update({
        'text': editedText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сэтгэгдэл засах үед алдаа гарлаа: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  Future<void> _deleteComment(
    QueryDocumentSnapshot<Map<String, dynamic>> comment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Сэтгэгдэл устгах'),
          content: const Text('Энэ сэтгэгдлийг устгах уу?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Болих'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Устгах'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await comment.reference.delete();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сэтгэгдэл устгах үед алдаа гарлаа: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  String _formatCommentTime(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate().toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Саяхан';
    if (difference.inHours < 1) return '${difference.inMinutes} мин өмнө';
    if (difference.inDays < 1) return '${difference.inHours} цагийн өмнө';
    if (difference.inDays < 7) return '${difference.inDays} өдрийн өмнө';

    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _loadLikeStatus() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      if (!mounted) return;

      setState(() {
        _isLiked = false;
      });
      return;
    }

    try {
      final likeSnapshot = await _likes.doc(firebaseUser.uid).get();

      if (!mounted) return;

      setState(() {
        _isLiked = likeSnapshot.exists;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLiked = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дуртай болгохын тулд нэвтэрсэн байх шаардлагатай.'),
        ),
      );
      return;
    }

    if (_updatingLike) return;

    final wasLiked = _isLiked;

    setState(() {
      _updatingLike = true;
    });

    try {
      final userRef = _firestore.collection('users').doc(firebaseUser.uid);
      final likeRef = _likes.doc(firebaseUser.uid);
      final batch = _firestore.batch();

      if (wasLiked) {
        batch.delete(likeRef);
        batch.update(userRef, {
          'likedNovelIds': FieldValue.arrayRemove([novel.id]),
        });
      } else {
        batch.set(likeRef, {
          'userUid': firebaseUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(userRef, {
          'likedNovelIds': FieldValue.arrayUnion([novel.id]),
        });
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _isLiked = !wasLiked;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Дуртай зохиол хадгалах үед алдаа гарлаа: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Дуртай зохиол хадгалах үед алдаа гарлаа: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingLike = false;
        });
      }
    }
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
      final snapshot =
          await _firestore.collection('users').doc(firebaseUser.uid).get();
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
          legacyDays = int.tryParse(legacyValue?.toString() ?? '') ?? 0;
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
        message = 'Энэ бүлгийг уншихын тулд VIP эсвэл VVIP эрх шаардлагатай.';
        break;
      case AccessLevel.vvip:
        message = 'Энэ бүлгийг уншихын тулд VVIP эрх шаардлагатай.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          message,
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Future<Novel> _loadReadableNovelForReader() async {
    final chapterRefs = _firestore
        .collection('novels')
        .doc(novel.id)
        .collection('chapters');

    final loadedChapters = await Future.wait(
      _chapters.map((chapter) async {
        if (!_canAccessChapter(chapter)) return chapter;

        try {
          final snapshot = await chapterRefs.doc(chapter.id).get();
          final data = snapshot.data();
          if (data == null) return chapter;

          return Chapter(
            id: chapter.id,
            number: chapter.number,
            title: chapter.title,
            content: (data['content'] ?? '').toString(),
            accessLevel: chapter.accessLevel,
          );
        } on FirebaseException {
          return chapter;
        }
      }),
    );

    return Novel(
      id: novel.id,
      title: novel.title,
      author: novel.author,
      coverImage: novel.coverImage,
      description: novel.description,
      genre: novel.genre,
      rating: _ratingCount == 0 ? novel.rating : _averageRating,
      chapters: loadedChapters,
    );
  }

  Future<void> _openChapter(int index) async {
    if (_loadingAccess || _loadingChapters) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Мэдээлэл шалгаж байна...')),
      );
      return;
    }

    if (_openingChapter) return;
    if (index < 0 || index >= _chapters.length) return;

    final chapter = _chapters[index];

    if (!_canAccessChapter(chapter)) {
      _showLockedMessage(chapter);
      return;
    }

    setState(() {
      _openingChapter = true;
    });

    try {
      final readerNovel = await _loadReadableNovelForReader();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChapterReaderScreen(
            novel: readerNovel,
            chapterIndex: index,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      final message = error.code == 'permission-denied'
          ? 'Энэ бүлгийг унших эрх хүрэхгүй байна.'
          : 'Бүлгийг нээх үед алдаа гарлаа: ${error.message ?? error.code}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бүлгийг нээх үед алдаа гарлаа: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingChapter = false;
        });
      }
    }
  }

  void _startReading() {
    if (_loadingChapters) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бүлгийн мэдээлэл ачаалж байна...')),
      );
      return;
    }

    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Одоогоор бүлэг нэмэгдээгүй байна.')),
      );
      return;
    }

    if (_loadingAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Эрхийн мэдээлэл шалгаж байна...')),
      );
      return;
    }

    final firstAccessibleIndex = _chapters.indexWhere(_canAccessChapter);

    if (firstAccessibleIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Танд унших боломжтой бүлэг алга.')),
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
            onPressed: _updatingLike ? null : _toggleLike,
            tooltip: _isLiked ? 'Дуртайгаас хасах' : 'Дуртай болгох',
            icon: _updatingLike
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isLiked
                        ? Colors.redAccent
                        : AppColors.textPrimary,
                  ),
          ),
          IconButton(
            onPressed: () {},
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
            constraints: const BoxConstraints(maxWidth: 920),
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
                _buildRatingPanel(),
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
                _buildCover(width: 190, height: 270),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(child: _buildNovelInfo(centered: false)),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildCover(width: 160, height: 230),
            const SizedBox(height: AppSpacing.xl),
            _buildNovelInfo(centered: true),
          ],
        );
      },
    );
  }

  Widget _buildCover({
    required double width,
    required double height,
  }) {
    final isNetworkImage = novel.coverImage.startsWith('http://') ||
        novel.coverImage.startsWith('https://');

    Widget fallback() {
      return Container(
        color: AppColors.surfaceElevated,
        alignment: Alignment.center,
        child: const Icon(
          Icons.auto_stories_rounded,
          color: AppColors.textMuted,
          size: 56,
        ),
      );
    }

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
        child: novel.coverImage.isEmpty
            ? fallback()
            : isNetworkImage
                ? Image.network(
                    novel.coverImage,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback(),
                  )
                : Image.asset(
                    novel.coverImage,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback(),
                  ),
      ),
    );
  }

  Widget _buildNovelInfo({required bool centered}) {
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    final chapterCountText = _loadingChapters ? '...' : '${_chapters.length}';
    final ratingText = _loadingRatings
        ? '...'
        : _ratingCount == 0
            ? novel.rating.toStringAsFixed(1)
            : _averageRating.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          novel.title,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: AppTypography.novelTitle(fontSize: 28),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          novel.author,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: AppTypography.body(color: AppColors.goldLight),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
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
          mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment:
              centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            _StatItem(
              icon: Icons.star_rounded,
              iconColor: AppColors.gold,
              value: ratingText,
              label: _ratingCount == 0
                  ? 'Үнэлгээ'
                  : '$_ratingCount үнэлгээ',
            ),
            const SizedBox(width: AppSpacing.xxl),
            _StatItem(
              icon: Icons.menu_book_rounded,
              iconColor: AppColors.primaryLight,
              value: chapterCountText,
              label: 'Бүлэг',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingPanel() {
    if (_loadingRatings) {
      return const PremiumCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_ratingLoadError != null) {
      return PremiumCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Үнэлгээний мэдээлэл унших үед алдаа гарлаа:\n$_ratingLoadError',
            textAlign: TextAlign.center,
            style: AppTypography.body(),
          ),
        ),
      );
    }

    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.gold,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Зохиолыг үнэлэх',
                  style: AppTypography.sectionTitle(),
                ),
              ),
              if (_ratingCount > 0)
                Text(
                  '${_averageRating.toStringAsFixed(1)} / 5.0',
                  style: GoogleFonts.poppins(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _ratingCount == 0
                ? 'Одоогоор хэрэглэгчийн үнэлгээ алга.'
                : 'Нийт $_ratingCount хэрэглэгч үнэлсэн.',
            style: AppTypography.body(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: AppSpacing.sm,
            children: [
              ...List.generate(5, (index) {
                final starValue = index + 1;
                final selected = starValue <= _myRating;

                return IconButton(
                  onPressed: _updatingRating
                      ? null
                      : () => _submitRating(starValue),
                  tooltip: '$starValue од',
                  iconSize: 34,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    selected
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: selected
                        ? AppColors.gold
                        : AppColors.textMuted,
                  ),
                );
              }),
              if (_updatingRating) ...[
                const SizedBox(width: AppSpacing.md),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          if (_myRating > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Таны үнэлгээ: $_myRating / 5',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _updatingRating ? null : _removeRating,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Устгах'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Тайлбар', style: AppTypography.sectionTitle()),
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
    final loading = _loadingAccess || _loadingChapters || _openingChapter;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : _startReading,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.menu_book_rounded),
        label: Text(
          _openingChapter
              ? 'Бүлэг нээж байна...'
              : _loadingAccess || _loadingChapters
                  ? 'Мэдээлэл ачаалж байна...'
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
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.border),
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
    if (_loadingChapters) {
      return const PremiumCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_chapterLoadError != null) {
      return PremiumCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Бүлгийн жагсаалт унших үед алдаа гарлаа:\n$_chapterLoadError',
              textAlign: TextAlign.center,
              style: AppTypography.body(),
            ),
          ),
        ),
      );
    }

    if (_chapters.isEmpty) {
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
              'Нийт ${_chapters.length} бүлэг',
              style: AppTypography.meta(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(_chapters.length, (index) {
          final chapter = _chapters[index];
          final canAccess = !_loadingAccess && _canAccessChapter(chapter);
          final accessColor = _chapterAccessColor(chapter);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openingChapter ? null : () => _openChapter(index),
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: canAccess
                              ? accessColor.withValues(alpha: 0.12)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: canAccess
                            ? Text(
                                '${chapter.number}',
                                style: GoogleFonts.poppins(
                                  color: accessColor,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accessColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _chapterAccessName(chapter),
                          style: GoogleFonts.poppins(
                            color: accessColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!canAccess) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.lock_rounded,
                          color: AppColors.textMuted,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCommentsPlaceholder() {
    final firebaseUser = _auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumCard(
          elevated: true,
          radius: AppRadius.premium,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Сэтгэгдэл бичих', style: AppTypography.sectionTitle()),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _commentController,
                enabled: !_sendingComment,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Сэтгэгдлээ бичнэ үү...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _sendingComment ? null : _sendComment,
                  icon: _sendingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Илгээх'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_loadingComments)
          const PremiumCard(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          )
        else if (_commentLoadError != null)
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Сэтгэгдэл унших үед алдаа гарлаа:\n$_commentLoadError',
                textAlign: TextAlign.center,
                style: AppTypography.body(),
              ),
            ),
          )
        else if (_comments.isEmpty)
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primaryLight,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Одоогоор сэтгэгдэл алга.',
                    style: AppTypography.body(),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            'Нийт ${_comments.length} сэтгэгдэл',
            style: AppTypography.meta(),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._comments.map((comment) {
            final data = comment.data();
            final username =
                (data['username'] ?? 'Хэрэглэгч').toString().trim();
            final text = (data['text'] ?? '').toString();
            final isOwner = firebaseUser != null &&
                data['userUid'] == firebaseUser.uid;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surfaceElevated,
                          child: Icon(
                            Icons.person_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username.isEmpty ? 'Хэрэглэгч' : username,
                                style: GoogleFonts.poppins(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatCommentTime(data['createdAt']),
                                style: AppTypography.meta(),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editComment(comment);
                              } else if (value == 'delete') {
                                _deleteComment(comment);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Засах'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Устгах'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
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
        Icon(icon, color: iconColor, size: 20),
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
            Text(label, style: AppTypography.meta()),
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
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
