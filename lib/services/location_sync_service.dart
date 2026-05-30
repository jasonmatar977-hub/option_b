import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart';
import 'firebase_service.dart';

class LocationSyncService {
  LocationSyncService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  static const collectionName = 'driverLocations';

  Future<void> updateDriverLocation(DriverLocation location) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(collectionName)
        .doc(location.workerId)
        .set({
          ...location.toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> setWorkerOnline({
    required String workerId,
    required String workerName,
    required String workerPhone,
    required double lat,
    required double lng,
    double heading = 0,
    double speed = 0,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(collectionName)
        .doc(workerId)
        .set(<String, Object?>{
          'workerName': workerName,
          'workerPhone': workerPhone,
          'lat': lat,
          'lng': lng,
          'heading': heading,
          'speed': speed,
          'isOnline': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> setWorkerOffline(String workerId) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(collectionName)
        .doc(workerId)
        .set({
          'isOnline': false,
          'activeJobId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<DriverLocation?> watchDriverLocation(String workerId) {
    if (!_firebaseService.isReady) {
      return const Stream<DriverLocation?>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .doc(workerId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            return null;
          }
          return DriverLocation.fromFirestore(snapshot);
        });
  }

  Stream<List<DriverLocation>> watchOnlineDrivers() {
    if (!_firebaseService.isReady) {
      return const Stream<List<DriverLocation>>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DriverLocation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<DriverLocation>> watchOnlineDriversForOwner() =>
      watchOnlineDrivers();

  Stream<List<DriverLocation>> watchApprovedOnlineWorkers() =>
      watchOnlineDrivers();

  Future<void> bindLocationToActiveJob({
    required String workerId,
    required String jobId,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(collectionName)
        .doc(workerId)
        .set({
          'activeJobId': jobId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> clearActiveJob(String workerId) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(collectionName)
        .doc(workerId)
        .set({
          'activeJobId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> stopLocationSync(String workerId) => setWorkerOffline(workerId);
}
