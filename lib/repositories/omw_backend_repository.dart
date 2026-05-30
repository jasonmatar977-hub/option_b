import '../config/app_config.dart';
import '../services/firebase_service.dart';

enum BackendMode { localFallback, firebase }

class OmwBackendRepository {
  OmwBackendRepository({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  BackendMode get mode => AppConfig.useFirebase && _firebaseService.isReady
      ? BackendMode.firebase
      : BackendMode.localFallback;

  bool get usesFirebase => mode == BackendMode.firebase;
  bool get usesLocalFallback => mode == BackendMode.localFallback;
}
