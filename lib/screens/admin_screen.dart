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

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _processingRequestKey;

  final TextEditingController _userSearchController =
      TextEditingController();

  bool _searchingUser = false;
  String? _selectedUserUid;
  Map<String, dynamic>? _selectedUserData;

  late final TabController _adminTabController;
  int _adminTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _adminTabController = TabController(
      length: 4,
      vsync: this,
    );
    _adminTabController.addListener(() {
      if (!_adminTabController.indexIsChanging && mounted) {
        setState(() {
          _adminTabIndex = _adminTabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _adminTabController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

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
      _showMessage('Админ хэрэглэгч нэвтрээгүй байна.');
      return;
    }

    final processingKey = 'xp:$requestId';
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
            throw Exception('Танд админ эрх байхгүй байна.');
          }

          final requestRef = _firestore
              .collection('xpRedeemRequests')
              .doc(requestId);
          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception('XP хүсэлт олдсонгүй.');
          }

          final requestData = requestSnapshot.data() ??
              <String, dynamic>{};

          if (requestData['status'] != 'pending') {
            throw Exception(
              'Энэ хүсэлтийг аль хэдийн шийдвэрлэсэн байна.',
            );
          }

          final userUid =
              (requestData['userUid'] ?? '').toString();
          final mode =
              (requestData['mode'] ?? '').toString();
          final recipientUid =
              (requestData['recipientUid'] ?? '').toString();
          final entitlementType =
              (requestData['entitlementType'] ?? '')
                  .toString();
          final days = _readInt(requestData['days']);
          final xpCost = _readInt(requestData['xpCost']);

          if (userUid.isEmpty) {
            throw Exception('Хэрэглэгчийн UID байхгүй байна.');
          }
          if (mode != 'self') {
            throw Exception('XP-г зөвхөн өөртөө сольж болно.');
          }
          if (recipientUid != userUid) {
            throw Exception('XP хүсэлтийн хэрэглэгч зөрүүтэй байна.');
          }
          if (entitlementType != 'vip') {
            throw Exception('XP-г зөвхөн VIP хоног болгоно.');
          }
          if (days <= 0 || xpCost != days * 10) {
            throw Exception('XP тооцоолол буруу байна.');
          }

          final userRef =
              _firestore.collection('users').doc(userUid);
          final userSnapshot =
              await transaction.get(userRef);

          if (!userSnapshot.exists) {
            throw Exception('Хэрэглэгч олдсонгүй.');
          }

          final userData = userSnapshot.data() ??
              <String, dynamic>{};
          final currentXp = _readInt(userData['xp']);

          if (currentXp < xpCost) {
            throw Exception(
              'XP хүрэлцэхгүй байна. Одоогийн XP: $currentXp, шаардлагатай XP: $xpCost.',
            );
          }

          final now = DateTime.now();
          final newExpiresAt = _calculateNewExpiration(
            userData: userData,
            entitlementType: 'vip',
            days: days,
            now: now,
          );
          final remainingDays = _calculateRemainingDays(
            newExpiresAt,
            now,
          );

          transaction.update(
            userRef,
            {
              'vipExpiresAt':
                  Timestamp.fromDate(newExpiresAt),
              'vipDays': remainingDays,
              'xp': currentXp - xpCost,
            },
          );

          transaction.update(
            requestRef,
            {
              'status': 'approved',
              'approvedAt': FieldValue.serverTimestamp(),
              'approvedBy': adminUser.uid,
            },
          );
        },
      );

      if (!mounted) return;
      _showMessage(
        'XP хүсэлт батлагдлаа. VIP хоног нэмэгдэж, XP хасагдлаа.',
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

  Future<void> _approveBirthdayRequest(
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
        'birthday:$requestId';

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
              .collection('birthdayGiftRequests')
              .doc(requestId);

          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception(
              'Төрсөн өдрийн хүсэлт олдсонгүй.',
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

          final giftYear =
              _readInt(requestData['year']);

          final createdAt =
              requestData['createdAt'];

          if (userUid.isEmpty) {
            throw Exception(
              'Хэрэглэгчийн UID байхгүй байна.',
            );
          }

          if (entitlementType != 'vip') {
            throw Exception(
              'Төрсөн өдрийн бэлэг зөвхөн VIP байна.',
            );
          }

          if (days != 7) {
            throw Exception(
              'Төрсөн өдрийн бэлэг зөвхөн +7 хоног байна.',
            );
          }

          if (giftYear <= 0) {
            throw Exception(
              'Төрсөн өдрийн бэлгийн жил буруу байна.',
            );
          }

          if (createdAt is! Timestamp) {
            throw Exception(
              'Хүсэлт илгээсэн огноо байхгүй байна.',
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

          final birthDateValue =
              userData['birthDate'];

          if (birthDateValue is! Timestamp) {
            throw Exception(
              'Хэрэглэгчийн төрсөн өдөр бүртгэгдээгүй байна.',
            );
          }

          final birthDate =
              birthDateValue.toDate();

          final requestDate =
              createdAt.toDate().toLocal();

          if (requestDate.year != giftYear ||
              requestDate.month != birthDate.month ||
              requestDate.day != birthDate.day) {
            throw Exception(
              'Энэ хүсэлт төрсөн өдрөөр илгээгдээгүй байна.',
            );
          }

          final claimedYear =
              _readInt(
            userData['birthdayGiftClaimedYear'],
          );

          if (claimedYear == giftYear) {
            throw Exception(
              'Энэ жилийн төрсөн өдрийн бэлгийг аль хэдийн авсан байна.',
            );
          }

          final now = DateTime.now();

          final newExpiresAt =
              _calculateNewExpiration(
            userData: userData,
            entitlementType: 'vip',
            days: 7,
            now: now,
          );

          final remainingDays =
              _calculateRemainingDays(
            newExpiresAt,
            now,
          );

          transaction.update(
            userRef,
            {
              'vipExpiresAt':
                  Timestamp.fromDate(
                newExpiresAt,
              ),
              'vipDays': remainingDays,
              'birthdayGiftClaimedYear':
                  giftYear,
            },
          );

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
        '🎂 Төрсөн өдрийн бэлэг батлагдлаа. VIP +7 хоног нэмэгдлээ.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Төрсөн өдрийн хүсэлт батлах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  Future<void> _rejectBirthdayRequest(
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
        'birthday:$requestId';

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
              .collection('birthdayGiftRequests')
              .doc(requestId);

          final requestSnapshot =
              await transaction.get(requestRef);

          if (!requestSnapshot.exists) {
            throw Exception(
              'Төрсөн өдрийн хүсэлт олдсонгүй.',
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
        'Төрсөн өдрийн хүсэлтийг татгалзлаа.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Төрсөн өдрийн хүсэлт татгалзах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  Future<void> _searchUserBySixDigitId() async {
    final id = _userSearchController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(id)) {
      _showMessage('6 оронтой ID зөв оруулна уу.');
      return;
    }

    setState(() {
      _searchingUser = true;
      _selectedUserUid = null;
      _selectedUserData = null;
    });

    try {
      final idSnapshot = await _firestore
          .collection('sixDigitIds')
          .doc(id)
          .get();

      if (!idSnapshot.exists) {
        throw Exception('Ийм ID-тай хэрэглэгч олдсонгүй.');
      }

      final uid =
          (idSnapshot.data()?['uid'] ?? '').toString();

      if (uid.isEmpty) {
        throw Exception('Хэрэглэгчийн UID олдсонгүй.');
      }

      final userSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!userSnapshot.exists) {
        throw Exception('Хэрэглэгчийн мэдээлэл олдсонгүй.');
      }

      if (!mounted) return;

      setState(() {
        _selectedUserUid = uid;
        _selectedUserData =
            userSnapshot.data() ?? <String, dynamic>{};
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Хэрэглэгч хайх үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _searchingUser = false;
        });
      }
    }
  }

  Future<void> _refreshSelectedUser() async {
    final uid = _selectedUserUid;

    if (uid == null || uid.isEmpty) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .get();

    if (!mounted || !snapshot.exists) return;

    setState(() {
      _selectedUserData =
          snapshot.data() ?? <String, dynamic>{};
    });
  }

  int _remainingDaysForUser(
    Map<String, dynamic> data,
    String type,
  ) {
    final now = DateTime.now();
    final field =
        type == 'vip' ? 'vipExpiresAt' : 'vvipExpiresAt';
    final legacy =
        type == 'vip' ? 'vipDays' : 'vvipDays';

    final value = data[field];

    if (value is Timestamp) {
      return _calculateRemainingDays(
        value.toDate(),
        now,
      );
    }

    return _readInt(data[legacy]);
  }

  Future<void> _changeEntitlementDays({
    required String type,
    required bool add,
  }) async {
    final uid = _selectedUserUid;
    final userData = _selectedUserData;

    if (uid == null || userData == null) {
      _showMessage('Эхлээд хэрэглэгчээ хайна уу.');
      return;
    }

    final controller = TextEditingController(text: '1');
    final label = type == 'vip' ? 'VIP' : 'VVIP';

    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            add
                ? '$label хоног нэмэх'
                : '$label хоног хасах',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Хоног',
              hintText: 'Жишээ: 7',
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
                final value =
                    int.tryParse(controller.text.trim());

                if (value == null || value <= 0) {
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: Text(
                add ? 'Нэмэх' : 'Хасах',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (amount == null) return;

    final processingKey =
        'user:$uid:$type:${add ? 'add' : 'remove'}';

    if (_processingRequestKey != null) return;

    setState(() {
      _processingRequestKey = processingKey;
    });

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final userRef =
              _firestore.collection('users').doc(uid);

          final snapshot =
              await transaction.get(userRef);

          if (!snapshot.exists) {
            throw Exception('Хэрэглэгч олдсонгүй.');
          }

          final data =
              snapshot.data() ?? <String, dynamic>{};

          final now = DateTime.now();
          final expiresField =
              type == 'vip'
                  ? 'vipExpiresAt'
                  : 'vvipExpiresAt';
          final daysField =
              type == 'vip' ? 'vipDays' : 'vvipDays';

          DateTime newExpiresAt;

          if (add) {
            newExpiresAt =
                _calculateNewExpiration(
              userData: data,
              entitlementType: type,
              days: amount,
              now: now,
            );
          } else {
            DateTime currentExpiresAt = now;

            final existing = data[expiresField];

            if (existing is Timestamp &&
                existing.toDate().isAfter(now)) {
              currentExpiresAt = existing.toDate();
            } else {
              final legacyDays =
                  _readInt(data[daysField]);

              if (legacyDays > 0) {
                currentExpiresAt = now.add(
                  Duration(days: legacyDays),
                );
              }
            }

            newExpiresAt = currentExpiresAt.subtract(
              Duration(days: amount),
            );

            if (!newExpiresAt.isAfter(now)) {
              newExpiresAt = now;
            }
          }

          final remainingDays =
              _calculateRemainingDays(
            newExpiresAt,
            now,
          );

          transaction.update(
            userRef,
            {
              expiresField:
                  Timestamp.fromDate(newExpiresAt),
              daysField: remainingDays,
            },
          );
        },
      );

      await _refreshSelectedUser();

      if (!mounted) return;

      _showMessage(
        add
            ? '$label +$amount хоног нэмэгдлээ.'
            : '$label -$amount хоног хасагдлаа.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        '$label хоног өөрчлөх үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  Future<void> _editSelectedUserBirthDate() async {
    final uid = _selectedUserUid;
    final data = _selectedUserData;

    if (uid == null || data == null) {
      _showMessage('Эхлээд хэрэглэгчээ хайна уу.');
      return;
    }

    final value = data['birthDate'];
    final currentBirthDate =
        value is Timestamp
            ? value.toDate()
            : DateTime(2000, 1, 1);

    final selected = await showDatePicker(
      context: context,
      initialDate: currentBirthDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    final processingKey = 'user:$uid:birthDate';

    if (_processingRequestKey != null) return;

    setState(() {
      _processingRequestKey = processingKey;
    });

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({
        'birthDate': Timestamp.fromDate(
          DateTime(
            selected.year,
            selected.month,
            selected.day,
          ),
        ),
      });

      await _refreshSelectedUser();

      if (!mounted) return;

      _showMessage('Төрсөн өдөр шинэчлэгдлээ.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Төрсөн өдөр засах үед алдаа гарлаа: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingRequestKey = null;
        });
      }
    }
  }

  String _formatBirthDate(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${date.year}.'
        '${twoDigits(date.month)}.'
        '${twoDigits(date.day)}';
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

          return Column(
            children: [
              Material(
                color: AppColors.background,
                child: TabBar(
                  controller: _adminTabController,
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor:
                      AppColors.textMuted,
                  onTap: (index) {
                    setState(() {
                      _adminTabIndex = index;
                    });
                  },
                  tabs: const [
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
                    Tab(
                      icon: Icon(
                        Icons.cake_outlined,
                      ),
                      text: 'Төрсөн өдөр',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.manage_accounts_outlined,
                      ),
                      text: 'Хэрэглэгч',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _adminTabIndex,
                  children: [
                    _buildPaymentRequests(),
                    _buildXpRequests(),
                    _buildBirthdayRequests(),
                    _buildUserManagement(),
                  ],
                ),
              ),
            ],
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
                'XP → VIP хүсэлт энд харагдана.',
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

  // ---------------------------------------------------------------------
  // Хэрэглэгч tab.
  //
  // Layout history:
  // 1. Originally the content was a ListView whose only item was a
  //    Center wrapping a Column. A ListView item gets an UNBOUNDED
  //    height, and Column defaults to MainAxisSize.max (fill available
  //    height), so it tried to fill infinite height -> layout exception
  //    -> tab rendered empty. No compile/analyze error, purely runtime.
  // 2. That was fixed by mirroring the other tabs' structure: a bounded
  //    Center wrapping a ConstrainedBox wrapping the ListView. That
  //    removed the height crash, but on Flutter Web this combination
  //    can still end up passing a genuinely UNBOUNDED WIDTH down into
  //    the ListView's internal Viewport/slivers, depending on exactly
  //    how the ambient constraints from IndexedStack/Expanded resolve.
  //    That is exactly what "BoxConstraints forces an infinite width"
  //    plus the resulting sliver/box assertion cascade means.
  //
  // Fix: stop relying on ConstrainedBox+Center to infer a bounded width
  // from ambient constraints. Use LayoutBuilder to read the real
  // incoming constraints, compute an explicit finite pixel width
  // ourselves (falling back to the screen width if the incoming
  // constraint is unbounded), and hand that finite width to the subtree
  // via a SizedBox before anything else (Row, Expanded, TextField,
  // buttons, PremiumCard) gets built. Everything below this point is
  // then guaranteed to receive a finite width, no matter what the
  // ancestor chain does.
  // ---------------------------------------------------------------------
  Widget _buildUserManagement() {
    final data = _selectedUserData;
    final uid = _selectedUserUid;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final double screenWidth = MediaQuery.of(context).size.width;

        // Never trust an ambient max width blindly: fall back to the
        // screen width if it's unbounded, then clamp to the app's
        // preferred content width.
        final double availableWidth = outerConstraints.hasBoundedWidth
            ? outerConstraints.maxWidth
            : screenWidth;

        final double contentWidth =
            availableWidth < AppLayout.profileMaxWidth
                ? availableWidth
                : AppLayout.profileMaxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  'Хэрэглэгч удирдах',
                  style: AppTypography.pageTitle(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '6 оронтой ID-аар хэрэглэгч хайна.',
                  style: AppTypography.body(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userSearchController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onSubmitted: (_) {
                          if (!_searchingUser) {
                            _searchUserBySixDigitId();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: '6 оронтой ID',
                          hintText: 'Жишээ: 123456',
                          counterText: '',
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  // Explicit width AND height: as a non-flex Row child
                  // this must never be asked to report an intrinsic
                  // width under an unbounded main-axis layout pass.
                  width: 120,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _searchingUser
                        ? null
                        : _searchUserBySixDigitId,
                    icon: _searchingUser
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.search_rounded,
                          ),
                    label: const Text('Хайх'),
                  ),
                ),
              ],
            ),
            if (data == null || uid == null) ...[
              const SizedBox(height: AppSpacing.xxl),
              PremiumCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.manage_search_rounded,
                      size: 44,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Хэрэглэгчийн 6 оронтой ID-г оруулаад хайна уу.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(),
                    ),
                  ],
                ),
              ),
            ],
            if (data != null && uid != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              PremiumCard(
                elevated: true,
                radius: AppRadius.premium,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle_rounded,
                          size: 48,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(
                          width: AppSpacing.md,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                (data['username'] ?? '-')
                                    .toString(),
                                style:
                                    AppTypography.cardTitle(),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${(data['sixDigitId'] ?? _userSearchController.text.trim())}',
                                style: AppTypography.meta(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Divider(
                        height: 1,
                        color: AppColors.border,
                      ),
                    ),
                    _AdminInfoRow(
                      label: 'Gmail',
                      value:
                          (data['email'] ?? '-').toString(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AdminInfoRow(
                      label: 'Утас',
                      value: (data['phoneNumber'] ?? '-')
                          .toString(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AdminInfoRow(
                      label: 'Төрсөн өдөр',
                      value: _formatBirthDate(
                        data['birthDate'],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AdminInfoRow(
                      label: 'XP',
                      value: '${_readInt(data['xp'])} XP',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AdminInfoRow(
                      label: 'VIP үлдэгдэл',
                      value:
                          '${_remainingDaysForUser(data, 'vip')} хоног',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AdminInfoRow(
                      label: 'VVIP үлдэгдэл',
                      value:
                          '${_remainingDaysForUser(data, 'vvip')} хоног',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VIP эрх',
                      style: AppTypography.cardTitle(
                        color: AppColors.vipAccent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _processingRequestKey != null
                                    ? null
                                    : () =>
                                        _changeEntitlementDays(
                                          type: 'vip',
                                          add: false,
                                        ),
                            icon: const Icon(
                              Icons.remove_rounded,
                            ),
                            label: const Text('Хоног хасах'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _processingRequestKey != null
                                    ? null
                                    : () =>
                                        _changeEntitlementDays(
                                          type: 'vip',
                                          add: true,
                                        ),
                            icon: const Icon(
                              Icons.add_rounded,
                            ),
                            label: const Text('Хоног нэмэх'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VVIP эрх',
                      style: AppTypography.cardTitle(
                        color: AppColors.vvipAccent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _processingRequestKey != null
                                    ? null
                                    : () =>
                                        _changeEntitlementDays(
                                          type: 'vvip',
                                          add: false,
                                        ),
                            icon: const Icon(
                              Icons.remove_rounded,
                            ),
                            label: const Text('Хоног хасах'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _processingRequestKey != null
                                    ? null
                                    : () =>
                                        _changeEntitlementDays(
                                          type: 'vvip',
                                          add: true,
                                        ),
                            icon: const Icon(
                              Icons.add_rounded,
                            ),
                            label: const Text('Хоног нэмэх'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _processingRequestKey != null
                      ? null
                      : _editSelectedUserBirthDate,
                  icon: const Icon(Icons.cake_outlined),
                  label: const Text('Төрсөн өдөр засах'),
                ),
              ),
            ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBirthdayRequests() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('birthdayGiftRequests')
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(
            'Төрсөн өдрийн хүсэлт унших үед алдаа гарлаа:\n'
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
            icon: Icons.cake_outlined,
            title:
                'Хүлээгдэж буй төрсөн өдрийн хүсэлт алга',
            description:
                'VIP +7 хоногийн төрсөн өдрийн хүсэлт энд харагдана.',
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
                  'Төрсөн өдрийн хүсэлтүүд',
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
                        _buildBirthdayCard(
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

  Widget _buildBirthdayCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        document,
  ) {
    final data = document.data();

    final sixDigitId =
        (data['sixDigitId'] ?? '-')
            .toString();

    final days =
        _readInt(data['days']);

    final year =
        _readInt(data['year']);

    final createdAt =
        data['createdAt'] as Timestamp?;

    final processing =
        _processingRequestKey ==
        'birthday:${document.id}';

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
                  color: AppColors.gold.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: AppColors.gold,
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
                      'Төрсөн өдрийн бэлэг',
                      style:
                          AppTypography.cardTitle(
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      'VIP +$days хоног',
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
            label: 'Хэрэглэгчийн ID',
            value: sixDigitId,
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _AdminInfoRow(
            label: 'Бэлгийн эрх',
            value: 'VIP +$days хоног',
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          _AdminInfoRow(
            label: 'Он',
            value: '$year',
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
                          _rejectBirthdayRequest(
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
                          _approveBirthdayRequest(
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
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final days = _readInt(data['days']);
    final xpCost = _readInt(data['xpCost']);
    final sixDigitId =
        (data['sixDigitId'] ?? '-').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final processing =
        _processingRequestKey == 'xp:${document.id}';

    return PremiumCard(
      elevated: true,
      radius: AppRadius.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.vipAccent.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.vipAccent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VIP • Өөртөө',
                      style: AppTypography.cardTitle(
                        color: AppColors.vipAccent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$xpCost XP → $days VIP хоног',
                      style: AppTypography.meta(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
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
          const SizedBox(height: AppSpacing.sm),
          _AdminInfoRow(
            label: 'Зарцуулах XP',
            value: '-$xpCost XP',
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdminInfoRow(
            label: 'Нэмэгдэх эрх',
            value: 'VIP +$days хоног',
          ),
          if (createdAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _AdminInfoRow(
              label: 'Хүсэлт илгээсэн',
              value: _formatDate(createdAt.toDate()),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: processing ||
                          _processingRequestKey != null
                      ? null
                      : () => _rejectXpRequest(document.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(
                      color: AppColors.danger,
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Татгалзах'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: processing ||
                          _processingRequestKey != null
                      ? null
                      : () => _approveXpRequest(document.id),
                  icon: processing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    processing ? '...' : 'Батлах',
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