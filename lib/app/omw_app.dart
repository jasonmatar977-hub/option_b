part of '../main.dart';

class OptionBApp extends StatefulWidget {
  const OptionBApp({super.key});

  @override
  State<OptionBApp> createState() => _OptionBAppState();
}

class _OptionBAppState extends State<OptionBApp> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  DemoRole? _selectedRole;
  List<DemoRole>? _availableRoles;
  String? _phoneNumber;
  PhoneVerificationSession? _verificationSession;
  bool _isVerified = false;
  bool _showSplash = true;
  bool _restoringSession = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (FirebaseService.instance.isReady) {
      _authService.keepSessionPersistent();
      final user = _authService.currentUser;
      if (user != null) {
        _phoneNumber = user.phoneNumber;
        _isVerified = true;
        _restoreFirebaseSession(user);
      }
      _authSubscription = _authService.authStateChanges().listen((user) {
        if (!mounted) {
          return;
        }
        if (user == null) {
          setState(() {
            _selectedRole = null;
            _availableRoles = null;
            _phoneNumber = null;
            _verificationSession = null;
            _isVerified = false;
          });
          return;
        }
        _restoreFirebaseSession(user);
      });
    }
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  Future<void> _restoreFirebaseSession(User user) async {
    if (!FirebaseService.instance.isReady) {
      return;
    }
    setState(() {
      _restoringSession = true;
      _phoneNumber ??= user.phoneNumber;
      _isVerified = true;
    });
    try {
      final savedUser = await _userService.getUser(user.uid);
      if (!mounted) {
        return;
      }
      final roles = savedUser?.roles.map(demoRoleForBackend).toList();
      setState(() {
        _phoneNumber = savedUser?.phoneNumber.isNotEmpty == true
            ? savedUser!.phoneNumber
            : user.phoneNumber ?? _phoneNumber;
        if (roles != null && roles.isNotEmpty) {
          _availableRoles = roles;
          _selectedRole = roles.length == 1
              ? roles.first
              : _selectedRole != null && roles.contains(_selectedRole)
              ? _selectedRole
              : null;
        }
        _isVerified = true;
      });
      await _userService.updateLastLogin(user.uid);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phoneNumber ??= user.phoneNumber;
        _isVerified = true;
      });
    } finally {
      if (mounted) {
        setState(() => _restoringSession = false);
      }
    }
  }

  void _selectRole(DemoRole role) {
    final signedInUser = _authService.currentUser;
    setState(() {
      _selectedRole = role;
      _availableRoles = null;
      _phoneNumber = signedInUser?.phoneNumber;
      _verificationSession = null;
      _isVerified = FirebaseService.instance.isReady && signedInUser != null;
    });
    if (FirebaseService.instance.isReady && signedInUser != null) {
      _persistSignedInUser(signedInUser, role);
    }
  }

  void _sendCode(LoginVerificationRequest request) {
    setState(() {
      _phoneNumber = request.phoneNumber;
      _verificationSession = request.session;
      _isVerified = false;
    });
    if (FirebaseService.instance.isReady &&
        !request.session.isDemo &&
        request.session.verificationId.isEmpty &&
        _authService.currentUser != null) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final role = _selectedRole;
    final user = _authService.currentUser;
    if (FirebaseService.instance.isReady && role != null && user != null) {
      await _persistSignedInUser(user, role);
    }
    setState(() => _isVerified = true);
  }

  Future<void> _persistSignedInUser(User user, DemoRole role) async {
    final now = DateTime.now();
    final existing = await _userService.getUser(user.uid);
    final roles = {...?existing?.roles, backendRoleFor(role)}.toList();
    final verifiedWithWhatsApp =
        _verificationSession?.channel == AuthOtpChannel.whatsApp;
    await _userService.createOrUpdateUser(
      backend.AppUser(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? _phoneNumber ?? '',
        displayName: user.displayName ?? existing?.displayName ?? '',
        email: user.email ?? existing?.email,
        roles: roles,
        activeRole: backendRoleFor(role),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastLoginAt: now,
        isActive: true,
        whatsappNumber: verifiedWithWhatsApp
            ? (_phoneNumber ?? user.phoneNumber ?? '')
            : existing?.whatsappNumber ?? '',
        whatsappVerified:
            verifiedWithWhatsApp || (existing?.whatsappVerified ?? false),
        whatsappVerifiedAt: verifiedWithWhatsApp
            ? now
            : existing?.whatsappVerifiedAt,
        authProvider: verifiedWithWhatsApp
            ? 'whatsapp_otp_test'
            : existing?.authProvider ?? 'firebase_phone',
      ),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {
      _selectedRole = null;
      _availableRoles = null;
      _phoneNumber = null;
      _verificationSession = null;
      _isVerified = false;
      _restoringSession = false;
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = _selectedRole;
    final availableRoles = _availableRoles;
    final phone = _phoneNumber;
    Widget home;
    if (_showSplash || _restoringSession) {
      home = const BrandedSplashScreen();
    } else if (availableRoles != null &&
        availableRoles.length > 1 &&
        role == null) {
      home = RoleSelectionScreen(
        roles: availableRoles,
        title: 'Continue as',
        subtitle: 'Choose which On My Way role to use now.',
        onRoleSelected: _selectRole,
      );
    } else if (role == null) {
      home = RoleSelectionScreen(onRoleSelected: _selectRole);
    } else if (phone == null) {
      home = PhoneLoginScreen(role: role, onCodeSent: _sendCode);
    } else if (!_isVerified) {
      home = OtpVerificationScreen(
        role: role,
        phoneNumber: phone,
        session: _verificationSession,
        onVerified: _verify,
      );
    } else if (role == DemoRole.admin) {
      home = AdminDashboardScreen(onSignOut: _signOut);
    } else if (role == DemoRole.customer) {
      home = CustomerHomeScreen(userPhone: phone, onSignOut: _signOut);
    } else if (role == DemoRole.storeOwner) {
      home = StoreOwnerDashboardScreen(userPhone: phone, onSignOut: _signOut);
    } else if (role == DemoRole.driver &&
        FirebaseService.instance.isReady &&
        _authService.currentUser != null) {
      home = _FirebaseWorkerGate(
        userId: _authService.currentUser!.uid,
        phoneNumber: phone,
        onChanged: () => setState(() {}),
        onSignOut: _signOut,
      );
    } else if (demoWorkerProfile.status != WorkerApplicationStatus.approved) {
      home = WorkerOnboardingScreen(
        phoneNumber: phone,
        onChanged: () => setState(() {}),
        onSignOut: _signOut,
      );
    } else {
      home = DriverHomeScreen(userPhone: phone, onSignOut: _signOut);
    }

    return MaterialApp(
      title: kBrandName,
      debugShowCheckedModeBanner: false,
      theme: _buildOwmTheme(),
      home: home,
    );
  }
}
