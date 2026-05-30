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
      setState(() => _error = 'Verification code is required');
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
            'We could not verify that code. Check the SMS and try again.',
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
      return 'Code sent on WhatsApp to ${widget.phoneNumber}.';
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
