import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'translator_draft_editor_screen.dart';

class TranslatorNovelScreen extends StatelessWidget {
  final String novelId;
  final String novelTitle;

  const TranslatorNovelScreen({
    super.key,
    required this.novelId,
    required this.novelTitle,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(novelTitle),
      ),
      body: uid == null
          ? Center(
              child: Text(
                'Нэвтэрсэн хэрэглэгч олдсонгүй.',
                style: AppTypography.body(),
              ),
            )
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('novels')
                  .doc(novelId)
                  .get(),
              builder: (context, novelSnapshot) {
                if (novelSnapshot.hasError) {
                  return _buildError(
                    'Зохиолын мэдээлэл авах үед алдаа гарлаа:\n'
                    '${novelSnapshot.error}',
                  );
                }

                if (novelSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                final novelDocument = novelSnapshot.data;

                if (novelDocument == null || !novelDocument.exists) {
                  return _buildError(
                    'Зохиол олдсонгүй.',
                  );
                }

                final novelData =
                    novelDocument.data() ?? <String, dynamic>{};

                final rawTranslatorUids =
                    novelData['translatorUids'];

                final translatorUids = rawTranslatorUids is List
                    ? rawTranslatorUids
                        .map((item) => item.toString())
                        .toList()
                    : <String>[];

                if (!translatorUids.contains(uid)) {
                  return _buildError(
                    'Энэ зохиол танд хуваарилагдаагүй байна.',
                  );
                }

                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('novels')
                      .doc(novelId)
                      .collection('chapterCatalog')
                      .snapshots(),
                  builder: (context, chapterSnapshot) {
                    if (chapterSnapshot.hasError) {
                      return _buildError(
                        'Бүлгүүдийг унших үед алдаа гарлаа:\n'
                        '${chapterSnapshot.error}',
                      );
                    }

                    if (chapterSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final chapters = [
                      ...?chapterSnapshot.data?.docs,
                    ];

                    chapters.sort((a, b) {
                      final aValue = a.data()['number'];
                      final bValue = b.data()['number'];

                      final aNumber = aValue is num
                          ? aValue.toInt()
                          : int.tryParse(
                                  aValue?.toString() ?? '',
                                ) ??
                              0;

                      final bNumber = bValue is num
                          ? bValue.toInt()
                          : int.tryParse(
                                  bValue?.toString() ?? '',
                                ) ??
                              0;

                      return aNumber.compareTo(bNumber);
                    });

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.profileMaxWidth,
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(
                            AppSpacing.xl,
                          ),
                          children: [
                            Text(
                              novelTitle,
                              style: AppTypography.pageTitle(),
                            ),
                            const SizedBox(
                              height: AppSpacing.sm,
                            ),
                            Text(
                              '${chapters.length} бүлэг байна.',
                              style: AppTypography.body(),
                            ),
                            const SizedBox(
                              height: AppSpacing.xl,
                            ),
                            if (chapters.isEmpty)
                              PremiumCard(
                                child: Text(
                                  'Одоогоор бүлэг байхгүй байна.',
                                  style: AppTypography.body(),
                                ),
                              )
                            else
                              ...chapters.map(
                                (chapter) {
                                  final data = chapter.data();

                                  final numberValue =
                                      data['number'];

                                  final chapterNumber =
                                      numberValue is num
                                          ? numberValue.toInt()
                                          : int.tryParse(
                                                  numberValue
                                                          ?.toString() ??
                                                      '',
                                                ) ??
                                              0;

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child:
                                        _TranslatorChapterCard(
                                      document: chapter,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) {
                                              return TranslatorDraftEditorScreen(
                                                novelId: novelId,
                                                novelTitle:
                                                    novelTitle,
                                                chapterId:
                                                    chapter.id,
                                                chapterNumber:
                                                    chapterNumber,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSpacing.xl,
        ),
        child: PremiumCard(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(),
          ),
        ),
      ),
    );
  }
}

class _TranslatorChapterCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> document;
  final VoidCallback onTap;

  const _TranslatorChapterCard({
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data =
        document.data() ?? <String, dynamic>{};

    final numberValue = data['number'];

    final number = numberValue is num
        ? numberValue.toInt()
        : int.tryParse(
                numberValue?.toString() ?? '',
              ) ??
            0;

    final title =
        (data['title'] ?? '').toString();

    final accessLevel =
        (data['accessLevel'] ?? 'free')
            .toString()
            .toUpperCase();

    final isPublished =
        data['isPublished'] == true;

    final isHidden =
        data['isHidden'] == true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppRadius.premium,
      ),
      child: PremiumCard(
        elevated: true,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.background,
              child: Text(
                '$number',
                style: AppTypography.cardTitle(),
              ),
            ),
            const SizedBox(
              width: AppSpacing.md,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? 'Бүлэг $number'
                        : title,
                    style: AppTypography.cardTitle(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$accessLevel'
                    ' • ${isPublished ? 'Нийтэлсэн' : 'Ноорог'}'
                    '${isHidden ? ' • Нуусан' : ''}',
                    style: AppTypography.meta(),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: AppSpacing.sm,
            ),
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