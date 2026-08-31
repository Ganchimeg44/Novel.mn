import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class XpRedeemScreen extends StatefulWidget {
  const XpRedeemScreen({super.key});

  @override
  State<XpRedeemScreen> createState() => _XpRedeemScreenState();
}

class _XpRedeemScreenState extends State<XpRedeemScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _daysController =
      TextEditingController(text: '1');

  bool _loading = true;
  bool _submitting = false;

  int _currentXp = 0;
  String _sixDigitId = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _daysController.dispose();
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
        _currentXp = (data?['xp'] as num?)?.toInt() ?? 0;
        _sixDigitId = (data?['sixDigitId'] ?? '').toString();
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
    return int.tryParse(_daysController.text.trim()) ?? 0;
  }

  int get _requiredXp {
    if (_days <= 0) return 0;
    return _days * 10;
  }

  bool get _hasEnoughXp {
    return _days > 0 && _currentXp >= _requiredXp;
  }

  Future<void> _submitRequest() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      _showMessage('Нэвтэрсэн хэрэглэгч олдсонгүй.');
      return;
    }

    final days = _days;

    if (days <= 0) {
      _showMessage('Авах хоногоо зөв оруулна уу.');
      return;
    }

    final requiredXp = days * 10;

    if (_currentXp < requiredXp) {
      _showMessage(
        'XP хүрэлцэхгүй байна. '
        '$days VIP хоног авахад $requiredXp XP шаардлагатай.',
      );
      return;
    }

    if (_sixDigitId.isEmpty) {
      _showMessage('6 оронтой ID олдсонгүй.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final userSnapshot = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final userData = userSnapshot.data();

      if (userData == null) {
        throw Exception('Хэрэглэгчийн мэдээлэл олдсонгүй.');
      }

      final latestXp = (userData['xp'] as num?)?.toInt() ?? 0;

      if (latestXp < requiredXp) {
        throw Exception('XP хүрэлцэхгүй байна.');
      }

      final pendingSnapshot = await _firestore
          .collection('xpRedeemRequests')
          .where(
            'userUid',
            isEqualTo: firebaseUser.uid,
          )
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .limit(1)
          .get();

      if (pendingSnapshot.docs.isNotEmpty) {
        throw Exception(
          'Танд шийдэгдээгүй XP хүсэлт байна.',
        );
      }

      final requestRef =
          _firestore.collection('xpRedeemRequests').doc();

      await requestRef.set({
        'requestId': requestRef.id,
        'userUid': firebaseUser.uid,
        'sixDigitId': _sixDigitId,

        // XP-г зөвхөн өөртөө VIP хоног болгон солино.
        'mode': 'self',
        'recipientUid': firebaseUser.uid,
        'recipientSixDigitId': _sixDigitId,
        'recipientUsername':
            (userData['username'] ?? '').toString(),
        'entitlementType': 'vip',

        'days': days,
        'xpCost': requiredXp,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'approvedBy': null,
        'rejectedAt': null,
        'rejectedBy': null,
      });

      if (!mounted) return;

      _showMessage(
        'XP → VIP хүсэлт амжилттай илгээгдлээ.',
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('XP ашиглах'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.profileMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(
                    AppSpacing.xl,
                  ),
                  children: [
                    _buildXpCard(),
                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),
                    Text(
                      'XP-гээ VIP хоног болгох',
                      style: AppTypography.sectionTitle(),
                    ),
                    const SizedBox(
                      height: AppSpacing.md,
                    ),
                    PremiumCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.vipAccent,
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
                                  'VIP эрх',
                                  style: AppTypography.cardTitle(
                                    color: AppColors.vipAccent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'XP-г зөвхөн өөрийн VIP эрхийн хоног болгон солино.',
                                  style: AppTypography.meta(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),
                    Text(
                      'Хэдэн VIP хоног авах вэ?',
                      style: AppTypography.sectionTitle(),
                    ),
                    const SizedBox(
                      height: AppSpacing.md,
                    ),
                    TextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: 'VIP хоног',
                        hintText: 'Жишээ: 3',
                        prefixIcon: Icon(
                          Icons.calendar_month_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.lg,
                    ),
                    PremiumCard(
                      child: Column(
                        children: [
                          const _InfoRow(
                            label: 'Хэнд',
                            value: 'Өөртөө',
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          const _InfoRow(
                            label: 'Эрх',
                            value: 'VIP',
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          _InfoRow(
                            label: 'Авах хоног',
                            value:
                                '${_days > 0 ? _days : 0} хоног',
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          _InfoRow(
                            label: 'Зарцуулах XP',
                            value: '$_requiredXp XP',
                          ),
                          const SizedBox(
                            height: AppSpacing.sm,
                          ),
                          _InfoRow(
                            label: 'Үлдэх XP',
                            value: _hasEnoughXp
                                ? '${_currentXp - _requiredXp} XP'
                                : 'XP хүрэлцэхгүй',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.xl,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _submitting || !_hasEnoughXp
                                ? null
                                : _submitRequest,
                        icon: _submitting
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
                                Icons.swap_horiz_rounded,
                              ),
                        label: Text(
                          _submitting
                              ? 'Илгээж байна...'
                              : 'XP → VIP хүсэлт илгээх',
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.md,
                    ),
                    Text(
                      'Админ хүсэлтийг баталсны дараа XP хасагдаж, '
                      'таны VIP эрхийн хугацаа нэмэгдэнэ.',
                      textAlign: TextAlign.center,
                      style: AppTypography.meta(),
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
      radius: AppRadius.premium,
      child: Column(
        children: [
          const Icon(
            Icons.diamond_outlined,
            color: AppColors.primaryLight,
            size: 42,
          ),
          const SizedBox(
            height: AppSpacing.md,
          ),
          Text(
            '$_currentXp XP',
            style: AppTypography.pageTitle(),
          ),
          const SizedBox(
            height: AppSpacing.xs,
          ),
          Text(
            '10 XP = 1 VIP хоног',
            style: AppTypography.body(),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(),
          ),
        ),
        Text(
          value,
          style: AppTypography.cardTitle(),
        ),
      ],
    );
  }
}
