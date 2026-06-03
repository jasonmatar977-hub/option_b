part of '../../main.dart';

InputDecoration _storeOwnerInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: false,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon == null ? null : Icon(icon, color: kDeepGold),
    labelStyle: const TextStyle(
      color: kBrandBlack,
      fontWeight: FontWeight.w800,
    ),
    floatingLabelStyle: const TextStyle(
      color: kAccentYellow,
      fontWeight: FontWeight.w900,
    ),
    hintStyle: TextStyle(color: Colors.grey.shade500),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kAccentYellow, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade700),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade700, width: 2),
    ),
  );
}

const TextStyle _storeOwnerInputTextStyle = TextStyle(
  color: Colors.black87,
  fontWeight: FontWeight.w700,
);

const List<String> _storeTimeOptions = [
  '06:00',
  '07:00',
  '08:00',
  '09:00',
  '10:00',
  '11:00',
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
  '18:00',
  '19:00',
  '20:00',
  '21:00',
  '22:00',
  '23:00',
];

const DemoMapPoint _defaultStorePoint = DemoMapPoint(33.8938, 35.5018);

class StoreOwnerDashboardScreen extends StatefulWidget {
  const StoreOwnerDashboardScreen({
    super.key,
    required this.userPhone,
    required this.onSignOut,
  });

  final String userPhone;
  final VoidCallback onSignOut;

  @override
  State<StoreOwnerDashboardScreen> createState() =>
      _StoreOwnerDashboardScreenState();
}

class _StoreOwnerDashboardScreenState extends State<StoreOwnerDashboardScreen> {
  final StoreCrmService _service = StoreCrmService();
  bool _editingProfile = false;

  String get _ownerId => AuthService().currentUser?.uid ?? 'local-store-owner';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.MarketplaceStore>>(
      stream: _service.watchStoresForOwner(_ownerId),
      builder: (context, storeSnapshot) {
        final stores = storeSnapshot.data ?? const <backend.MarketplaceStore>[];
        final store = stores.isEmpty ? null : stores.first;
        final status = store?.status ?? 'not_created';
        final approved = status == 'approved' || status == 'active';
        final showProfileForm =
            store == null || _editingProfile || status == 'rejected';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Store Owner Dashboard'),
            actions: [
              OmwNotificationBell(userId: _ownerId, roleTarget: 'store_owner'),
              IconButton(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (showProfileForm) ...[
                  _StoreProfileCard(
                    ownerId: _ownerId,
                    userPhone: widget.userPhone,
                    store: store,
                    onSave: _saveStoreProfile,
                    onToggleOpen: store == null
                        ? null
                        : (value) => _service.setStoreOpen(store.id, value),
                  ),
                  const SizedBox(height: 16),
                  if (store == null)
                    const _StateMessage(
                      icon: Icons.storefront_outlined,
                      text:
                          'Create your store profile and submit it for admin approval.',
                    ),
                ] else ...[
                  _StoreOwnerHomeCard(
                    store: store,
                    onEditProfile: () => setState(() => _editingProfile = true),
                  ),
                ],
                const SizedBox(height: 16),
                if (store != null && !approved)
                  _StoreApprovalStatusCard(
                    store: store,
                    onEditProfile: () => setState(() => _editingProfile = true),
                  )
                else if (store != null && approved)
                  _StoreCrmBody(store: store, service: _service),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveStoreProfile(backend.MarketplaceStore store) async {
    try {
      await _service.upsertStore(store);
      if (!mounted) return;
      setState(() => _editingProfile = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store profile submitted.')));
    } on FirebaseException catch (error) {
      debugPrint(
        '[StoreOwner] Save store profile FirebaseException: '
        '${error.code} ${error.message}',
      );
      if (!mounted) return;
      final message = switch (error.code) {
        'permission-denied' =>
          'You do not have permission to save this store profile. Please sign out and sign in again as Store Owner.',
        'unauthenticated' => 'Please sign in again before saving.',
        _ => 'Could not save store profile: ${error.code}',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      debugPrint('[StoreOwner] Save store profile failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save store profile.')),
      );
    }
  }
}

class _StoreImageUploadCell extends StatelessWidget {
  const _StoreImageUploadCell({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.placeholder,
    required this.onUpload,
  });

  final String label;
  final String imageUrl;
  final bool uploading;
  final IconData placeholder;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder,
                      )
                    : _placeholder,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : onUpload,
                  icon: uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kAccentYellow,
                          ),
                        )
                      : const Icon(Icons.upload_outlined, size: 16),
                  label: Text(
                    imageUrl.isNotEmpty ? 'Replace' : 'Upload',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentYellow,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget get _placeholder => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white24),
    ),
    child: Icon(placeholder, color: Colors.white38, size: 22),
  );
}

class _StoreOwnerHomeCard extends StatelessWidget {
  const _StoreOwnerHomeCard({required this.store, required this.onEditProfile});

  final backend.MarketplaceStore store;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OmwNetworkImage(
                url: store.imageUrl,
                width: 58,
                height: 58,
                borderRadius: 14,
                placeholder: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: kAccentYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: kAccentYellow,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${backend.marketplaceCategoryLabel(store.category)} - ${store.isOpen ? 'Open' : 'Closed'}',
                      style: const TextStyle(
                        color: kMutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StoreOwnerSummaryChip(label: 'Status', value: store.status),
              _StoreOwnerSummaryChip(
                label: 'Hours',
                value: store.openingHoursLabel.isEmpty
                    ? 'Not set'
                    : store.openingHoursLabel,
              ),
              _StoreOwnerSummaryChip(
                label: 'Location',
                value: store.address.isEmpty ? 'Not set' : store.address,
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
            style: FilledButton.styleFrom(
              backgroundColor: kAccentYellow,
              foregroundColor: kBrandBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreApprovalStatusCard extends StatelessWidget {
  const _StoreApprovalStatusCard({
    required this.store,
    required this.onEditProfile,
  });

  final backend.MarketplaceStore store;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final rejected = store.status == 'rejected';
    final suspended = store.status == 'suspended';
    final title = rejected
        ? 'Store profile rejected'
        : suspended
        ? 'Store suspended'
        : 'Store profile pending approval';
    final text = rejected
        ? 'Review the reason, edit your profile, and resubmit for approval.'
        : suspended
        ? 'Your store is suspended. Contact OMW admin before making changes.'
        : 'Your store profile is pending admin approval.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rejected || suspended ? Colors.red.shade200 : kAccentYellow,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                rejected || suspended
                    ? Icons.error_outline
                    : Icons.hourglass_top_outlined,
                color: rejected || suspended ? Colors.red.shade700 : kDeepGold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (store.rejectionReason?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${store.rejectionReason}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: suspended ? null : onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: Text(rejected ? 'Edit and resubmit' : 'Edit profile'),
          ),
        ],
      ),
    );
  }
}

class _StoreOwnerSummaryChip extends StatelessWidget {
  const _StoreOwnerSummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StoreCrmBody extends StatelessWidget {
  const _StoreCrmBody({required this.store, required this.service});

  final backend.MarketplaceStore store;
  final StoreCrmService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.MarketplaceProduct>>(
      stream: service.watchProducts(store.id),
      builder: (context, productSnapshot) {
        final products =
            productSnapshot.data ?? const <backend.MarketplaceProduct>[];
        return StreamBuilder<List<backend.MarketplaceOrder>>(
          stream: service.watchOrders(store.id),
          builder: (context, orderSnapshot) {
            final orders =
                orderSnapshot.data ?? const <backend.MarketplaceOrder>[];
            return StreamBuilder<List<StoreExpense>>(
              stream: service.watchExpenses(store.id),
              builder: (context, expenseSnapshot) {
                final expenses = expenseSnapshot.data ?? const <StoreExpense>[];
                final money = service.moneySnapshot(
                  orders: orders,
                  products: products,
                  expenses: expenses,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StoreOverviewGrid(
                      store: store,
                      products: products,
                      orders: orders,
                    ),
                    const SizedBox(height: 16),
                    _StoreMoneyCard(snapshot: money),
                    const SizedBox(height: 16),
                    _StoreInventoryCard(
                      store: store,
                      products: products,
                      service: service,
                    ),
                    const SizedBox(height: 16),
                    _StoreOrdersCard(orders: orders, service: service),
                    const SizedBox(height: 16),
                    _StoreExpensesCard(
                      storeId: store.id,
                      expenses: expenses,
                      service: service,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StoreProfileCard extends StatefulWidget {
  const _StoreProfileCard({
    required this.ownerId,
    required this.userPhone,
    required this.store,
    required this.onSave,
    required this.onToggleOpen,
  });

  final String ownerId;
  final String userPhone;
  final backend.MarketplaceStore? store;
  final ValueChanged<backend.MarketplaceStore> onSave;
  final ValueChanged<bool>? onToggleOpen;

  @override
  State<_StoreProfileCard> createState() => _StoreProfileCardState();
}

class _StoreProfileCardState extends State<_StoreProfileCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  final GooglePlacesService _placesService = const GooglePlacesService();
  bool _delivery = true;
  bool _pickup = true;
  bool _freeDeliveryEnabled = false;
  bool _firstOrderDealEnabled = false;
  bool _discountEnabled = false;
  final TextEditingController _discountLabelCtrl = TextEditingController();
  String _category = backend.marketplaceCategoryOptions.first.value;
  List<String> _daysOpen = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  String _openTime = '09:00';
  String _closeTime = '20:00';
  String _placeId = '';
  String _cityArea = '';
  DemoMapPoint? _storePoint;
  List<PlaceSuggestion> _addressSuggestions = const [];
  String _logoUrl = '';
  String _coverUrl = '';
  bool _uploadingLogo = false;
  bool _uploadingCover = false;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    _nameCtrl = TextEditingController(text: store?.name ?? '');
    _descriptionCtrl = TextEditingController(text: store?.description ?? '');
    _phoneCtrl = TextEditingController(
      text: store?.phone.isNotEmpty == true ? store!.phone : widget.userPhone,
    );
    _addressCtrl = TextEditingController(text: store?.address ?? '');
    _hydrateStructuredState(store);
    _delivery = store?.deliveryAvailable ?? true;
    _pickup = store?.pickupAvailable ?? true;
    _freeDeliveryEnabled = store?.freeDeliveryEnabled ?? false;
    _firstOrderDealEnabled = store?.firstOrderDealEnabled ?? false;
    _discountEnabled = store?.discountEnabled ?? false;
    _discountLabelCtrl.text = store?.discountLabel ?? '';
    _logoUrl = store?.imageUrl ?? '';
    _coverUrl = store?.coverUrl ?? '';
  }

  @override
  void didUpdateWidget(covariant _StoreProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store?.id == widget.store?.id) return;
    final store = widget.store;
    _nameCtrl.text = store?.name ?? '';
    _descriptionCtrl.text = store?.description ?? '';
    _phoneCtrl.text = store?.phone.isNotEmpty == true
        ? store!.phone
        : widget.userPhone;
    _addressCtrl.text = store?.address ?? '';
    _hydrateStructuredState(store);
    _delivery = store?.deliveryAvailable ?? true;
    _pickup = store?.pickupAvailable ?? true;
    _freeDeliveryEnabled = store?.freeDeliveryEnabled ?? false;
    _firstOrderDealEnabled = store?.firstOrderDealEnabled ?? false;
    _discountEnabled = store?.discountEnabled ?? false;
    _discountLabelCtrl.text = store?.discountLabel ?? '';
    _logoUrl = store?.imageUrl ?? '';
    _coverUrl = store?.coverUrl ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _discountLabelCtrl.dispose();
    super.dispose();
  }

  void _hydrateStructuredState(backend.MarketplaceStore? store) {
    _category = backend.normalizeMarketplaceCategory(store?.category);
    _daysOpen = store?.daysOpen.isNotEmpty == true
        ? List<String>.of(store!.daysOpen)
        : const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    _openTime = _storeTimeOptions.contains(store?.openTime)
        ? store!.openTime
        : '09:00';
    _closeTime = _storeTimeOptions.contains(store?.closeTime)
        ? store!.closeTime
        : '20:00';
    _placeId = store?.placeId ?? '';
    _cityArea = store?.cityArea ?? '';
    _storePoint = store != null && store.lat != 0 && store.lng != 0
        ? DemoMapPoint(store.lat, store.lng)
        : null;
    _addressSuggestions = const [];
  }

  void _updateAddressSuggestions(String value) {
    setState(() {
      _addressSuggestions = _placesService.localSuggestions(value);
    });
  }

  void _selectAddressSuggestion(PlaceSuggestion suggestion) {
    setState(() {
      _addressCtrl.text = suggestion.description;
      _placeId = suggestion.placeId;
      _cityArea = suggestion.mainText;
      if (suggestion.localPoint != null) {
        _storePoint = suggestion.localPoint;
      }
      _addressSuggestions = const [];
    });
  }

  void _setStorePoint(DemoMapPoint point) {
    setState(() {
      _storePoint = point;
      if (_addressCtrl.text.trim().isEmpty) {
        _addressCtrl.text =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
    });
  }

  String get _hoursPreview => backend.marketplaceHoursLabel(
    daysOpen: _daysOpen,
    openTime: _openTime,
    closeTime: _closeTime,
  );

  Future<void> _pickStoreImage({required bool isLogo}) async {
    final storeId = widget.store?.id ?? '';
    if (storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Save your store profile first before uploading images.',
          ),
        ),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (!FirebaseService.instance.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload requires Firebase Storage.'),
          ),
        );
      }
      return;
    }
    final ext = (file.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      if (isLogo) {
        _uploadingLogo = true;
      } else {
        _uploadingCover = true;
      }
    });
    try {
      final url = isLogo
          ? await StorageService().uploadStoreLogo(
              storeId: storeId,
              bytes: bytes,
              fileName: file.name,
              contentType: mime,
              extension: ext,
            )
          : await StorageService().uploadStoreCover(
              storeId: storeId,
              bytes: bytes,
              fileName: file.name,
              contentType: mime,
              extension: ext,
            );
      if (kDebugMode) {
        debugPrint(
          '[StoreOwner] upload returned URL for ${isLogo ? 'store logo' : 'store cover'}: $url',
        );
      }
      if (!mounted) return;
      setState(() {
        if (url != null) {
          if (isLogo) {
            _logoUrl = url;
          } else {
            _coverUrl = url;
          }
        }
        if (isLogo) {
          _uploadingLogo = false;
        } else {
          _uploadingCover = false;
        }
      });
      if (url != null) _save();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _uploadingLogo = false;
        } else {
          _uploadingCover = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'Storage permission denied. Check Firebase Storage rules.'
                : 'Upload failed. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _uploadingLogo = false;
        } else {
          _uploadingCover = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload failed. Please try again.')),
      );
    }
  }

  void _save() {
    final now = DateTime.now();
    final existing = widget.store;
    if (_daysOpen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one open day.')),
      );
      return;
    }
    if (backend.marketplaceTimeMinutes(_closeTime) <=
        backend.marketplaceTimeMinutes(_openTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Closing time must be after opening time.'),
        ),
      );
      return;
    }
    final point = _storePoint;
    final address = _addressCtrl.text.trim();
    final hoursLabel = _hoursPreview;
    if (kDebugMode) {
      debugPrint(
        '[StoreOwner] saving store logo/cover URL: logo=$_logoUrl cover=$_coverUrl',
      );
    }
    final existingStatus = existing?.status ?? '';
    final nextStatus =
        existing == null ||
            existingStatus == 'rejected' ||
            existingStatus == 'pending_approval'
        ? 'pending'
        : existingStatus;
    widget.onSave(
      backend.MarketplaceStore(
        id: existing?.id ?? '',
        ownerId: widget.ownerId,
        name: _nameCtrl.text.trim().isEmpty
            ? 'OMW Store'
            : _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        category: backend.normalizeMarketplaceCategory(_category),
        imageUrl: _logoUrl.isNotEmpty ? _logoUrl : (existing?.imageUrl ?? ''),
        coverUrl: _coverUrl.isNotEmpty ? _coverUrl : (existing?.coverUrl ?? ''),
        status: nextStatus,
        rating: existing?.rating ?? 0,
        isOpen: existing?.isOpen ?? true,
        lat: point?.latitude ?? existing?.lat ?? 0,
        lng: point?.longitude ?? existing?.lng ?? 0,
        address: address,
        deliveryEstimateMinutes: existing?.deliveryEstimateMinutes ?? 30,
        categories: [backend.normalizeMarketplaceCategory(_category)],
        deliveryAvailable: _delivery,
        pickupAvailable: _pickup,
        freeDeliveryEnabled: _freeDeliveryEnabled,
        firstOrderDealEnabled: _firstOrderDealEnabled,
        discountEnabled: _discountEnabled,
        discountLabel: _discountLabelCtrl.text.trim(),
        featuredEnabled: existing?.featuredEnabled ?? false,
        openingHours: hoursLabel,
        daysOpen: List<String>.of(_daysOpen),
        openTime: _openTime,
        closeTime: _closeTime,
        openingHoursLabel: hoursLabel,
        addressLabel: address,
        placeId: _placeId,
        cityArea: _cityArea,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBrandBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OmwNetworkImage(
                url: _logoUrl,
                width: 56,
                height: 56,
                borderRadius: 14,
                placeholder: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kAccentYellow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: kBrandBlack,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store?.name.isNotEmpty == true
                          ? store!.name
                          : 'Store profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Status: ${store?.status ?? 'not_created'}',
                      style: const TextStyle(
                        color: kMutedText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onToggleOpen != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        store?.isOpen == true ? 'Open' : 'Closed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Switch(
                        value: store?.isOpen ?? false,
                        onChanged: widget.onToggleOpen,
                        activeThumbColor: kAccentYellow,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          const Text(
            'Store settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            cursorColor: kDeepGold,
            style: _storeOwnerInputTextStyle,
            decoration: _storeOwnerInputDecoration(
              label: 'Store name',
              icon: Icons.storefront_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            cursorColor: kDeepGold,
            style: _storeOwnerInputTextStyle,
            minLines: 2,
            maxLines: 3,
            decoration: _storeOwnerInputDecoration(
              label: 'Description',
              icon: Icons.notes_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            cursorColor: kDeepGold,
            style: _storeOwnerInputTextStyle,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _storeOwnerInputDecoration(
              label: 'Phone number',
              hint: 'e.g. +961 70 000 000',
              icon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: Colors.white,
            style: _storeOwnerInputTextStyle,
            items: backend.marketplaceCategoryOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.value,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(
              () => _category =
                  value ?? backend.marketplaceCategoryOptions.first.value,
            ),
            decoration: _storeOwnerInputDecoration(
              label: 'Store category',
              icon: Icons.category_outlined,
            ),
          ),
          const SizedBox(height: 12),
          _StoreHoursPicker(
            daysOpen: _daysOpen,
            openTime: _openTime,
            closeTime: _closeTime,
            onDaysChanged: (days) => setState(() => _daysOpen = days),
            onOpenTimeChanged: (value) => setState(() => _openTime = value),
            onCloseTimeChanged: (value) => setState(() => _closeTime = value),
          ),
          const SizedBox(height: 12),
          _StoreLocationPicker(
            addressCtrl: _addressCtrl,
            suggestions: _addressSuggestions,
            selectedPoint: _storePoint,
            placeId: _placeId,
            cityArea: _cityArea,
            onAddressChanged: _updateAddressSuggestions,
            onSuggestionSelected: _selectAddressSuggestion,
            onMapTap: _setStorePoint,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: kAccentYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hoursPreview,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StoreToggleChip(
                  label: 'Delivery',
                  value: _delivery,
                  onChanged: (value) => setState(() => _delivery = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StoreToggleChip(
                  label: 'Pickup',
                  value: _pickup,
                  onChanged: (value) => setState(() => _pickup = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StoreDiscoveryChip(
                label: 'Free delivery',
                value: _freeDeliveryEnabled,
                onChanged: (value) =>
                    setState(() => _freeDeliveryEnabled = value),
              ),
              _StoreDiscoveryChip(
                label: 'First order deal',
                value: _firstOrderDealEnabled,
                onChanged: (value) =>
                    setState(() => _firstOrderDealEnabled = value),
              ),
              _StoreDiscoveryChip(
                label: 'Discount',
                value: _discountEnabled,
                onChanged: (value) => setState(() => _discountEnabled = value),
              ),
            ],
          ),
          if (_discountEnabled) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _discountLabelCtrl,
              cursorColor: kDeepGold,
              style: _storeOwnerInputTextStyle,
              decoration: _storeOwnerInputDecoration(
                label: 'Discount label',
                icon: Icons.local_offer_outlined,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StoreImageUploadCell(
                label: 'Logo',
                imageUrl: _logoUrl,
                uploading: _uploadingLogo,
                placeholder: Icons.storefront_outlined,
                onUpload: () => _pickStoreImage(isLogo: true),
              ),
              const SizedBox(width: 12),
              _StoreImageUploadCell(
                label: 'Cover',
                imageUrl: _coverUrl,
                uploading: _uploadingCover,
                placeholder: Icons.photo_outlined,
                onUpload: () => _pickStoreImage(isLogo: false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save store profile'),
              style: FilledButton.styleFrom(
                backgroundColor: kAccentYellow,
                foregroundColor: kBrandBlack,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreHoursPicker extends StatelessWidget {
  const _StoreHoursPicker({
    required this.daysOpen,
    required this.openTime,
    required this.closeTime,
    required this.onDaysChanged,
    required this.onOpenTimeChanged,
    required this.onCloseTimeChanged,
  });

  final List<String> daysOpen;
  final String openTime;
  final String closeTime;
  final ValueChanged<List<String>> onDaysChanged;
  final ValueChanged<String> onOpenTimeChanged;
  final ValueChanged<String> onCloseTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Days open',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: backend.marketplaceDayValues.map((day) {
              final selected = daysOpen.contains(day);
              return FilterChip(
                label: Text(backend.marketplaceDayLabel(day)),
                selected: selected,
                selectedColor: kAccentYellow,
                checkmarkColor: kBrandBlack,
                labelStyle: TextStyle(
                  color: selected ? kBrandBlack : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(
                  color: selected ? kAccentYellow : Colors.white24,
                ),
                onSelected: (value) {
                  final next = List<String>.of(daysOpen);
                  if (value) {
                    next.add(day);
                  } else {
                    next.remove(day);
                  }
                  next.sort(
                    (a, b) => backend.marketplaceDayValues
                        .indexOf(a)
                        .compareTo(backend.marketplaceDayValues.indexOf(b)),
                  );
                  onDaysChanged(next);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: openTime,
                  dropdownColor: Colors.white,
                  style: _storeOwnerInputTextStyle,
                  items: _storeTimeOptions
                      .map(
                        (time) => DropdownMenuItem<String>(
                          value: time,
                          child: Text(backend.marketplaceTimeLabel(time)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onOpenTimeChanged(value);
                  },
                  decoration: _storeOwnerInputDecoration(
                    label: 'Opening time',
                    icon: Icons.schedule_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: closeTime,
                  dropdownColor: Colors.white,
                  style: _storeOwnerInputTextStyle,
                  items: _storeTimeOptions
                      .map(
                        (time) => DropdownMenuItem<String>(
                          value: time,
                          child: Text(backend.marketplaceTimeLabel(time)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onCloseTimeChanged(value);
                  },
                  decoration: _storeOwnerInputDecoration(
                    label: 'Closing time',
                    icon: Icons.lock_clock_outlined,
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

class _StoreLocationPicker extends StatelessWidget {
  const _StoreLocationPicker({
    required this.addressCtrl,
    required this.suggestions,
    required this.selectedPoint,
    required this.placeId,
    required this.cityArea,
    required this.onAddressChanged,
    required this.onSuggestionSelected,
    required this.onMapTap,
  });

  final TextEditingController addressCtrl;
  final List<PlaceSuggestion> suggestions;
  final DemoMapPoint? selectedPoint;
  final String placeId;
  final String cityArea;
  final ValueChanged<String> onAddressChanged;
  final ValueChanged<PlaceSuggestion> onSuggestionSelected;
  final ValueChanged<DemoMapPoint> onMapTap;

  @override
  Widget build(BuildContext context) {
    final point = selectedPoint ?? _defaultStorePoint;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: addressCtrl,
            cursorColor: kDeepGold,
            style: _storeOwnerInputTextStyle,
            onChanged: onAddressChanged,
            decoration: _storeOwnerInputDecoration(
              label: AppConfig.useGoogleMaps
                  ? 'Search or select store location'
                  : 'Address',
              hint: AppConfig.useGoogleMaps
                  ? 'Search area or tap the map'
                  : 'Temporary manual address until Maps is configured',
              icon: Icons.location_on_outlined,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PlacesSuggestionList(
              suggestions: suggestions,
              onSelected: onSuggestionSelected,
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppMap(
                    pickup: point,
                    offerMarkers: [
                      DemoMapMarker(
                        id: 'store-location',
                        point: point,
                        label: 'Store location',
                        icon: Icons.storefront_outlined,
                      ),
                    ],
                    height: 180,
                    gesturesEnabled: true,
                    onMapTap: onMapTap,
                  ),
                  if (!AppConfig.useGoogleMaps)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Google Maps is not configured. Save an address now; latitude and longitude can be added later.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedPoint == null
                ? 'No map pin selected yet.'
                : 'Selected: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'
                      '${cityArea.isEmpty ? '' : ' - $cityArea'}'
                      '${placeId.isEmpty ? '' : ' - $placeId'}',
            style: const TextStyle(
              color: kMutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreToggleChip extends StatelessWidget {
  const _StoreToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      checkmarkColor: kBrandBlack,
      selectedColor: kAccentYellow,
      backgroundColor: Colors.white,
      label: Text(
        label,
        style: const TextStyle(color: kBrandBlack, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StoreDiscoveryChip extends StatelessWidget {
  const _StoreDiscoveryChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      checkmarkColor: kBrandBlack,
      selectedColor: kAccentYellow,
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      label: Text(
        label,
        style: const TextStyle(color: kBrandBlack, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StoreOverviewGrid extends StatelessWidget {
  const _StoreOverviewGrid({
    required this.store,
    required this.products,
    required this.orders,
  });

  final backend.MarketplaceStore store;
  final List<backend.MarketplaceProduct> products;
  final List<backend.MarketplaceOrder> orders;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOrders = orders
        .where(
          (order) =>
              order.createdAt.year == today.year &&
              order.createdAt.month == today.month &&
              order.createdAt.day == today.day,
        )
        .length;
    final pending = orders
        .where(
          (order) => order.status == backend.MarketplaceOrderStatus.pending,
        )
        .length;
    final completed = orders
        .where(
          (order) => order.status == backend.MarketplaceOrderStatus.delivered,
        )
        .length;
    final lowStock = products
        .where((product) => product.stockStatus == 'low_stock')
        .length;
    final outOfStock = products
        .where((product) => product.stockStatus == 'out_of_stock')
        .length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StoreMetricTile(label: 'Today orders', value: '$todayOrders'),
        _StoreMetricTile(label: 'Pending', value: '$pending'),
        _StoreMetricTile(label: 'Completed', value: '$completed'),
        _StoreMetricTile(label: 'Products', value: '${products.length}'),
        _StoreMetricTile(label: 'Low stock', value: '$lowStock'),
        _StoreMetricTile(label: 'Out of stock', value: '$outOfStock'),
      ],
    );
  }
}

class _StoreMetricTile extends StatelessWidget {
  const _StoreMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreMoneyCard extends StatelessWidget {
  const _StoreMoneyCard({required this.snapshot});

  final StoreMoneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _StoreSectionCard(
      title: 'Money snapshot',
      icon: Icons.payments_outlined,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MoneySnapshotTile(
              label: 'Today sales',
              value: '\$${snapshot.todaySales.toStringAsFixed(2)}',
            ),
            _MoneySnapshotTile(
              label: 'Total sales',
              value: '\$${snapshot.totalSales.toStringAsFixed(2)}',
            ),
            _MoneySnapshotTile(
              label: 'Completed',
              value: '${snapshot.completedOrders}',
            ),
            _MoneySnapshotTile(
              label: 'Expenses',
              value: '\$${snapshot.expenses.toStringAsFixed(2)}',
            ),
            _MoneySnapshotTile(
              label: 'Est. profit',
              value: '\$${snapshot.estimatedProfit.toStringAsFixed(2)}',
              highlighted: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _MoneySnapshotTile extends StatelessWidget {
  const _MoneySnapshotTile({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted
              ? kAccentYellow.withValues(alpha: 0.22)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? kAccentYellow : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreInventoryCard extends StatelessWidget {
  const _StoreInventoryCard({
    required this.store,
    required this.products,
    required this.service,
  });

  final backend.MarketplaceStore store;
  final List<backend.MarketplaceProduct> products;
  final StoreCrmService service;

  Future<void> _openProductDialog(
    BuildContext context, {
    backend.MarketplaceProduct? product,
    List<ProductCategory> categories = const [],
  }) async {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final priceCtrl = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final costCtrl = TextEditingController(
      text: product?.cost?.toString() ?? '',
    );
    final stockCtrl = TextEditingController(
      text: product?.stockQuantity.toString() ?? '10',
    );
    final thresholdCtrl = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '2',
    );
    var productImageUrl = product?.imageUrl ?? '';
    var uploadingImage = false;
    var available = product?.isAvailable ?? true;
    var visible = product?.isVisibleToCustomers ?? true;
    var productDiscountEnabled = product?.discountEnabled ?? false;
    final productDiscountLabelCtrl = TextEditingController(
      text: product?.discountLabel ?? '',
    );
    final productCategory = backend.normalizeMarketplaceCategory(
      store.category,
    );
    var selectedSubcategory = backend.normalizeMarketplaceSubcategory(
      productCategory,
      product?.subcategory,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Add product' : 'Edit product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  cursorColor: kDeepGold,
                  style: _storeOwnerInputTextStyle,
                  decoration: _storeOwnerInputDecoration(
                    label: 'Product name',
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  cursorColor: kDeepGold,
                  style: _storeOwnerInputTextStyle,
                  minLines: 2,
                  maxLines: 3,
                  decoration: _storeOwnerInputDecoration(
                    label: 'Description',
                    icon: Icons.notes_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubcategory,
                  dropdownColor: Colors.white,
                  style: _storeOwnerInputTextStyle,
                  items: backend
                      .marketplaceSubcategoryOptionsFor(productCategory)
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(
                    () => selectedSubcategory =
                        value ??
                        backend
                            .marketplaceSubcategoryOptionsFor(productCategory)
                            .first
                            .value,
                  ),
                  decoration: _storeOwnerInputDecoration(
                    label:
                        '${backend.marketplaceCategoryLabel(productCategory)} subcategory',
                    icon: Icons.category_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  cursorColor: kDeepGold,
                  style: _storeOwnerInputTextStyle,
                  decoration: _storeOwnerInputDecoration(
                    label: 'Price',
                    icon: Icons.sell_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  cursorColor: kDeepGold,
                  style: _storeOwnerInputTextStyle,
                  decoration: _storeOwnerInputDecoration(
                    label: 'Cost',
                    icon: Icons.request_quote_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  cursorColor: kDeepGold,
                  style: _storeOwnerInputTextStyle,
                  decoration: _storeOwnerInputDecoration(
                    label: 'Stock quantity',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  cursorColor: kDeepGold,
                  style: _storeOwnerInputTextStyle,
                  decoration: _storeOwnerInputDecoration(
                    label: 'Low-stock threshold',
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: available,
                  onChanged: (value) => setDialogState(() => available = value),
                  title: const Text(
                    'Available',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: visible,
                  onChanged: (value) => setDialogState(() => visible = value),
                  title: const Text(
                    'Visible to customers',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: productDiscountEnabled,
                  onChanged: (value) =>
                      setDialogState(() => productDiscountEnabled = value),
                  title: const Text(
                    'Include in deals',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (productDiscountEnabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: productDiscountLabelCtrl,
                    cursorColor: kDeepGold,
                    style: _storeOwnerInputTextStyle,
                    decoration: _storeOwnerInputDecoration(
                      label: 'Deal label',
                      icon: Icons.local_offer_outlined,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (productImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      productImageUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: uploadingImage
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result == null || result.files.isEmpty) return;
                            final file = result.files.single;
                            final bytes = file.bytes;
                            if (bytes == null || bytes.isEmpty) return;
                            if (!FirebaseService.instance.isReady) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Image upload requires Firebase Storage.',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            final ext = (file.extension ?? 'jpg').toLowerCase();
                            final mime = ext == 'png'
                                ? 'image/png'
                                : 'image/jpeg';
                            setDialogState(() => uploadingImage = true);
                            try {
                              final url = await StorageService()
                                  .uploadProductImage(
                                    storeId: store.id,
                                    productId: product?.id ?? '',
                                    bytes: bytes,
                                    fileName: file.name,
                                    contentType: mime,
                                    extension: ext,
                                  );
                              if (kDebugMode) {
                                debugPrint(
                                  '[StoreOwner] upload returned URL for product image: $url',
                                );
                              }
                              setDialogState(() {
                                if (url != null) productImageUrl = url;
                                uploadingImage = false;
                              });
                            } on FirebaseException catch (error) {
                              setDialogState(() => uploadingImage = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Image upload failed: ${error.code}',
                                    ),
                                  ),
                                );
                              }
                              debugPrint(
                                '[StoreOwner] Product image upload failed: ${error.code} ${error.message}',
                              );
                            } catch (error) {
                              setDialogState(() => uploadingImage = false);
                              debugPrint(
                                '[StoreOwner] Product image upload failed: $error',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Image upload failed.'),
                                  ),
                                );
                              }
                            }
                          },
                    icon: uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: Text(
                      productImageUrl.isNotEmpty
                          ? 'Replace image'
                          : 'Upload product image',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: Text(product == null ? 'Save product' : 'Update product'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final productName = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim());
    final stock = int.tryParse(stockCtrl.text.trim());
    final lowStockThreshold = int.tryParse(thresholdCtrl.text.trim());
    if (productName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product name is required.')),
        );
      }
      return;
    }
    if (price == null || price <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Price must be greater than 0.')),
        );
      }
      return;
    }
    if (stock == null || stock < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock quantity must be 0 or higher.')),
        );
      }
      return;
    }
    final now = DateTime.now();
    final normalizedSubcategory = backend.normalizeMarketplaceSubcategory(
      productCategory,
      selectedSubcategory,
    );
    if (kDebugMode) {
      debugPrint('[StoreOwner] saving product image URL: $productImageUrl');
    }
    try {
      await service.upsertProduct(
        backend.MarketplaceProduct(
          id: product?.id ?? '',
          storeId: store.id,
          storeOwnerId: store.ownerId,
          name: productName,
          description: descCtrl.text.trim(),
          category: productCategory,
          subcategory: normalizedSubcategory,
          discountEnabled: productDiscountEnabled,
          discountLabel: productDiscountLabelCtrl.text.trim(),
          price: price,
          cost: double.tryParse(costCtrl.text.trim()),
          imageUrl: productImageUrl,
          stockQuantity: stock,
          lowStockThreshold: lowStockThreshold ?? 2,
          isAvailable: stock <= 0 ? false : available,
          isVisibleToCustomers: visible,
          createdAt: product?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (context.mounted) {
        final message = product == null
            ? 'Product added successfully.'
            : 'Product updated successfully.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on FirebaseException catch (error) {
      debugPrint(
        '[StoreOwner] Save product FirebaseException: ${error.code} ${error.message}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save product: ${error.code}')),
        );
      }
    } catch (error) {
      debugPrint('[StoreOwner] Save product failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save product.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductCategory>>(
      stream: service.watchCategories(store.id),
      builder: (context, categorySnapshot) {
        final categories = categorySnapshot.data ?? const <ProductCategory>[];
        final lowStock = products
            .where((product) => product.stockStatus == 'low_stock')
            .length;
        final outOfStock = products
            .where((product) => product.stockStatus == 'out_of_stock')
            .length;
        return _StoreSectionCard(
          title: 'Inventory',
          subtitle: 'Manage products, stock, and availability',
          icon: Icons.inventory_2_outlined,
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _openProductDialog(context, categories: categories),
                icon: const Icon(Icons.add),
                label: const Text('Product'),
              ),
            ],
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InventoryCountPill(
                  label: 'Products',
                  value: products.length,
                  icon: Icons.shopping_bag_outlined,
                ),
                _InventoryCountPill(
                  label: 'Low stock',
                  value: lowStock,
                  icon: Icons.warning_amber_outlined,
                ),
                _InventoryCountPill(
                  label: 'Out of stock',
                  value: outOfStock,
                  icon: Icons.remove_shopping_cart_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: backend.marketplaceCategoryOptions
                  .map(
                    (category) => Chip(
                      label: Text(category.label),
                      avatar: Icon(
                        _marketplaceCategoryIcon(category.value),
                        size: 18,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              const _StoreEmptyState(
                icon: Icons.inventory_2_outlined,
                text:
                    'No products yet. Add your first product to start selling.',
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 560),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Scrollbar(
                  thumbVisibility: products.length > 3,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductInventoryTile(
                        product: product,
                        onTap: () => _openProductDialog(
                          context,
                          product: product,
                          categories: categories,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InventoryCountPill extends StatelessWidget {
  const _InventoryCountPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kDeepGold),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ProductInventoryTile extends StatelessWidget {
  const _ProductInventoryTile({required this.product, required this.onTap});

  final backend.MarketplaceProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                OmwNetworkImage(
                  url: product.imageUrl,
                  width: 44,
                  height: 44,
                  borderRadius: 22,
                  placeholder: CircleAvatar(
                    backgroundColor: kAccentYellow.withValues(alpha: 0.25),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: kDeepGold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        backend.marketplaceSubcategoryLabel(
                          product.category,
                          product.subcategory,
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit product',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StockStatusBadge(status: product.stockStatus),
                _AvailabilityBadge(
                  label: product.isAvailable ? 'Available' : 'Unavailable',
                  active: product.isAvailable,
                ),
                _AvailabilityBadge(
                  label: product.isVisibleToCustomers ? 'Visible' : 'Hidden',
                  active: product.isVisibleToCustomers,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _MiniProductFact(
                  label: 'Price',
                  value: '\$${product.price.toStringAsFixed(2)}',
                ),
                if (product.cost != null)
                  _MiniProductFact(
                    label: 'Cost',
                    value: '\$${product.cost!.toStringAsFixed(2)}',
                  ),
                _MiniProductFact(
                  label: 'Stock',
                  value: '${product.stockQuantity}',
                ),
                _MiniProductFact(
                  label: 'Low alert',
                  value: '${product.lowStockThreshold}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockStatusBadge extends StatelessWidget {
  const _StockStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'out_of_stock' => 'Out of stock',
      'low_stock' => 'Low stock',
      _ => 'In stock',
    };
    final color = switch (status) {
      'out_of_stock' => Colors.red.shade700,
      'low_stock' => kDeepGold,
      _ => Colors.green.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green.shade700 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniProductFact extends StatelessWidget {
  const _MiniProductFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: kBrandBlack,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreOrdersCard extends StatelessWidget {
  const _StoreOrdersCard({required this.orders, required this.service});

  final List<backend.MarketplaceOrder> orders;
  final StoreCrmService service;

  Future<void> _setStatus(
    BuildContext context,
    backend.MarketplaceOrder order,
    backend.MarketplaceOrderStatus status,
  ) async {
    await service.updateOrderStatus(order.id, status);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StoreSectionCard(
      title: 'Orders',
      icon: Icons.receipt_long_outlined,
      children: orders.isEmpty
          ? [
              const _StoreEmptyState(
                icon: Icons.receipt_long_outlined,
                text: 'No marketplace orders yet.',
              ),
            ]
          : orders.take(8).map((order) {
              final shortId = order.id.length <= 8
                  ? order.id
                  : order.id.substring(0, 8);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order #$shortId',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _OrderStatusPill(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StoreInfoRow(
                      'Customer',
                      order.customerPhone.isEmpty
                          ? order.customerId
                          : order.customerPhone,
                    ),
                    _StoreInfoRow('Created', _dateLabel(order.createdAt)),
                    _StoreInfoRow(
                      'Total',
                      '\$${order.total.toStringAsFixed(2)}',
                    ),
                    if (order.deliveryStatus.isNotEmpty &&
                        order.deliveryStatus != 'none')
                      _StoreInfoRow('Delivery', order.deliveryStatus),
                    if (order.assignedWorkerName?.isNotEmpty == true)
                      _StoreInfoRow('Worker', order.assignedWorkerName!),
                    const SizedBox(height: 6),
                    Text(
                      order.items
                          .map(
                            (item) => '${item.quantity}x ${item.productName}',
                          )
                          .join(', '),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _orderActions(context, order),
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }

  List<Widget> _orderActions(
    BuildContext context,
    backend.MarketplaceOrder order,
  ) {
    Widget action(String label, backend.MarketplaceOrderStatus status) {
      final button = status == backend.MarketplaceOrderStatus.delivered
          ? FilledButton(
              onPressed: () => _setStatus(context, order, status),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: () => _setStatus(context, order, status),
              child: Text(label),
            );
      return button;
    }

    switch (order.status) {
      case backend.MarketplaceOrderStatus.pending:
        return [
          action('Accept', backend.MarketplaceOrderStatus.accepted),
          action('Reject', backend.MarketplaceOrderStatus.cancelled),
        ];
      case backend.MarketplaceOrderStatus.accepted:
        return [
          action('Mark preparing', backend.MarketplaceOrderStatus.shopping),
        ];
      case backend.MarketplaceOrderStatus.shopping:
        return [action('Mark ready', backend.MarketplaceOrderStatus.pickedUp)];
      case backend.MarketplaceOrderStatus.pickedUp:
        // Order is ready for pickup — worker dispatch in progress.
        // Store owner cannot mark delivered; worker does that.
        return const [];
      case backend.MarketplaceOrderStatus.onTheWay:
        // Worker is delivering; no store action needed.
        return const [];
      case backend.MarketplaceOrderStatus.delivered:
      case backend.MarketplaceOrderStatus.cancelled:
        return const [];
    }
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({required this.status});

  final backend.MarketplaceOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      backend.MarketplaceOrderStatus.cancelled => Colors.red.shade700,
      backend.MarketplaceOrderStatus.delivered => Colors.green.shade700,
      backend.MarketplaceOrderStatus.pending => kDeepGold,
      _ => Colors.blueGrey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StoreExpensesCard extends StatelessWidget {
  const _StoreExpensesCard({
    required this.storeId,
    required this.expenses,
    required this.service,
  });

  final String storeId;
  final List<StoreExpense> expenses;
  final StoreCrmService service;

  Future<void> _addExpense(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');
    final notesCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                cursorColor: kDeepGold,
                style: _storeOwnerInputTextStyle,
                decoration: _storeOwnerInputDecoration(
                  label: 'Title',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                cursorColor: kDeepGold,
                style: _storeOwnerInputTextStyle,
                decoration: _storeOwnerInputDecoration(
                  label: 'Amount',
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                cursorColor: kDeepGold,
                style: _storeOwnerInputTextStyle,
                decoration: _storeOwnerInputDecoration(
                  label: 'Category',
                  icon: Icons.category_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                cursorColor: kDeepGold,
                style: _storeOwnerInputTextStyle,
                minLines: 2,
                maxLines: 3,
                decoration: _storeOwnerInputDecoration(
                  label: 'Notes',
                  icon: Icons.notes_outlined,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save expense'),
          ),
        ],
      ),
    );
    if (saved != true || titleCtrl.text.trim().isEmpty) return;
    final now = DateTime.now();
    await service.addExpense(
      StoreExpense(
        id: '',
        storeId: storeId,
        title: titleCtrl.text.trim(),
        amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
        category: categoryCtrl.text.trim().isEmpty
            ? 'General'
            : categoryCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StoreSectionCard(
      title: 'Expenses',
      icon: Icons.request_quote_outlined,
      action: FilledButton.icon(
        onPressed: () => _addExpense(context),
        icon: const Icon(Icons.add),
        label: const Text('Expense'),
      ),
      children: expenses.isEmpty
          ? [
              const _StoreEmptyState(
                icon: Icons.request_quote_outlined,
                text: 'No expenses recorded yet.',
              ),
            ]
          : expenses
                .map(
                  (expense) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                expense.category,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${expense.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
    );
  }
}

class _StoreSectionCard extends StatelessWidget {
  const _StoreSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

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
              Icon(icon, color: kDeepGold),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
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
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: action!),
          ],
          const Divider(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class _StoreEmptyState extends StatelessWidget {
  const _StoreEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: kDeepGold, size: 30),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreInfoRow extends StatelessWidget {
  const _StoreInfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
