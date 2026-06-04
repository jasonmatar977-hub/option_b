import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'firebase_service.dart';

enum AuthOtpChannel { demo, sms, whatsApp }

class PhoneVerificationSession {
  const PhoneVerificationSession({
    required this.verificationId,
    this.resendToken,
    required this.message,
    required this.isDemo,
    this.channel = AuthOtpChannel.sms,
    this.phoneNumber = '',
  });

  final String verificationId;
  final int? resendToken;
  final String message;
  final bool isDemo;
  final AuthOtpChannel channel;
  final String phoneNumber;
}

class AuthService {
  AuthService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService.instance;

  final FirebaseService _firebaseService;

  FirebaseFunctions get _functions => FirebaseFunctions.instance;

  Stream<User?> authStateChanges() {
    if (!_firebaseService.isReady) {
      return const Stream<User?>.empty();
    }
    return _firebaseService.auth.authStateChanges();
  }

  Future<void> keepSessionPersistent() async {
    if (!_firebaseService.isReady) {
      return;
    }
    try {
      await _firebaseService.auth.setPersistence(Persistence.LOCAL);
    } on UnimplementedError {
      // Native Firebase Auth already persists sessions by default.
    } on UnsupportedError {
      // Native Firebase Auth already persists sessions by default.
    }
  }

  User? get currentUser {
    if (!_firebaseService.isReady) {
      return null;
    }
    return _firebaseService.auth.currentUser;
  }

  Future<PhoneVerificationSession> startPhoneVerification(
    String phoneNumber, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!_firebaseService.isReady) {
      return const PhoneVerificationSession(
        verificationId: 'demo',
        message: 'Demo code sent: 1234',
        isDemo: true,
        channel: AuthOtpChannel.demo,
      );
    }

    final completer = Completer<PhoneVerificationSession>();
    await _firebaseService.auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        try {
          await _firebaseService.auth.signInWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(
              PhoneVerificationSession(
                verificationId: '',
                message: 'Phone verified automatically.',
                isDemo: false,
                channel: AuthOtpChannel.sms,
                phoneNumber: phoneNumber,
              ),
            );
          }
        } on FirebaseAuthException catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerificationSession(
              verificationId: verificationId,
              resendToken: resendToken,
              message: 'Verification code sent.',
              isDemo: false,
              channel: AuthOtpChannel.sms,
              phoneNumber: phoneNumber,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerificationSession(
              verificationId: verificationId,
              message: 'Verification code sent.',
              isDemo: false,
              channel: AuthOtpChannel.sms,
              phoneNumber: phoneNumber,
            ),
          );
        }
      },
      timeout: timeout,
    );
    return completer.future;
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) {
    if (!_firebaseService.isReady) {
      throw StateError('Firebase Auth is not ready. Demo OTP should be used.');
    }
    return _firebaseService.auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: timeout,
    );
  }

  PhoneAuthCredential credentialFromCode({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    if (!_firebaseService.isReady) {
      throw StateError('Firebase Auth is not ready. Demo OTP should be used.');
    }
    return _firebaseService.auth.signInWithCredential(credential);
  }

  Future<UserCredential?> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) {
    if (!_firebaseService.isReady) {
      return Future<UserCredential?>.value(null);
    }
    return signInWithCredential(
      credentialFromCode(verificationId: verificationId, smsCode: smsCode),
    );
  }

  Future<PhoneVerificationSession> requestWhatsAppOtp({
    required String phoneNumber,
    required String role,
  }) async {
    if (!_firebaseService.isReady || !AppConfig.useWhatsAppOtp) {
      return const PhoneVerificationSession(
        verificationId: 'demo',
        message: 'Demo code sent: 1234',
        isDemo: true,
        channel: AuthOtpChannel.demo,
      );
    }
    final callable = _functions.httpsCallable('sendWhatsAppOtp');
    final result = await callable.call<Map<String, dynamic>>({
      'phoneNumber': phoneNumber,
      'role': role,
    });
    final data = Map<String, dynamic>.from(result.data);
    return PhoneVerificationSession(
      verificationId: data['sessionId'] as String? ?? phoneNumber,
      message: data['message'] as String? ?? 'WhatsApp verification code sent.',
      isDemo: false,
      channel: AuthOtpChannel.whatsApp,
      phoneNumber: phoneNumber,
    );
  }

  Future<UserCredential?> verifyWhatsAppOtp({
    required String phoneNumber,
    required String code,
    required String role,
  }) async {
    if (!_firebaseService.isReady || !AppConfig.useWhatsAppOtp) {
      return null;
    }
    final callable = _functions.httpsCallable('verifyWhatsAppOtp');
    final result = await callable.call<Map<String, dynamic>>({
      'phoneNumber': phoneNumber,
      'otpCode': code,
      'role': role,
    });
    final data = Map<String, dynamic>.from(result.data);
    final customToken = data['customToken'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-custom-token',
        message: 'WhatsApp OTP backend did not return a custom token.',
      );
    }
    return signInWithCustomToken(customToken);
  }

  Future<UserCredential> signInWithCustomToken(String customToken) async {
    if (!_firebaseService.isReady) {
      throw StateError('Firebase Auth is not ready.');
    }
    return _firebaseService.auth.signInWithCustomToken(customToken);
  }

  // ---------------------------------------------------------------------------
  // Email / password authentication (MVP primary login method)
  // ---------------------------------------------------------------------------

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (kDebugMode) {
      debugPrint('Email sign-up started');
    }
    if (!_firebaseService.isReady) {
      final error = FirebaseAuthException(
        code: 'operation-not-allowed',
        message:
            'Firebase is not available. '
            'Run with --dart-define=OMW_USE_FIREBASE=true.',
      );
      debugPrint('Email sign-up failed: ${error.code} ${error.message}');
      throw error;
    }
    try {
      await _firebaseService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        debugPrint('Email sign-up success');
      }
    } on FirebaseAuthException catch (error) {
      debugPrint('Email sign-up failed: ${error.code} ${error.message}');
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    if (!_firebaseService.isReady) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message:
            'Firebase is not available. '
            'Run with --dart-define=OMW_USE_FIREBASE=true.',
      );
    }
    await _firebaseService.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Send a verification email to the currently signed-in user.
  ///
  /// Throws [FirebaseAuthException] on failure so callers can surface the
  /// real error to the user instead of silently dropping it.
  ///
  /// On web builds an [ActionCodeSettings] is included so Firebase redirects
  /// the user back to the deployed app after clicking the verification link.
  /// The redirect domain MUST be listed in Firebase Console →
  /// Authentication → Settings → Authorized domains:
  ///   • localhost
  ///   • jasonmatar977-hub.github.io
  Future<void> sendEmailVerification() async {
    debugPrint('Verification email sending started');
    if (!_firebaseService.isReady) {
      final error = FirebaseAuthException(
        code: 'operation-not-allowed',
        message:
            'Firebase is not available. '
            'Run with --dart-define=OMW_USE_FIREBASE=true.',
      );
      debugPrint('Verification email failed: ${error.code} ${error.message}');
      throw error;
    }
    final user = _firebaseService.auth.currentUser;
    if (user == null) {
      final error = FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user is available for email verification.',
      );
      debugPrint('Verification email failed: ${error.code} ${error.message}');
      throw error;
    }
    if (kDebugMode) {
      debugPrint('[OMW Auth] sendEmailVerification: dispatching…');
    }
    // On web include a continue-URL so the email link redirects back to the
    // correct app page after Firebase verifies the address.
    // handleCodeInApp:false keeps standard email-verification behaviour —
    // NOT passwordless / email-link sign-in.
    final settings = kIsWeb
        ? ActionCodeSettings(
            url: 'https://jasonmatar977-hub.github.io/option_b/',
            handleCodeInApp: false,
          )
        : null;
    try {
      await user.sendEmailVerification(settings);
      debugPrint('Verification email sent');
      if (kDebugMode) {
        debugPrint('[OMW Auth] sendEmailVerification: dispatched OK.');
      }
    } on FirebaseAuthException catch (error) {
      debugPrint('Verification email failed: ${error.code} ${error.message}');
      rethrow;
    }
  }

  /// Send a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    if (kDebugMode) {
      debugPrint(
        '[OMW Auth] sendPasswordResetEmail: starting… '
        'firebaseReady=${_firebaseService.isReady}',
      );
    }
    if (!_firebaseService.isReady) {
      final error = FirebaseAuthException(
        code: 'firebase-not-ready',
        message: 'Firebase is not initialized for password reset.',
      );
      if (kDebugMode) {
        debugPrint(
          '[OMW Auth] sendPasswordResetEmail aborted: ${error.code} — ${error.message}',
        );
      }
      throw error;
    }
    if (kDebugMode) {
      try {
        final projectId = _firebaseService.auth.app.options.projectId;
        debugPrint('[OMW Auth] sendPasswordResetEmail: projectId=$projectId');
      } catch (_) {
        debugPrint('[OMW Auth] sendPasswordResetEmail: projectId unavailable');
      }
    }
    try {
      await _firebaseService.auth.sendPasswordResetEmail(email: email);
      if (kDebugMode) {
        debugPrint('[OMW Auth] sendPasswordResetEmail: sent OK.');
      }
    } on FirebaseAuthException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[OMW Auth] sendPasswordResetEmail FirebaseAuthException: '
          'code=${error.code} message=${error.message}',
        );
      }
      rethrow;
    }
  }

  /// Force-reload the current user's Firebase profile so that
  /// [User.emailVerified] reflects the latest server state.
  Future<void> reloadUser() async {
    if (!_firebaseService.isReady) return;
    debugPrint('[OMW Auth] reloadUser: reloading…');
    await _firebaseService.auth.currentUser?.reload();
    debugPrint(
      '[OMW Auth] reloadUser: emailVerified=${_firebaseService.auth.currentUser?.emailVerified}',
    );
  }

  Future<void> signOut() async {
    if (!_firebaseService.isReady) {
      return;
    }
    await _firebaseService.auth.signOut();
  }
}
