import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _processingRequestKey;

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMoney(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }

    return '${buffer.toString()}₮';
  }

  int _calculateRemainingDays(
    DateTime expiresAt,
    DateTime now,
  ) {
    if (!expiresAt.isAfter(now)) {
      return 0;
    }

    final difference = expiresAt.difference(now);
    final fullDays = difference.inDays;

    final hasPartialDay =
        difference.inSeconds >
        fullDays * Duration.secondsPerDay;

    return fullDays + (hasPartialDay ? 1 : 0);
  }

  DateTime _calculateNewExpiration({
    required Map<String, dynamic> userData,
    required String entitlementType,
    required int days,
    required DateTime now,
  }) {
    DateTime baseDate = now;

    final expirationField =
        entitlementType == 'vip'
            ? 'vipExpiresAt'
            : 'vvipExpiresAt';

    final legacyDaysField =
        entitlementType == 'vip'
            ? 'vipDays'
            : 'vvipDays';

    final currentExpiresAt = userData[expirationField];

    if (currentExpiresAt is Timestamp) {
      final existingDate = currentExpiresAt.toDate();

      if (existingDate.isAfter(now)) {
        baseDate = existingDate;
      }
    } else if (currentExpiresAt == null) {
      final legacyDays =
          _readInt(userData[legacyDaysField]);

      if (legacyDays > 0) {
        baseDate = now.add(
          Duration(days: legacyDays),
        );
      }
    }

    return baseDate.add(
      Duration(days: days),
    );
  }

  Future<bool> _checkAdmin() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return false;
    }

    try {
      final document = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      return document.data()?['isAdmin'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _approvePaymentRequest(
    String requestId,
  ) async {
    final adminUser = _auth.currentUser;

    if (adminUser == null) {
      _showMessage(
        'Админ хэрэглэгч нэвтрээгүй байна.',
      );
      return;
    }

    final processingKey =
        'payment:$requestId';

    if (_processingRequestKey != null) return;

    setState(() {
      _processingRequestKey = processingKey;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final adminRef = _firestore
              .collection('users')
              .doc(adminUser.uid);

          final adminSnapshot =
              await transaction.get(adminRef);

          if (!adminSnapshot.exists ||
              adminSnapshot.data()?['isAdmin'] != true) {
            throw Exception(
              'Танд админ эрх байхгүй байна.',
            );
          }

          final requestRef = _firestore
              .collection('paymentRequests')
              .doc(requestId);

          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception(
              'Төлбөрийн хүсэлт олдсонгүй.',
            );
          }

          final requestData =
              requestSnapshot.data() ??
              <String, dynamic>{};

          if (requestData['status'] != 'pending') {
            throw Exception(
              'Энэ хүсэлтийг аль хэдийн шийдвэрлэсэн байна.',
            );
          }

          final userUid =
              (requestData['userUid'] ?? '')
                  .toString();

          final entitlementType =
              (requestData['entitlementType'] ?? '')
                  .toString();

          final days =
              _readInt(requestData['days']);

          if (userUid.isEmpty) {
            throw Exception(
              'Хэрэглэгчийн UID байхгүй байна.',
            );
          }

          if (days <= 0) {
            throw Exception(
              'Нэмэгдэх хоног буруу байна.',
            );
          }

          if (entitlementType != 'vip' &&
              entitlementType != 'vvip') {
            throw Exception(
              'Эрхийн төрөл буруу байна.',
            );
          }

          final userRef = _firestore
              .collection('users')
              .doc(userUid);

          final userSnapshot =
              await transaction.get(userRef);

          if (!userSnapshot.exists) {
            throw Exception(
              'Хэрэглэгч олдсонгүй.',
            );
          }

          final userData =
              userSnapshot.data() ??
              <String, dynamic>{};

          final currentXp =
              _readInt(userData['xp']);

          final now = DateTime.now();

          final newExpiresAt =
              _calculateNewExpiration(
            userData: userData,
            entitlementType: entitlementType,
            days: days,
            now: now,
          );

          final remainingDays =
              _calculateRemainingDays(
            newExpiresAt,
            now,
          );

          if (entitlementType == 'vip') {
            transaction.update(
              userRef,
              {
                'vipExpiresAt':
                    Timestamp.fromDate(
                  newExpiresAt,
                ),
                'vipDays': remainingDays,
                'xp': currentXp + days,
              },
            );
          } else {
            transaction.update(
              userRef,
              {
                'vvipExpiresAt':
                    Timestamp.fromDate(
                  newExpiresAt,
                ),
                'vvipDays': remainingDays,
                'xp': currentXp + days,
              },
            );
          }

          transaction.update(
            requestRef,
            {
              'status': 'approved',
              'approvedAt':
                  FieldValue.serverTimestamp(),
              'approvedBy': adminUser.uid,
            },
          );
        },
      );

      if (!mounted) return;

      _showMessage(
        'Төлбөр батлагдлаа. Эрхийн хугацаа болон XP нэмэгдлээ.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Батлах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  Future<void> _rejectPaymentRequest(
    String requestId,
  ) async {
    final adminUser = _auth.currentUser;

    if (adminUser == null) {
      _showMessage(
        'Админ хэрэглэгч нэвтрээгүй байна.',
      );
      return;
    }

    final processingKey =
        'payment:$requestId';

    if (_processingRequestKey != null) return;

    setState(() {
      _processingRequestKey = processingKey;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final adminRef = _firestore
              .collection('users')
              .doc(adminUser.uid);

          final adminSnapshot =
              await transaction.get(adminRef);

          if (!adminSnapshot.exists ||
              adminSnapshot.data()?['isAdmin'] != true) {
            throw Exception(
              'Танд админ эрх байхгүй байна.',
            );
          }

          final requestRef = _firestore
              .collection('paymentRequests')
              .doc(requestId);

          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception(
              'Төлбөрийн хүсэлт олдсонгүй.',
            );
          }

          final data =
              requestSnapshot.data() ??
              <String, dynamic>{};

          if (data['status'] != 'pending') {
            throw Exception(
              'Энэ хүсэлтийг аль хэдийн шийдвэрлэсэн байна.',
            );
          }

          transaction.update(
            requestRef,
            {
              'status': 'rejected',
              'rejectedAt':
                  FieldValue.serverTimestamp(),
              'rejectedBy': adminUser.uid,
            },
          );
        },
      );

      if (!mounted) return;

      _showMessage(
        'Төлбөрийн хүсэлтийг татгалзлаа.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Татгалзах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  Future<void> _approveXpRequest(
    String requestId,
  ) async {
    final adminUser = _auth.currentUser;

    if (adminUser == null) {
      _showMessage(
        'Админ хэрэглэгч нэвтрээгүй байна.',
      );
      return;
    }

    final processingKey =
        'xp:$requestId';

    if (_processingRequestKey != null) return;

    setState(() {
      _processingRequestKey = processingKey;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final adminRef = _firestore
              .collection('users')
              .doc(adminUser.uid);

          final adminSnapshot =
              await transaction.get(adminRef);

          if (!adminSnapshot.exists ||
              adminSnapshot.data()?['isAdmin'] != true) {
            throw Exception(
              'Танд админ эрх байхгүй байна.',
            );
          }

          final requestRef = _firestore
              .collection('xpRedeemRequests')
              .doc(requestId);

          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception(
              'XP хүсэлт олдсонгүй.',
            );
          }

          final requestData =
              requestSnapshot.data() ??
              <String, dynamic>{};

          if (requestData['status'] != 'pending') {
            throw Exception(
              'Энэ хүсэлтийг аль хэдийн шийдвэрлэсэн байна.',
            );
          }

          final senderUid =
              (requestData['userUid'] ?? '')
                  .toString();

          final mode =
              (requestData['mode'] ?? 'self')
                  .toString();

          final recipientUid =
              (requestData['recipientUid'] ??
                      senderUid)
                  .toString();

          final entitlementType =
              (requestData['entitlementType'] ?? '')
                  .toString();

          final days =
              _readInt(requestData['days']);

          final xpCost =
              _readInt(requestData['xpCost']);

          if (senderUid.isEmpty) {
            throw Exception(
              'XP илгээгчийн UID байхгүй байна.',
            );
          }

          if (recipientUid.isEmpty) {
            throw Exception(
              'Хүлээн авагчийн UID байхгүй байна.',
            );
          }

          if (mode != 'self' &&
              mode != 'gift') {
            throw Exception(
              'XP хүсэлтийн төрөл буруу байна.',
            );
          }

          if (mode == 'self' &&
              senderUid != recipientUid) {
            throw Exception(
              'Өөртөө солих хүсэлтийн хэрэглэгч зөрүүтэй байна.',
            );
          }

          if (mode == 'gift' &&
              senderUid == recipientUid) {
            throw Exception(
              'Бэлэглэх хүсэлтийн хүлээн авагч буруу байна.',
            );
          }

          if (days <= 0) {
            throw Exception(
              'Хоног буруу байна.',
            );
          }

          if (xpCost != days * 10) {
            throw Exception(
              'XP тооцоолол буруу байна.',
            );
          }

          if (entitlementType != 'vip' &&
              entitlementType != 'vvip') {
            throw Exception(
              'Эрхийн төрөл буруу байна.',
            );
          }

          final senderRef = _firestore
              .collection('users')
              .doc(senderUid);

          final senderSnapshot =
              await transaction.get(senderRef);

          if (!senderSnapshot.exists) {
            throw Exception(
              'XP илгээгч хэрэглэгч олдсонгүй.',
            );
          }

          final senderData =
              senderSnapshot.data() ??
              <String, dynamic>{};

          final currentXp =
              _readInt(senderData['xp']);

          if (currentXp < xpCost) {
            throw Exception(
              'Илгээгчийн XP хүрэлцэхгүй байна. '
              'Одоогийн XP: $currentXp, '
              'шаардлагатай XP: $xpCost.',
            );
          }

          final recipientRef = _firestore
              .collection('users')
              .doc(recipientUid);

          final recipientSnapshot =
              senderUid == recipientUid
                  ? senderSnapshot
                  : await transaction.get(
                      recipientRef,
                    );

          if (!recipientSnapshot.exists) {
            throw Exception(
              'Хүлээн авагч хэрэглэгч олдсонгүй.',
            );
          }

          final recipientData =
              recipientSnapshot.data() ??
              <String, dynamic>{};

          final now = DateTime.now();

          final newExpiresAt =
              _calculateNewExpiration(
            userData: recipientData,
            entitlementType: entitlementType,
            days: days,
            now: now,
          );

          final remainingDays =
              _calculateRemainingDays(
            newExpiresAt,
            now,
          );

          final newXp =
              currentXp - xpCost;

          if (senderUid == recipientUid) {
            if (entitlementType == 'vip') {
              transaction.update(
                senderRef,
                {
                  'vipExpiresAt':
                      Timestamp.fromDate(
                    newExpiresAt,
                  ),
                  'vipDays': remainingDays,
                  'xp': newXp,
                },
              );
            } else {
              transaction.update(
                senderRef,
                {
                  'vvipExpiresAt':
                      Timestamp.fromDate(
                    newExpiresAt,
                  ),
                  'vvipDays': remainingDays,
                  'xp': newXp,
                },
              );
            }
          } else {
            transaction.update(
              senderRef,
              {
                'xp': newXp,
              },
            );

            if (entitlementType == 'vip') {
              transaction.update(
                recipientRef,
                {
                  'vipExpiresAt':
                      Timestamp.fromDate(
                    newExpiresAt,
                  ),
                  'vipDays': remainingDays,
                },
              );
            } else {
              transaction.update(
                recipientRef,
                {
                  'vvipExpiresAt':
                      Timestamp.fromDate(
                    newExpiresAt,
                  ),
                  'vvipDays': remainingDays,
                },
              );
            }
          }

          transaction.update(
            requestRef,
            {
              'status': 'approved',
              'approvedAt':
                  FieldValue.serverTimestamp(),
              'approvedBy': adminUser.uid,
            },
          );
        },
      );

      if (!mounted) return;

      _showMessage(
        'XP хүсэлт батлагдлаа.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'XP хүсэлт батлах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  Future<void> _rejectXpRequest(
    String requestId,
  ) async {
    final adminUser = _auth.currentUser;

    if (adminUser == null) {
      _showMessage(
        'Админ хэрэглэгч нэвтрээгүй байна.',
      );
      return;
    }

    final processingKey =
        'xp:$requestId';

    if (_processingRequestKey != null) return;

    setState(() {
      _processingRequestKey = processingKey;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final adminRef = _firestore
              .collection('users')
              .doc(adminUser.uid);

          final adminSnapshot =
              await transaction.get(adminRef);

          if (!adminSnapshot.exists ||
              adminSnapshot.data()?['isAdmin'] != true) {
            throw Exception(
              'Танд админ эрх байхгүй байна.',
            );
          }

          final requestRef = _firestore
              .collection('xpRedeemRequests')
              .doc(requestId);

          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception(
              'XP хүсэлт олдсонгүй.',
            );
          }

          final data =
              requestSnapshot.data() ??
              <String, dynamic>{};

          if (data['status'] != 'pending') {
            throw Exception(
              'Энэ хүсэлтийг аль хэдийн шийдвэрлэсэн байна.',
            );
          }

          transaction.update(
            requestRef,
            {
              'status': 'rejected',
              'rejectedAt':
                  FieldValue.serverTimestamp(),
              'rejectedBy': adminUser.uid,
            },
          );
        },
      );

      if (!mounted) return;

      _showMessage(
        'XP хүсэлтийг татгалзлаа.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'XP хүсэлт татгалзах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
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
        title: const Text('Админ'),
      ),
      body: FutureBuilder<bool>(
        future: _checkAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.data != true) {
            return _buildNoPermission();
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const Material(
                  color: AppColors.background,
                  child: TabBar(
                    indicatorColor:
                        AppColors.primary,
                    labelColor:
                        AppColors.textPrimary,
                    unselectedLabelColor:
                        AppColors.textMuted,
                    tabs: [
                      Tab(
                        icon: Icon(
                          Icons.payments_outlined,
                        ),
                        text: 'Төлбөр',
                      ),
                      Tab(
                        icon: Icon(
                          Icons.diamond_outlined,
                        ),
                        text: 'XP',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPaymentRequests(),
                      _buildXpRequests(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSpacing.xl,
        ),
        child: PremiumCard(
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppColors.danger,
                size: 48,
              ),
              const SizedBox(
                height: AppSpacing.lg,
              ),
              Text(
                'Админ эрх байхгүй',
                style:
                    AppTypography.sectionTitle(),
              ),
              const SizedBox(
                height: AppSpacing.sm,
              ),
              Text(
                'Энэ хэсэгт зөвхөн админ хэрэглэгч нэвтрэх боломжтой.',
                textAlign: TextAlign.center,
                style: AppTypography.body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRequests() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('paymentRequests')
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(
            'Төлбөрийн хүсэлт унших үед алдаа гарлаа:\n'
            '${snapshot.error}',
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

        final requests =
            snapshot.data?.docs ?? [];

        _sortByCreatedAt(requests);

        if (requests.isEmpty) {
          return _buildEmpty(
            icon:
                Icons.check_circle_outline_rounded,
            title:
                'Хүлээгдэж буй төлбөр алга',
            description:
                'Шинэ төлбөрийн хүсэлт ирэхэд энд харагдана.',
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth:
                  AppLayout.profileMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'Хүлээгдэж буй төлбөрүүд',
                  style:
                      AppTypography.pageTitle(),
                ),
                const SizedBox(
                  height: AppSpacing.sm,
                ),
                Text(
                  '${requests.length} хүсэлт байна',
                  style: AppTypography.body(),
                ),
                const SizedBox(
                  height: AppSpacing.xl,
                ),
                ...requests.map(
                  (document) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: AppSpacing.lg,
                    ),
                    child:
                        _buildPaymentCard(
                      document,
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

  Widget _buildXpRequests() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('xpRedeemRequests')
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(
            'XP хүсэлт унших үед алдаа гарлаа:\n'
            '${snapshot.error}',
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

        final requests =
            snapshot.data?.docs ?? [];

        _sortByCreatedAt(requests);

        if (requests.isEmpty) {
          return _buildEmpty(
            icon: Icons.diamond_outlined,
            title:
                'Хүлээгдэж буй XP хүсэлт алга',
            description:
                'XP солих эсвэл бэлэглэх хүсэлт энд харагдана.',
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth:
                  AppLayout.profileMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'XP хүсэлтүүд',
                  style:
                      AppTypography.pageTitle(),
                ),
                const SizedBox(
                  height: AppSpacing.sm,
                ),
                Text(
                  '${requests.length} хүсэлт байна',
                  style: AppTypography.body(),
                ),
                const SizedBox(
                  height: AppSpacing.xl,
                ),
                ...requests.map(
                  (document) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: AppSpacing.lg,
                    ),
                    child: _buildXpCard(
                      document,
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

  void _sortByCreatedAt(
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        requests,
  ) {
    requests.sort(
      (a, b) {
        final aTime =
            a.data()['createdAt']
                as Timestamp?;

        final bTime =
            b.data()['createdAt']
                as Timestamp?;

        if (aTime == null &&
            bTime == null) {
          return 0;
        }

        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      },
    );
  }

  Widget _buildPaymentCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        document,
  ) {
    final data = document.data();

    final type =
        (data['entitlementType'] ?? '')
            .toString();

    final displayType =
        type == 'vvip' ? 'VVIP' : 'VIP';

    final days =
        _readInt(data['days']);

    final amount =
        _readInt(data['amount']);

    final sixDigitId =
        (data['sixDigitId'] ?? '-')
            .toString();

    final planLabel =
        (data['planLabel'] ?? '')
            .toString();

    final createdAt =
        data['createdAt'] as Timestamp?;

    final processing =
        _processingRequestKey ==
        'payment:${document.id}';

    final accent =
        type == 'vvip'
            ? AppColors.vvipAccent
            : AppColors.vipAccent;

    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  type == 'vvip'
                      ? Icons.diamond_rounded
                      : Icons
                          .workspace_premium_rounded,
                  color: accent,
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
                      '$displayType эрх',
                      style:
                          AppTypography.cardTitle(
                        color: accent,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      planLabel.isEmpty
                          ? '$days хоног'
                          : '$planLabel • $days хоног',
                      style:
                          AppTypography.meta(),
                    ),
                  ],
                ),
              ),
              Text(
                _formatMoney(amount),
                style: GoogleFonts.poppins(
                  color:
                      AppColors.goldLight,
                  fontWeight:
                      FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
            ),
            child: Divider(
              height: 1,
              color: AppColors.border,
            ),
          ),
          _AdminInfoRow(
            label: 'Хэрэглэгчийн ID',
            value: sixDigitId,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _AdminInfoRow(
            label: 'Нэмэгдэх хоног',
            value: '$days хоног',
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _AdminInfoRow(
            label: 'Нэмэгдэх XP',
            value: '+$days XP',
          ),
          if (createdAt != null) ...[
            const SizedBox(
              height: AppSpacing.sm,
            ),
            _AdminInfoRow(
              label: 'Хүсэлт илгээсэн',
              value: _formatDate(
                createdAt.toDate(),
              ),
            ),
          ],
          const SizedBox(
            height: AppSpacing.lg,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: processing ||
                          _processingRequestKey != null
                      ? null
                      : () =>
                          _rejectPaymentRequest(
                            document.id,
                          ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors.danger,
                    side: const BorderSide(
                      color:
                          AppColors.danger,
                    ),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                  label: const Text(
                    'Татгалзах',
                  ),
                ),
              ),
              const SizedBox(
                width: AppSpacing.md,
              ),
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed: processing ||
                          _processingRequestKey != null
                      ? null
                      : () =>
                          _approvePaymentRequest(
                            document.id,
                          ),
                  icon: processing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_rounded,
                        ),
                  label: Text(
                    processing
                        ? '...'
                        : 'Батлах',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildXpCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        document,
  ) {
    final data = document.data();

    final type =
        (data['entitlementType'] ?? '')
            .toString();

    final displayType =
        type == 'vvip' ? 'VVIP' : 'VIP';

    final mode =
        (data['mode'] ?? 'self')
            .toString();

    final isGift = mode == 'gift';

    final days =
        _readInt(data['days']);

    final xpCost =
        _readInt(data['xpCost']);

    final senderId =
        (data['sixDigitId'] ?? '-')
            .toString();

    final recipientId =
        (data['recipientSixDigitId'] ??
                senderId)
            .toString();

    final recipientUsername =
        (data['recipientUsername'] ?? '')
            .toString();

    final createdAt =
        data['createdAt'] as Timestamp?;

    final processing =
        _processingRequestKey ==
        'xp:${document.id}';

    final accent =
        type == 'vvip'
            ? AppColors.vvipAccent
            : AppColors.vipAccent;

    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  isGift
                      ? Icons.card_giftcard_rounded
                      : type == 'vvip'
                          ? Icons.diamond_rounded
                          : Icons
                              .workspace_premium_rounded,
                  color: accent,
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
                      isGift
                          ? '$displayType • Бэлэг'
                          : '$displayType • Өөртөө',
                      style:
                          AppTypography.cardTitle(
                        color: accent,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      '$xpCost XP → $days хоног',
                      style:
                          AppTypography.meta(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
            ),
            child: Divider(
              height: 1,
              color: AppColors.border,
            ),
          ),
          _AdminInfoRow(
            label: 'Илгээгчийн ID',
            value: senderId,
          ),
          if (isGift) ...[
            const SizedBox(
              height: AppSpacing.sm,
            ),
            _AdminInfoRow(
              label: 'Хүлээн авагч',
              value:
                  recipientUsername.isEmpty
                      ? '-'
                      : recipientUsername,
            ),
            const SizedBox(
              height: AppSpacing.sm,
            ),
            _AdminInfoRow(
              label: 'Хүлээн авагч ID',
              value: recipientId,
            ),
          ],
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _AdminInfoRow(
            label: 'Зарцуулах XP',
            value: '-$xpCost XP',
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _AdminInfoRow(
            label: isGift
                ? 'Бэлэглэх эрх'
                : 'Нэмэгдэх эрх',
            value:
                '$displayType +$days хоног',
          ),
          if (createdAt != null) ...[
            const SizedBox(
              height: AppSpacing.sm,
            ),
            _AdminInfoRow(
              label: 'Хүсэлт илгээсэн',
              value: _formatDate(
                createdAt.toDate(),
              ),
            ),
          ],
          const SizedBox(
            height: AppSpacing.lg,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: processing ||
                          _processingRequestKey != null
                      ? null
                      : () =>
                          _rejectXpRequest(
                            document.id,
                          ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors.danger,
                    side: const BorderSide(
                      color:
                          AppColors.danger,
                    ),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                  label: const Text(
                    'Татгалзах',
                  ),
                ),
              ),
              const SizedBox(
                width: AppSpacing.md,
              ),
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed: processing ||
                          _processingRequestKey != null
                      ? null
                      : () =>
                          _approveXpRequest(
                            document.id,
                          ),
                  icon: processing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_rounded,
                        ),
                  label: Text(
                    processing
                        ? '...'
                        : 'Батлах',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSpacing.xl,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body(),
        ),
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.success,
              size: 52,
            ),
            const SizedBox(
              height: AppSpacing.lg,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  AppTypography.sectionTitle(),
            ),
            const SizedBox(
              height: AppSpacing.sm,
            ),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.body(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String twoDigits(int number) {
      return number
          .toString()
          .padLeft(2, '0');
    }

    return '${date.year}.'
        '${twoDigits(date.month)}.'
        '${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }
}

class _AdminInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _AdminInfoRow({
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}