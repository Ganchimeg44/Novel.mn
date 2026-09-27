import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class AdminTranslationReviewScreen extends StatelessWidget {
  const AdminTranslationReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            color: Colors.transparent,
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.rate_review_outlined),
                  text: 'Хяналтад',
                ),
                Tab(
                  icon: Icon(Icons.publish_rounded),
                  text: 'Publish бэлэн',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TabBarView(
              children: [
                _TranslationDraftList(
                  status: 'submitted',
                  emptyMessage: 'Хяналтад ирсэн орчуулга алга.',
                  emptyIcon: Icons.inbox_outlined,
                ),
                _TranslationDraftList(
                  status: 'approved',
                  emptyMessage: 'Publish хийхэд бэлэн орчуулга алга.',
                  emptyIcon: Icons.publish_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationDraftList extends StatelessWidget {
  final String status;
  final String emptyMessage;
  final IconData emptyIcon;

  const _TranslationDraftList({
    required this.status,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('translationDrafts')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Орчуулгуудыг унших үед алдаа гарлаа:\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTypography.body(),
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

        final drafts = [...?snapshot.data?.docs];

        drafts.sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final aValue = status == 'submitted'
              ? aData['submittedAt']
              : aData['reviewedAt'];

          final bValue = status == 'submitted'
              ? bData['submittedAt']
              : bData['reviewedAt'];

          final aTime = aValue is Timestamp ? aValue : null;
          final bTime = bValue is Timestamp ? bValue : null;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });

        if (drafts.isEmpty) {
          return Center(
            child: PremiumCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      emptyIcon,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            final draft = drafts[index];

            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
              ),
              child: _TranslationDraftCard(
                draft: draft,
              ),
            );
          },
        );
      },
    );
  }
}

class _TranslationDraftCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> draft;

  const _TranslationDraftCard({
    required this.draft,
  });

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate().toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${date.year}.'
        '${twoDigits(date.month)}.'
        '${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = draft.data();

    final chapterNumberValue = data['chapterNumber'];

    final chapterNumber = chapterNumberValue is num
        ? chapterNumberValue.toInt()
        : int.tryParse(
              chapterNumberValue?.toString() ?? '',
            ) ??
            0;

    final title = (data['title'] ?? '').toString();
    final translatorUid =
        (data['translatorUid'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    final dateValue = status == 'approved'
        ? data['reviewedAt']
        : data['submittedAt'];

    return InkWell(
      borderRadius: BorderRadius.circular(
        AppRadius.premium,
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) {
              return AdminTranslationDraftDetailScreen(
                draftReference: draft.reference,
              );
            },
          ),
        );
      },
      child: PremiumCard(
        elevated: true,
        radius: AppRadius.premium,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                '$chapterNumber',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? 'Бүлэг $chapterNumber'
                        : title,
                    style: AppTypography.cardTitle(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Бүлэг $chapterNumber',
                    style: AppTypography.meta(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Орчуулагч: $translatorUid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status == 'approved'
                        ? 'Зөвшөөрсөн: ${_formatDate(dateValue)}'
                        : 'Илгээсэн: ${_formatDate(dateValue)}',
                    style: AppTypography.meta(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusChip(status: status),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminTranslationDraftDetailScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> draftReference;

  const AdminTranslationDraftDetailScreen({
    super.key,
    required this.draftReference,
  });

  @override
  State<AdminTranslationDraftDetailScreen> createState() =>
      _AdminTranslationDraftDetailScreenState();
}

class _AdminTranslationDraftDetailScreenState
    extends State<AdminTranslationDraftDetailScreen> {
  bool _working = false;

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate().toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${date.year}.'
        '${twoDigits(date.month)}.'
        '${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  Future<void> _approve() async {
    if (_working) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Орчуулгыг зөвшөөрөх үү?'),
          content: const Text(
            'Энэ үйлдэл зөвхөн орчуулгыг approved төлөвт оруулна.\n\n'
            'Live бүлэгт одоогоор ямар ч өөрчлөлт орохгүй. '
            'Publish дараа нь тусдаа хийгдэнэ.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Болих'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Зөвшөөрөх'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _reviewDraft(
      newStatus: 'approved',
      reviewNote: '',
    );
  }

  Future<void> _reject() async {
    if (_working) return;

    final controller = TextEditingController();

    final reviewNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Орчуулгыг буцаах'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Буцаах шалтгаан *',
              hintText:
                  'Орчуулагчид засах шаардлагатай хэсгийг тайлбарлана уу.',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Болих'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Буцаах'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reviewNote == null || reviewNote.isEmpty) {
      return;
    }

    await _reviewDraft(
      newStatus: 'rejected',
      reviewNote: reviewNote,
    );
  }

  Future<void> _reviewDraft({
    required String newStatus,
    required String reviewNote,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('Админ хэрэглэгч нэвтрээгүй байна.');
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      final snapshot = await widget.draftReference.get();

      if (!snapshot.exists) {
        throw Exception(
          'Орчуулгын draft олдсонгүй.',
        );
      }

      final data =
          snapshot.data() ?? <String, dynamic>{};

      if ((data['status'] ?? '').toString() !=
          'submitted') {
        throw Exception(
          'Энэ орчуулга хяналтын төлөвт биш байна.',
        );
      }

      await widget.draftReference.update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentUser.uid,
        'reviewNote': reviewNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        newStatus == 'approved'
            ? 'Орчуулга зөвшөөрөгдлөө. Publish тусдаа хийгдэнэ.'
            : 'Орчуулга буцаагдлаа.',
      );

      Navigator.of(context).pop();
    } catch (error) {
      _showMessage(
        'Орчуулга хянах үед алдаа гарлаа: $error',
      );

      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _publish(
    Map<String, dynamic> currentDraftData,
  ) async {
    if (_working) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Publish хийх үү?'),
          content: const Text(
            'Зөвшөөрөгдсөн орчуулгын нэр болон текстийг '
            'live бүлэгт оруулна.\n\n'
            'Бүлгийн дугаар, FREE/VIP/VVIP эрх, нуусан төлөв '
            'болон бусад metadata өөрчлөгдөхгүй.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Болих'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publish'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('Админ хэрэглэгч нэвтрээгүй байна.');
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      // -------------------------------------------------------
      // Draft-ийг дахин server-ээс уншина.
      // Ингэснээр хуучин UI data-аар publish хийхгүй.
      // -------------------------------------------------------

      final freshDraftSnapshot =
          await widget.draftReference.get();

      if (!freshDraftSnapshot.exists) {
        throw Exception(
          'Орчуулгын draft олдсонгүй.',
        );
      }

      final draftData =
          freshDraftSnapshot.data() ??
              <String, dynamic>{};

      final status =
          (draftData['status'] ?? '').toString();

      if (status != 'approved') {
        throw Exception(
          'Зөвхөн approved орчуулгыг Publish хийж болно.',
        );
      }

      final novelId =
          (draftData['novelId'] ?? '').toString().trim();

      final chapterId =
          (draftData['chapterId'] ?? '').toString().trim();

      final title =
          (draftData['title'] ?? '').toString().trim();

      final content =
          (draftData['content'] ?? '').toString();

      if (novelId.isEmpty) {
        throw Exception(
          'Draft дээр novelId байхгүй байна.',
        );
      }

      if (chapterId.isEmpty) {
        throw Exception(
          'Draft дээр chapterId байхгүй байна.',
        );
      }

      if (content.trim().isEmpty) {
        throw Exception(
          'Орчуулгын текст хоосон байна.',
        );
      }

      final firestore = FirebaseFirestore.instance;

      final novelRef =
          firestore.collection('novels').doc(novelId);

      final chapterRef =
          novelRef.collection('chapters').doc(chapterId);

      final catalogRef =
          novelRef.collection('chapterCatalog').doc(chapterId);

      // -------------------------------------------------------
      // Live chapter үнэхээр байгаа эсэхийг шалгана.
      // -------------------------------------------------------

      final chapterSnapshot = await chapterRef.get();

      if (!chapterSnapshot.exists) {
        throw Exception(
          'Publish хийх live бүлэг олдсонгүй.',
        );
      }

      // -------------------------------------------------------
      // chapterCatalog мөн байгаа эсэхийг шалгана.
      // Танай систем chapter + catalog-ийг ижил ID-тай хадгалдаг.
      // -------------------------------------------------------

      final catalogSnapshot = await catalogRef.get();

      if (!catalogSnapshot.exists) {
        throw Exception(
          'Энэ бүлгийн chapterCatalog олдсонгүй.',
        );
      }

      // -------------------------------------------------------
      // ATOMIC PUBLISH
      //
      // 1. Live chapter title/content
      // 2. Catalog title
      // 3. Draft approved -> published
      //
      // Аль нэг нь бүтэлгүйтвэл 3 update бүгд хийгдэхгүй.
      // -------------------------------------------------------

      final batch = firestore.batch();

      batch.update(
        chapterRef,
        {
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        catalogRef,
        {
          'title': title,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        widget.draftReference,
        {
          'status': 'published',
          'publishedAt': FieldValue.serverTimestamp(),
          'publishedBy': currentUser.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      if (!mounted) return;

      _showMessage(
        'Орчуулга амжилттай Publish хийгдлээ.',
      );

      Navigator.of(context).pop();
    } catch (error) {
      _showMessage(
        'Publish хийх үед алдаа гарлаа: $error',
      );

      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Орчуулга хянах'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.draftReference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  AppSpacing.xl,
                ),
                child: Text(
                  'Орчуулга унших үед алдаа гарлаа:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(),
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data?.exists != true) {
            return Center(
              child: Text(
                'Орчуулгын draft олдсонгүй.',
                style: AppTypography.body(),
              ),
            );
          }

          final data =
              snapshot.data?.data() ??
                  <String, dynamic>{};

          final status =
              (data['status'] ?? '').toString();

          final novelId =
              (data['novelId'] ?? '').toString();

          final chapterId =
              (data['chapterId'] ?? '').toString();

          final translatorUid =
              (data['translatorUid'] ?? '').toString();

          final title =
              (data['title'] ?? '').toString();

          final content =
              (data['content'] ?? '').toString();

          final chapterNumberValue =
              data['chapterNumber'];

          final chapterNumber =
              chapterNumberValue is num
                  ? chapterNumberValue.toInt()
                  : int.tryParse(
                        chapterNumberValue
                                ?.toString() ??
                            '',
                      ) ??
                      0;

          final reviewNote =
              (data['reviewNote'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(
              AppSpacing.xl,
            ),
            children: [
              PremiumCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty
                                ? 'Бүлэг $chapterNumber'
                                : title,
                            style:
                                AppTypography.pageTitle(),
                          ),
                        ),
                        _StatusChip(
                          status: status,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: AppSpacing.lg,
                    ),
                    _InfoRow(
                      label: 'Бүлэг',
                      value: '$chapterNumber',
                    ),
                    _InfoRow(
                      label: 'Novel ID',
                      value: novelId,
                    ),
                    _InfoRow(
                      label: 'Chapter ID',
                      value: chapterId,
                    ),
                    _InfoRow(
                      label: 'Орчуулагч UID',
                      value: translatorUid,
                    ),
                    _InfoRow(
                      label: 'Илгээсэн',
                      value: _formatDate(
                        data['submittedAt'],
                      ),
                    ),
                    if (data['reviewedAt'] != null)
                      _InfoRow(
                        label: 'Хянасан',
                        value: _formatDate(
                          data['reviewedAt'],
                        ),
                      ),
                    if ((data['reviewedBy'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _InfoRow(
                        label: 'Хянасан админ',
                        value:
                            data['reviewedBy'].toString(),
                      ),
                    if (data['publishedAt'] != null)
                      _InfoRow(
                        label: 'Publish хийсэн',
                        value: _formatDate(
                          data['publishedAt'],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(
                height: AppSpacing.lg,
              ),
              PremiumCard(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Орчуулгын текст',
                      style: AppTypography.cardTitle(),
                    ),
                    const SizedBox(
                      height: AppSpacing.md,
                    ),
                    SelectableText(
                      content,
                      style: AppTypography.body(),
                    ),
                  ],
                ),
              ),
              if (reviewNote.isNotEmpty) ...[
                const SizedBox(
                  height: AppSpacing.lg,
                ),
                PremiumCard(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Хяналтын тайлбар',
                        style:
                            AppTypography.cardTitle(),
                      ),
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      Text(
                        reviewNote,
                        style: AppTypography.body(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(
                height: AppSpacing.xl,
              ),

              // =================================================
              // SUBMITTED
              // =================================================

              if (status == 'submitted')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _working ? null : _reject,
                        icon: const Icon(
                          Icons.undo_rounded,
                        ),
                        label: const Text(
                          'Буцаах',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: AppSpacing.md,
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _working ? null : _approve,
                        icon: _working
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_rounded,
                              ),
                        label: const Text(
                          'Зөвшөөрөх',
                        ),
                      ),
                    ),
                  ],
                ),

              // =================================================
              // APPROVED
              // =================================================

              if (status == 'approved')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _working
                        ? null
                        : () {
                            _publish(data);
                          },
                    icon: _working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.publish_rounded,
                          ),
                    label: Text(
                      _working
                          ? 'Publish хийж байна...'
                          : 'Publish',
                    ),
                  ),
                ),

              if (status == 'rejected')
                PremiumCard(
                  child: Text(
                    'Энэ орчуулгыг буцаасан байна.',
                    style: AppTypography.body(),
                  ),
                ),

              if (status == 'published')
                PremiumCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(
                        width: AppSpacing.sm,
                      ),
                      Expanded(
                        child: Text(
                          'Энэ орчуулга Publish хийгдсэн.',
                          style: AppTypography.body(),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              if (status == 'submitted')
                Text(
                  'Зөвшөөрөхөд зөвхөн draft approved болно. '
                  'Live бүлэг өөрчлөгдөхгүй.',
                  textAlign: TextAlign.center,
                  style: AppTypography.meta(),
                ),

              if (status == 'approved')
                Text(
                  'Publish хийхэд approved орчуулгын нэр болон '
                  'текст live бүлэгт орно.',
                  textAlign: TextAlign.center,
                  style: AppTypography.meta(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;

    switch (status) {
      case 'submitted':
        label = 'Хяналтад';
        icon = Icons.rate_review_outlined;
        break;

      case 'approved':
        label = 'Зөвшөөрсөн';
        icon = Icons.check_circle_outline_rounded;
        break;

      case 'rejected':
        label = 'Буцаасан';
        icon = Icons.undo_rounded;
        break;

      case 'published':
        label = 'Published';
        icon = Icons.public_rounded;
        break;

      default:
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.meta(),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.meta(),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: AppTypography.body(),
            ),
          ),
        ],
      ),
    );
  }
}