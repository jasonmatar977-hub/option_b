import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/backend_models.dart';
import 'firebase_service.dart';

class JobService {
  JobService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  static const collectionName = 'jobs';

  Future<String?> createJobOffer(JobOffer offer) => createJob(offer);

  Future<String?> createJob(JobOffer offer) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    final collection = _firebaseService.firestore.collection(collectionName);
    final ref = offer.id.isEmpty ? collection.doc() : collection.doc(offer.id);
    await ref.set({
      ...offer.toFirestore(),
      'createdAt': offer.createdAt == DateTime.fromMillisecondsSinceEpoch(0)
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(offer.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Stream<List<JobOffer>> watchNearbyJobs({
    double? lat,
    double? lng,
    double? workerLat,
    double? workerLng,
    double radiusMiles = 50,
    double? radiusKm,
  }) {
    final effectiveLat = workerLat ?? lat;
    final effectiveLng = workerLng ?? lng;
    if (effectiveLat == null || effectiveLng == null) {
      return const Stream<List<JobOffer>>.empty();
    }
    return watchNearbyPendingJobs(
      lat: effectiveLat,
      lng: effectiveLng,
      radiusKm: radiusKm ?? radiusMiles * 1.60934,
    );
  }

  Stream<JobOffer?> watchJob(String jobId) {
    if (!_firebaseService.isReady) {
      return const Stream<JobOffer?>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .doc(jobId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }
          return JobOffer.fromFirestore(snapshot);
        });
  }

  Stream<List<JobOffer>> watchCustomerJobs(String customerId) {
    if (!_firebaseService.isReady) {
      return const Stream<List<JobOffer>>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(_jobsFromSnapshot);
  }

  Stream<List<JobOffer>> watchWorkerJobs(String workerId) {
    if (!_firebaseService.isReady) {
      return const Stream<List<JobOffer>>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .where('assignedWorkerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(_jobsFromSnapshot);
  }

  Stream<List<JobOffer>> watchOwnerJobs() => watchJobs();

  Future<void> acceptJob({
    required String jobId,
    required String workerId,
    required String workerName,
    String? workerPhone,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final ref = _firebaseService.firestore
        .collection(collectionName)
        .doc(jobId);
    await _firebaseService.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('This offer is no longer available.');
      }
      final job = JobOffer.fromMap(snapshot.id, data);
      if (job.status != JobStatus.pending) {
        throw StateError('This offer was already accepted.');
      }
      transaction.set(ref, {
        'status': JobStatus.accepted.name,
        'assignedWorkerId': workerId,
        'assignedWorkerName': workerName,
        'assignedWorkerPhone': workerPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> rejectJob(String jobId, {required String workerId}) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore.collection(collectionName).doc(jobId).set({
      'status': JobStatus.rejected.name,
      'assignedWorkerId': workerId,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelJob(String jobId) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore.collection(collectionName).doc(jobId).set({
      'status': JobStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> completeJob(String jobId) async {
    if (!_firebaseService.isReady) {
      return;
    }
    final ref = _firebaseService.firestore
        .collection(collectionName)
        .doc(jobId);
    await _firebaseService.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        return;
      }
      final offer = JobOffer.fromMap(snapshot.id, data);
      final gross = offer.offerAmount;
      final commission = AppConfig.platformCommissionFor(gross);
      final payout = AppConfig.workerPayoutFor(gross);
      transaction.set(ref, {
        'status': JobStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'gross': gross,
        'platformCommission': commission,
        'workerPayout': payout,
        'ownerNet': commission,
        'paymentStatus': 'manual',
        'workerPayoutStatus': 'unpaid',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateWorkerPayoutStatus({
    required String jobId,
    required String status,
    String? note,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore.collection(collectionName).doc(jobId).set({
      'workerPayoutStatus': status,
      'payoutNote': note,
      if (status == 'paid') 'workerPaidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateJobStatus({
    required String jobId,
    required Object status,
    String? assignedWorkerId,
    String? assignedWorkerName,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }

    final parsedStatus = status is JobStatus
        ? status
        : JobStatus.fromValue(status.toString());
    final updates = <String, Object?>{
      'status': parsedStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (assignedWorkerId != null) {
      updates['assignedWorkerId'] = assignedWorkerId;
    }
    if (assignedWorkerName != null) {
      updates['assignedWorkerName'] = assignedWorkerName;
    }
    if (parsedStatus == JobStatus.accepted) {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    if (parsedStatus == JobStatus.active) {
      updates['startedAt'] = FieldValue.serverTimestamp();
    }
    if (parsedStatus == JobStatus.completed) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    if (parsedStatus == JobStatus.cancelled) {
      updates['cancelledAt'] = FieldValue.serverTimestamp();
    }
    if (parsedStatus == JobStatus.rejected) {
      updates['rejectedAt'] = FieldValue.serverTimestamp();
    }

    await _firebaseService.firestore
        .collection(collectionName)
        .doc(jobId)
        .set(updates, SetOptions(merge: true));
  }

  Stream<List<JobOffer>> watchPendingJobs() {
    if (!_firebaseService.isReady) {
      return const Stream<List<JobOffer>>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .where('status', isEqualTo: JobStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(_jobsFromSnapshot);
  }

  Stream<List<JobOffer>> watchNearbyPendingJobs({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) {
    if (!_firebaseService.isReady) {
      return const Stream<List<JobOffer>>.empty();
    }
    return watchPendingJobs().map(
      (jobs) => jobs.where((job) {
        final distance = _distanceKm(lat, lng, job.pickupLat, job.pickupLng);
        return distance <= radiusKm;
      }).toList(),
    );
  }

  Stream<List<JobOffer>> watchJobs() {
    if (!_firebaseService.isReady) {
      return const Stream<List<JobOffer>>.empty();
    }
    return _firebaseService.firestore
        .collection(collectionName)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(_jobsFromSnapshot);
  }

  Stream<OwnerStats> watchOwnerStats() {
    if (!_firebaseService.isReady) {
      return const Stream<OwnerStats>.empty();
    }
    return watchJobs().map((jobs) => OwnerStats.fromJobs(jobs));
  }

  List<JobOffer> _jobsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => JobOffer.fromMap(doc.id, doc.data()))
        .toList();
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    final a =
        _sinSquared(dLat / 2) +
        _cos(_degreesToRadians(lat1)) *
            _cos(_degreesToRadians(lat2)) *
            _sinSquared(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double value) => value * 3.141592653589793 / 180;
  double _sinSquared(double value) => math.sin(value) * math.sin(value);
  double _cos(double value) => math.cos(value);
}
