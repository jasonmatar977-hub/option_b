import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.userId,
    this.roleTarget,
    this.relatedId,
    this.relatedCollection,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String? userId;
  final String? roleTarget;
  final String? relatedId;
  final String? relatedCollection;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromMap(String id, Map<String, Object?> data) {
    return AppNotification(
      id: id,
      type: data['type'] as String? ?? 'general',
      title: data['title'] as String? ?? 'OMW update',
      message: data['message'] as String? ?? '',
      userId: data['userId'] as String? ?? data['workerId'] as String?,
      roleTarget: data['roleTarget'] as String?,
      relatedId: data['relatedId'] as String?,
      relatedCollection: data['relatedCollection'] as String?,
      isRead: data['isRead'] as bool? ?? data['read'] as bool? ?? false,
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
    );
  }
}

class NotificationService {
  NotificationService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  static const collectionName = 'notifications';

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firebaseService.firestore.collection(collectionName);

  Future<void> create({
    required String type,
    required String title,
    required String message,
    String? userId,
    String? workerId,
    String? roleTarget,
    String? relatedId,
    String? relatedCollection,
    Map<String, Object?> data = const {},
  }) async {
    await createNotification(
      type: type,
      title: title,
      message: message,
      userId: userId ?? workerId,
      workerId: workerId,
      roleTarget: roleTarget,
      relatedId: relatedId,
      relatedCollection: relatedCollection,
      data: data,
    );
  }

  Future<void> createNotification({
    required String type,
    required String title,
    required String message,
    String? userId,
    String? workerId,
    String? roleTarget,
    String? relatedId,
    String? relatedCollection,
    Map<String, Object?> data = const {},
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final doc = _notifications.doc();
    await doc.set({
      'id': doc.id,
      'type': type,
      'title': title,
      'message': message,
      'userId': userId ?? workerId,
      'workerId': workerId,
      'roleTarget': roleTarget,
      'relatedId': relatedId,
      'relatedCollection': relatedCollection,
      'data': data,
      'isRead': false,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createRoleNotification({
    required String roleTarget,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedCollection,
    Map<String, Object?> data = const {},
  }) {
    return createNotification(
      roleTarget: roleTarget,
      type: type,
      title: title,
      message: message,
      relatedId: relatedId,
      relatedCollection: relatedCollection,
      data: data,
    );
  }

  Stream<List<AppNotification>> watchDashboardNotifications({
    String? userId,
    String? roleTarget,
    int limit = 5,
  }) {
    if (!_firebaseService.isReady) {
      return Stream.value(const <AppNotification>[]);
    }
    final uid = userId?.trim() ?? '';
    final role = roleTarget?.trim() ?? '';
    if (uid.isEmpty && role.isEmpty) {
      return Stream.value(const <AppNotification>[]);
    }

    late final StreamController<List<AppNotification>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? userSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roleSubscription;
    var userNotifications = const <AppNotification>[];
    var roleNotifications = const <AppNotification>[];

    void emit() {
      final byId = <String, AppNotification>{};
      for (final notification in [...userNotifications, ...roleNotifications]) {
        byId[notification.id] = notification;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged.take(limit).toList());
    }

    controller = StreamController<List<AppNotification>>.broadcast(
      onListen: () {
        if (uid.isNotEmpty) {
          userSubscription = _notifications
              .where('userId', isEqualTo: uid)
              .limit(30)
              .snapshots()
              .listen((snapshot) {
                userNotifications = snapshot.docs
                    .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
                    .toList();
                emit();
              }, onError: controller.addError);
        }
        if (role.isNotEmpty) {
          roleSubscription = _notifications
              .where('roleTarget', isEqualTo: role)
              .limit(30)
              .snapshots()
              .listen((snapshot) {
                roleNotifications = snapshot.docs
                    .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
                    .toList();
                emit();
              }, onError: controller.addError);
        }
      },
      onCancel: () async {
        await userSubscription?.cancel();
        await roleSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<AppNotification>> watchUserNotifications(
    String userId, {
    String? roleTarget,
    int limit = 5,
  }) {
    return watchDashboardNotifications(
      userId: userId,
      roleTarget: roleTarget,
      limit: limit,
    );
  }

  Stream<List<AppNotification>> watchRoleNotifications(
    String roleTarget, {
    int limit = 5,
  }) {
    return watchDashboardNotifications(roleTarget: roleTarget, limit: limit);
  }

  Future<void> markAsRead(String notificationId) async {
    if (!_firebaseService.isReady || notificationId.trim().isEmpty) {
      return;
    }
    await _notifications.doc(notificationId).set({
      'isRead': true,
      'read': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllAsRead({String? userId, String? roleTarget}) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final uid = userId?.trim() ?? '';
    final role = roleTarget?.trim() ?? '';
    if (uid.isEmpty && role.isEmpty) {
      return;
    }
    final snapshots = <QuerySnapshot<Map<String, dynamic>>>[];
    if (uid.isNotEmpty) {
      snapshots.add(
        await _notifications.where('userId', isEqualTo: uid).limit(80).get(),
      );
    }
    if (role.isNotEmpty) {
      snapshots.add(
        await _notifications
            .where('roleTarget', isEqualTo: role)
            .limit(80)
            .get(),
      );
    }
    final batch = _firebaseService.firestore.batch();
    var writes = 0;
    final seen = <String>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        if (!seen.add(doc.id)) continue;
        final notification = AppNotification.fromMap(doc.id, doc.data());
        if (!notification.isRead) {
          batch.set(doc.reference, {
            'isRead': true,
            'read': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          writes++;
        }
      }
    }
    if (writes > 0) {
      await batch.commit();
    }
  }
}

DateTime? _dateFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
