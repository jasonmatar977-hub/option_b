import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/backend_models.dart';
import 'firebase_service.dart';
import 'worker_service.dart';

class StorageService {
  StorageService({
    FirebaseService? firebaseService,
    WorkerService? workerService,
  }) : _firebaseService = firebaseService ?? FirebaseService.instance,
       _workerService = workerService ?? WorkerService();

  final FirebaseService _firebaseService;
  final WorkerService _workerService;

  Future<WorkerDocument?> uploadWorkerDocument({
    required String workerId,
    required WorkerDocumentType type,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'application/octet-stream',
    String extension = 'bin',
  }) {
    return uploadWorkerDocumentBytes(
      workerId: workerId,
      documentType: type.name,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      extension: extension,
    );
  }

  Future<WorkerDocument?> uploadWorkerDocumentBytes({
    required String workerId,
    required String documentType,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'application/octet-stream',
    String extension = 'bin',
  }) async {
    if (!_firebaseService.isReady) {
      return null;
    }

    final safeDocumentType = documentType
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safeFileName = fileName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'workers/$workerId/documents/${safeDocumentType.isEmpty ? 'document' : safeDocumentType}/${timestamp}_${safeFileName.isEmpty ? 'document.$extension' : safeFileName}';

    final ref = _firebaseService.storage.ref(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final downloadUrl = await ref.getDownloadURL();

    final document = WorkerDocument(
      id: WorkerDocumentType.fromValue(documentType).name,
      workerId: workerId,
      type: WorkerDocumentType.fromValue(documentType),
      storagePath: storagePath,
      fileUrl: downloadUrl,
      fileName: fileName,
      status: WorkerDocumentStatus.pendingReview,
      mimeType: contentType,
      fileSize: bytes.length,
      uploadedAt: DateTime.now(),
    );
    await _workerService.addWorkerDocument(document);
    return document;
  }

  Future<String?> getDownloadUrl(String storagePath) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    return _firebaseService.storage.ref(storagePath).getDownloadURL();
  }

  Future<String?> getDocumentUrl(String storagePath) =>
      getDownloadUrl(storagePath);

  Future<void> deleteDocument(String storagePath) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.storage.ref(storagePath).delete();
  }
}
