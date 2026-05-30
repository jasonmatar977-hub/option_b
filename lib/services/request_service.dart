import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart' as backend;
import '../models/service_request.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'worker_service.dart';

class RequestAcceptException implements Exception {
  const RequestAcceptException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RequestService {
  RequestService({
    FirebaseService? firebaseService,
    WorkerService? workerService,
    NotificationService? notificationService,
  }) : _firebaseService = firebaseService ?? FirebaseService.instance,
       _workerService = workerService ?? WorkerService(),
       _notificationService = notificationService ?? NotificationService();

  final FirebaseService _firebaseService;
  final WorkerService _workerService;
  final NotificationService _notificationService;

  static const collectionName = 'serviceRequests';

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firebaseService.firestore.collection(collectionName);

  Future<String?> createRequest(ServiceRequest request) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    final now = DateTime.now();
    final ref = request.id.trim().isEmpty
        ? _requests.doc()
        : _requests.doc(request.id);
    final payload = request
        .copyWith(id: ref.id, createdAt: now, updatedAt: now)
        .toMap();
    payload['id'] = ref.id;
    await ref.set(payload);
    await _notificationService.create(
      type: 'customer_request_created',
      title: 'New OMW request',
      message:
          '${request.customerName.isEmpty ? 'Customer' : request.customerName} requested ${request.serviceType}.',
      userId: request.customerId,
      roleTarget: 'customer',
      relatedId: ref.id,
      relatedCollection: collectionName,
      data: {'requestId': ref.id, 'serviceType': request.serviceType},
    );
    await _notificationService.create(
      type: 'matching_worker_request_available',
      title: 'New request available',
      message:
          'A new ${request.serviceType} request is waiting for approved online workers.',
      roleTarget: 'worker',
      relatedId: ref.id,
      relatedCollection: collectionName,
      data: {'requestId': ref.id, 'serviceType': request.serviceType},
    );
    await _notificationService.create(
      type: 'owner_customer_request_created',
      title: 'New customer request',
      message: 'A new ${request.serviceType} request was created.',
      roleTarget: 'owner',
      relatedId: ref.id,
      relatedCollection: collectionName,
      data: {'requestId': ref.id, 'serviceType': request.serviceType},
    );
    return ref.id;
  }

  Stream<List<ServiceRequest>> watchCustomerRequests(String customerId) {
    if (!_firebaseService.isReady) {
      return const Stream.empty();
    }
    return _requests
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Stream<List<ServiceRequest>> watchOwnerRequests() {
    if (!_firebaseService.isReady) {
      return const Stream.empty();
    }
    return _requests
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Stream<List<ServiceRequest>> watchWorkerAvailableRequests(String workerId) {
    if (!_firebaseService.isReady) {
      return const Stream.empty();
    }
    return _workerService.watchWorkerProfile(workerId).asyncExpand((profile) {
      if (!_workerCanReceive(profile)) {
        return Stream.value(const <ServiceRequest>[]);
      }
      final serviceTypes = profile!.serviceTypes.toSet();
      return _requests
          .where(
            'status',
            isEqualTo: ServiceRequestStatus.requested.firestoreValue,
          )
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => _requestsFromSnapshot(snapshot).where((request) {
              return request.isOpen &&
                  serviceTypes.contains(request.serviceType) &&
                  !request.rejectedWorkerIds.contains(workerId);
            }).toList(),
          );
    });
  }

  Stream<List<ServiceRequest>> watchWorkerAssignedRequests(String workerId) {
    if (!_firebaseService.isReady) {
      return const Stream.empty();
    }
    return _requests
        .where('assignedWorkerId', isEqualTo: workerId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(_requestsFromSnapshot);
  }

  Future<void> acceptRequest({
    required String requestId,
    required String workerId,
    required String workerName,
    required String workerPhone,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final requestRef = _requests.doc(requestId);
    await _firebaseService.firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw const RequestAcceptException(
          'This request is no longer available.',
        );
      }
      final request = ServiceRequest.fromMap(
        requestSnapshot.id,
        requestSnapshot.data() ?? const <String, Object?>{},
      );
      if (request.status != ServiceRequestStatus.requested ||
          request.assignedWorkerId?.trim().isNotEmpty == true) {
        throw const RequestAcceptException(
          'Another worker already accepted this request.',
        );
      }

      final workerRef = _firebaseService.firestore
          .collection(WorkerService.workersCollection)
          .doc(workerId);
      final workerSnapshot = await transaction.get(workerRef);
      if (!workerSnapshot.exists) {
        throw const RequestAcceptException('Complete worker onboarding first.');
      }
      final profile = backend.WorkerProfile.fromMap(
        workerSnapshot.id,
        workerSnapshot.data() ?? const <String, Object?>{},
      );
      final documents = await _workerService.getWorkerDocuments(workerId);
      if (profile.status != backend.WorkerStatus.approved ||
          !profile.isOnline ||
          !profile.serviceTypes.contains(request.serviceType) ||
          !profile.canGoOnline(documents)) {
        throw const RequestAcceptException(
          'Please complete approval and go online before accepting this request.',
        );
      }

      transaction.update(requestRef, {
        'status': ServiceRequestStatus.accepted.firestoreValue,
        'assignedWorkerId': workerId,
        'assignedWorkerName': workerName,
        'assignedWorkerPhone': workerPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _notificationService.create(
      type: 'worker_request_accepted',
      title: 'Request accepted',
      message: '$workerName accepted an OMW request.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: requestId,
      relatedCollection: collectionName,
      data: {'requestId': requestId},
    );
    final acceptedSnapshot = await requestRef.get();
    final acceptedRequest = ServiceRequest.fromMap(
      acceptedSnapshot.id,
      acceptedSnapshot.data() ?? const <String, Object?>{},
    );
    await _notificationService.create(
      type: 'customer_request_accepted',
      title: 'Your request was accepted',
      message:
          '$workerName accepted your ${acceptedRequest.serviceType} request.',
      userId: acceptedRequest.customerId,
      roleTarget: 'customer',
      relatedId: requestId,
      relatedCollection: collectionName,
      data: {'requestId': requestId, 'workerId': workerId},
    );
  }

  Future<void> rejectRequest({
    required String requestId,
    required String workerId,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _requests.doc(requestId).update({
      'rejectedWorkerIds': FieldValue.arrayUnion([workerId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _notificationService.create(
      type: 'worker_request_rejected',
      title: 'Request skipped',
      message: 'A worker skipped an available OMW request.',
      userId: workerId,
      workerId: workerId,
      roleTarget: 'worker',
      relatedId: requestId,
      relatedCollection: collectionName,
      data: {'requestId': requestId},
    );
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required ServiceRequestStatus status,
    String? workerId,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final payload = <String, Object?>{
      'status': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == ServiceRequestStatus.completed) {
      payload['completedAt'] = FieldValue.serverTimestamp();
    }
    if (status == ServiceRequestStatus.canceled) {
      payload['canceledAt'] = FieldValue.serverTimestamp();
    }
    await _requests.doc(requestId).update(payload);
    final requestSnapshot = await _requests.doc(requestId).get();
    final request = ServiceRequest.fromMap(
      requestSnapshot.id,
      requestSnapshot.data() ?? const <String, Object?>{},
    );
    await _notificationService.create(
      type: status == ServiceRequestStatus.completed
          ? 'request_completed'
          : status == ServiceRequestStatus.canceled
          ? 'request_canceled'
          : 'worker_request_status_updated',
      title: 'Request updated',
      message: 'OMW request status changed to ${status.firestoreValue}.',
      userId: request.customerId,
      workerId: workerId,
      roleTarget: 'customer',
      relatedId: requestId,
      relatedCollection: collectionName,
      data: {'requestId': requestId, 'status': status.firestoreValue},
    );
    if (status == ServiceRequestStatus.canceled) {
      await _notificationService.create(
        type: 'worker_request_canceled',
        title: 'Request canceled',
        message: 'A customer canceled an OMW request.',
        userId: request.assignedWorkerId,
        roleTarget: 'worker',
        relatedId: requestId,
        relatedCollection: collectionName,
        data: {'requestId': requestId, 'status': status.firestoreValue},
      );
    }
  }

  Future<void> cancelRequest(String requestId, {String? customerId}) {
    return updateRequestStatus(
      requestId: requestId,
      status: ServiceRequestStatus.canceled,
      workerId: customerId,
    );
  }

  List<ServiceRequest> _requestsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => ServiceRequest.fromMap(doc.id, doc.data()))
        .toList();
  }

  bool _workerCanReceive(backend.WorkerProfile? profile) {
    return profile != null &&
        profile.status == backend.WorkerStatus.approved &&
        profile.isOnline &&
        profile.serviceTypes.isNotEmpty;
  }
}
