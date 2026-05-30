import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart';
import 'firebase_service.dart';

class UserService {
  UserService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  static const collectionName = 'users';

  Future<void> createOrUpdateUser(AppUser user) => upsertUser(user);

  Future<void> upsertUser(AppUser user) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(collectionName)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String uid) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    final snapshot = await _firebaseService.firestore
        .collection(collectionName)
        .doc(uid)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return AppUser.fromMap(snapshot.id, data);
  }

  Stream<AppUser?> watchUser(String uid) {
    if (!_firebaseService.isReady) {
      return const Stream<AppUser?>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            return null;
          }
          return AppUser.fromMap(snapshot.id, data);
        });
  }

  Future<void> updateRole(String uid, AppRole role) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore.collection(collectionName).doc(uid).set({
      'role': role.name,
      'activeRole': role.name,
      'roles': FieldValue.arrayUnion([role.name]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateLastLogin(String uid) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore.collection(collectionName).doc(uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
