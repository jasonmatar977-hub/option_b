part of '../../main.dart';

class WorkerOnboardingScreen extends StatefulWidget {
  const WorkerOnboardingScreen({
    super.key,
    required this.phoneNumber,
    required this.onChanged,
    required this.onSignOut,
  });

  final String phoneNumber;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;

  @override
  State<WorkerOnboardingScreen> createState() => _WorkerOnboardingScreenState();
}

class _FirebaseWorkerGate extends StatelessWidget {
  const _FirebaseWorkerGate({
    required this.userId,
    required this.phoneNumber,
    required this.onChanged,
    required this.onSignOut,
  });

  final String userId;
  final String phoneNumber;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<backend.WorkerProfile?>(
      stream: WorkerService().watchWorkerProfile(userId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        if (profile != null) {
          syncDemoWorkerFromBackend(profile);
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            profile == null) {
          return const BrandedSplashScreen();
        }
        if (profile?.status == backend.WorkerStatus.approved) {
          return DriverHomeScreen(userPhone: phoneNumber, onSignOut: onSignOut);
        }
        return WorkerOnboardingScreen(
          phoneNumber: phoneNumber,
          onChanged: onChanged,
          onSignOut: onSignOut,
        );
      },
    );
  }
}

class _WorkerOnboardingScreenState extends State<WorkerOnboardingScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _payoutNameCtrl;
  late final TextEditingController _payoutPhoneCtrl;
  late final TextEditingController _payoutNotesCtrl;
  final AuthService _authService = AuthService();
  final WorkerService _workerService = WorkerService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final profile = demoWorkerProfile;
    if (profile.phoneNumber.isEmpty) {
      profile.phoneNumber = widget.phoneNumber;
    }
    _nameCtrl = TextEditingController(text: profile.fullName);
    _phoneCtrl = TextEditingController(text: profile.phoneNumber);
    _plateCtrl = TextEditingController(text: profile.plateNumber);
    _cityCtrl = TextEditingController(text: profile.cityArea);
    _payoutNameCtrl = TextEditingController(text: profile.payoutDisplayName);
    _payoutPhoneCtrl = TextEditingController(text: profile.payoutPhoneNumber);
    _payoutNotesCtrl = TextEditingController(text: profile.payoutNotes);
    _loadFirebaseWorkerProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _cityCtrl.dispose();
    _payoutNameCtrl.dispose();
    _payoutPhoneCtrl.dispose();
    _payoutNotesCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final profile = demoWorkerProfile;
    profile.fullName = _nameCtrl.text.trim();
    profile.phoneNumber = _phoneCtrl.text.trim();
    profile.plateNumber = _plateCtrl.text.trim();
    profile.cityArea = _cityCtrl.text.trim();
    if (profile.servicesOffered.isEmpty) {
      profile.servicesOffered = backendWorkerServiceTypesFor(
        profile.serviceType,
      );
    }
    profile.payoutDisplayName = _payoutNameCtrl.text.trim();
    profile.payoutPhoneNumber = _payoutPhoneCtrl.text.trim();
    profile.payoutNotes = _payoutNotesCtrl.text.trim();
    if (profile.status == WorkerApplicationStatus.notStarted) {
      profile.status = WorkerApplicationStatus.incomplete;
    }
  }

  Future<void> _loadFirebaseWorkerProfile() async {
    final user = _authService.currentUser;
    if (!FirebaseService.instance.isReady || user == null) {
      return;
    }
    try {
      final profile = await _workerService.watchWorkerProfile(user.uid).first;
      if (profile == null || !mounted) {
        return;
      }
      syncDemoWorkerFromBackend(profile);
      _nameCtrl.text = demoWorkerProfile.fullName;
      _phoneCtrl.text = demoWorkerProfile.phoneNumber;
      _plateCtrl.text = demoWorkerProfile.plateNumber;
      _cityCtrl.text = demoWorkerProfile.cityArea;
      _payoutNameCtrl.text = demoWorkerProfile.payoutDisplayName;
      _payoutPhoneCtrl.text = demoWorkerProfile.payoutPhoneNumber;
      _payoutNotesCtrl.text = demoWorkerProfile.payoutNotes;
      setState(() {});
    } catch (_) {
      // Worker profile restoration is best-effort; onboarding remains usable.
    }
  }

  Future<void> _submit([
    List<backend.WorkerDocument> firebaseDocuments = const [],
  ]) async {
    _saveProfile();
    final firebaseMode = FirebaseService.instance.isReady;
    final canSubmit = firebaseMode
        ? demoWorkerProfile.hasProfileDetails &&
              requiredWorkerDocumentsUploaded(firebaseDocuments)
        : demoWorkerProfile.canSubmit;
    if (!canSubmit) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload all required documents before submitting.',
          ),
        ),
      );
      return;
    }
    setState(() {
      demoWorkerProfile.status = WorkerApplicationStatus.pending;
    });
    if (FirebaseService.instance.isReady) {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in again before submitting.'),
            ),
          );
        }
        return;
      }
      final now = DateTime.now();
      try {
        final existing = await _workerService
            .watchWorkerProfile(user.uid)
            .first;
        await _workerService.upsertWorkerProfile(
          backend.WorkerProfile(
            id: user.uid,
            userId: user.uid,
            fullName: demoWorkerProfile.fullName,
            phone: demoWorkerProfile.phoneNumber,
            serviceTypes: demoWorkerProfile.servicesOffered,
            vehicleType: demoWorkerProfile.vehicleType,
            plateNumber: demoWorkerProfile.plateNumber,
            operatingArea: demoWorkerProfile.cityArea,
            status: backend.WorkerStatus.pending,
            documentsStatus: backend.documentsStatusFor(firebaseDocuments),
            isOnline: existing?.isOnline ?? false,
            currentLat: existing?.currentLat,
            currentLng: existing?.currentLng,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            submittedAt: now,
            approvedAt: existing?.approvedAt,
            rejectedAt: existing?.rejectedAt,
            suspendedAt: existing?.suspendedAt,
            agreementAccepted: demoWorkerProfile.agreementAccepted,
            agreementAcceptedAt: demoWorkerProfile.agreementAcceptedAt ?? now,
            agreementVersion: kWorkerAgreementVersion,
            payoutMethod: demoWorkerProfile.payoutMethod,
            payoutDetails: demoWorkerProfile.payoutNotes,
            payoutDisplayName: demoWorkerProfile.payoutDisplayName,
            payoutPhoneNumber: demoWorkerProfile.payoutPhoneNumber,
            bankDetails: demoWorkerProfile.payoutMethod == 'bankTransfer'
                ? demoWorkerProfile.payoutNotes
                : '',
            payoutNotes: demoWorkerProfile.payoutNotes,
          ),
        );
        await _workerService.submitApplication(user.uid);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save worker application to Firebase.'),
            ),
          );
        }
        return;
      }
    }
    widget.onChanged();
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Application submitted'),
        content: const Text(
          'Application submitted. Waiting for owner approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _contentTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _uploadFirebaseDocument(
    WorkerDocumentRequirement requirement,
  ) async {
    final user = _authService.currentUser;
    if (!FirebaseService.instance.isReady || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again before uploading.')),
      );
      return;
    }
    try {
      final source = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose image'),
                onTap: () => Navigator.of(ctx).pop('gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Upload file'),
                onTap: () => Navigator.of(ctx).pop('file'),
              ),
            ],
          ),
        ),
      );
      if (source == null) {
        return;
      }
      Uint8List? bytes;
      String fileName;
      String extension;
      if (source == 'camera' || source == 'gallery') {
        final picked = await _imagePicker.pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2200,
        );
        if (picked == null) {
          return;
        }
        bytes = await picked.readAsBytes();
        fileName = picked.name;
        extension = fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : 'jpg';
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          return;
        }
        final file = result.files.single;
        bytes = file.bytes;
        fileName = file.name;
        extension = (file.extension ?? '').toLowerCase();
      }
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload a JPG, PNG, or PDF document.'),
            ),
          );
        }
        return;
      }
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file is empty.')),
          );
        }
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File must be 10MB or smaller.')),
          );
        }
        return;
      }
      await _storageService.uploadWorkerDocument(
        workerId: user.uid,
        type: requirement.type,
        bytes: bytes,
        fileName: fileName,
        contentType: _contentTypeFor(extension),
        extension: extension,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${requirement.label} uploaded for review.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.code == 'permission-denied'
          ? 'You do not have permission to upload this document yet.'
          : 'Upload failed. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    }
  }

  Future<void> _saveAgreementAccepted(bool value) async {
    final profile = demoWorkerProfile;
    setState(() {
      profile.agreementAccepted = value;
      profile.agreementAcceptedAt = value ? DateTime.now() : null;
      profile.agreementVersion = value ? kWorkerAgreementVersion : '';
      _saveProfile();
    });
    final user = _authService.currentUser;
    if (value && FirebaseService.instance.isReady && user != null) {
      unawaited(
        _workerService.acceptAgreement(
          workerId: user.uid,
          agreementVersion: kWorkerAgreementVersion,
        ),
      );
    }
  }

  void _savePayoutMethod(String value) {
    final profile = demoWorkerProfile;
    setState(() {
      profile.payoutMethod = value;
      _saveProfile();
    });
    final user = _authService.currentUser;
    if (FirebaseService.instance.isReady && user != null) {
      unawaited(
        _workerService.updatePayoutMethod(
          workerId: user.uid,
          payoutMethod: profile.payoutMethod,
          payoutDetails: profile.payoutNotes,
          payoutPhone: profile.payoutPhoneNumber,
          bankDetails: profile.payoutMethod == 'bankTransfer'
              ? profile.payoutNotes
              : '',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = demoWorkerProfile;
    return Scaffold(
      appBar: AppBar(
        leading: OmwBackButton(
          fallback: () => switchAccountFrom(context, widget.onSignOut),
        ),
        title: const Text('OMW Worker approval'),
        actions: [
          TextButton.icon(
            onPressed: () => switchAccountFrom(context, widget.onSignOut),
            icon: const Icon(Icons.logout),
            label: const Text('Switch'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Complete your worker profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit your details so On My Way can approve you before you receive requests.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _ComplianceStatusCard(
              status: profile.status,
              documentsSummary: profile.documentsSummary,
            ),
            const SizedBox(height: 16),
            _ApprovalProgress(status: profile.status),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(_saveProfile),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              onChanged: (_) => setState(_saveProfile),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Vehicle type',
              value: profile.vehicleType,
              options: const ['Car', 'Moto', 'Bike', 'Van'],
              onChanged: (value) => setState(() {
                profile.vehicleType = value;
                _saveProfile();
              }),
            ),
            const SizedBox(height: 12),
            _WorkerServicesSelector(
              selectedServices: profile.servicesOffered,
              onChanged: (services) => setState(() {
                profile.servicesOffered = services;
                profile.serviceType = serviceTypeLabelFromBackend(services);
                _saveProfile();
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateCtrl,
              decoration: const InputDecoration(
                labelText: 'Vehicle plate number',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              onChanged: (_) => setState(_saveProfile),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'City / operating area',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              onChanged: (_) => setState(_saveProfile),
            ),
            const SizedBox(height: 16),
            _WorkerAgreementCard(
              accepted: profile.agreementAccepted,
              onChanged: _saveAgreementAccepted,
            ),
            const SizedBox(height: 16),
            _PayoutMethodForm(
              selectedMethod: profile.payoutMethod,
              nameController: _payoutNameCtrl,
              phoneController: _payoutPhoneCtrl,
              notesController: _payoutNotesCtrl,
              onMethodChanged: _savePayoutMethod,
              onChanged: () => setState(_saveProfile),
            ),
            const SizedBox(height: 20),
            const Text(
              'Required documents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (FirebaseService.instance.isReady &&
                _authService.currentUser != null)
              StreamBuilder<List<backend.WorkerDocument>>(
                stream: _workerService.watchWorkerDocuments(
                  _authService.currentUser!.uid,
                ),
                builder: (context, snapshot) {
                  final documents =
                      snapshot.data ?? const <backend.WorkerDocument>[];
                  final canSubmit =
                      profile.hasProfileDetails &&
                      requiredWorkerDocumentsUploaded(documents);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...kWorkerDocumentRequirements.map(
                        (requirement) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FirebaseWorkerDocumentCard(
                            requirement: requirement,
                            document: documentForRequirement(
                              documents,
                              requirement,
                            ),
                            onUpload: () =>
                                _uploadFirebaseDocument(requirement),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PrimaryCtaButton(
                        label:
                            profile.status == WorkerApplicationStatus.rejected
                            ? 'Resubmit application'
                            : 'Submit application',
                        onPressed: canSubmit
                            ? () => _submit(documents)
                            : () => _submit(documents),
                      ),
                    ],
                  );
                },
              )
            else ...[
              ...kWorkerDocumentNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DocumentCard(
                    name: name,
                    requiredDocument: workerRequirementForName(name).required,
                    status: profile.documents[name] ?? DocumentStatus.missing,
                    onUpload: () => setState(() {
                      profile.documents[name] = DocumentStatus.uploaded;
                      _saveProfile();
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryCtaButton(
                label: profile.status == WorkerApplicationStatus.rejected
                    ? 'Resubmit application'
                    : 'Submit application',
                onPressed: profile.hasProfileDetails ? () => _submit() : null,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                profile.reset();
                _nameCtrl.clear();
                _phoneCtrl.text = widget.phoneNumber;
                profile.phoneNumber = widget.phoneNumber;
                _plateCtrl.clear();
                _cityCtrl.clear();
                _payoutNameCtrl.clear();
                _payoutPhoneCtrl.clear();
                _payoutNotesCtrl.clear();
                widget.onChanged();
              }),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset OMW worker application'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccentBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _WorkerServicesSelector extends StatelessWidget {
  const _WorkerServicesSelector({
    required this.selectedServices,
    required this.onChanged,
  });

  final List<String> selectedServices;
  final ValueChanged<List<String>> onChanged;

  static const options = [
    ('ride', 'Ride'),
    ('moto', 'Moto'),
    ('courier', 'Courier'),
    ('marketplace_delivery', 'Marketplace Delivery'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E1D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services offered',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = selectedServices.contains(option.$1);
              return FilterChip(
                label: Text(option.$2),
                selected: selected,
                selectedColor: kAccentYellow.withValues(alpha: 0.45),
                onSelected: (value) {
                  final next = [...selectedServices];
                  if (value) {
                    next.add(option.$1);
                  } else {
                    next.remove(option.$1);
                  }
                  onChanged(next.toSet().toList());
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.name,
    required this.requiredDocument,
    required this.status,
    required this.onUpload,
  });

  final String name;
  final bool requiredDocument;
  final DocumentStatus status;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: kAccentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusChip(
                      label: documentStatusLabel(status),
                      status: status.name,
                    ),
                    _StatusChip(
                      label: requiredDocument ? 'Required' : 'Optional',
                      status: requiredDocument ? 'pending' : 'approved',
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: status == DocumentStatus.approved ? null : onUpload,
            child: const Text('Upload local'),
          ),
        ],
      ),
    );
  }
}

class _FirebaseWorkerDocumentCard extends StatelessWidget {
  const _FirebaseWorkerDocumentCard({
    required this.requirement,
    required this.document,
    required this.onUpload,
  });

  final WorkerDocumentRequirement requirement;
  final backend.WorkerDocument? document;
  final VoidCallback onUpload;

  Future<void> _viewDocument(BuildContext context) async {
    final url = document?.fileUrl ?? '';
    if (url.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document link is not valid.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = document?.status ?? backend.WorkerDocumentStatus.missing;
    final fileName = document?.fileName ?? '';
    final rejected = status == backend.WorkerDocumentStatus.rejected;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rejected ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: kDeepGold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requirement.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusChip(label: status.name, status: status.name),
                        _StatusChip(
                          label: requirement.required ? 'Required' : 'Optional',
                          status: requirement.required ? 'pending' : 'approved',
                        ),
                      ],
                    ),
                    if (fileName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (rejected && document?.rejectionReason?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Rejected: ${document!.rejectionReason}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: document?.fileUrl.isNotEmpty == true
                      ? () => _viewDocument(context)
                      : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: status == backend.WorkerDocumentStatus.approved
                      ? null
                      : onUpload,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    document?.fileUrl.isNotEmpty == true ? 'Replace' : 'Upload',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccentYellow,
                    foregroundColor: kBrandBlack,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OwnerFinancialSummary {
  const OwnerFinancialSummary({
    required this.grossRevenue,
    required this.ownerNet,
    required this.workerPayoutsOwed,
    required this.paidToWorkers,
    required this.unpaidWorkerBalance,
    required this.manualPayments,
    required this.completedJobs,
    required this.completedMarketplaceOrders,
  });

  final double grossRevenue;
  final double ownerNet;
  final double workerPayoutsOwed;
  final double paidToWorkers;
  final double unpaidWorkerBalance;
  final double manualPayments;
  final int completedJobs;
  final int completedMarketplaceOrders;
}

OwnerFinancialSummary ownerFinancialSummaryFor({
  required List<DemoServiceJob> jobs,
  required List<backend.MarketplaceOrder> marketplaceOrders,
}) {
  var gross = 0.0;
  var ownerNet = 0.0;
  var owed = 0.0;
  var paid = 0.0;
  var manual = 0.0;
  var completedJobs = 0;
  var completedOrders = 0;

  for (final job in jobs) {
    if (job.status != DemoServiceJobStatus.completed) continue;
    completedJobs++;
    gross += job.gross;
    ownerNet += job.commission;
    final payout = job.workerPayout;
    if (job.workerPayoutStatus == 'paid') {
      paid += payout;
    } else {
      owed += payout;
    }
    manual += job.gross;
  }

  for (final order in marketplaceOrders) {
    if (order.status != backend.MarketplaceOrderStatus.delivered) continue;
    completedOrders++;
    final orderGross = order.gross ?? order.total;
    final commission =
        order.platformCommission ?? AppConfig.platformCommissionFor(orderGross);
    final payout = order.workerPayout ?? AppConfig.workerPayoutFor(orderGross);
    gross += orderGross;
    ownerNet += commission;
    if (order.workerPayoutStatus == 'paid') {
      paid += payout;
    } else {
      owed += payout;
    }
    manual += orderGross;
  }

  return OwnerFinancialSummary(
    grossRevenue: gross,
    ownerNet: ownerNet,
    workerPayoutsOwed: owed,
    paidToWorkers: paid,
    unpaidWorkerBalance: owed,
    manualPayments: manual,
    completedJobs: completedJobs,
    completedMarketplaceOrders: completedOrders,
  );
}

class _WorkerAgreementCard extends StatelessWidget {
  const _WorkerAgreementCard({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBrandSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'On My Way Worker Agreement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You operate as an independent service provider. Customer payments are collected by On My Way first. Worker payout is calculated after completed jobs and issued manually by owner/admin based on your approved payout method. Jobs must be completed properly before payout is eligible. You must follow safety, legal, and service rules. Accounts may be suspended for fraud, unsafe behavior, cancellation abuse, or policy violations.',
            style: TextStyle(color: kMutedText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Final agreement text should be reviewed by a qualified lawyer before public launch.',
            style: TextStyle(color: kAccentYellow, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: accepted,
            onChanged: (value) => onChanged(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: kAccentYellow,
            checkColor: kBrandBlack,
            title: const Text(
              'I have read and agree to the On My Way Worker Agreement.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutMethodForm extends StatelessWidget {
  const _PayoutMethodForm({
    required this.selectedMethod,
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.onMethodChanged,
    required this.onChanged,
  });

  final String selectedMethod;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onChanged;

  static const methods = [
    ('wishMoney', 'Wish Money'),
    ('omtPay', 'OMT Pay'),
    ('cash', 'Cash'),
    ('bankTransfer', 'Bank Transfer'),
    ('other', 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Worker payout method',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedMethod.isEmpty ? null : selectedMethod,
            decoration: const InputDecoration(
              labelText: 'Payout method',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: methods
                .map(
                  (method) => DropdownMenuItem<String>(
                    value: method.$1,
                    child: Text(method.$2),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onMethodChanged(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Payout display name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Payout phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: selectedMethod == 'bankTransfer'
                  ? 'Bank details'
                  : 'Payout details optional',
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _ComplianceStatusCard extends StatelessWidget {
  const _ComplianceStatusCard({
    required this.status,
    required this.documentsSummary,
  });

  final WorkerApplicationStatus status;
  final String documentsSummary;

  @override
  Widget build(BuildContext context) {
    final title = switch (status) {
      WorkerApplicationStatus.notStarted => 'Complete application',
      WorkerApplicationStatus.incomplete => 'Missing documents',
      WorkerApplicationStatus.pending => 'Pending approval',
      WorkerApplicationStatus.approved => 'Approved worker',
      WorkerApplicationStatus.rejected => 'Application rejected',
    };
    final message = switch (status) {
      WorkerApplicationStatus.notStarted ||
      WorkerApplicationStatus.incomplete =>
        'Complete approval before receiving offers.',
      WorkerApplicationStatus.pending => 'Waiting for owner approval.',
      WorkerApplicationStatus.approved => 'Eligible to receive offers.',
      WorkerApplicationStatus.rejected =>
        'Please update documents and resubmit.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status == WorkerApplicationStatus.approved
            ? Colors.green.withValues(alpha: 0.1)
            : kAccentYellow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(documentsSummary),
        ],
      ),
    );
  }
}

class _ApprovalProgress extends StatelessWidget {
  const _ApprovalProgress({required this.status});

  final WorkerApplicationStatus status;

  int get _step {
    return switch (status) {
      WorkerApplicationStatus.notStarted => 0,
      WorkerApplicationStatus.incomplete => 1,
      WorkerApplicationStatus.pending => 2,
      WorkerApplicationStatus.rejected => 2,
      WorkerApplicationStatus.approved => 3,
    };
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Profile details', 'Documents', 'Submitted', 'Approved'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= _step;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: active ? kAccentBlue : Colors.grey.shade300,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => Colors.green,
      'uploaded' ||
      'pending' ||
      'pendingReview' ||
      'pending_review' => Colors.amber.shade800,
      'rejected' => Colors.red,
      'suspended' => Colors.grey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.userPhone,
    required this.onSignOut,
  });

  final String userPhone;
  final VoidCallback onSignOut;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final AuthService _authService = AuthService();
  final JobService _jobService = JobService();
  final LocationSyncService _locationSyncService = LocationSyncService();
  final WorkerService _workerService = WorkerService();
  final MarketplaceService _marketplaceService = MarketplaceService();
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastLocationWriteAt;
  DemoMapPoint? _lastLocationWritePoint;
  String? _firebaseActiveJobId;
  bool _accepted = false;
  bool _rejected = false;
  int _jobStep = 1;
  bool _completionShown = false;
  OfferPayload? _activeOffer;
  MarketplaceDeliveryJob? _activeMarketplaceJob;
  DemoServiceJob? _selectedNearbyJob;
  MarketplaceDeliveryJob? _selectedMarketplaceJob;

  @override
  void initState() {
    super.initState();
    final activeJob = _assignedActiveJob;
    if (activeJob != null) {
      _accepted = true;
      _activeOffer = activeJob.offer;
    }
  }

  @override
  void dispose() {
    _stopFirebaseLocationStream();
    super.dispose();
  }

  DemoServiceJob? get _assignedActiveJob {
    for (final job in demoServiceJobs) {
      if ((job.status == DemoServiceJobStatus.active ||
              job.status == DemoServiceJobStatus.accepted) &&
          job.assignedWorkerId == 'demo-worker-1') {
        return job;
      }
    }
    return null;
  }

  List<DemoServiceJob> get _nearbyPendingJobs {
    if (!demoDriverAvailability.isOnline ||
        demoWorkerProfile.status != WorkerApplicationStatus.approved) {
      return const [];
    }
    return demoServiceJobs
        .where((job) => job.status == DemoServiceJobStatus.pending)
        .where(
          (job) =>
              demoDistanceKm(
                demoDriverAvailability.location,
                job.pickupPoint,
              ) <=
              80.47,
        )
        .toList();
  }

  List<MarketplaceDeliveryJob> _localMarketplaceDeliveryJobs() {
    if (!demoDriverAvailability.isOnline ||
        demoWorkerProfile.status != WorkerApplicationStatus.approved) {
      return const [];
    }
    return MarketplaceService.localMarketplaceOrders
        .where(
          (order) => order.status == backend.MarketplaceOrderStatus.pending,
        )
        .map((order) {
          final store = MarketplaceService.sampleStores.firstWhere(
            (candidate) => candidate.id == order.storeId,
            orElse: () => MarketplaceService.sampleStores.first,
          );
          return MarketplaceDeliveryJob(order: order, store: store);
        })
        .where(
          (job) =>
              demoDistanceKm(
                demoDriverAvailability.location,
                job.pickupPoint,
              ) <=
              80.47,
        )
        .toList();
  }

  OfferPayload get _currentOffer => _activeOffer ?? _previewOffer;

  OfferPayload get _previewOffer => OfferPayload(
    id: 'OPT-B-8891',
    service: ServiceType.ride,
    pickup: 'Current Location',
    destination: 'Hamra',
    offerAmount: 19,
    paymentMethod: PaymentMethod.cash,
    pickupPoint: kDemoPickupPoint,
    destinationPoint: const DemoMapPoint(33.8968, 35.4825),
  );

  DemoMapPoint get _driverPoint {
    if (!_accepted) {
      return demoDriverAvailability.location;
    }
    if (_activeMarketplaceJob != null) {
      final marketplaceJob = _activeMarketplaceJob!;
      if (_jobStep <= 3) {
        return DemoMapPoint.lerp(
          demoDriverAvailability.location,
          marketplaceJob.pickupPoint,
          (_jobStep / 3).clamp(0.0, 1.0),
        );
      }
      return DemoMapPoint.lerp(
        marketplaceJob.pickupPoint,
        marketplaceJob.destinationPoint,
        ((_jobStep - 3) / 2).clamp(0.0, 1.0),
      );
    }
    final offer = _currentOffer;
    final pickup = offer.pickupPoint ?? kDemoPickupPoint;
    final destination = offer.destinationPoint ?? kDemoDestinationPoint;
    if (_jobStep <= 3) {
      return DemoMapPoint.lerp(
        demoDriverAvailability.location,
        pickup,
        (_jobStep / 3).clamp(0.0, 1.0),
      );
    }
    return DemoMapPoint.lerp(
      pickup,
      destination,
      ((_jobStep - 3) / 2).clamp(0.0, 1.0),
    );
  }

  List<DemoMapPoint> get _driverRoutePoints {
    if (_activeMarketplaceJob != null) {
      return [
        _driverPoint,
        _activeMarketplaceJob!.pickupPoint,
        _activeMarketplaceJob!.destinationPoint,
      ];
    }
    return [
      _driverPoint,
      _currentOffer.pickupPoint ?? kDemoPickupPoint,
      _currentOffer.destinationPoint ?? kDemoDestinationPoint,
    ];
  }

  String get _jobStatus {
    switch (_jobStep) {
      case 1:
        return _activeMarketplaceJob == null
            ? 'Your OMW driver accepted the request'
            : 'Marketplace order accepted';
      case 2:
        return _activeMarketplaceJob == null
            ? 'OMW driver on the way'
            : 'Heading to store';
      case 3:
        return _activeMarketplaceJob == null
            ? 'Arrived at pickup'
            : 'Shopping/preparing';
      case 4:
        return _activeMarketplaceJob == null ? 'In progress' : 'On the way';
      default:
        return _activeMarketplaceJob == null ? 'Completed' : 'Delivered';
    }
  }

  Future<void> _useDriverLocation() async {
    final result = await LocationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      if (result.point != null) {
        demoDriverAvailability.location = result.point!;
        demoDriverAvailability.locationLabel = 'GPS driver location';
      } else {
        demoDriverAvailability.locationLabel = 'Default OMW driver location';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              (result.point != null
                  ? 'Driver location updated'
                  : 'Using default OMW driver location'),
        ),
      ),
    );
  }

  String _firebaseWorkerName() => demoWorkerProfile.fullName.trim().isEmpty
      ? 'OMW Driver'
      : demoWorkerProfile.fullName.trim();

  String _firebaseWorkerPhone() => demoWorkerProfile.phoneNumber.trim().isEmpty
      ? (_authService.currentUser?.phoneNumber ?? widget.userPhone)
      : demoWorkerProfile.phoneNumber.trim();

  Future<void> _setFirebaseOnline(bool online) async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to go online.')),
      );
      return;
    }
    if (!online) {
      await _stopFirebaseLocationStream();
      await _locationSyncService.setWorkerOffline(user.uid);
      await _workerService.setWorkerOffline(user.uid);
      if (!mounted) {
        return;
      }
      setState(() => demoDriverAvailability.isOnline = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are offline.')));
      return;
    }

    if (FirebaseService.instance.isReady) {
      final profile = await _workerService.getWorkerProfile(user.uid);
      final documents = await _workerService.getWorkerDocuments(user.uid);
      if (!mounted) {
        return;
      }
      if (profile?.status != backend.WorkerStatus.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please complete onboarding and wait for owner approval before going online.',
            ),
          ),
        );
        return;
      }
      if (profile?.agreementAccepted != true ||
          profile!.payoutMethod.isEmpty ||
          profile.payoutDisplayName.isEmpty ||
          profile.payoutPhoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please accept the worker agreement and complete payout details before going online.',
            ),
          ),
        );
        return;
      }
      if (!requiredWorkerDocumentsApproved(documents)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please complete your document verification before going online.',
            ),
          ),
        );
        return;
      }
    }

    final result = await LocationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    if (result.point == null) {
      final message = switch (result.status) {
        DemoLocationStatus.permissionDenied =>
          'Location permission denied. Enable it to go online.',
        DemoLocationStatus.permissionDeniedForever =>
          'Location permission is blocked. Please enable it from browser/app settings.',
        DemoLocationStatus.servicesDisabled =>
          'Enable location services to go online.',
        DemoLocationStatus.failed =>
          'Could not get your location. Try again to go online.',
        DemoLocationStatus.allowed => 'Could not get your location.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final point = result.point!;
    final workerName = _firebaseWorkerName();
    final workerPhone = _firebaseWorkerPhone();
    await _locationSyncService.setWorkerOnline(
      workerId: user.uid,
      workerName: workerName,
      workerPhone: workerPhone,
      lat: point.latitude,
      lng: point.longitude,
    );
    await _workerService.setWorkerOnline(
      user.uid,
      lat: point.latitude,
      lng: point.longitude,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      demoDriverAvailability.isOnline = true;
      demoDriverAvailability.location = point;
      demoDriverAvailability.locationLabel = 'Live OMW driver location';
      _rejected = false;
      _lastLocationWriteAt = DateTime.now();
      _lastLocationWritePoint = point;
    });
    _startFirebaseLocationStream(user.uid, workerName, workerPhone);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are online and visible to nearby customers'),
      ),
    );
  }

  void _startFirebaseLocationStream(
    String workerId,
    String workerName,
    String workerPhone,
  ) {
    _positionSubscription?.cancel();
    _positionSubscription = LocationService.positionStream().listen(
      (position) {
        final point = DemoMapPoint(position.latitude, position.longitude);
        final now = DateTime.now();
        final lastAt = _lastLocationWriteAt;
        final lastPoint = _lastLocationWritePoint;
        final movedMeters = lastPoint == null
            ? double.infinity
            : Geolocator.distanceBetween(
                lastPoint.latitude,
                lastPoint.longitude,
                point.latitude,
                point.longitude,
              );
        if (lastAt != null &&
            now.difference(lastAt) < const Duration(seconds: 5) &&
            movedMeters < 25) {
          return;
        }
        _lastLocationWriteAt = now;
        _lastLocationWritePoint = point;
        demoDriverAvailability.location = point;
        demoDriverAvailability.locationLabel = 'Live OMW driver location';
        if (mounted) {
          setState(() {});
        }
        _locationSyncService.updateDriverLocation(
          backend.DriverLocation(
            workerId: workerId,
            workerName: workerName,
            workerPhone: workerPhone,
            lat: position.latitude,
            lng: position.longitude,
            heading: position.heading.isNaN ? 0 : position.heading,
            speed: position.speed.isNaN ? 0 : position.speed,
            isOnline: true,
            activeJobId: _firebaseActiveJobId,
            updatedAt: now,
          ),
        );
      },
      onError: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver location is temporarily unavailable.'),
            ),
          );
        }
      },
    );
  }

  Future<void> _stopFirebaseLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _firebaseActiveJobId = null;
  }

  Future<void> _rejectOffer(OfferPayload offer) async {
    if (useFirebaseJobs) {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to reject this offer.'),
          ),
        );
        return;
      }
      try {
        await _jobService.rejectJob(offer.id, workerId: user.uid);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer rejected. Staying online.')),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reject this offer. Please try again.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _rejected = false;
      _selectedNearbyJob = null;
      upsertDemoJob(offer, DemoJobStatus.rejected);
      rejectServiceJob(offer);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer rejected. Staying online.')),
    );
  }

  Future<void> _rejectMarketplaceOrder(MarketplaceDeliveryJob job) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marketplace order skipped.')));
    setState(() => _selectedMarketplaceJob = null);
  }

  Future<void> _acceptOffer(OfferPayload offer) async {
    if (useFirebaseJobs) {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to accept this offer.'),
          ),
        );
        return;
      }
      final workerName = demoWorkerProfile.fullName.trim().isEmpty
          ? 'OMW Driver'
          : demoWorkerProfile.fullName.trim();
      final workerPhone = demoWorkerProfile.phoneNumber.trim().isEmpty
          ? (user.phoneNumber ?? widget.userPhone)
          : demoWorkerProfile.phoneNumber.trim();
      try {
        await _jobService.acceptJob(
          jobId: offer.id,
          workerId: user.uid,
          workerName: workerName,
          workerPhone: workerPhone,
        );
        _firebaseActiveJobId = offer.id;
        await _locationSyncService.bindLocationToActiveJob(
          workerId: user.uid,
          jobId: offer.id,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _accepted = true;
          _activeOffer = offer;
          _selectedNearbyJob = null;
          _rejected = false;
          _jobStep = 1;
          _completionShown = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer accepted. Customer notified.')),
        );
      } on StateError catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not accept this offer. Please try again.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _accepted = true;
      _activeOffer = offer;
      _selectedNearbyJob = null;
      _rejected = false;
      _jobStep = 1;
      _completionShown = false;
      upsertDemoJob(offer, DemoJobStatus.accepted);
      assignServiceJob(offer, demoDrivers(offer.service).first);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer accepted. Customer notified.')),
    );
  }

  Future<void> _acceptMarketplaceOrder(MarketplaceDeliveryJob job) async {
    final workerId = useFirebaseJobs
        ? _authService.currentUser?.uid ?? 'demo-worker-1'
        : 'demo-worker-1';
    final workerName = _firebaseWorkerName();
    final workerPhone = _firebaseWorkerPhone();
    try {
      await _marketplaceService.acceptMarketplaceOrder(
        job.order.id,
        workerId,
        workerName: workerName,
        workerPhone: workerPhone,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _accepted = true;
        _activeOffer = null;
        _activeMarketplaceJob = job;
        _selectedNearbyJob = null;
        _selectedMarketplaceJob = null;
        _rejected = false;
        _jobStep = 1;
        _completionShown = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marketplace order accepted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is StateError
          ? error.message
          : 'Could not accept this marketplace order.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _selectNearbyOffer(DemoServiceJob job, {bool openDetail = true}) {
    setState(() => _selectedNearbyJob = job);
    if (openDetail) {
      _showNearbyOfferSheet(job);
    }
  }

  void _showNearbyOfferSheet(DemoServiceJob job) {
    final offer = job.offer;
    final distanceKm = demoDistanceKm(
      demoDriverAvailability.location,
      job.pickupPoint,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        offer.id,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _KeyValueRow(
                        label: 'Service',
                        value: serviceLabel(offer.service),
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(label: 'Pickup', value: offer.pickup),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Destination',
                        value: offer.destination,
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Customer offer',
                        value: '\$${offer.offerAmount}',
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Payment',
                        value: paymentLabel(offer.paymentMethod),
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(label: 'Customer', value: job.customerName),
                      const SizedBox(height: 8),
                      _KeyValueRow(label: 'Phone', value: job.customerPhone),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Distance/ETA',
                        value:
                            '${distanceKm.toStringAsFixed(1)} km to pickup - ${math.max(2, (distanceKm / 35 * 60).round())} min',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => showDemoCallDialog(
                                context,
                                title: 'Calling ${job.customerName}',
                              ),
                              icon: const Icon(Icons.call),
                              label: const Text('Call'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const DemoChatScreen(
                                    title: 'Customer',
                                    meLabel: 'Driver',
                                    themLabel: 'Customer',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _rejectOffer(offer);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _acceptOffer(offer);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kAccentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectMarketplaceOrder(
    MarketplaceDeliveryJob job, {
    bool openDetail = true,
  }) {
    setState(() => _selectedMarketplaceJob = job);
    if (openDetail) {
      _showMarketplaceOrderSheet(job);
    }
  }

  void _showMarketplaceOrderSheet(MarketplaceDeliveryJob job) {
    final order = job.order;
    final distanceKm = demoDistanceKm(
      demoDriverAvailability.location,
      job.pickupPoint,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Marketplace Order',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _KeyValueRow(label: 'Store', value: order.storeName),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Items',
                        value: '${order.itemCount} items',
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Products',
                        value: marketplaceItemSummary(order.items),
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(label: 'Pickup', value: job.storeAddress),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Deliver to',
                        value: order.deliveryLabel,
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Order total',
                        value: '\$${order.total.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Payment',
                        value: paymentLabel(
                          paymentMethodFromBackend(order.paymentMethod),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Customer',
                        value: order.customerPhone,
                      ),
                      const SizedBox(height: 8),
                      _KeyValueRow(
                        label: 'Distance/ETA',
                        value:
                            '${distanceKm.toStringAsFixed(1)} km to store - ${math.max(2, (distanceKm / 35 * 60).round())} min',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => showDemoCallDialog(
                                context,
                                title: 'Calling marketplace customer',
                              ),
                              icon: const Icon(Icons.call),
                              label: const Text('Call'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const DemoChatScreen(
                                    title: 'Marketplace Customer',
                                    meLabel: 'Courier',
                                    themLabel: 'Customer',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _rejectMarketplaceOrder(job);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _acceptMarketplaceOrder(job);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kAccentYellow,
                          foregroundColor: kBrandBlack,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _advanceJob(OfferPayload offer) async {
    if (_jobStep >= 5) {
      return;
    }
    setState(() => _jobStep++);
    if (_activeMarketplaceJob != null && _jobStep < 5) {
      final nextStatus = switch (_jobStep) {
        1 => backend.MarketplaceOrderStatus.accepted,
        2 => backend.MarketplaceOrderStatus.shopping,
        3 => backend.MarketplaceOrderStatus.pickedUp,
        _ => backend.MarketplaceOrderStatus.onTheWay,
      };
      await _marketplaceService.updateMarketplaceOrderStatus(
        _activeMarketplaceJob!.order.id,
        nextStatus,
      );
      return;
    }
    if (_jobStep >= 5) {
      if (_activeMarketplaceJob != null) {
        try {
          await _marketplaceService.completeMarketplaceOrder(
            _activeMarketplaceJob!.order.id,
          );
          final completedOffer = OfferPayload(
            id: _activeMarketplaceJob!.order.id,
            service: ServiceType.courier,
            pickup: _activeMarketplaceJob!.storeAddress,
            destination: _activeMarketplaceJob!.order.deliveryLabel,
            offerAmount: math.max(
              1,
              _activeMarketplaceJob!.order.deliveryFee.round(),
            ),
            paymentMethod: paymentMethodFromBackend(
              _activeMarketplaceJob!.order.paymentMethod,
            ),
            pickupPoint: _activeMarketplaceJob!.pickupPoint,
            destinationPoint: _activeMarketplaceJob!.destinationPoint,
          );
          upsertDemoJob(completedOffer, DemoJobStatus.completed);
          if (!mounted) {
            return;
          }
          setState(() => _activeMarketplaceJob = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marketplace order delivered.')),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not complete this marketplace order.'),
              ),
            );
          }
        }
        return;
      }
      if (useFirebaseJobs) {
        try {
          await _jobService.completeJob(offer.id);
          final user = _authService.currentUser;
          if (user != null) {
            await _locationSyncService.clearActiveJob(user.uid);
            _firebaseActiveJobId = null;
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not complete this OMW job. Please try again.',
                ),
              ),
            );
          }
          return;
        }
      }
      upsertDemoJob(offer, DemoJobStatus.completed);
      completeServiceJob(offer);
      saveCompletedOfferHistory(offer, demoDrivers(offer.service).first);
      _showCompletionSummary(offer);
    }
  }

  void _showCompletionSummary(OfferPayload offer) {
    if (_completionShown) {
      return;
    }
    _completionShown = true;
    final job = findDemoJob(offer.id);
    if (job == null) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Job completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gross fare: \$${job.grossFare.toStringAsFixed(2)}'),
            Text(
              'Platform commission: \$${job.platformCommission.toStringAsFixed(2)}',
            ),
            Text('Driver payout: \$${job.driverPayout.toStringAsFixed(2)}'),
            Text('Payment: ${paymentLabel(job.offer.paymentMethod)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessChecklist({
    required bool documentsApproved,
    required bool ownerApproved,
  }) {
    final profile = demoWorkerProfile;
    final items = [
      ('Agreement accepted', profile.agreementAccepted),
      ('Payout method added', profile.payoutMethod.trim().isNotEmpty),
      ('Required documents uploaded', documentsApproved),
      (
        documentsApproved ? 'Documents approved' : 'Documents pending review',
        documentsApproved,
      ),
      ('Owner approval', ownerApproved),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E1D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Worker readiness checklist',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: item.$2 ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineControl(bool online) {
    final user = _authService.currentUser;
    if (FirebaseService.instance.isReady && user != null) {
      return StreamBuilder<List<backend.WorkerDocument>>(
        stream: _workerService.watchWorkerDocuments(user.uid),
        builder: (context, snapshot) {
          final documents = snapshot.data ?? const <backend.WorkerDocument>[];
          final documentsApproved = requiredWorkerDocumentsApproved(documents);
          final ownerApproved =
              demoWorkerProfile.status == WorkerApplicationStatus.approved;
          final canGoOnline =
              demoWorkerProfile.agreementAccepted &&
              demoWorkerProfile.payoutMethod.trim().isNotEmpty &&
              documentsApproved &&
              ownerApproved;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canGoOnline) ...[
                _buildReadinessChecklist(
                  documentsApproved: documentsApproved,
                  ownerApproved: ownerApproved,
                ),
                const SizedBox(height: 16),
              ],
              _OnlineStatusCard(
                online: online,
                enabled: canGoOnline,
                onChanged: _setFirebaseOnline,
              ),
            ],
          );
        },
      );
    }
    final canGoOnline =
        demoWorkerProfile.status == WorkerApplicationStatus.approved &&
        demoWorkerProfile.agreementAccepted &&
        demoWorkerProfile.payoutMethod.trim().isNotEmpty &&
        demoWorkerProfile.allDocumentsUploaded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canGoOnline) ...[
          _buildReadinessChecklist(
            documentsApproved: demoWorkerProfile.allDocumentsUploaded,
            ownerApproved:
                demoWorkerProfile.status == WorkerApplicationStatus.approved,
          ),
          const SizedBox(height: 16),
        ],
        _OnlineStatusCard(
          online: online,
          enabled: canGoOnline,
          onChanged: (value) {
            if (!canGoOnline && value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please complete onboarding and wait for owner approval before going online.',
                  ),
                ),
              );
              return;
            }
            setState(() {
              demoDriverAvailability.isOnline = value;
              if (value) {
                _rejected = false;
              }
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _currentOffer;
    final nearbyJobs = _nearbyPendingJobs;
    final online = demoDriverAvailability.isOnline;
    final summary = driverEarningsSummary();
    final userId = _authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: OmwBackButton(
          fallback: () => switchAccountFrom(context, widget.onSignOut),
        ),
        title: const Text('OMW Driver'),
        actions: [
          OmwNotificationBell(userId: userId, roleTarget: 'worker'),
          TextButton.icon(
            onPressed: () => switchAccountFrom(context, widget.onSignOut),
            icon: const Icon(Icons.logout),
            label: const Text('Switch'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'OMW Driver profile',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBrandSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: kAccentYellow,
                    child: Icon(Icons.person, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OMW Driver',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.userPhone,
                          style: TextStyle(
                            color: kMutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ComplianceStatusCard(
              status: demoWorkerProfile.status,
              documentsSummary: demoWorkerProfile.documentsSummary,
            ),
            const SizedBox(height: 16),
            _buildOnlineControl(online),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Current driver location',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    demoDriverAvailability.locationLabel,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _useDriverLocation,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Use my current location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: kAccentBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DriverDashboardSummary(summary: summary),
            const SizedBox(height: 16),
            _PayoutCard(summary: summary),
            const SizedBox(height: 16),
            if (demoWorkerProfile.status != WorkerApplicationStatus.approved)
              _StateMessage(
                icon: Icons.verified_user_outlined,
                text: 'Complete approval before receiving offers.',
              )
            else if (!online)
              _StateMessage(
                icon: Icons.pause_circle_outline,
                text: 'Go online to receive OMW requests.',
              )
            else if (_rejected)
              _StateMessage(
                icon: Icons.block,
                text: 'Offer rejected. Waiting for the next OMW request.',
              )
            else ...[
              if (useFirebaseJobs) ...[
                _WorkerServiceRequestsPanel(
                  workerId: AuthService().currentUser?.uid ?? '',
                  workerName: _firebaseWorkerName(),
                  workerPhone: _firebaseWorkerPhone(),
                ),
                const SizedBox(height: 16),
              ],
              if (!_accepted) ...[
                if (useFirebaseJobs)
                  _FirebaseDriverNearbyQueue(
                    jobService: _jobService,
                    marketplaceService: _marketplaceService,
                    driverPoint: demoDriverAvailability.location,
                    selectedJob: _selectedNearbyJob,
                    selectedMarketplaceJob: _selectedMarketplaceJob,
                    onSelectJob: (job) =>
                        _selectNearbyOffer(job, openDetail: false),
                    onOpenJobDetail: _selectNearbyOffer,
                    onSelectMarketplaceJob: (job) =>
                        _selectMarketplaceOrder(job, openDetail: false),
                    onOpenMarketplaceDetail: _selectMarketplaceOrder,
                  )
                else
                  _DriverNearbyOffersPanel(
                    jobs: nearbyJobs,
                    marketplaceJobs: _localMarketplaceDeliveryJobs(),
                    driverPoint: demoDriverAvailability.location,
                    selectedJob: _selectedNearbyJob,
                    selectedMarketplaceJob: _selectedMarketplaceJob,
                    onSelect: (job) =>
                        _selectNearbyOffer(job, openDetail: false),
                    onOpenDetail: _selectNearbyOffer,
                    onSelectMarketplace: (job) =>
                        _selectMarketplaceOrder(job, openDetail: false),
                    onOpenMarketplaceDetail: _selectMarketplaceOrder,
                  ),
              ] else ...[
                const SizedBox(height: 16),
                _StateMessage(
                  icon: Icons.check_circle,
                  text: 'Accepted. Head to pickup and start the OMW job.',
                ),
                const SizedBox(height: 16),
                _DriverActiveJobPanel(
                  offer: o,
                  marketplaceJob: _activeMarketplaceJob,
                  status: _jobStatus,
                  driverPoint: _driverPoint,
                  routePoints: _driverRoutePoints,
                  navigateLabel: _jobStep < 3
                      ? 'Navigate to pickup'
                      : 'Navigate to destination',
                  onNavigate: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation started')),
                    );
                  },
                  onCall: () =>
                      showDemoCallDialog(context, title: 'Calling customer'),
                  onMessage: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DemoChatScreen(
                        title: 'Customer',
                        meLabel: 'Driver',
                        themLabel: 'Customer',
                      ),
                    ),
                  ),
                  onNextStep: _jobStep >= 5 ? null : () => _advanceJob(o),
                ),
              ],
            ],
            const SizedBox(height: 16),
            _DriverJobsPreview(jobs: demoDriverJobs),
          ],
        ),
      ),
    );
  }
}

class _WorkerServiceRequestsPanel extends StatelessWidget {
  const _WorkerServiceRequestsPanel({
    required this.workerId,
    required this.workerName,
    required this.workerPhone,
  });

  final String workerId;
  final String workerName;
  final String workerPhone;

  @override
  Widget build(BuildContext context) {
    if (workerId.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<ServiceRequest>>(
      stream: RequestService().watchWorkerAssignedRequests(workerId),
      builder: (context, assignedSnapshot) {
        final assigned = assignedSnapshot.data ?? const <ServiceRequest>[];
        final active = assigned
            .where((request) => !request.isDone)
            .take(1)
            .toList();
        final completed = assigned
            .where(
              (request) => request.status == ServiceRequestStatus.completed,
            )
            .take(3)
            .toList();
        return StreamBuilder<List<ServiceRequest>>(
          stream: RequestService().watchWorkerAvailableRequests(workerId),
          builder: (context, availableSnapshot) {
            final available =
                availableSnapshot.data ?? const <ServiceRequest>[];
            final loading =
                assignedSnapshot.connectionState == ConnectionState.waiting ||
                availableSnapshot.connectionState == ConnectionState.waiting;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WorkerRequestSectionShell(
                  title: 'Assigned OMW request',
                  loading: loading,
                  emptyText: 'No active assigned request.',
                  children: active
                      .map(
                        (request) => _WorkerAssignedRequestCard(
                          request: request,
                          workerId: workerId,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                _WorkerRequestSectionShell(
                  title: 'Available matching requests',
                  loading: loading,
                  emptyText:
                      'No matching ride, moto, courier, or delivery requests right now.',
                  children: available
                      .take(5)
                      .map(
                        (request) => _WorkerAvailableRequestCard(
                          request: request,
                          workerId: workerId,
                          workerName: workerName,
                          workerPhone: workerPhone,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                _WorkerRequestSectionShell(
                  title: 'Completed request history',
                  loading: loading,
                  emptyText: 'Completed service requests will appear here.',
                  children: completed
                      .map(
                        (request) =>
                            _WorkerCompletedRequestTile(request: request),
                      )
                      .toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WorkerRequestSectionShell extends StatelessWidget {
  const _WorkerRequestSectionShell({
    required this.title,
    required this.loading,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final bool loading;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _WorkerAvailableRequestCard extends StatelessWidget {
  const _WorkerAvailableRequestCard({
    required this.request,
    required this.workerId,
    required this.workerName,
    required this.workerPhone,
  });

  final ServiceRequest request;
  final String workerId;
  final String workerName;
  final String workerPhone;

  Future<void> _accept(BuildContext context) async {
    try {
      await RequestService().acceptRequest(
        requestId: request.id,
        workerId: workerId,
        workerName: workerName,
        workerPhone: workerPhone,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request accepted.')));
    } on RequestAcceptException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept this request.')),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    try {
      await RequestService().rejectRequest(
        requestId: request.id,
        workerId: workerId,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not skip this request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WorkerRequestCardShell(
      request: request,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => _reject(context),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () => _accept(context),
            style: FilledButton.styleFrom(
              backgroundColor: kAccentYellow,
              foregroundColor: kBrandBlack,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

class _WorkerAssignedRequestCard extends StatelessWidget {
  const _WorkerAssignedRequestCard({
    required this.request,
    required this.workerId,
  });

  final ServiceRequest request;
  final String workerId;

  ServiceRequestStatus? get _nextStatus {
    final status = request.status;
    if (request.serviceType == 'ride' || request.serviceType == 'moto') {
      return switch (status) {
        ServiceRequestStatus.accepted => ServiceRequestStatus.workerOnWay,
        ServiceRequestStatus.workerOnWay => ServiceRequestStatus.arrived,
        ServiceRequestStatus.arrived => ServiceRequestStatus.inProgress,
        ServiceRequestStatus.inProgress => ServiceRequestStatus.completed,
        _ => null,
      };
    }
    if (request.serviceType == 'courier') {
      return switch (status) {
        ServiceRequestStatus.accepted => ServiceRequestStatus.pickupStarted,
        ServiceRequestStatus.pickupStarted => ServiceRequestStatus.pickedUp,
        ServiceRequestStatus.pickedUp => ServiceRequestStatus.deliveryStarted,
        ServiceRequestStatus.deliveryStarted => ServiceRequestStatus.delivered,
        ServiceRequestStatus.delivered => ServiceRequestStatus.completed,
        _ => null,
      };
    }
    return switch (status) {
      ServiceRequestStatus.accepted => ServiceRequestStatus.pickupStarted,
      ServiceRequestStatus.pickupStarted => ServiceRequestStatus.pickedUp,
      ServiceRequestStatus.pickedUp => ServiceRequestStatus.onTheWay,
      ServiceRequestStatus.onTheWay => ServiceRequestStatus.delivered,
      ServiceRequestStatus.delivered => ServiceRequestStatus.completed,
      _ => null,
    };
  }

  Future<void> _advance(BuildContext context) async {
    final next = _nextStatus;
    if (next == null) {
      return;
    }
    try {
      await RequestService().updateRequestStatus(
        requestId: request.id,
        status: next,
        workerId: workerId,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update request status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus;
    return _WorkerRequestCardShell(
      request: request,
      trailing: next == null
          ? null
          : FilledButton.icon(
              onPressed: () => _advance(context),
              icon: Icon(
                next == ServiceRequestStatus.completed
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward,
              ),
              label: Text(
                next == ServiceRequestStatus.completed
                    ? 'Complete'
                    : serviceRequestStatusLabel(next),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kAccentYellow,
                foregroundColor: kBrandBlack,
              ),
            ),
    );
  }
}

class _WorkerCompletedRequestTile extends StatelessWidget {
  const _WorkerCompletedRequestTile({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    return _WorkerRequestCardShell(request: request);
  }
}

class _WorkerRequestCardShell extends StatelessWidget {
  const _WorkerRequestCardShell({required this.request, this.trailing});

  final ServiceRequest request;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  serviceRequestLabel(request.serviceType),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                serviceRequestStatusLabel(request.status),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${request.pickupAddress} - ${request.dropoffAddress}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (request.customerName.trim().isNotEmpty)
                'Customer: ${request.customerName}',
              if (request.customerPhone.trim().isNotEmpty)
                request.customerPhone,
              if (request.totalAmount != null)
                '\$${request.totalAmount!.toStringAsFixed(2)}',
            ].join(' - '),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (request.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(request.notes!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
  }
}

class DriverJobsHistoryScreen extends StatelessWidget {
  const DriverJobsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const OmwBackButton(),
        title: const Text('OMW Driver Earnings'),
      ),
      body: SafeArea(
        child: demoDriverJobs.isEmpty
            ? const Center(child: Text('No OMW driver jobs yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: demoDriverJobs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _DriverJobCard(job: demoDriverJobs[index]);
                },
              ),
      ),
    );
  }
}

class _DriverJobCard extends StatelessWidget {
  const _DriverJobCard({required this.job});

  final DemoJob job;

  @override
  Widget build(BuildContext context) {
    final o = job.offer;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(serviceIcon(o.service), color: kAccentBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    o.id,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  jobStatusLabel(job.status),
                  style: TextStyle(
                    color: job.status == DemoJobStatus.rejected
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            _KeyValueRow(label: 'Service', value: serviceLabel(o.service)),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Pickup', value: o.pickup),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Destination', value: o.destination),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Customer', value: job.customerName),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Fare',
              value: '\$${job.grossFare.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Payment',
              value: paymentLabel(o.paymentMethod),
            ),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Net',
              value: job.status == DemoJobStatus.rejected
                  ? '\$0.00'
                  : '\$${job.driverPayout.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Date', value: _dateLabel(job.dateTime)),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return 'Today $hour:$minute';
  }
}

class _DriverActiveJobPanel extends StatelessWidget {
  const _DriverActiveJobPanel({
    required this.offer,
    this.marketplaceJob,
    required this.status,
    required this.driverPoint,
    required this.routePoints,
    required this.navigateLabel,
    required this.onNavigate,
    required this.onCall,
    required this.onMessage,
    required this.onNextStep,
  });

  final OfferPayload offer;
  final MarketplaceDeliveryJob? marketplaceJob;
  final String status;
  final DemoMapPoint driverPoint;
  final List<DemoMapPoint> routePoints;
  final String navigateLabel;
  final VoidCallback onNavigate;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback? onNextStep;

  @override
  Widget build(BuildContext context) {
    final isMarketplace = marketplaceJob != null;
    final pickup = isMarketplace
        ? marketplaceJob!.pickupPoint
        : offer.pickupPoint ?? kDemoPickupPoint;
    final destination = isMarketplace
        ? marketplaceJob!.destinationPoint
        : offer.destinationPoint ?? kDemoDestinationPoint;
    final detailText = isMarketplace
        ? '${marketplaceJob!.order.storeName} to ${marketplaceJob!.order.deliveryLabel} - ${paymentLabel(paymentMethodFromBackend(marketplaceJob!.order.paymentMethod))}'
        : '${offer.pickup} to ${offer.destination} - ${paymentLabel(offer.paymentMethod)}';
    final moneyText = isMarketplace
        ? 'Order: \$${marketplaceJob!.order.total.toStringAsFixed(2)} - Delivery fee: \$${marketplaceJob!.order.deliveryFee.toStringAsFixed(2)}'
        : 'Fare: \$${offer.offerAmount.toStringAsFixed(2)} - Expected payout: \$${(offer.offerAmount * 0.85).toStringAsFixed(2)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppMap(
            pickup: pickup,
            destination: destination,
            driver: driverPoint,
            routePoints: routePoints,
            cameraUpdateKey: status.hashCode,
            height: 210,
            showRoute: true,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kAccentBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                status,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detailText,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                moneyText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Approx. route',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryCtaButton(label: navigateLabel, onPressed: onNavigate),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: kAccentBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: kAccentBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onNextStep,
          icon: const Icon(Icons.skip_next),
          label: const Text('Simulate next step'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: kAccentBlue,
          ),
        ),
      ],
    );
  }
}

Future<void> showDemoCallDialog(BuildContext context, {required String title}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DemoCallDialog(title: title),
  );
}

class _DemoCallDialog extends StatefulWidget {
  const _DemoCallDialog({required this.title});

  final String title;

  @override
  State<_DemoCallDialog> createState() => _DemoCallDialogState();
}

class _DemoCallDialogState extends State<_DemoCallDialog> {
  String _status = 'Ringing';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _status = 'Connected');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Row(
        children: [
          const Icon(Icons.call, color: kAccentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _status,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('End Call'),
        ),
      ],
    );
  }
}
