part of '../../main.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({
    super.key,
    required this.onRoleSelected,
    this.roles = DemoRole.values,
    this.title = 'Welcome to On My Way',
    this.subtitle = '24/24 ride, moto, and courier requests.',
  });

  final ValueChanged<DemoRole> onRoleSelected;
  final List<DemoRole> roles;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandBlack,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MotionLinesPainter())),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Center(child: OwmBrandMark(size: 82)),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kMutedText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...roles.map(
                      (role) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RoleCard(
                          icon: _roleIcon(role),
                          title: _roleTitle(role),
                          subtitle: _roleSubtitle(role),
                          onTap: () => onRoleSelected(role),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Local test mode - no real SMS or backend',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kMutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _roleIcon(DemoRole role) {
    return switch (role) {
      DemoRole.customer => Icons.near_me_outlined,
      DemoRole.driver => Icons.work_outline,
      DemoRole.storeOwner => Icons.storefront_outlined,
      DemoRole.admin => Icons.admin_panel_settings_outlined,
    };
  }

  static String _roleTitle(DemoRole role) {
    return switch (role) {
      DemoRole.customer => 'Continue as Customer',
      DemoRole.driver => 'Continue as Worker',
      DemoRole.storeOwner => 'Continue as Store Owner',
      DemoRole.admin => 'Continue as Owner/Admin',
    };
  }

  static String _roleSubtitle(DemoRole role) {
    return switch (role) {
      DemoRole.customer =>
        'Request rides, moto service, courier, and market orders',
      DemoRole.driver => 'Go online and accept OMW requests',
      DemoRole.storeOwner => 'Manage store profile, products, and orders',
      DemoRole.admin => 'Open the OMW Control Center',
    };
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBrandSurfaceAlt,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kAccentYellow.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: kAccentYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.black, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kMutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kAccentYellow),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.role,
    required this.onCodeSent,
  });

  final DemoRole role;
  final ValueChanged<LoginVerificationRequest> onCodeSent;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _error;
  bool _sending = false;
  bool _useSmsFallback = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Phone number is required');
      return;
    }
    final useFirebase = FirebaseService.instance.isReady;
    final useWhatsApp =
        useFirebase && AppConfig.useWhatsAppOtp && !_useSmsFallback;
    if (useFirebase && !phone.startsWith('+')) {
      setState(
        () => _error = 'Please include your country code, for example +961...',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final session = useWhatsApp
          ? await _requestWhatsAppOrSms(phone)
          : useFirebase
          ? await _authService.startPhoneVerification(phone)
          : const PhoneVerificationSession(
              verificationId: 'demo',
              message: 'Demo code sent: 1234',
              isDemo: true,
              channel: AuthOtpChannel.demo,
            );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(session.message)));
      widget.onCodeSent(
        LoginVerificationRequest(phoneNumber: phone, session: session),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyFunctionsError(error));
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyAuthError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(
        () => _error =
            'We could not send the verification code. Check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<PhoneVerificationSession> _requestWhatsAppOrSms(String phone) {
    return _authService.requestWhatsAppOtp(
      phoneNumber: phone,
      role: backendRoleNameFor(widget.role),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.role) {
      DemoRole.driver => 'OMW Worker access',
      DemoRole.storeOwner => 'OMW Store Owner access',
      DemoRole.admin => 'OMW Owner/Admin access',
      DemoRole.customer => 'Welcome to On My Way',
    };
    final firebaseAuth = FirebaseService.instance.isReady;
    final whatsAppAuth =
        firebaseAuth && AppConfig.useWhatsAppOtp && !_useSmsFallback;
    return Scaffold(
      appBar: AppBar(title: const Text(kBrandName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const OwmBrandMark(size: 72, badge: true),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              firebaseAuth
                  ? whatsAppAuth
                        ? 'Enter your phone number with country code. We will send a verification code to your WhatsApp number.'
                        : 'Enter your phone number with country code. We will send an SMS verification code.'
                  : 'Enter your phone number to continue. Test verification code: 1234',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            if (firebaseAuth && AppConfig.useWhatsAppOtp) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kAccentYellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kAccentYellow.withValues(alpha: 0.45),
                  ),
                ),
                child: const Text(
                  'WhatsApp OTP is currently in test mode. Only approved tester numbers can receive codes.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                errorText: _error,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 20),
            PrimaryCtaButton(
              label: whatsAppAuth
                  ? 'Send code on WhatsApp'
                  : firebaseAuth
                  ? 'Send SMS code'
                  : 'Continue',
              onPressed: _sending ? null : _continue,
            ),
            if (firebaseAuth && AppConfig.useWhatsAppOtp) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _sending
                    ? null
                    : () => setState(() {
                        _useSmsFallback = !_useSmsFallback;
                        _error = null;
                      }),
                icon: Icon(
                  _useSmsFallback
                      ? Icons.chat_bubble_outline
                      : Icons.sms_outlined,
                ),
                label: Text(
                  _useSmsFallback
                      ? 'Use WhatsApp test OTP'
                      : 'Use emergency SMS fallback',
                ),
              ),
            ],
            if (_sending) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.role,
    required this.phoneNumber,
    required this.session,
    required this.onVerified,
  });

  final DemoRole role;
  final String phoneNumber;
  final PhoneVerificationSession? session;
  final Future<void> Function() onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeCtrl = TextEditingController();
  String? _error;
  bool _verifying = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    final session = widget.session;
    final useFirebase =
        FirebaseService.instance.isReady && session != null && !session.isDemo;
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the verification code.');
      return;
    }
    if (!useFirebase) {
      if (code != '1234') {
        setState(
          () => _error = 'That code is not correct. Use 1234 for testing.',
        );
        return;
      }
      await widget.onVerified();
      return;
    }
    // Backend always issues 6-digit codes; catch short entries before the round-trip.
    if (code.length != 6) {
      setState(
        () => _error = 'Please enter the full 6-digit verification code.',
      );
      return;
    }
    if (session.verificationId.isEmpty && _authService.currentUser != null) {
      await widget.onVerified();
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      if (session.channel == AuthOtpChannel.whatsApp) {
        await _authService.verifyWhatsAppOtp(
          phoneNumber: widget.phoneNumber,
          code: code,
          role: backendRoleNameFor(widget.role),
        );
      } else {
        await _authService.verifyOtpCode(
          verificationId: session.verificationId,
          smsCode: code,
        );
      }
      if (!mounted) {
        return;
      }
      await widget.onVerified();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      // Use OTP-specific mapping so invalid-argument shows a code error,
      // not the phone-number hint from _friendlyFunctionsError.
      setState(() => _error = _friendlyOtpError(error));
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyAuthError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(
        () => _error =
            'We could not verify that code. '
            'Please check your WhatsApp or SMS message and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify On My Way')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.session?.channel == AuthOtpChannel.whatsApp
                  ? 'Enter WhatsApp code'
                  : 'Enter verification code',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _otpSubtitle(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Code',
                errorText: _error,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 20),
            PrimaryCtaButton(
              label: _verifying ? 'Verifying...' : 'Verify',
              onPressed: _verifying ? null : _verify,
            ),
            if (_verifying) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
            if (FirebaseService.instance.isReady) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _verifying ? null : _resendCode,
                icon: const Icon(Icons.refresh),
                label: const Text('Resend code'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _otpSubtitle() {
    final session = widget.session;
    if (!FirebaseService.instance.isReady || session?.isDemo == true) {
      return 'OMW test code sent to ${widget.phoneNumber}: 1234';
    }
    if (session?.channel == AuthOtpChannel.whatsApp) {
      return 'A verification code was requested via WhatsApp for ${widget.phoneNumber}. '
          'Please check your WhatsApp messages.';
    }
    return 'Code sent by SMS to ${widget.phoneNumber}.';
  }

  Future<void> _resendCode() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please go back and request a new verification code.'),
      ),
    );
  }
}

// =============================================================================
// EmailAuthScreen — email/password sign-in & sign-up with email verification.
// Used by the Worker and Store Owner tabs as the MVP primary auth method.
// WhatsApp OTP is preserved in the codebase but not wired to these buttons.
// =============================================================================

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({
    super.key,
    required this.role,
    required this.onAuthenticated,
    this.appBarTitle,
  });

  final DemoRole role;

  /// Called after sign-in + email verified. The screen pops itself after this.
  final Future<void> Function() onAuthenticated;

  final String? appBarTitle;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _loading = false;
  bool _showVerifyPending = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _pendingEmail;

  @override
  void initState() {
    super.initState();
    // If a Firebase user is already signed in, handle their state immediately.
    _checkExistingSession();
  }

  void _checkExistingSession() {
    final user = _authService.currentUser;
    if (user == null) return;
    if (user.emailVerified) {
      // Already verified — proceed after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _proceed());
    } else if (user.email != null) {
      // Signed in but not yet verified.
      setState(() {
        _showVerifyPending = true;
        _pendingEmail = user.email;
      });
    }
  }

  /// Calls the parent callback then pops all routes back to the shell.
  Future<void> _proceed() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final nav = Navigator.of(context);
      await widget.onAuthenticated();
      if (mounted) nav.popUntil((r) => r.isFirst);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateEmail(String v) {
    if (v.isEmpty) return 'Please enter your email.';
    if (!v.contains('@') || !v.contains('.')) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String v) {
    if (v.isEmpty) return 'Please enter your password.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    final emailErr = _validateEmail(email);
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }
    final passErr = _validatePassword(password);
    if (passErr != null) {
      setState(() => _error = passErr);
      return;
    }
    if (!_isLogin && _confirmCtrl.text != password) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(email, password);
        await _authService.reloadUser();
        final user = _authService.currentUser;
        if (user?.emailVerified == true) {
          await _proceed();
        } else {
          // Signed in but email not verified — resend and show pending screen.
          await _authService.sendEmailVerification();
          if (mounted) {
            setState(() {
              _showVerifyPending = true;
              _pendingEmail = email;
              _loading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Verification email sent. Please check your inbox.',
                ),
              ),
            );
          }
        }
      } else {
        // Sign-up
        await _authService.createUserWithEmailAndPassword(email, password);
        await _authService.sendEmailVerification();
        if (mounted) {
          setState(() {
            _showVerifyPending = true;
            _pendingEmail = email;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account created! Verification email sent. Please check your inbox.',
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyEmailAuthError(e);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.reloadUser();
      if (_authService.currentUser?.emailVerified == true) {
        await _proceed();
      } else {
        setState(() {
          _error =
              'Email not verified yet. Please check your inbox and click the link.';
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Could not check verification status. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _resendVerification() async {
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not resend email. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showVerifyPending ? _buildVerifyPending() : _buildForm();
  }

  Widget _buildForm() {
    final roleLabel = _emailRoleLabel(widget.role);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appBarTitle ?? (_isLogin ? 'Sign In' : 'Create Account'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 4),
            Text(
              _isLogin ? 'Welcome back' : 'Create your OMW account',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _isLogin
                  ? 'Sign in to access your $roleLabel portal.'
                  : 'Sign up to join OMW as a $roleLabel.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBox(message: _error!),
            ],
            const SizedBox(height: 24),
            PrimaryCtaButton(
              label: _loading
                  ? (_isLogin ? 'Signing in…' : 'Creating account…')
                  : (_isLogin ? 'Sign In' : 'Create Account'),
              onPressed: _loading ? null : _submit,
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() {
                _isLogin = !_isLogin;
                _error = null;
              }),
              child: Text(
                _isLogin
                    ? "Don't have an account? Sign up"
                    : 'Already have an account? Sign in',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyPending() {
    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle ?? 'Verify Email')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            const Center(child: OwmBrandMark(size: 72, badge: true)),
            const SizedBox(height: 24),
            const Text(
              'Verify your email',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'A verification link was sent to:\n${_pendingEmail ?? ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please open your email, click the verification link, then tap the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(message: _error!),
            ],
            const SizedBox(height: 32),
            PrimaryCtaButton(
              label: _loading ? 'Checking…' : 'I verified my email',
              onPressed: _loading ? null : _checkVerification,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loading ? null : _resendVerification,
              icon: const Icon(Icons.refresh),
              label: const Text('Resend verification email'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                _showVerifyPending = false;
                _error = null;
              }),
              child: const Text('Use a different email'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable error box used by EmailAuthScreen.
// ---------------------------------------------------------------------------

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers for EmailAuthScreen
// ---------------------------------------------------------------------------

String _emailRoleLabel(DemoRole role) => switch (role) {
  DemoRole.driver => 'Worker',
  DemoRole.storeOwner => 'Store Owner',
  DemoRole.customer => 'Customer',
  DemoRole.admin => 'Admin',
};

String _friendlyEmailAuthError(FirebaseAuthException e) => switch (e.code) {
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Incorrect email or password. Please try again.',
  'email-already-in-use' =>
    'An account with this email already exists. Please sign in instead.',
  'invalid-email' => 'Please enter a valid email address.',
  'weak-password' => 'Password must be at least 6 characters.',
  'too-many-requests' => 'Too many attempts. Please wait and try again.',
  'network-request-failed' =>
    'Network error. Check your connection and try again.',
  'user-disabled' => 'This account has been disabled. Please contact support.',
  'operation-not-allowed' => e.message ?? 'Email login is not enabled.',
  _ => 'Authentication failed. Please try again.',
};
