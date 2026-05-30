import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class WorkerService {
  WorkerService({
    FirebaseService? firebaseService,
    NotificationService? notificationService,
  }) : _firebaseService = firebaseService ?? FirebaseService.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseService _firebaseService;
  final NotificationService _notificationService;

  static const workersCollection = 'workers';
  static const documentsCollection = 'workerDocuments';

  Future<String?> createWorkerApplication(WorkerProfile profile) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    final collection = _firebaseService.firestore.collection(workersCollection);
    final ref = profile.id.isEmpty
        ? collection.doc()
        : collection.doc(profile.id);
    await ref.set(profile.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> updateWorkerProfile(WorkerProfile profile) =>
      upsertWorkerProfile(profile);

  Future<void> upsertWorkerProfile(WorkerProfile profile) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(profile.id.isEmpty ? profile.userId : profile.id)
        .set(profile.toMap(), SetOptions(merge: true));
    await _notificationService.create(
      type: 'worker_onboarding_started',
      title: 'Worker onboarding updated',
      message:
          '${profile.fullName.isEmpty ? 'A worker' : profile.fullName} updated onboarding.',
      userId: profile.userId,
      workerId: profile.userId,
      roleTarget: 'worker',
      relatedId: profile.userId,
      relatedCollection: workersCollection,
    );
  }

  Future<void> updateWorkerDocumentStatus({
    required String documentId,
    required WorkerDocumentStatus status,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(documentsCollection)
        .doc(documentId)
        .set({
          'status': status.firestoreValue,
          'reviewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> reviewWorkerDocument({
    required String workerId,
    required WorkerDocumentType type,
    required WorkerDocumentStatus status,
    String? rejectionReason,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .collection('documents')
        .doc(type.name)
        .set({
          'status': status.firestoreValue,
          'reviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': rejectionReason,
        }, SetOptions(merge: true));
    await _refreshDocumentsStatus(workerId);
  }

  Future<void> submitApplication(String workerId) async {
    await _updateWorkerStatus(
      workerId,
      WorkerStatus.pending,
      timestampField: 'submittedAt',
      extra: const {'isOnline': false},
    );
    await _notificationService.create(
      type: 'worker_onboarding_submitted',
      title: 'Worker submitted onboarding',
      message: 'A worker application is ready for owner review.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: workerId,
      relatedCollection: workersCollection,
    );
    await _notificationService.create(
      type: 'owner_worker_waiting_approval',
      title: 'Worker waiting approval',
      message: 'A worker application is ready for owner review.',
      roleTarget: 'owner',
      relatedId: workerId,
      relatedCollection: workersCollection,
    );
  }

  Future<void> approveWorker(String workerId, {String? adminId}) async {
    await _updateWorkerStatus(
      workerId,
      WorkerStatus.approved,
      timestampField: 'approvedAt',
      extra: {
        'approvedByAdminId': adminId,
        'isOnline': false,
        'rejectionReason': null,
      },
    );
    await _notificationService.create(
      type: 'worker_approved',
      title: 'Worker approved',
      message: 'Your OMW worker account was approved.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: workerId,
      relatedCollection: workersCollection,
    );
  }

  Future<void> rejectWorker(String workerId, {String? rejectionReason}) async {
    await _updateWorkerStatus(
      workerId,
      WorkerStatus.rejected,
      timestampField: 'rejectedAt',
      extra: {'isOnline': false, 'rejectionReason': rejectionReason},
    );
    await _notificationService.create(
      type: 'worker_rejected',
      title: 'Worker rejected',
      message: rejectionReason?.isNotEmpty == true
          ? rejectionReason!
          : 'Your OMW worker application was rejected.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: workerId,
      relatedCollection: workersCollection,
    );
  }

  Future<void> suspendWorker(String workerId) async {
    await _updateWorkerStatus(
      workerId,
      WorkerStatus.suspended,
      timestampField: 'suspendedAt',
      extra: const {'isOnline': false},
    );
    await _notificationService.create(
      type: 'worker_suspended',
      title: 'Worker suspended',
      message: 'Your OMW worker account was suspended.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: workerId,
      relatedCollection: workersCollection,
    );
  }

  Future<void> setWorkerOnline(
    String workerId, {
    double? lat,
    double? lng,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final profile = await getWorkerProfile(workerId);
    final documents = await getWorkerDocuments(workerId);
    if (profile?.canGoOnline(documents) != true) {
      throw StateError(
        'Please complete onboarding and wait for owner approval before going online.',
      );
    }
    final updates = <String, Object?>{'isOnline': true};
    if (lat != null) {
      updates['currentLat'] = lat;
    }
    if (lng != null) {
      updates['currentLng'] = lng;
    }
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .set({
          ...updates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> setWorkerOffline(String workerId) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .set({
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _updateWorkerStatus(
    String workerId,
    WorkerStatus status, {
    required String timestampField,
    Map<String, Object?> extra = const {},
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .set({
          'status': status.name,
          'workerStatus': status.firestoreValue,
          timestampField: FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          ...extra,
        }, SetOptions(merge: true));
  }

  Stream<WorkerProfile?> watchWorkerProfile(String userId) {
    if (!_firebaseService.isReady) {
      return const Stream<WorkerProfile?>.empty();
    }
    return _firebaseService.firestore
        .collection(workersCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) {
            return null;
          }
          return WorkerProfile.fromMap(snapshot.id, data);
        });
  }

  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    final snapshot = await _firebaseService.firestore
        .collection(workersCollection)
        .doc(userId)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return WorkerProfile.fromMap(snapshot.id, data);
  }

  Stream<List<WorkerProfile>> watchApprovedWorkers() {
    if (!_firebaseService.isReady) {
      return const Stream<List<WorkerProfile>>.empty();
    }
    return _firebaseService.firestore
        .collection(workersCollection)
        .where('status', isEqualTo: WorkerStatus.approved.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerProfile.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<WorkerProfile>> watchWorkers() {
    if (!_firebaseService.isReady) {
      return const Stream<List<WorkerProfile>>.empty();
    }
    return _firebaseService.firestore
        .collection(workersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_workersFromSnapshot);
  }

  Stream<List<WorkerProfile>> watchPendingWorkers() {
    if (!_firebaseService.isReady) {
      return const Stream<List<WorkerProfile>>.empty();
    }
    return _firebaseService.firestore
        .collection(workersCollection)
        .where('status', isEqualTo: WorkerStatus.pending.name)
        .snapshots()
        .map(_workersFromSnapshot);
  }

  Stream<List<WorkerProfile>> watchOnlineWorkers() {
    if (!_firebaseService.isReady) {
      return const Stream<List<WorkerProfile>>.empty();
    }
    return _firebaseService.firestore
        .collection(workersCollection)
        .where('status', isEqualTo: WorkerStatus.approved.name)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map(_workersFromSnapshot);
  }

  Future<void> addWorkerDocument(WorkerDocument document) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final data = document.toMap();
    final workerDocRef = _firebaseService.firestore
        .collection(workersCollection)
        .doc(document.workerId)
        .collection('documents')
        .doc(document.type.name);
    await workerDocRef.set(data, SetOptions(merge: true));
    await _firebaseService.firestore
        .collection(documentsCollection)
        .doc('${document.workerId}_${document.type.name}')
        .set({'id': workerDocRef.id, ...data}, SetOptions(merge: true));
    await _refreshDocumentsStatus(document.workerId);
    await _notificationService.create(
      type: 'worker_document_uploaded',
      title: 'Worker uploaded document',
      message: '${document.type.name} uploaded for review.',
      userId: document.workerId,
      workerId: document.workerId,
      roleTarget: 'worker',
      relatedId: '${document.workerId}_${document.type.name}',
      relatedCollection: documentsCollection,
      data: {'documentType': document.type.name},
    );
    await _notificationService.create(
      type: 'owner_worker_document_uploaded',
      title: 'Worker document uploaded',
      message: '${document.type.name} uploaded for review.',
      roleTarget: 'owner',
      relatedId: '${document.workerId}_${document.type.name}',
      relatedCollection: documentsCollection,
      data: {'workerId': document.workerId, 'documentType': document.type.name},
    );
  }

  Future<void> acceptAgreement({
    required String workerId,
    required String agreementVersion,
  }) async {
    if (!_firebaseService.isReady) return;
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .set({
          'agreementAccepted': true,
          'agreementAcceptedAt': FieldValue.serverTimestamp(),
          'agreementVersion': agreementVersion,
          'platformCommissionRate': 0.15,
          'workerPayoutRate': 0.85,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    await _firebaseService.firestore
        .collection('workerAgreements')
        .doc(workerId)
        .set({
          'workerId': workerId,
          'agreementAccepted': true,
          'agreementAcceptedAt': FieldValue.serverTimestamp(),
          'agreementVersion': agreementVersion,
          'platformCommissionRate': 0.15,
          'workerPayoutRate': 0.85,
        }, SetOptions(merge: true));
    await _notificationService.create(
      type: 'worker_agreement_accepted',
      title: 'Worker accepted agreement',
      message: 'Worker accepted the OMW agreement.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: workerId,
      relatedCollection: 'workerAgreements',
    );
  }

  Future<void> updatePayoutMethod({
    required String workerId,
    required String payoutMethod,
    String payoutDetails = '',
    String payoutPhone = '',
    String bankDetails = '',
  }) async {
    if (!_firebaseService.isReady) return;
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .set({
          'payoutMethod': payoutMethod,
          'payoutDetails': payoutDetails,
          'payoutNotes': payoutDetails,
          'payoutPhone': payoutPhone,
          'payoutPhoneNumber': payoutPhone,
          'bankDetails': bankDetails,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _refreshDocumentsStatus(String workerId) async {
    final documents = await getWorkerDocuments(workerId);
    final status = documentsStatusFor(documents);
    await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .set({
          'documentsStatus': status.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<List<WorkerDocument>> watchWorkerDocuments(String workerId) {
    if (!_firebaseService.isReady) {
      return const Stream<List<WorkerDocument>>.empty();
    }
    return _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .collection('documents')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerDocument.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<WorkerDocument>> getWorkerDocuments(String workerId) async {
    if (!_firebaseService.isReady) {
      return const [];
    }
    final snapshot = await _firebaseService.firestore
        .collection(workersCollection)
        .doc(workerId)
        .collection('documents')
        .get();
    return snapshot.docs
        .map((doc) => WorkerDocument.fromMap(doc.id, doc.data()))
        .toList();
  }

  List<WorkerProfile> _workersFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => WorkerProfile.fromMap(doc.id, doc.data()))
        .toList();
  }
}
