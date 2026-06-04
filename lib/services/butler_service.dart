import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart';
import 'firebase_service.dart';

class ButlerService {
  ButlerService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;
  static const _collection = 'butlerRequests';

  Future<String> createRequest(ButlerRequest request) async {
    final doc = _firebaseService.firestore.collection(_collection).doc();
    final data = request.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await doc.set(data);
    return doc.id;
  }

  Stream<List<ButlerRequest>> watchCustomerRequests(String customerId) {
    if (!_firebaseService.isReady) return const Stream.empty();
    return _firebaseService.firestore
        .collection(_collection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(ButlerRequest.fromFirestore).toList());
  }

  Stream<List<ButlerRequest>> watchPendingRequests() {
    if (!_firebaseService.isReady) return const Stream.empty();
    return _firebaseService.firestore
        .collection(_collection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(ButlerRequest.fromFirestore).toList());
  }

  Stream<List<ButlerRequest>> watchWorkerAssignedRequests(String workerId) {
    if (!_firebaseService.isReady) return const Stream.empty();
    return _firebaseService.firestore
        .collection(_collection)
        .where('assignedWorkerId', isEqualTo: workerId)
        .where('status', whereIn: ['assigned', 'pickedUp', 'onTheWay'])
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.map(ButlerRequest.fromFirestore).toList());
  }

  Stream<List<ButlerRequest>> watchAllRequests() {
    if (!_firebaseService.isReady) return const Stream.empty();
    return _firebaseService.firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(ButlerRequest.fromFirestore).toList());
  }

  Future<void> claimRequest(
    String requestId, {
    required String workerId,
    required String workerName,
  }) {
    return _firebaseService.firestore
        .collection(_collection)
        .doc(requestId)
        .update({
          'status': 'assigned',
          'assignedWorkerId': workerId,
          'assignedWorkerName': workerName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updateStatus(String requestId, ButlerRequestStatus status) {
    return _firebaseService.firestore
        .collection(_collection)
        .doc(requestId)
        .update({
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> cancelRequest(String requestId) {
    return _firebaseService.firestore
        .collection(_collection)
        .doc(requestId)
        .update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}
