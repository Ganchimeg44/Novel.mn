import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'translator_novel_screen.dart';

class TranslatorScreen extends StatelessWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Орчуулагчийн хэсэг'),
      ),
      body: uid == null
          ? Center(
              child: Text(
                'Нэвтэрсэн хэрэглэгч олдсонгүй.',
                style: AppTypography.body(),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('novels')
                  .where(
                    'translatorUids',
                    arrayContains: uid,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        AppSpacing.xl,
                      ),
                      child: Text(
                        'Хуваарилсан зохиолуудыг унших үед алдаа гарлаа:\n'
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

                final novels = [
                  ...?snapshot.data?.docs,
                ];

                novels.sort((a, b) {
                  final aTitle = (a.data()['title'] ?? '')
                      .toString()
                      .toLowerCase();

                  final bTitle = (b.data()['title'] ?? '')
                      .toString()
                      .toLowerCase();

                  return aTitle.compareTo(bTitle);
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
                          'Миний зохиолууд',
                          style: AppTypography.pageTitle(),
                        ),
                        const SizedBox(
                          height: AppSpacing.sm,
                        ),
                        Text(
                          '${novels.length} зохиол хуваарилагдсан байна.',
                          style: AppTypography.body(),
                        ),
                        const SizedBox(
                          height: AppSpacing.xl,
                        ),
                        if (novels.isEmpty)
                          PremiumCard(
                            child: Text(
                              'Одоогоор танд зохиол хуваарилаагүй байна.',
                              style: AppTypography.body(),
                            ),
                          )
                        else
                          ...novels.map(
                            (novel) => Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _AssignedNovelCard(
                                document: novel,
                                onTap: () {
                                  final data =
                                      novel.data();

                                  final title =
                                      (data['title'] ??
                                              'Нэргүй зохиол')
                                          .toString();

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) {
                                        return TranslatorNovelScreen(
                                          novelId: novel.id,
                                          novelTitle: title,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _AssignedNovelCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> document;
  final VoidCallback onTap;

  const _AssignedNovelCard({
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data =
        document.data() ?? <String, dynamic>{};

    final title =
        (data['title'] ?? 'Нэргүй зохиол').toString();

    final author =
        (data['author'] ?? '').toString();

    final chapterCountValue =
        data['chapterCount'];

    final chapterCount =
        chapterCountValue is num
            ? chapterCountValue.toInt()
            : int.tryParse(
                    chapterCountValue?.toString() ?? '',
                  ) ??
                0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppRadius.premium,
      ),
      child: PremiumCard(
        elevated: true,
        child: Row(
          children: [
            const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primaryLight,
              size: 34,
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
                    title,
                    style: AppTypography.cardTitle(),
                  ),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      author,
                      style: AppTypography.meta(),
                    ),
                  ],
                  const SizedBox(
                    height: AppSpacing.xs,
                  ),
                  Text(
                    '$chapterCount бүлэг',
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