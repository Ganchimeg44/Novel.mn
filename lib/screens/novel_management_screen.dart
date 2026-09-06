import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class NovelManagementScreen extends StatefulWidget {
  const NovelManagementScreen({super.key});

  @override
  State<NovelManagementScreen> createState() => _NovelManagementScreenState();
}

class _NovelManagementScreenState extends State<NovelManagementScreen> {
  static const String _coverBucket = 'novel-covers';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  CollectionReference<Map<String, dynamic>> get _novels =>
      _firestore.collection('novels');

  SupabaseClient get _supabase => Supabase.instance.client;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '-';
    final date = value.toDate().toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${date.year}.'
        '${twoDigits(date.month)}.'
        '${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  Future<String?> _pickAndUploadCover({
    required String novelId,
  }) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );

    if (picked == null) return null;

    final bytes = await picked.readAsBytes();

    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw Exception('Cover зураг 5MB-аас бага байх ёстой.');
    }

    final lowerName = picked.name.toLowerCase();
    final extension = lowerName.endsWith('.png')
        ? 'png'
        : lowerName.endsWith('.webp')
            ? 'webp'
            : 'jpg';

    final contentType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    final path =
        'novels/$novelId/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _supabase.storage.from(_coverBucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: contentType,
          ),
        );

    return _supabase.storage.from(_coverBucket).getPublicUrl(path);
  }

  Future<void> _openNovelEditor({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data() ?? <String, dynamic>{};

    final titleController = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final authorController = TextEditingController(
      text: (data['author'] ?? '').toString(),
    );
    final descriptionController = TextEditingController(
      text: (data['description'] ?? '').toString(),
    );
    final genresController = TextEditingController(
      text: _stringList(data['genres']).join(', '),
    );
    List<String> selectedTranslatorUids =
        _stringList(data['translatorUids']);

    String coverUrl = (data['coverUrl'] ?? '').toString();
    bool isPublished = data['isPublished'] == true;
    bool isHidden = data['isHidden'] == true;
    bool isAdultContent = data['isAdultContent'] == true;
    bool saving = false;
    bool uploadingCover = false;

    final draftId = document?.id ?? _novels.doc().id;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> chooseCover() async {
              if (uploadingCover || saving) return;

              setDialogState(() {
                uploadingCover = true;
              });

              try {
                final uploadedUrl = await _pickAndUploadCover(
                  novelId: draftId,
                );

                if (uploadedUrl != null && dialogContext.mounted) {
                  setDialogState(() {
                    coverUrl = uploadedUrl;
                  });
                }
              } catch (error) {
                _showMessage(
                  'Cover зураг upload хийх үед алдаа гарлаа: $error',
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    uploadingCover = false;
                  });
                }
              }
            }

            Future<void> chooseTranslators() async {
              QuerySnapshot<Map<String, dynamic>> snapshot;

              try {
                snapshot = await _firestore
                    .collection('users')
                    .where('isTranslator', isEqualTo: true)
                    .get();
              } catch (error) {
                _showMessage(
                  'Орчуулагчдын жагсаалт авах үед алдаа гарлаа: $error',
                );
                return;
              }

              final translatorDocs = [...snapshot.docs];
              translatorDocs.sort((a, b) {
                final aName =
                    (a.data()['username'] ?? '').toString().toLowerCase();
                final bName =
                    (b.data()['username'] ?? '').toString().toLowerCase();
                return aName.compareTo(bName);
              });

              if (!dialogContext.mounted) return;

              final workingSelection =
                  selectedTranslatorUids.toSet();

              final result = await showDialog<List<String>>(
                context: dialogContext,
                builder: (selectorContext) {
                  return StatefulBuilder(
                    builder: (context, setSelectorState) {
                      return AlertDialog(
                        title: const Text('Орчуулагч сонгох'),
                        content: SizedBox(
                          width: 520,
                          child: translatorDocs.isEmpty
                              ? const Text(
                                  'Одоогоор орчуулагч эрхтэй хэрэглэгч алга.',
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: translatorDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = translatorDocs[index];
                                    final user = doc.data();
                                    final username =
                                        (user['username'] ?? '-').toString();
                                    final sixDigitId =
                                        (user['sixDigitId'] ?? '-').toString();
                                    final selected =
                                        workingSelection.contains(doc.id);

                                    return CheckboxListTile(
                                      value: selected,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(username),
                                      subtitle: Text('ID: $sixDigitId'),
                                      onChanged: (value) {
                                        setSelectorState(() {
                                          if (value == true) {
                                            workingSelection.add(doc.id);
                                          } else {
                                            workingSelection.remove(doc.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(selectorContext).pop();
                            },
                            child: const Text('Болих'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(selectorContext).pop(
                                workingSelection.toList(),
                              );
                            },
                            child: const Text('Сонгох'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );

              if (result != null && dialogContext.mounted) {
                setDialogState(() {
                  selectedTranslatorUids = result;
                });
              }
            }

            Future<void> saveNovel() async {
              final title = titleController.text.trim();

              if (title.isEmpty) {
                _showMessage('Зохиолын нэр оруулна уу.');
                return;
              }

              final genres = genresController.text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toSet()
                  .toList();

              final translatorUids =
                  selectedTranslatorUids.toSet().toList();

              setDialogState(() {
                saving = true;
              });

              try {
                final novelRef = _novels.doc(draftId);

                final payload = <String, dynamic>{
                  'title': title,
                  'author': authorController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'coverUrl': coverUrl,
                  'genres': genres,
                  'translatorUids': translatorUids,
                  'isPublished': isPublished,
                  'isHidden': isHidden,
                  'isAdultContent': isAdultContent,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (document == null) {
                  payload.addAll({
                    'createdAt': FieldValue.serverTimestamp(),
                    'ratingAverage': 0.0,
                    'ratingCount': 0,
                    'likeCount': 0,
                    'readCount': 0,
                    'chapterCount': 0,
                  });
                  await novelRef.set(payload);
                } else {
                  await novelRef.update(payload);
                }

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();

                _showMessage(
                  document == null
                      ? 'Зохиол амжилттай нэмэгдлээ.'
                      : 'Зохиол шинэчлэгдлээ.',
                );
              } catch (error) {
                _showMessage(
                  'Зохиол хадгалах үед алдаа гарлаа: $error',
                );
                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(
                document == null ? 'Шинэ зохиол' : 'Зохиол засах',
              ),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (coverUrl.isNotEmpty) ...[
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              coverUrl,
                              width: 150,
                              height: 210,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  width: 150,
                                  height: 210,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.border,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      OutlinedButton.icon(
                        onPressed: saving || uploadingCover
                            ? null
                            : chooseCover,
                        icon: uploadingCover
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          uploadingCover
                              ? 'Upload хийж байна...'
                              : coverUrl.isEmpty
                                  ? 'Cover зураг сонгох'
                                  : 'Cover зураг солих',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Зохиолын нэр *',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: authorController,
                        decoration: const InputDecoration(
                          labelText: 'Зохиолч',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: descriptionController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Тайлбар',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: genresController,
                        decoration: const InputDecoration(
                          labelText: 'Жанр',
                          hintText: 'Romance, Fantasy, Action',
                          helperText:
                              'Жанруудыг таслалаар тусгаарлана.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: saving ? null : chooseTranslators,
                        icon: const Icon(Icons.group_add_rounded),
                        label: Text(
                          selectedTranslatorUids.isEmpty
                              ? 'Орчуулагч сонгох'
                              : 'Орчуулагч сонгох (${selectedTranslatorUids.length})',
                        ),
                      ),
                      if (selectedTranslatorUids.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${selectedTranslatorUids.length} орчуулагч сонгосон.',
                          style: AppTypography.meta(),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Нийтэлсэн'),
                        subtitle: const Text(
                          'Уншигчид харах боломжтой төлөв.',
                        ),
                        value: isPublished,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isPublished = value;
                                });
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Нуусан'),
                        subtitle: const Text(
                          'Админд үлдэнэ, хэрэглэгчдээс нууна.',
                        ),
                        value: isHidden,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isHidden = value;
                                });
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('+18 контент'),
                        subtitle: const Text(
                          'VVIP тусгай контент гэж тэмдэглэнэ.',
                        ),
                        value: isAdultContent,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isAdultContent = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Болих'),
                ),
                ElevatedButton.icon(
                  onPressed: saving || uploadingCover
                      ? null
                      : saveNovel,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    saving ? 'Хадгалж байна...' : 'Хадгалах',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
    descriptionController.dispose();
    genresController.dispose();
  }

  Future<void> _togglePublished(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data() ?? <String, dynamic>{};
    final published = data['isPublished'] == true;

    try {
      await document.reference.update({
        'isPublished': !published,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _showMessage(
        'Нийтлэх төлөв өөрчлөх үед алдаа гарлаа: $error',
      );
    }
  }

  Future<void> _toggleHidden(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data() ?? <String, dynamic>{};
    final hidden = data['isHidden'] == true;

    try {
      await document.reference.update({
        'isHidden': !hidden,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      _showMessage(
        'Нуух/харуулах үед алдаа гарлаа: $error',
      );
    }
  }

 Future<void> _deleteNovel(
  DocumentSnapshot<Map<String, dynamic>> document,
) async {
  final data = document.data() ?? <String, dynamic>{};
  final title = (data['title'] ?? 'Зохиол').toString();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Зохиол устгах уу?'),
        content: Text(
          '"$title" зохиол болон доторх бүх бүлгийг устгана.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Болих'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Устгах'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  try {
    // 1. Бүлгийн бүтэн content-уудыг устгана.
    while (true) {
      final chapters = await document.reference
          .collection('chapters')
          .limit(400)
          .get();

      if (chapters.docs.isEmpty) break;

      final batch = _firestore.batch();

      for (final chapter in chapters.docs) {
        batch.delete(chapter.reference);
      }

      await batch.commit();

      if (chapters.docs.length < 400) break;
    }

    // 2. Chapter catalog metadata-г устгана.
    while (true) {
      final catalog = await document.reference
          .collection('chapterCatalog')
          .limit(400)
          .get();

      if (catalog.docs.isEmpty) break;

      final batch = _firestore.batch();

      for (final chapter in catalog.docs) {
        batch.delete(chapter.reference);
      }

      await batch.commit();

      if (catalog.docs.length < 400) break;
    }

    // 3. Эцэст нь зохиолын үндсэн document-ийг устгана.
    await document.reference.delete();

    _showMessage('Зохиол устгагдлаа.');
  } catch (error) {
    _showMessage(
      'Зохиол устгах үед алдаа гарлаа: $error',
    );
  }
}
  Future<void> _openChapters(
    DocumentSnapshot<Map<String, dynamic>> novel,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return ChapterManagementScreen(
            novelRef: novel.reference,
            novelTitle:
                (novel.data()?['title'] ?? 'Зохиол').toString(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _novels.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Зохиол унших үед алдаа гарлаа:\n${snapshot.error}',
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

        final novels = [...?snapshot.data?.docs];

        novels.sort((a, b) {
          final aValue = a.data()['updatedAt'];
          final bValue = b.data()['updatedAt'];
          final aTime = aValue is Timestamp ? aValue : null;
          final bTime = bValue is Timestamp ? bValue : null;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });

        return LayoutBuilder(
          builder: (context, outerConstraints) {
            final screenWidth =
                MediaQuery.of(context).size.width;

            final availableWidth =
                outerConstraints.hasBoundedWidth
                    ? outerConstraints.maxWidth
                    : screenWidth;

            final contentWidth =
                availableWidth < AppLayout.profileMaxWidth
                    ? availableWidth
                    : AppLayout.profileMaxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: ListView(
                  padding: const EdgeInsets.all(
                    AppSpacing.xl,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Зохиолын удирдлага',
                            style: AppTypography.pageTitle(),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _openNovelEditor();
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                            ),
                            label: const Text(
                              'Зохиол нэмэх',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    Text(
                      '${novels.length} зохиол байна',
                      style: AppTypography.body(),
                    ),
                    const SizedBox(
                      height: AppSpacing.xl,
                    ),
                    if (novels.isEmpty)
                      PremiumCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(
                              height: AppSpacing.md,
                            ),
                            Text(
                              'Одоогоор зохиол байхгүй байна.',
                              style: AppTypography.body(),
                            ),
                          ],
                        ),
                      )
                    else
                      ...novels.map(
                        (novel) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: AppSpacing.lg,
                            ),
                            child: _NovelAdminCard(
                              document: novel,
                              formatDate: _formatDate,
                              onEdit: () {
                                _openNovelEditor(
                                  document: novel,
                                );
                              },
                              onChapters: () {
                                _openChapters(novel);
                              },
                              onTogglePublished: () {
                                _togglePublished(novel);
                              },
                              onToggleHidden: () {
                                _toggleHidden(novel);
                              },
                              onDelete: () {
                                _deleteNovel(novel);
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
    );
  }
}

class _NovelAdminCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> document;
  final String Function(dynamic value) formatDate;
  final VoidCallback onEdit;
  final VoidCallback onChapters;
  final VoidCallback onTogglePublished;
  final VoidCallback onToggleHidden;
  final VoidCallback onDelete;

  const _NovelAdminCard({
    required this.document,
    required this.formatDate,
    required this.onEdit,
    required this.onChapters,
    required this.onTogglePublished,
    required this.onToggleHidden,
    required this.onDelete,
  });

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((item) => item.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = document.data() ?? <String, dynamic>{};

    final title =
        (data['title'] ?? 'Нэргүй зохиол').toString();
    final author = (data['author'] ?? '').toString();
    final coverUrl = (data['coverUrl'] ?? '').toString();
    final genres = _stringList(data['genres']);
    final translators = _stringList(
      data['translatorUids'],
    );

    final published = data['isPublished'] == true;
    final hidden = data['isHidden'] == true;
    final adult = data['isAdultContent'] == true;
    final chapterCountValue = data['chapterCount'];
    final chapterCount = chapterCountValue is num
        ? chapterCountValue.toInt()
        : int.tryParse(chapterCountValue?.toString() ?? '') ?? 0;

    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 108,
                  child: coverUrl.isEmpty
                      ? Container(
                          color: AppColors.background,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppColors.textMuted,
                          ),
                        )
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return Container(
                              color:
                                  AppColors.background,
                              alignment:
                                  Alignment.center,
                              child: const Icon(
                                Icons
                                    .broken_image_outlined,
                                color:
                                    AppColors.textMuted,
                              ),
                            );
                          },
                        ),
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
                      title,
                      style:
                          AppTypography.cardTitle(),
                    ),
                    if (author.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        author,
                        style: AppTypography.meta(),
                      ),
                    ],
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _AdminChip(
                          label: published
                              ? 'Нийтэлсэн'
                              : 'Ноорог',
                          icon: published
                              ? Icons.public_rounded
                              : Icons
                                  .edit_note_rounded,
                        ),
                        _AdminChip(
                          label: hidden
                              ? 'Нуусан'
                              : 'Харагдана',
                          icon: hidden
                              ? Icons
                                  .visibility_off_rounded
                              : Icons
                                  .visibility_rounded,
                        ),
                        if (adult)
                          const _AdminChip(
                            label: '+18 / VVIP',
                            icon:
                                Icons.lock_outline_rounded,
                          ),
                        _AdminChip(
                          label:
                              '$chapterCount бүлэг',
                          icon: Icons
                              .library_books_outlined,
                        ),
                        ...genres.take(5).map(
                              (genre) =>
                                  _AdminChip(
                                label: genre,
                                icon: Icons
                                    .sell_outlined,
                              ),
                            ),
                      ],
                    ),
                    if (translators.isNotEmpty) ...[
                      const SizedBox(
                        height: AppSpacing.sm,
                      ),
                      Text(
                        'Орчуулагч: '
                        '${translators.join(', ')}',
                        style: AppTypography.meta(),
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    Text(
                      'Шинэчилсэн: '
                      '${formatDate(data['updatedAt'])}',
                      style: AppTypography.meta(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_rounded,
                ),
                label: const Text('Засах'),
              ),
              ElevatedButton.icon(
                onPressed: onChapters,
                icon: const Icon(
                  Icons.library_books_rounded,
                ),
                label: const Text('Бүлгүүд'),
              ),
              OutlinedButton.icon(
                onPressed: onTogglePublished,
                icon: Icon(
                  published
                      ? Icons
                          .unpublished_outlined
                      : Icons.public_rounded,
                ),
                label: Text(
                  published
                      ? 'Ноорог болгох'
                      : 'Нийтлэх',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onToggleHidden,
                icon: Icon(
                  hidden
                      ? Icons.visibility_rounded
                      : Icons
                          .visibility_off_rounded,
                ),
                label: Text(
                  hidden ? 'Харуулах' : 'Нуух',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                ),
                label: const Text('Устгах'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AdminChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
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
            size: 14,
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

class ChapterManagementScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> novelRef;
  final String novelTitle;

  const ChapterManagementScreen({
    super.key,
    required this.novelRef,
    required this.novelTitle,
  });

  @override
  State<ChapterManagementScreen> createState() =>
      _ChapterManagementScreenState();
}

class _ChapterManagementScreenState
    extends State<ChapterManagementScreen> {
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  CollectionReference<Map<String, dynamic>> get _chapterCatalog =>
      widget.novelRef.collection('chapterCatalog');

  Map<String, dynamic> _chapterCatalogPayload({
    required int number,
    required String title,
    required String accessLevel,
    required bool isPublished,
    required bool isHidden,
  }) {
    return <String, dynamic>{
      'number': number,
      'title': title,
      'accessLevel': accessLevel,
      'isPublished': isPublished,
      'isHidden': isHidden,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _updateChapterCount() async {
    final snapshot =
        await widget.novelRef.collection('chapters').get();

    await widget.novelRef.update({
      'chapterCount': snapshot.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openChapterEditor({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data() ?? <String, dynamic>{};

    final numberController = TextEditingController(
      text: data['number']?.toString() ?? '',
    );
    final titleController = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final contentController = TextEditingController(
      text: (data['content'] ?? '').toString(),
    );

    String accessLevel =
        (data['accessLevel'] ?? 'free').toString();

    if (!const <String>[
      'free',
      'vip',
      'vvip',
    ].contains(accessLevel)) {
      accessLevel = 'free';
    }

    bool isPublished = data['isPublished'] == true;
    bool isHidden = data['isHidden'] == true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveChapter() async {
              final number = int.tryParse(
                numberController.text.trim(),
              );

              if (number == null || number <= 0) {
                _showMessage(
                  'Бүлгийн дугаар зөв оруулна уу.',
                );
                return;
              }

              final title =
                  titleController.text.trim();

              if (title.isEmpty) {
                _showMessage(
                  'Бүлгийн нэр оруулна уу.',
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                final payload =
                    <String, dynamic>{
                  'number': number,
                  'title': title,
                  'content': contentController.text,
                  'accessLevel': accessLevel,
                  'isPublished': isPublished,
                  'isHidden': isHidden,
                  'updatedAt':
                      FieldValue.serverTimestamp(),
                };

                final catalogPayload = _chapterCatalogPayload(
                  number: number,
                  title: title,
                  accessLevel: accessLevel,
                  isPublished: isPublished,
                  isHidden: isHidden,
                );

                if (document == null) {
                  payload['createdAt'] =
                      FieldValue.serverTimestamp();
                  catalogPayload['createdAt'] =
                      FieldValue.serverTimestamp();

                  final chapterRef =
                      widget.novelRef.collection('chapters').doc();
                  final catalogRef =
                      _chapterCatalog.doc(chapterRef.id);

                  final batch = FirebaseFirestore.instance.batch();
                  batch.set(chapterRef, payload);
                  batch.set(catalogRef, catalogPayload);
                  await batch.commit();
                } else {
                  final catalogRef =
                      _chapterCatalog.doc(document.id);

                  final batch = FirebaseFirestore.instance.batch();
                  batch.update(document.reference, payload);
                  batch.set(
                    catalogRef,
                    catalogPayload,
                    SetOptions(merge: true),
                  );
                  await batch.commit();
                }

                await _updateChapterCount();

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _showMessage(
                  document == null
                      ? 'Бүлэг нэмэгдлээ.'
                      : 'Бүлэг шинэчлэгдлээ.',
                );
              } catch (error) {
                _showMessage(
                  'Бүлэг хадгалах үед алдаа гарлаа: '
                  '$error',
                );

                if (dialogContext.mounted) {
                  setDialogState(() {
                    saving = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(
                document == null
                    ? 'Шинэ бүлэг'
                    : 'Бүлэг засах',
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      TextField(
                        controller:
                            numberController,
                        keyboardType:
                            TextInputType.number,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Бүлгийн дугаар *',
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
                      TextField(
                        controller:
                            titleController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Бүлгийн нэр *',
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
                      DropdownButtonFormField<
                          String>(
                        initialValue: accessLevel,
                        decoration:
                            const InputDecoration(
                          labelText: 'Унших эрх',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'free',
                            child: Text('FREE'),
                          ),
                          DropdownMenuItem(
                            value: 'vip',
                            child: Text('VIP'),
                          ),
                          DropdownMenuItem(
                            value: 'vvip',
                            child: Text('VVIP'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setDialogState(() {
                                  accessLevel = value;
                                });
                              },
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
                      TextField(
                        controller:
                            contentController,
                        minLines: 12,
                        maxLines: 24,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Бүлгийн текст',
                          alignLabelWithHint:
                              true,
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.md,
                      ),
                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        title:
                            const Text('Нийтэлсэн'),
                        value: isPublished,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isPublished =
                                      value;
                                });
                              },
                      ),
                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        title:
                            const Text('Нуусан'),
                        value: isHidden,
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  isHidden =
                                      value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child: const Text('Болих'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      saving ? null : saveChapter,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.save_rounded,
                        ),
                  label: Text(
                    saving
                        ? 'Хадгалж байна...'
                        : 'Хадгалах',
                  ),
                ),
              ],
            );
          },
        );
      },
    );


  }

  Future<void> _deleteChapter(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) async {
    final data =
        document.data() ?? <String, dynamic>{};

    final number = data['number'] ?? '-';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Бүлэг устгах уу?'),
          content: Text(
            '$number-р бүлгийг устгах гэж байна.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Болих'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Устгах'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(document.reference);
      batch.delete(_chapterCatalog.doc(document.id));
      await batch.commit();

      await _updateChapterCount();

      _showMessage('Бүлэг устгагдлаа.');
    } catch (error) {
      _showMessage(
        'Бүлэг устгах үед алдаа гарлаа: $error',
      );
    }
  }

  Future<void> _toggleChapterPublished(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) async {
    final data =
        document.data() ?? <String, dynamic>{};

    final newValue = !(data['isPublished'] == true);

    final batch = FirebaseFirestore.instance.batch();
    batch.update(document.reference, {
      'isPublished': newValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _chapterCatalog.doc(document.id),
      {
        'number': data['number'],
        'title': (data['title'] ?? '').toString(),
        'accessLevel': (data['accessLevel'] ?? 'free').toString(),
        'isPublished': newValue,
        'isHidden': data['isHidden'] == true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _toggleChapterHidden(
    DocumentSnapshot<Map<String, dynamic>>
        document,
  ) async {
    final data =
        document.data() ?? <String, dynamic>{};

    final newValue = !(data['isHidden'] == true);

    final batch = FirebaseFirestore.instance.batch();
    batch.update(document.reference, {
      'isHidden': newValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _chapterCatalog.doc(document.id),
      {
        'number': data['number'],
        'title': (data['title'] ?? '').toString(),
        'accessLevel': (data['accessLevel'] ?? 'free').toString(),
        'isPublished': data['isPublished'] == true,
        'isHidden': newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.novelTitle),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          _openChapterEditor();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Бүлэг нэмэх'),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.novelRef
            .collection('chapters')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  AppSpacing.xl,
                ),
                child: Text(
                  'Бүлгүүд унших үед алдаа гарлаа:\n'
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

          final chapters =
              [...?snapshot.data?.docs];

          chapters.sort((a, b) {
            final aValue = a.data()['number'];
            final bValue = b.data()['number'];

            final aNumber = aValue is num
                ? aValue.toInt()
                : int.tryParse(aValue?.toString() ?? '') ?? 0;

            final bNumber = bValue is num
                ? bValue.toInt()
                : int.tryParse(bValue?.toString() ?? '') ?? 0;

            return aNumber.compareTo(bNumber);
          });

          if (chapters.isEmpty) {
            return Center(
              child: Text(
                'Одоогоор бүлэг байхгүй байна.',
                style: AppTypography.body(),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(
              AppSpacing.xl,
            ),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              final data = chapter.data();

              final numberValue = data['number'];
              final number = numberValue is num
                  ? numberValue.toInt()
                  : int.tryParse(numberValue?.toString() ?? '') ?? 0;

              final title =
                  (data['title'] ?? '').toString();

              final access =
                  (data['accessLevel'] ?? 'free')
                      .toString()
                      .toUpperCase();

              final published =
                  data['isPublished'] == true;

              final hidden =
                  data['isHidden'] == true;

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.md,
                ),
                child: PremiumCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text('$number'),
                      ),
                      const SizedBox(
                        width: AppSpacing.md,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              title,
                              style: AppTypography
                                  .cardTitle(),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              '$access • '
                              '${published ? 'Нийтэлсэн' : 'Ноорог'}'
                              '${hidden ? ' • Нуусан' : ''}',
                              style:
                                  AppTypography.meta(),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: published
                            ? 'Ноорог болгох'
                            : 'Нийтлэх',
                        onPressed: () {
                          _toggleChapterPublished(
                            chapter,
                          );
                        },
                        icon: Icon(
                          published
                              ? Icons
                                  .unpublished_outlined
                              : Icons
                                  .public_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: hidden
                            ? 'Харуулах'
                            : 'Нуух',
                        onPressed: () {
                          _toggleChapterHidden(
                            chapter,
                          );
                        },
                        icon: Icon(
                          hidden
                              ? Icons
                                  .visibility_rounded
                              : Icons
                                  .visibility_off_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Засах',
                        onPressed: () {
                          _openChapterEditor(
                            document: chapter,
                          );
                        },
                        icon: const Icon(
                          Icons.edit_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Устгах',
                        onPressed: () {
                          _deleteChapter(chapter);
                        },
                        icon: const Icon(
                          Icons
                              .delete_outline_rounded,
                        ),
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
}
