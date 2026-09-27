import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _webVapidKey =
      String.fromEnvironment('FCM_VAPID_KEY');

  StreamSubscription<String>? _tokenRefreshSubscription;

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(user.uid);
  }

  Future<bool> isEnabled() async {
    final ref = _userRef;

    if (ref == null) {
      return false;
    }

    final snapshot = await ref.get();
    final data = snapshot.data();

    return data?['notificationsEnabled'] == true;
  }

  Future<bool> enableNotifications() async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final allowed =
        settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus ==
            AuthorizationStatus.provisional;

    if (!allowed) {
      await _setEnabled(false);
      return false;
    }

    if (kIsWeb && _webVapidKey.isEmpty) {
      throw StateError(
        'FCM_VAPID_KEY тохируулаагүй байна.',
      );
    }

    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? _webVapidKey : null,
    );

    if (token == null || token.isEmpty) {
      throw StateError(
        'FCM token авч чадсангүй.',
      );
    }

    await _saveToken(
      uid: user.uid,
      token: token,
    );

    await _setEnabled(true);

    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen(
      (newToken) async {
        final currentUser = _auth.currentUser;

        if (currentUser == null ||
            newToken.isEmpty) {
          return;
        }

        try {
          final enabled = await isEnabled();

          if (!enabled) {
            return;
          }

          await _saveToken(
            uid: currentUser.uid,
            token: newToken,
          );
        } catch (error) {
          debugPrint(
            'FCM token refresh хадгалах алдаа: $error',
          );
        }
      },
    );

    return true;
  }

  Future<void> disableNotifications() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    String? token;

    try {
      token = await _messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );
    } catch (error) {
      debugPrint(
        'FCM token унших үед алдаа: $error',
      );
    }

    final updates = <String, dynamic>{
      'notificationsEnabled': false,
    };

    if (token != null && token.isNotEmpty) {
      updates['fcmTokens'] =
          FieldValue.arrayRemove([token]);
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(updates);

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  Future<void> _setEnabled(bool value) async {
    final ref = _userRef;

    if (ref == null) {
      return;
    }

    await ref.update({
      'notificationsEnabled': value,
    });
  }

  Future<void> _saveToken({
    required String uid,
    required String token,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }
}
