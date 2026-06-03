import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  Object? _failure;

  bool get isReady => _initialized && _failure == null;
  bool get isDemoMode => !isReady;
  Object? get failure => _failure;
  bool get useFirebase => AppConfig.useFirebase;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;

  Future<void> initialize() async {
    if (!AppConfig.useFirebase) {
      debugPrint(
        'Firebase not configured. Running in local fallback mode. '
        'Pass --dart-define=OMW_USE_FIREBASE=true to enable Firebase. '
        'Legacy OPTION_B_USE_FIREBASE is still supported temporarily.',
      );
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _initialized = true;
      _failure = null;
      debugPrint('On My Way Firebase initialized. Using backend services.');

      // TODO(security): Enable Firebase App Check before public launch.
      // Steps:
      //   1. Firebase Console → App Check → Register app
      //   2. For web: choose reCAPTCHA Enterprise (preferred) or reCAPTCHA v3
      //   3. Add the site key to AppConfig (via --dart-define=OMW_RECAPTCHA_SITE_KEY=...)
      //   4. Add firebase_app_check: ^0.x.x to pubspec.yaml
      //   5. Call FirebaseAppCheck.instance.activate(...) here after initializeApp
      //   6. Enforce App Check in Firebase Console for Firestore, Storage, Functions
      //   See docs/SECURITY_CHECKLIST.md for full steps.
    } catch (error, stackTrace) {
      _initialized = false;
      _failure = error;
      debugPrint(
        'Firebase not configured. Running in local fallback mode. Error: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
