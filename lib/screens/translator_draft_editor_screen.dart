import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class TranslatorDraftEditorScreen extends StatefulWidget {
  final String novelId;
  final String novelTitle;
  final String chapterId;
  final int chapterNumber;

  const TranslatorDraftEditorScreen({
    super.key,
    required this.novelId,
    required this.novelTitle,
    required this.chapterId,
    required this.chapterNumber,
  });

  @override
  State<TranslatorDraftEditorScreen> createState() =>
      _TranslatorDraftEditorScreenState();
}

class _TranslatorDraftEditorScreenState
    extends State<TranslatorDraftEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _contentController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _submitting = false;

  String? _errorMessage;

  bool _draftExists = false;
  String _draftStatus = 'draft';
  String _reviewNote = '';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String get _draftId =>
      '${widget.chapterId}_${_uid ?? ''}';

  bool get _isRejected =>
      _draftStatus == 'rejected';

  bool get _isSubmitted =>
      _draftStatus == 'submitted';

  bool get _isApproved =>
      _draftStatus == 'approved';

  bool get _isPublished =>
      _draftStatus == 'published';

  bool get _isLocked =>
      _isSubmitted || _isApproved || _isPublished;

  bool get _canEdit => !_isLocked;

  DocumentReference<Map<String, dynamic>> get _chapterRef =>
      _firestore
          .collection('novels')
          .doc(widget.novelId)
          .collection('chapters')
          .doc(widget.chapterId);

  DocumentReference<Map<String, dynamic>> get _draftRef =>
      _firestore
          .collection('novels')
          .doc(widget.novelId)
          .collection('translationDrafts')
          .doc(_draftId);

  @override
  void initState() {
    super.initState();
    _loadEditor();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadEditor() async {
    final uid = _uid;

    if (uid == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Нэвтэрсэн хэрэглэгч олдсонгүй.';
      });

      return;
    }

    try {
      final novelSnapshot = await _firestore
          .collection('novels')
          .doc(widget.novelId)
          .get();

      final novelData =
          novelSnapshot.data() ?? <String, dynamic>{};

      final rawTranslatorUids =
          novelData['translatorUids'];

      final translatorUids = rawTranslatorUids is List
          ? rawTranslatorUids
              .map((item) => item.toString())
              .toList()
          : <String>[];

      if (!translatorUids.contains(uid)) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _errorMessage =
              'Энэ зохиол танд хуваарилагдаагүй байна.';
        });

        return;
      }

      final results = await Future.wait([
        _chapterRef.get(),
        _draftRef.get(),
      ]);

      final chapterSnapshot = results[0];
      final draftSnapshot = results[1];

      if (!chapterSnapshot.exists) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _errorMessage =
              'Бүлгийн мэдээлэл олдсонгүй.';
        });

        return;
      }

      final chapterData =
          chapterSnapshot.data() ?? <String, dynamic>{};

      final draftData = draftSnapshot.exists
          ? draftSnapshot.data()
          : null;

      if (draftData != null) {
        _titleController.text =
            (draftData['title'] ?? '').toString();

        _contentController.text =
            (draftData['content'] ?? '').toString();

        _draftStatus =
            (draftData['status'] ?? 'draft').toString();

        _reviewNote =
            (draftData['reviewNote'] ?? '').toString();

        _draftExists = true;
      } else {
        _titleController.text =
            (chapterData['title'] ?? '').toString();

        _contentController.text =
            (chapterData['content'] ?? '').toString();

        _draftStatus = 'draft';
        _reviewNote = '';
        _draftExists = false;
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            '${error.code}: ${error.message ?? error.toString()}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<bool> _saveDraft({
    bool showMessage = true,
  }) async {
    final uid = _uid;

    if (uid == null ||
        _saving ||
        _submitting ||
        !_canEdit) {
      return false;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Бүлгийн текст хоосон байна.',
          ),
        ),
      );

      return false;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload = <String, dynamic>{
        'novelId': widget.novelId,
        'chapterId': widget.chapterId,
        'chapterNumber': widget.chapterNumber,
        'translatorUid': uid,
        'title': title,
        'content': content,

        // Rejected үед rejected хэвээр хадгална.
        // Ингэснээр админы буцаасан төлөв алга болохгүй.
        'status': _isRejected ? 'rejected' : 'draft',

        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_draftExists) {
        payload['createdAt'] =
            FieldValue.serverTimestamp();
      }

      await _draftRef.set(
        payload,
        SetOptions(merge: true),
      );

      if (!mounted) return true;

      setState(() {
        _draftExists = true;

        if (!_isRejected) {
          _draftStatus = 'draft';
        }
      });

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isRejected
                  ? 'Засвар хадгалагдлаа.'
                  : 'Ноорог хадгалагдлаа.',
            ),
          ),
        );
      }

      return true;
    } on FirebaseException catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Хадгалах үед алдаа гарлаа:\n'
            '${error.code}: ${error.message ?? ''}',
          ),
        ),
      );

      return false;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Хадгалах үед алдаа гарлаа:\n$error',
          ),
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _submitDraft() async {
    if (_submitting ||
        _saving ||
        !_canEdit) {
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Бүлгийн текст хоосон байна.',
          ),
        ),
      );
      return;
    }

    final saved = await _saveDraft(
      showMessage: false,
    );

    if (!saved || !mounted) {
      return;
    }

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _isRejected
                ? 'Дахин хяналтад илгээх үү?'
                : 'Хяналтад илгээх үү?',
          ),
          content: const Text(
            'Илгээсний дараа энэ орчуулга түгжигдэж, '
            'хяналт дуусах хүртэл засах боломжгүй болно.',
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
              child: const Text('Илгээх'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit != true || !mounted) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _draftRef.update({
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _draftStatus = 'submitted';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Хяналтад амжилттай илгээгдлээ.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Илгээх үед алдаа гарлаа:\n'
            '${error.code}: ${error.message ?? ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Илгээх үед алдаа гарлаа:\n$error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Бүлэг ${widget.chapterNumber}',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _errorMessage != null
              ? _buildError()
              : _buildEditor(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSpacing.xl,
        ),
        child: PremiumCard(
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppTypography.body(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    String text;

    if (_isSubmitted) {
      icon = Icons.lock_rounded;
      text = 'Хяналтад илгээсэн • Түгжигдсэн';
    } else if (_isApproved) {
      icon = Icons.check_circle_outline_rounded;
      text = 'Зөвшөөрөгдсөн • Түгжигдсэн';
    } else if (_isPublished) {
      icon = Icons.public_rounded;
      text = 'Publish хийгдсэн • Түгжигдсэн';
    } else if (_isRejected) {
      icon = Icons.undo_rounded;
      text = 'Засварт буцаасан';
    } else if (_draftExists) {
      icon = Icons.edit_note_rounded;
      text = 'Хадгалсан ноорог';
    } else {
      icon = Icons.edit_note_rounded;
      text = 'Шинэ ноорог';
    }

    return PremiumCard(
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryLight,
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.meta(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedMessage() {
    String message;

    if (_isSubmitted) {
      message =
          'Энэ орчуулга хяналтад байна. '
          'Одоогоор засах боломжгүй.';
    } else if (_isApproved) {
      message =
          'Энэ орчуулгыг админ зөвшөөрсөн байна. '
          'Publish хийх хүртэл орчуулагч засах боломжгүй.';
    } else {
      message =
          'Энэ орчуулга Publish хийгдсэн байна. '
          'Дахин засах боломжгүй.';
    }

    return PremiumCard(
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            color: AppColors.primaryLight,
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
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
              widget.novelTitle,
              style: AppTypography.pageTitle(),
            ),

            const SizedBox(
              height: AppSpacing.xs,
            ),

            Text(
              'Бүлэг ${widget.chapterNumber}',
              style: AppTypography.body(),
            ),

            const SizedBox(
              height: AppSpacing.md,
            ),

            _buildStatusCard(),

            if (_isRejected) ...[
              const SizedBox(
                height: AppSpacing.md,
              ),

              PremiumCard(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.feedback_outlined,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                        Expanded(
                          child: Text(
                            'Админы буцаасан шалтгаан',
                            style:
                                AppTypography.cardTitle(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    Text(
                      _reviewNote.trim().isEmpty
                          ? 'Шалтгаан бичээгүй байна.'
                          : _reviewNote,
                      style: AppTypography.body(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(
              height: AppSpacing.lg,
            ),

            Text(
              'Бүлгийн нэр',
              style: AppTypography.cardTitle(),
            ),

            const SizedBox(
              height: AppSpacing.sm,
            ),

            TextField(
              controller: _titleController,
              enabled: _canEdit,
              style: AppTypography.body(),
              decoration: const InputDecoration(
                hintText: 'Бүлгийн нэр',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: AppSpacing.lg,
            ),

            Text(
              'Орчуулга',
              style: AppTypography.cardTitle(),
            ),

            const SizedBox(
              height: AppSpacing.sm,
            ),

            TextField(
              controller: _contentController,
              enabled: _canEdit,
              minLines: 18,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: AppTypography.body(),
              decoration: const InputDecoration(
                hintText:
                    'Энд орчуулсан бүлгийн текстээ бичнэ...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(
              height: AppSpacing.xl,
            ),

            if (_canEdit) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_saving || _submitting)
                          ? null
                          : () {
                              _saveDraft();
                            },
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.save_rounded,
                        ),
                  label: Text(
                    _saving
                        ? 'Хадгалж байна...'
                        : _isRejected
                            ? 'Засвар хадгалах'
                            : 'Ноорог хадгалах',
                  ),
                ),
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      (_saving || _submitting)
                          ? null
                          : _submitDraft,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                        ),
                  label: Text(
                    _submitting
                        ? 'Илгээж байна...'
                        : _isRejected
                            ? 'Дахин хяналтад илгээх'
                            : 'Хяналтад илгээх',
                  ),
                ),
              ),
            ] else
              _buildLockedMessage(),

            const SizedBox(
              height: AppSpacing.md,
            ),

            Text(
              _isPublished
                  ? 'Энэ хувилбар live бүлэгт Publish хийгдсэн.'
                  : 'Live бүлэг шууд өөрчлөгдөхгүй.',
              textAlign: TextAlign.center,
              style: AppTypography.meta(),
            ),
          ],
        ),
      ),
    );
  }
}