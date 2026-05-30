import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart';
import 'firebase_service.dart';

class ChatService {
  ChatService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  static const jobsCollection = 'jobChats';
  static const messagesCollection = 'messages';

  Future<String?> sendMessage(ChatMessage message) async {
    if (!_firebaseService.isReady) {
      return null;
    }
    final collection = _firebaseService.firestore
        .collection(jobsCollection)
        .doc(message.jobId)
        .collection(messagesCollection);
    final ref = message.id.isEmpty
        ? collection.doc()
        : collection.doc(message.id);
    await ref.set(message.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  Stream<List<ChatMessage>> watchJobMessages(String jobId) {
    if (!_firebaseService.isReady) {
      return const Stream<List<ChatMessage>>.empty();
    }
    return _firebaseService.firestore
        .collection(jobsCollection)
        .doc(jobId)
        .collection(messagesCollection)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> markRead({
    required String jobId,
    required String messageId,
  }) async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.firestore
        .collection(jobsCollection)
        .doc(jobId)
        .collection(messagesCollection)
        .doc(messageId)
        .set({'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
