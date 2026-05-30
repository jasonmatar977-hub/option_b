import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Placeholder until `flutterfire configure` writes real project options.
///
/// Keeping this file in source lets the Firebase foundation compile before
/// project credentials exist. FirebaseService catches this and stays in demo
/// mode when OPTION_B_USE_FIREBASE is false or configuration is incomplete.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured for ${defaultTargetPlatform.name}. '
      'Run flutterfire configure to generate lib/firebase_options.dart.',
    );
  }
}
