part of '../main.dart';

// ---------------------------------------------------------------------------
// OmwMainShell — marketplace-first 5-tab app shell
// ---------------------------------------------------------------------------

class OmwMainShell extends StatefulWidget {
  const OmwMainShell({
    super.key,
    required this.phoneNumber,
    required this.isVerified,
    required this.selectedRole,
    required this.availableRoles,
    required this.verificationSession,
    required this.onSelectRole,
    required this.onSendCode,
    required this.onVerify,
    required this.onSignOut,
    required this.onRoleChanged,
  });

  final String? phoneNumber;
  final bool isVerified;
  final DemoRole? selectedRole;
  final List<DemoRole>? availableRoles;
  final PhoneVerificationSession? verificationSession;
  final ValueChanged<DemoRole> onSelectRole;
  final ValueChanged<LoginVerificationRequest> onSendCode;
  final Future<void> Function() onVerify;
  final VoidCallback onSignOut;
  final VoidCallback onRoleChanged;

  @override
  State<OmwMainShell> createState() => _OmwMainShellState();
}

class _OmwMainShellState extends State<OmwMainShell> {
  int _tab = 0;

  // Tabs are built lazily; marketplace (0) is pre-visited.
  final Set<int> _visited = {0};

  bool get _isWorker =>
      widget.isVerified &&
      (widget.selectedRole == DemoRole.driver ||
          (widget.availableRoles?.contains(DemoRole.driver) ?? false));

  bool get _isStoreOwner =>
      widget.isVerified &&
      (widget.selectedRole == DemoRole.storeOwner ||
          (widget.availableRoles?.contains(DemoRole.storeOwner) ?? false));

  String get _phone => widget.phoneNumber ?? '';

  void _onTabSelected(int index) {
    setState(() {
      _visited.add(index);
      _tab = index;
    });
  }

  Widget _marketplace() => MarketplaceHomeScreen(
    userPhone: _phone,
    deliveryLabel: kCurrentPickup,
    deliveryPoint: kDemoPickupPoint,
    showAsRootTab: true, // no back button, no Switch when inside shell
    onSwitchAccount: widget.onSignOut,
  );

  // Delivery tab — courier/delivery request flow.
  Widget _deliveryTab() => MainMapScreen(
    userPhone: _phone,
    onSignOut: widget.onSignOut,
    initialService: ServiceType.courier,
  );

  // Kept for future restoration but not wired to main navigation.
  // ignore: unused_element
  Widget _rideTab() => MainMapScreen(
    userPhone: _phone,
    onSignOut: widget.onSignOut,
    initialService: ServiceType.ride,
  );

  Widget _workerTab() {
    if (!_isWorker) {
      return _WorkerTabLanding(
        onSelectRole: widget.onSelectRole,
        onSendCode: widget.onSendCode,
        onVerify: widget.onVerify,
      );
    }
    // Safety gate: email/password users must verify their email before
    // accessing the worker dashboard. This catches the edge case where the
    // user closed EmailAuthScreen before completing verification.
    final user = AuthService().currentUser;
    if (FirebaseService.instance.isReady &&
        user != null &&
        !user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password')) {
      return _EmailVerificationPendingTab(
        email: user.email ?? '',
        onVerified: () async {
          await widget.onVerify();
          widget.onRoleChanged();
        },
      );
    }
    final userId = user?.uid;
    if (FirebaseService.instance.isReady && userId != null) {
      return _FirebaseWorkerGate(
        userId: userId,
        phoneNumber: _phone,
        onChanged: widget.onRoleChanged,
        onSignOut: widget.onSignOut,
      );
    }
    if (demoWorkerProfile.status == WorkerApplicationStatus.approved) {
      return DriverHomeScreen(userPhone: _phone, onSignOut: widget.onSignOut);
    }
    return WorkerOnboardingScreen(
      phoneNumber: _phone,
      onChanged: widget.onRoleChanged,
      onSignOut: widget.onSignOut,
    );
  }

  Widget _storeOwnerTab() {
    if (!_isStoreOwner) {
      return _StoreOwnerTabLanding(
        onSelectRole: widget.onSelectRole,
        onSendCode: widget.onSendCode,
        onVerify: widget.onVerify,
      );
    }
    // Safety gate: same email-verification check as _workerTab.
    final user = AuthService().currentUser;
    if (FirebaseService.instance.isReady &&
        user != null &&
        !user.emailVerified &&
        user.providerData.any((p) => p.providerId == 'password')) {
      return _EmailVerificationPendingTab(
        email: user.email ?? '',
        onVerified: () async {
          await widget.onVerify();
          widget.onRoleChanged();
        },
      );
    }
    return StoreOwnerDashboardScreen(
      userPhone: _phone,
      onSignOut: widget.onSignOut,
    );
  }

  // Returns the widget for a given tab index.
  // Called only after the tab has been marked visited.
  Widget _buildTab(int i) {
    switch (i) {
      case 0:
        return _marketplace();
      case 1:
        return _deliveryTab();
      case 2:
        return _workerTab();
      case 3:
        return _storeOwnerTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = List<Widget>.generate(5, (i) {
      return _visited.contains(i) ? _buildTab(i) : const _TabStub();
    });

    return Scaffold(
      body: IndexedStack(index: _tab, children: children),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabSelected,
        backgroundColor: Colors.white,
        indicatorColor: kAccentYellow.withValues(alpha: 0.28),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Delivery',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Worker',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'My Store',
          ),
        ],
      ),
    );
  }
}

// Invisible placeholder for tabs not yet visited inside IndexedStack.
class _TabStub extends StatelessWidget {
  const _TabStub();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// Butler tab removed from MVP navigation (client decision 2026-06-02).
// Restore by adding a 5th NavigationDestination and a case in _buildTab().
// Taxi ride tab also hidden (see _rideTab below); ServiceType.courier is now Delivery.

// ---------------------------------------------------------------------------
// Worker tab — landing page shown when user is not signed in as a worker
// ---------------------------------------------------------------------------

class _WorkerTabLanding extends StatelessWidget {
  const _WorkerTabLanding({
    required this.onSelectRole,
    required this.onSendCode,
    required this.onVerify,
  });

  final ValueChanged<DemoRole> onSelectRole;
  final ValueChanged<LoginVerificationRequest> onSendCode;
  final Future<void> Function() onVerify;

  void _startLogin(BuildContext context) {
    onSelectRole(DemoRole.driver);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmailAuthScreen(
          role: DemoRole.driver,
          appBarTitle: 'Worker Portal',
          onAuthenticated: onVerify,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Portal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const Center(child: OwmBrandMark(size: 72)),
            const SizedBox(height: 20),
            const Text(
              'Join OMW as a Worker',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'Sign in or register to access your worker dashboard, '
              'manage jobs, and track your earnings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            PrimaryCtaButton(
              label: 'Sign in / Register as Worker',
              onPressed: () => _startLogin(context),
            ),
            const SizedBox(height: 36),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Need help joining?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Contact our support team directly on WhatsApp '
              'and we will guide you through registration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const _WorkerWhatsAppSupportCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Store Owner tab — landing page shown when user is not signed in as owner
// ---------------------------------------------------------------------------

class _StoreOwnerTabLanding extends StatelessWidget {
  const _StoreOwnerTabLanding({
    required this.onSelectRole,
    required this.onSendCode,
    required this.onVerify,
  });

  final ValueChanged<DemoRole> onSelectRole;
  final ValueChanged<LoginVerificationRequest> onSendCode;
  final Future<void> Function() onVerify;

  void _startLogin(BuildContext context) {
    onSelectRole(DemoRole.storeOwner);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmailAuthScreen(
          role: DemoRole.storeOwner,
          appBarTitle: 'Store Owner Portal',
          onAuthenticated: onVerify,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Owner Portal')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OwmBrandMark(size: 72),
                const SizedBox(height: 20),
                const Text(
                  'Manage Your Store',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in or register to manage your store profile, '
                  'products, inventory, and orders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryCtaButton(
                    label: 'Sign in / Register as Store Owner',
                    onPressed: () => _startLogin(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmailVerificationPendingTab
// Safety-net screen shown inside the Worker/StoreOwner tab when the user is
// signed in via email/password but has not yet clicked the verification link.
// Displayed only if the user somehow reaches the tab without going through
// EmailAuthScreen's own pending screen (e.g. by pressing the back button
// mid-flow).
// ---------------------------------------------------------------------------

class _EmailVerificationPendingTab extends StatefulWidget {
  const _EmailVerificationPendingTab({
    required this.email,
    required this.onVerified,
  });

  final String email;
  final Future<void> Function() onVerified;

  @override
  State<_EmailVerificationPendingTab> createState() =>
      _EmailVerificationPendingTabState();
}

class _EmailVerificationPendingTabState
    extends State<_EmailVerificationPendingTab> {
  final _authService = AuthService();
  bool _loading = false;
  String? _message;
  bool _isError = false;

  Future<void> _checkVerification() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await _authService.reloadUser();
      if (_authService.currentUser?.emailVerified == true) {
        await widget.onVerified();
      } else {
        setState(() {
          _message =
              'Email not verified yet. Please check your inbox and click the link.';
          _isError = true;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _message = 'Could not check status. Please try again.';
        _isError = true;
        _loading = false;
      });
    }
  }

  Future<void> _resend() async {
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = 'Verification email sent. Please check your inbox.';
          _isError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Could not send email. Please try again.';
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: OwmBrandMark(size: 72, badge: true)),
              const SizedBox(height: 24),
              const Text(
                'Email verification required',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'Please verify your email address to continue.\n\n'
                'A verification link was sent to:\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isError
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isError
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              PrimaryCtaButton(
                label: _loading ? 'Checking…' : 'I verified my email',
                onPressed: _loading ? null : _checkVerification,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loading ? null : _resend,
                icon: const Icon(Icons.refresh),
                label: const Text('Resend verification email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RoleAuthFlow — hosts PhoneLoginScreen → OtpVerificationScreen in sequence.
// PRESERVED for future WhatsApp OTP restoration. NOT used by the main login
// buttons (Worker / Store Owner) which now use EmailAuthScreen instead.
// ---------------------------------------------------------------------------

class _RoleAuthFlow extends StatefulWidget {
  const _RoleAuthFlow({
    required this.role,
    required this.onSendCode,
    required this.onVerified,
  });

  final DemoRole role;
  final ValueChanged<LoginVerificationRequest> onSendCode;
  final Future<void> Function() onVerified;

  @override
  State<_RoleAuthFlow> createState() => _RoleAuthFlowState();
}

class _RoleAuthFlowState extends State<_RoleAuthFlow> {
  String? _phoneNumber;
  PhoneVerificationSession? _session;

  @override
  Widget build(BuildContext context) {
    if (_phoneNumber == null || _session == null) {
      return PhoneLoginScreen(
        role: widget.role,
        onCodeSent: (req) {
          widget.onSendCode(req); // persist in parent state
          setState(() {
            _phoneNumber = req.phoneNumber;
            _session = req.session;
          });
        },
      );
    }
    return OtpVerificationScreen(
      role: widget.role,
      phoneNumber: _phoneNumber!,
      session: _session,
      onVerified: () async {
        final nav = Navigator.of(context);
        await widget.onVerified();
        if (mounted) {
          nav.popUntil((r) => r.isFirst);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _WorkerWhatsAppSupportCard
// Worker type selector + pre-filled WhatsApp message to OMW support.
// Support number is configured via --dart-define=OMW_SUPPORT_WHATSAPP_NUMBER
// ---------------------------------------------------------------------------

class _WorkerWhatsAppSupportCard extends StatefulWidget {
  const _WorkerWhatsAppSupportCard({
    this.workerName = '',
    this.workerPhone = '',
  });

  final String workerName;
  final String workerPhone;

  @override
  State<_WorkerWhatsAppSupportCard> createState() =>
      _WorkerWhatsAppSupportCardState();
}

class _WorkerWhatsAppSupportCardState
    extends State<_WorkerWhatsAppSupportCard> {
  static const _workerTypes = [
    'Taxi Driver',
    'Delivery Worker',
    'Butler Services Worker',
  ];

  String _selectedType = 'Taxi Driver';

  Future<void> _contactSupport() async {
    const supportNumber = AppConfig.supportWhatsAppNumber;
    if (supportNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support WhatsApp number is not configured yet.'),
          ),
        );
      }
      return;
    }

    final name = widget.workerName.trim();
    final phone = widget.workerPhone.trim();
    final nameLine = name.isNotEmpty ? '\nName: $name' : '';
    final phoneLine = phone.isNotEmpty ? '\nPhone: $phone' : '';
    final text =
        'Hello OMW Support, I would like to join as a $_selectedType. '
        'Please help me complete my registration.$nameLine$phoneLine';

    final uri = Uri.parse(
      'https://wa.me/$supportNumber?text=${Uri.encodeComponent(text)}',
    );
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open WhatsApp. '
            'Please check that WhatsApp is installed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: 'I want to join as',
              prefixIcon: Icon(Icons.work_outline),
            ),
            items: _workerTypes
                .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _contactSupport,
            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
            label: const Text('Contact Support on WhatsApp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
