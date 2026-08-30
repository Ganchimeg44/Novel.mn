import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class XpRedeemScreen extends StatefulWidget {
  const XpRedeemScreen({super.key});

  @override
  State<XpRedeemScreen> createState() =>
      _XpRedeemScreenState();
}

class _XpRedeemScreenState
    extends State<XpRedeemScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final TextEditingController _daysController =
      TextEditingController(
    text: '1',
  );

  final TextEditingController
      _recipientIdController =
      TextEditingController();

  String _selectedType = 'vip';

  bool _isGift = false;
  bool _loading = true;
  bool _submitting = false;

  int _currentXp = 0;
  String _sixDigitId = '';

  String? _recipientUid;
  String? _recipientUsername;

  bool _checkingRecipient = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _daysController.dispose();
    _recipientIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final data = snapshot.data();

      if (!mounted) return;

      setState(() {
        _currentXp =
            (data?['xp'] as num?)?.toInt() ?? 0;

        _sixDigitId =
            (data?['sixDigitId'] ?? '')
                .toString();

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Хэрэглэгчийн мэдээлэл уншихад алдаа гарлаа: $error',
      );
    }
  }

  int get _days {
    return int.tryParse(
          _daysController.text.trim(),
        ) ??
        0;
  }

  int get _requiredXp {
    if (_days <= 0) {
      return 0;
    }

    return _days * 10;
  }

  bool get _hasEnoughXp {
    return _days > 0 &&
        _currentXp >= _requiredXp;
  }

  bool get _canSubmit {
    if (!_hasEnoughXp) {
      return false;
    }

    if (_isGift) {
      return _recipientUid != null &&
          _recipientUsername != null;
    }

    return true;
  }

  Future<void> _findRecipient() async {
    final enteredId =
        _recipientIdController.text.trim();

    if (enteredId.length != 6) {
      setState(() {
        _recipientUid = null;
        _recipientUsername = null;
      });

      _showMessage(
        '6 оронтой ID зөв оруулна уу.',
      );
      return;
    }

    if (enteredId == _sixDigitId) {
      setState(() {
        _recipientUid = null;
        _recipientUsername = null;
      });

      _showMessage(
        'Өөрийн ID-г бэлэглэх хэсэгт ашиглахгүй. '
        'Өөртөө авах сонголтыг ашиглана уу.',
      );
      return;
    }

    setState(() {
      _checkingRecipient = true;
      _recipientUid = null;
      _recipientUsername = null;
    });

    try {
      final idSnapshot = await _firestore
          .collection('sixDigitIds')
          .doc(enteredId)
          .get();

      final idData = idSnapshot.data();

      if (idData == null) {
        throw Exception(
          'Ийм ID-тай хэрэглэгч олдсонгүй.',
        );
      }

      final recipientUid =
          (idData['uid'] ?? '').toString();

      if (recipientUid.isEmpty) {
        throw Exception(
          'Хүлээн авагчийн мэдээлэл буруу байна.',
        );
      }

      final userSnapshot = await _firestore
          .collection('users')
          .doc(recipientUid)
          .get();

      final userData = userSnapshot.data();

      if (userData == null) {
        throw Exception(
          'Хүлээн авагчийн профайл олдсонгүй.',
        );
      }

      final username =
          (userData['username'] ?? '')
              .toString();

      if (!mounted) return;

      setState(() {
        _recipientUid = recipientUid;

        _recipientUsername =
            username.isEmpty
                ? 'Хэрэглэгч'
                : username;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _recipientUid = null;
        _recipientUsername = null;
      });

      _showMessage(
        error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingRecipient = false;
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      _showMessage(
        'Нэвтэрсэн хэрэглэгч олдсонгүй.',
      );
      return;
    }

    final days = _days;

    if (days <= 0) {
      _showMessage(
        'Авах хоногоо зөв оруулна уу.',
      );
      return;
    }

    final requiredXp = days * 10;

    if (_currentXp < requiredXp) {
      _showMessage(
        'XP хүрэлцэхгүй байна. '
        '$days хоног авахад '
        '$requiredXp XP шаардлагатай.',
      );
      return;
    }

    if (_sixDigitId.isEmpty) {
      _showMessage(
        '6 оронтой ID олдсонгүй.',
      );
      return;
    }

    if (_isGift &&
        (_recipientUid == null ||
            _recipientUsername == null)) {
      _showMessage(
        'Хүлээн авагчийг эхлээд шалгана уу.',
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final userSnapshot =
          await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get();

      final userData =
          userSnapshot.data();

      if (userData == null) {
        throw Exception(
          'Хэрэглэгчийн мэдээлэл олдсонгүй.',
        );
      }

      final latestXp =
          (userData['xp'] as num?)
                  ?.toInt() ??
              0;

      if (latestXp < requiredXp) {
        throw Exception(
          'XP хүрэлцэхгүй байна.',
        );
      }

      final pendingSnapshot =
          await _firestore
              .collection(
                'xpRedeemRequests',
              )
              .where(
                'userUid',
                isEqualTo:
                    firebaseUser.uid,
              )
              .where(
                'status',
                isEqualTo: 'pending',
              )
              .limit(1)
              .get();

      if (pendingSnapshot
          .docs.isNotEmpty) {
        throw Exception(
          'Танд шийдэгдээгүй XP хүсэлт байна.',
        );
      }

      if (_isGift) {
        final recipientSnapshot =
            await _firestore
                .collection('users')
                .doc(_recipientUid)
                .get();

        if (!recipientSnapshot.exists) {
          throw Exception(
            'Хүлээн авагч олдсонгүй.',
          );
        }
      }

      final requestRef =
          _firestore
              .collection(
                'xpRedeemRequests',
              )
              .doc();

      await requestRef.set({
        'requestId': requestRef.id,

        'userUid':
            firebaseUser.uid,

        'sixDigitId':
            _sixDigitId,

        'mode':
            _isGift
                ? 'gift'
                : 'self',

        'recipientUid':
            _isGift
                ? _recipientUid
                : firebaseUser.uid,

        'recipientSixDigitId':
            _isGift
                ? _recipientIdController
                    .text
                    .trim()
                : _sixDigitId,

        'recipientUsername':
            _isGift
                ? _recipientUsername
                : (userData['username'] ??
                        '')
                    .toString(),

        'entitlementType':
            _selectedType,

        'days':
            days,

        'xpCost':
            requiredXp,

        'status':
            'pending',

        'createdAt':
            FieldValue.serverTimestamp(),

        'approvedAt':
            null,

        'approvedBy':
            null,

        'rejectedAt':
            null,

        'rejectedBy':
            null,
      });

      if (!mounted) return;

      _showMessage(
        _isGift
            ? 'XP бэлэглэх хүсэлт амжилттай илгээгдлээ.'
            : 'XP солих хүсэлт амжилттай илгээгдлээ.',
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Хүсэлт илгээхэд алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title:
            const Text(
          'XP ашиглах',
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    AppColors.primary,
              ),
            )
          : Center(
              child:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth:
                      AppLayout
                          .profileMaxWidth,
                ),
                child:
                    ListView(
                  padding:
                      const EdgeInsets
                          .all(
                    AppSpacing.xl,
                  ),
                  children: [
                    _buildXpCard(),

                    const SizedBox(
                      height:
                          AppSpacing
                              .xxl,
                    ),

                    Text(
                      'XP-гээ хэрхэн ашиглах вэ?',
                      style:
                          AppTypography
                              .sectionTitle(),
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .md,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              _buildModeButton(
                            isGift:
                                false,
                            label:
                                'Өөртөө авах',
                            icon: Icons
                                .person_rounded,
                          ),
                        ),
                        const SizedBox(
                          width:
                              AppSpacing
                                  .md,
                        ),
                        Expanded(
                          child:
                              _buildModeButton(
                            isGift:
                                true,
                            label:
                                'Найздаа бэлэглэх',
                            icon: Icons
                                .card_giftcard_rounded,
                          ),
                        ),
                      ],
                    ),

                    if (_isGift) ...[
                      const SizedBox(
                        height:
                            AppSpacing
                                .xl,
                      ),

                      Text(
                        'Хүлээн авагч',
                        style:
                            AppTypography
                                .sectionTitle(),
                      ),

                      const SizedBox(
                        height:
                            AppSpacing
                                .md,
                      ),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            child:
                                TextField(
                              controller:
                                  _recipientIdController,
                              keyboardType:
                                  TextInputType
                                      .number,
                              maxLength:
                                  6,
                              onChanged:
                                  (_) {
                                setState(
                                    () {
                                  _recipientUid =
                                      null;

                                  _recipientUsername =
                                      null;
                                });
                              },
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    '6 оронтой ID',
                                hintText:
                                    'Жишээ: 123456',
                                prefixIcon:
                                    Icon(
                                  Icons
                                      .badge_outlined,
                                ),
                                counterText:
                                    '',
                              ),
                            ),
                          ),

                          const SizedBox(
                            width:
                                AppSpacing
                                    .sm,
                          ),

                          SizedBox(
                            height:
                                52,
                            child:
                                ElevatedButton(
                              onPressed:
                                  _checkingRecipient
                                      ? null
                                      : _findRecipient,
                              child:
                                  _checkingRecipient
                                      ? const SizedBox(
                                          width:
                                              18,
                                          height:
                                              18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color:
                                                Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Шалгах',
                                        ),
                            ),
                          ),
                        ],
                      ),

                      if (_recipientUsername !=
                          null) ...[
                        const SizedBox(
                          height:
                              AppSpacing
                                  .sm,
                        ),

                        PremiumCard(
                          child:
                              Row(
                            children: [
                              const Icon(
                                Icons
                                    .check_circle_rounded,
                                color:
                                    AppColors.success,
                              ),

                              const SizedBox(
                                width:
                                    AppSpacing
                                        .md,
                              ),

                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      _recipientUsername!,
                                      style:
                                          AppTypography.cardTitle(),
                                    ),
                                    Text(
                                      'ID: ${_recipientIdController.text.trim()}',
                                      style:
                                          AppTypography.meta(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(
                      height:
                          AppSpacing
                              .xxl,
                    ),

                    Text(
                      'Эрхийн төрөл',
                      style:
                          AppTypography
                              .sectionTitle(),
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .md,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              _buildTypeButton(
                            type:
                                'vip',
                            label:
                                'VIP',
                            icon: Icons
                                .workspace_premium_rounded,
                            accent:
                                AppColors
                                    .vipAccent,
                          ),
                        ),
                        const SizedBox(
                          width:
                              AppSpacing
                                  .md,
                        ),
                        Expanded(
                          child:
                              _buildTypeButton(
                            type:
                                'vvip',
                            label:
                                'VVIP',
                            icon: Icons
                                .diamond_rounded,
                            accent:
                                AppColors
                                    .vvipAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .xxl,
                    ),

                    Text(
                      _isGift
                          ? 'Хэдэн хоног бэлэглэх вэ?'
                          : 'Хэдэн хоног авах вэ?',
                      style:
                          AppTypography
                              .sectionTitle(),
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .md,
                    ),

                    TextField(
                      controller:
                          _daysController,
                      keyboardType:
                          TextInputType
                              .number,
                      onChanged:
                          (_) {
                        setState(
                            () {});
                      },
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Хоног',
                        hintText:
                            'Жишээ: 3',
                        prefixIcon:
                            Icon(
                          Icons
                              .calendar_month_rounded,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .lg,
                    ),

                    PremiumCard(
                      child:
                          Column(
                        children: [
                          _InfoRow(
                            label:
                                _isGift
                                    ? 'Хүлээн авагч'
                                    : 'Хэнд',
                            value:
                                _isGift
                                    ? (_recipientUsername ??
                                        'Сонгоогүй')
                                    : 'Өөртөө',
                          ),

                          const SizedBox(
                            height:
                                AppSpacing
                                    .sm,
                          ),

                          _InfoRow(
                            label:
                                'Эрх',
                            value:
                                _selectedType ==
                                        'vip'
                                    ? 'VIP'
                                    : 'VVIP',
                          ),

                          const SizedBox(
                            height:
                                AppSpacing
                                    .sm,
                          ),

                          _InfoRow(
                            label:
                                _isGift
                                    ? 'Бэлэглэх хоног'
                                    : 'Авах хоног',
                            value:
                                '${_days > 0 ? _days : 0} хоног',
                          ),

                          const SizedBox(
                            height:
                                AppSpacing
                                    .sm,
                          ),

                          _InfoRow(
                            label:
                                'Зарцуулах XP',
                            value:
                                '$_requiredXp XP',
                          ),

                          const SizedBox(
                            height:
                                AppSpacing
                                    .sm,
                          ),

                          _InfoRow(
                            label:
                                'Үлдэх XP',
                            value:
                                _hasEnoughXp
                                    ? '${_currentXp - _requiredXp} XP'
                                    : 'XP хүрэлцэхгүй',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .xl,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          ElevatedButton
                              .icon(
                        onPressed:
                            _submitting ||
                                    !_canSubmit
                                ? null
                                : _submitRequest,
                        icon:
                            _submitting
                                ? const SizedBox(
                                    width:
                                        18,
                                    height:
                                        18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isGift
                                        ? Icons
                                            .card_giftcard_rounded
                                        : Icons
                                            .swap_horiz_rounded,
                                  ),
                        label:
                            Text(
                          _submitting
                              ? 'Илгээж байна...'
                              : _isGift
                                  ? 'XP бэлэглэх хүсэлт илгээх'
                                  : 'XP солих хүсэлт илгээх',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          AppSpacing
                              .md,
                    ),

                    Text(
                      _isGift
                          ? 'Админ хүсэлтийг баталсны дараа таны XP хасагдаж, хүлээн авагчийн сонгосон эрхийн хугацаа нэмэгдэнэ.'
                          : 'Админ хүсэлтийг баталсны дараа XP хасагдаж, сонгосон эрхийн хугацаа нэмэгдэнэ.',
                      textAlign:
                          TextAlign
                              .center,
                      style:
                          AppTypography
                              .meta(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildXpCard() {
    return PremiumCard(
      elevated: true,
      radius:
          AppRadius.premium,
      child:
          Column(
        children: [
          const Icon(
            Icons
                .diamond_outlined,
            color:
                AppColors
                    .primaryLight,
            size:
                42,
          ),

          const SizedBox(
            height:
                AppSpacing
                    .md,
          ),

          Text(
            '$_currentXp XP',
            style:
                AppTypography
                    .pageTitle(),
          ),

          const SizedBox(
            height:
                AppSpacing
                    .xs,
          ),

          Text(
            '10 XP = 1 хоног',
            style:
                AppTypography
                    .body(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required bool isGift,
    required String label,
    required IconData icon,
  }) {
    final selected =
        _isGift == isGift;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isGift = isGift;

          _recipientUid =
              null;

          _recipientUsername =
              null;

          if (!isGift) {
            _recipientIdController
                .clear();
          }
        });
      },
      child:
          Container(
        padding:
            const EdgeInsets
                .symmetric(
          vertical:
              AppSpacing.lg,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors
                      .primary
                      .withValues(
                        alpha:
                            0.15,
                      )
                  : AppColors
                      .surface,
          borderRadius:
              BorderRadius
                  .circular(
            AppRadius.card,
          ),
          border:
              Border.all(
            color:
                selected
                    ? AppColors
                        .primary
                    : AppColors
                        .border,
            width:
                selected
                    ? 1.5
                    : 1,
          ),
        ),
        child:
            Column(
          children: [
            Icon(
              icon,
              color:
                  selected
                      ? AppColors
                          .primaryLight
                      : AppColors
                          .textMuted,
            ),

            const SizedBox(
              height:
                  AppSpacing
                      .sm,
            ),

            Text(
              label,
              textAlign:
                  TextAlign
                      .center,
              style:
                  AppTypography
                      .cardTitle(
                color:
                    selected
                        ? AppColors
                            .primaryLight
                        : AppColors
                            .textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String type,
    required String label,
    required IconData icon,
    required Color accent,
  }) {
    final selected =
        _selectedType ==
            type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType =
              type;
        });
      },
      child:
          Container(
        padding:
            const EdgeInsets
                .symmetric(
          vertical:
              AppSpacing.lg,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? accent
                      .withValues(
                        alpha:
                            0.15,
                      )
                  : AppColors
                      .surface,
          borderRadius:
              BorderRadius
                  .circular(
            AppRadius.card,
          ),
          border:
              Border.all(
            color:
                selected
                    ? accent
                    : AppColors
                        .border,
            width:
                selected
                    ? 1.5
                    : 1,
          ),
        ),
        child:
            Column(
          children: [
            Icon(
              icon,
              color:
                  selected
                      ? accent
                      : AppColors
                          .textMuted,
            ),

            const SizedBox(
              height:
                  AppSpacing
                      .sm,
            ),

            Text(
              label,
              style:
                  AppTypography
                      .cardTitle(
                color:
                    selected
                        ? accent
                        : AppColors
                            .textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                AppTypography
                    .body(),
          ),
        ),
        Text(
          value,
          style:
              AppTypography
                  .cardTitle(),
        ),
      ],
    );
  }
}