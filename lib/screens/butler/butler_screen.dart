part of '../../main.dart';

// ---------------------------------------------------------------------------
// Butler Screen — landing + request forms + customer details view
// ---------------------------------------------------------------------------

class ButlerScreen extends StatelessWidget {
  const ButlerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Butler')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'Butler',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "Tell us what you need. We'll connect you with a delivery partner.",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            _ButlerServiceCard(
              icon: Icons.local_shipping_outlined,
              title: 'Deliver your stuff',
              subtitle: 'Send a package or item from one place to another.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ButlerDeliverStuffScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ButlerServiceCard(
              icon: Icons.shopping_cart_outlined,
              title: 'Buy something',
              subtitle: "We'll go to a shop and buy items for you.",
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ButlerBuySomethingScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButlerServiceCard extends StatelessWidget {
  const _ButlerServiceCard({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAccentYellow.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kBrandBlack,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: kAccentYellow, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared location field with local suggestions
// ---------------------------------------------------------------------------

class _ButlerLocationField extends StatefulWidget {
  const _ButlerLocationField({
    required this.label,
    required this.hint,
    required this.controller,
    this.icon = Icons.place_outlined,
    this.onPointSelected,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;

  /// Called with the selected [DemoMapPoint] when a local suggestion is tapped,
  /// or with null when the field text is changed manually.
  final ValueChanged<DemoMapPoint?>? onPointSelected;

  @override
  State<_ButlerLocationField> createState() => _ButlerLocationFieldState();
}

class _ButlerLocationFieldState extends State<_ButlerLocationField> {
  List<PlaceSuggestion> _suggestions = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    // Manual edit — clear any previously resolved point.
    widget.onPointSelected?.call(null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _suggestions = const GooglePlacesService().localSuggestions(value);
      });
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    widget.controller.text = suggestion.description;
    setState(() => _suggestions = const []);
    // Fire resolved coordinates (may be null for non-local suggestions).
    widget.onPointSelected?.call(suggestion.localPoint);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
          ),
          onChanged: _onChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _suggestions
                  .map(
                    (s) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, size: 18),
                      title: Text(s.mainText),
                      subtitle: Text(s.secondaryText),
                      onTap: () => _selectSuggestion(s),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared error message container
// ---------------------------------------------------------------------------

class _ButlerErrorBox extends StatelessWidget {
  const _ButlerErrorBox({required this.message});

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
// Delivery fee estimate card (shown in Butler forms)
// ---------------------------------------------------------------------------

class _ButlerFeeCard extends StatelessWidget {
  const _ButlerFeeCard({
    required this.distanceKm,
    required this.fee,
    required this.showNote,
  });

  final double? distanceKm;
  final double? fee;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    if (distanceKm != null && fee != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kAccentYellow.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccentYellow.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, size: 16, color: kDeepGold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated delivery fee: \$${DeliveryPricingService.formatMoney(fee!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${distanceKm!.toStringAsFixed(1)} km · cash on delivery',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (!showNote) return const SizedBox.shrink();
    return Text(
      'Delivery fee will be confirmed after location is selected.',
      style: TextStyle(
        fontSize: 13,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Submit button style
// ---------------------------------------------------------------------------

ButtonStyle get _butlerSubmitStyle => FilledButton.styleFrom(
  backgroundColor: kAccentYellow,
  foregroundColor: Colors.black,
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
);

// ---------------------------------------------------------------------------
// Deliver your stuff form
// ---------------------------------------------------------------------------

class _ButlerDeliverStuffScreen extends StatefulWidget {
  const _ButlerDeliverStuffScreen();

  @override
  State<_ButlerDeliverStuffScreen> createState() =>
      _ButlerDeliverStuffScreenState();
}

class _ButlerDeliverStuffScreenState extends State<_ButlerDeliverStuffScreen> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  DemoMapPoint? _pickupPoint;
  DemoMapPoint? _dropoffPoint;
  double? _distanceKm;
  bool _submitting = false;
  String? _error;

  double? get _estimatedFee => _distanceKm != null
      ? DeliveryPricingService.calculateDeliveryFee(_distanceKm!)
      : null;

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _itemCtrl.dispose();
    _notesCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  void _onPickupPoint(DemoMapPoint? point) {
    setState(() {
      _pickupPoint = point;
      _recalcFee();
    });
  }

  void _onDropoffPoint(DemoMapPoint? point) {
    setState(() {
      _dropoffPoint = point;
      _recalcFee();
    });
  }

  void _recalcFee() {
    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;
    if (pickup != null && dropoff != null) {
      _distanceKm = DeliveryPricingService.calculateDistanceKm(
        pickup.latitude,
        pickup.longitude,
        dropoff.latitude,
        dropoff.longitude,
      );
    } else {
      _distanceKm = null;
    }
  }

  Future<void> _submit() async {
    final pickup = _pickupCtrl.text.trim();
    final dropoff = _dropoffCtrl.text.trim();
    final item = _itemCtrl.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty || item.isEmpty) {
      setState(
        () => _error =
            'Please fill in pickup location, drop-off location, and item description.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = AuthService().currentUser;
      if (!FirebaseService.instance.isReady) {
        throw StateError('Firebase is not available. Please try again.');
      }
      final dist = _distanceKm;
      final request = backend.ButlerRequest(
        id: '',
        customerId: user?.uid ?? '',
        customerName: user?.displayName ?? '',
        customerEmail: user?.email ?? '',
        requestType: backend.ButlerRequestType.deliverStuff,
        pickupLocation: pickup,
        dropoffLocation: dropoff,
        itemDescription: item,
        notes: _notesCtrl.text.trim(),
        contactPhone: _contactCtrl.text.trim(),
        distanceKm: dist,
        deliveryFee: _estimatedFee,
        deliveryFeeRateType: dist != null
            ? DeliveryPricingService.rateType(dist)
            : '',
        deliveryFeeCalculatedAt: dist != null ? DateTime.now() : null,
        paymentStatus: 'cashOnDelivery',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ButlerService().createRequest(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Butler request submitted. We will be in touch soon.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = _estimatedFee;
    final hasText = _pickupCtrl.text.isNotEmpty || _dropoffCtrl.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Deliver your stuff')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Tell us what needs delivering and where.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _ButlerLocationField(
              label: 'Pickup location *',
              hint: 'Where should we pick it up?',
              controller: _pickupCtrl,
              icon: Icons.trip_origin_outlined,
              onPointSelected: _onPickupPoint,
            ),
            const SizedBox(height: 14),
            _ButlerLocationField(
              label: 'Drop-off location *',
              hint: 'Where should we deliver it?',
              controller: _dropoffCtrl,
              onPointSelected: _onDropoffPoint,
            ),
            const SizedBox(height: 14),
            _ButlerFeeCard(
              distanceKm: _distanceKm,
              fee: fee,
              showNote: hasText,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _itemCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Item description *',
                hintText: 'What are we delivering?',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special instructions?',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contactCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone (optional)',
                hintText: "Recipient's phone number",
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ButlerErrorBox(message: _error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: _butlerSubmitStyle,
              child: Text(_submitting ? 'Submitting…' : 'Request Butler'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buy something form
// ---------------------------------------------------------------------------

class _ButlerBuySomethingScreen extends StatefulWidget {
  const _ButlerBuySomethingScreen();

  @override
  State<_ButlerBuySomethingScreen> createState() =>
      _ButlerBuySomethingScreenState();
}

class _ButlerBuySomethingScreenState extends State<_ButlerBuySomethingScreen> {
  final _shopCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  DemoMapPoint? _shopPoint;
  DemoMapPoint? _dropoffPoint;
  double? _distanceKm;
  bool _submitting = false;
  String? _error;

  double? get _estimatedFee => _distanceKm != null
      ? DeliveryPricingService.calculateDeliveryFee(_distanceKm!)
      : null;

  @override
  void dispose() {
    _shopCtrl.dispose();
    _dropoffCtrl.dispose();
    _itemCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  void _onShopPoint(DemoMapPoint? point) {
    setState(() {
      _shopPoint = point;
      _recalcFee();
    });
  }

  void _onDropoffPoint(DemoMapPoint? point) {
    setState(() {
      _dropoffPoint = point;
      _recalcFee();
    });
  }

  void _recalcFee() {
    final shop = _shopPoint;
    final dropoff = _dropoffPoint;
    if (shop != null && dropoff != null) {
      _distanceKm = DeliveryPricingService.calculateDistanceKm(
        shop.latitude,
        shop.longitude,
        dropoff.latitude,
        dropoff.longitude,
      );
    } else {
      _distanceKm = null;
    }
  }

  Future<void> _submit() async {
    final shop = _shopCtrl.text.trim();
    final dropoff = _dropoffCtrl.text.trim();
    final item = _itemCtrl.text.trim();
    if (shop.isEmpty || dropoff.isEmpty || item.isEmpty) {
      setState(
        () => _error =
            'Please fill in the store/pickup location, drop-off location, and what to buy.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = AuthService().currentUser;
      if (!FirebaseService.instance.isReady) {
        throw StateError('Firebase is not available. Please try again.');
      }
      final estimatedCost = double.tryParse(_costCtrl.text.trim());
      final dist = _distanceKm;
      final request = backend.ButlerRequest(
        id: '',
        customerId: user?.uid ?? '',
        customerName: user?.displayName ?? '',
        customerEmail: user?.email ?? '',
        requestType: backend.ButlerRequestType.buySomething,
        pickupLocation: shop,
        dropoffLocation: dropoff,
        shopName: shop,
        shopLocation: shop,
        itemDescription: item,
        estimatedItemCost: estimatedCost,
        notes: _notesCtrl.text.trim(),
        contactPhone: _contactCtrl.text.trim(),
        distanceKm: dist,
        deliveryFee: _estimatedFee,
        deliveryFeeRateType: dist != null
            ? DeliveryPricingService.rateType(dist)
            : '',
        deliveryFeeCalculatedAt: dist != null ? DateTime.now() : null,
        paymentStatus: 'cashOnDelivery',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ButlerService().createRequest(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Butler request submitted. We will be in touch soon.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = _estimatedFee;
    final hasText = _shopCtrl.text.isNotEmpty || _dropoffCtrl.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Buy something')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(
              'Tell us what to buy and where to deliver it.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _ButlerLocationField(
              label: 'Store / pickup location *',
              hint: 'Shop name or address',
              controller: _shopCtrl,
              icon: Icons.store_outlined,
              onPointSelected: _onShopPoint,
            ),
            const SizedBox(height: 14),
            _ButlerLocationField(
              label: 'Drop-off location *',
              hint: 'Where should we deliver it?',
              controller: _dropoffCtrl,
              onPointSelected: _onDropoffPoint,
            ),
            const SizedBox(height: 14),
            _ButlerFeeCard(
              distanceKm: _distanceKm,
              fee: fee,
              showNote: hasText,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _itemCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What should we buy? *',
                hintText: 'Describe the items to buy',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _costCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Estimated item cost (optional)',
                hintText: '0.00',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special instructions?',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _contactCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone (optional)',
                hintText: 'Your phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ButlerErrorBox(message: _error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: _butlerSubmitStyle,
              child: Text(_submitting ? 'Submitting…' : 'Request Butler'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Butler request details / tracking screen  (customer-facing)
// ---------------------------------------------------------------------------

class ButlerRequestDetailsScreen extends StatelessWidget {
  const ButlerRequestDetailsScreen({super.key, required this.request});

  final backend.ButlerRequest request;

  String get _typeLabel =>
      request.requestType == backend.ButlerRequestType.buySomething
      ? 'Buy something'
      : 'Deliver your stuff';

  String get _statusLabel => switch (request.status) {
    backend.ButlerRequestStatus.pending =>
      'Pending — waiting for a delivery partner',
    backend.ButlerRequestStatus.assigned =>
      'Assigned — delivery partner on the way',
    backend.ButlerRequestStatus.pickedUp => 'Picked up',
    backend.ButlerRequestStatus.onTheWay => 'On the way to you',
    backend.ButlerRequestStatus.delivered => 'Delivered',
    backend.ButlerRequestStatus.cancelled => 'Cancelled',
  };

  Color _statusColor() => switch (request.status) {
    backend.ButlerRequestStatus.delivered => Colors.green.shade700,
    backend.ButlerRequestStatus.cancelled => Colors.red.shade700,
    _ => kDeepGold,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Butler request')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ButlerDetailRow(label: 'Type', value: _typeLabel),
                  const Divider(height: 22),
                  _ButlerDetailRow(
                    label: 'Pickup',
                    value: request.pickupLocation,
                  ),
                  const SizedBox(height: 8),
                  _ButlerDetailRow(
                    label: 'Drop-off',
                    value: request.dropoffLocation,
                  ),
                  if (request.shopName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ButlerDetailRow(label: 'Store', value: request.shopName),
                  ],
                  const Divider(height: 22),
                  _ButlerDetailRow(
                    label: 'Items',
                    value: request.itemDescription,
                  ),
                  if (request.estimatedItemCost != null) ...[
                    const SizedBox(height: 8),
                    _ButlerDetailRow(
                      label: 'Est. cost',
                      value:
                          '\$${request.estimatedItemCost!.toStringAsFixed(2)}',
                    ),
                  ],
                  if (request.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ButlerDetailRow(label: 'Notes', value: request.notes),
                  ],
                  if (request.assignedWorkerName != null &&
                      request.assignedWorkerName!.isNotEmpty) ...[
                    const Divider(height: 22),
                    _ButlerDetailRow(
                      label: 'Partner',
                      value: request.assignedWorkerName!,
                    ),
                  ],
                  const Divider(height: 22),
                  _ButlerDetailRow(
                    label: 'Payment',
                    value: request.paymentStatus == 'cashOnDelivery'
                        ? 'Cash on delivery'
                        : request.paymentStatus,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButlerDetailRow extends StatelessWidget {
  const _ButlerDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Worker: Butler jobs panel shown in DriverHomeScreen
// ---------------------------------------------------------------------------

class _WorkerButlerJobsPanel extends StatelessWidget {
  const _WorkerButlerJobsPanel({
    required this.workerId,
    required this.workerName,
  });

  final String workerId;
  final String workerName;

  @override
  Widget build(BuildContext context) {
    if (workerId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<backend.ButlerRequest>>(
      stream: ButlerService().watchPendingRequests(),
      builder: (context, pendingSnap) {
        return StreamBuilder<List<backend.ButlerRequest>>(
          stream: ButlerService().watchWorkerAssignedRequests(workerId),
          builder: (context, assignedSnap) {
            final pending = pendingSnap.data ?? const [];
            final assigned = assignedSnap.data ?? const [];
            final loading =
                pendingSnap.connectionState == ConnectionState.waiting ||
                assignedSnap.connectionState == ConnectionState.waiting;

            if (!loading && pending.isEmpty && assigned.isEmpty) {
              return _WorkerRequestSectionShell(
                title: 'Butler requests',
                loading: false,
                emptyText: 'No pending Butler requests right now.',
                children: const [],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (assigned.isNotEmpty)
                  _WorkerRequestSectionShell(
                    title: 'Your Butler jobs',
                    loading: loading,
                    emptyText: '',
                    children: assigned
                        .map(
                          (req) => _WorkerActiveButlerCard(
                            request: req,
                            workerId: workerId,
                          ),
                        )
                        .toList(),
                  ),
                if (assigned.isNotEmpty) const SizedBox(height: 16),
                _WorkerRequestSectionShell(
                  title: 'Butler requests',
                  loading: loading,
                  emptyText: 'No pending Butler requests right now.',
                  children: pending
                      .map(
                        (req) => _WorkerPendingButlerCard(
                          request: req,
                          workerId: workerId,
                          workerName: workerName,
                        ),
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

class _WorkerPendingButlerCard extends StatefulWidget {
  const _WorkerPendingButlerCard({
    required this.request,
    required this.workerId,
    required this.workerName,
  });

  final backend.ButlerRequest request;
  final String workerId;
  final String workerName;

  @override
  State<_WorkerPendingButlerCard> createState() =>
      _WorkerPendingButlerCardState();
}

class _WorkerPendingButlerCardState extends State<_WorkerPendingButlerCard> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await ButlerService().claimRequest(
        widget.request.id,
        workerId: widget.workerId,
        workerName: widget.workerName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Butler request accepted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not accept request: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                req.requestType == backend.ButlerRequestType.buySomething
                    ? Icons.shopping_cart_outlined
                    : Icons.local_shipping_outlined,
                size: 18,
                color: kDeepGold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req.requestType == backend.ButlerRequestType.buySomething
                      ? 'Buy something'
                      : 'Deliver your stuff',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyValueRow(label: 'Pickup', value: req.pickupLocation),
          const SizedBox(height: 4),
          _KeyValueRow(label: 'Drop-off', value: req.dropoffLocation),
          const SizedBox(height: 4),
          _KeyValueRow(label: 'Items', value: req.itemDescription),
          if (req.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            _KeyValueRow(label: 'Notes', value: req.notes),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _accept,
            style: FilledButton.styleFrom(
              backgroundColor: kAccentYellow,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(40),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: Text(_loading ? 'Accepting…' : 'Accept Butler job'),
          ),
        ],
      ),
    );
  }
}

class _WorkerActiveButlerCard extends StatefulWidget {
  const _WorkerActiveButlerCard({
    required this.request,
    required this.workerId,
  });

  final backend.ButlerRequest request;
  final String workerId;

  @override
  State<_WorkerActiveButlerCard> createState() =>
      _WorkerActiveButlerCardState();
}

class _WorkerActiveButlerCardState extends State<_WorkerActiveButlerCard> {
  bool _loading = false;

  Future<void> _advance() async {
    final req = widget.request;
    backend.ButlerRequestStatus? next;
    if (req.status == backend.ButlerRequestStatus.assigned) {
      next = backend.ButlerRequestStatus.pickedUp;
    } else if (req.status == backend.ButlerRequestStatus.pickedUp) {
      next = backend.ButlerRequestStatus.onTheWay;
    } else if (req.status == backend.ButlerRequestStatus.onTheWay) {
      next = backend.ButlerRequestStatus.delivered;
    }
    if (next == null) return;
    setState(() => _loading = true);
    try {
      await ButlerService().updateStatus(req.id, next);
      if (!mounted) return;
      final label = switch (next) {
        backend.ButlerRequestStatus.pickedUp => 'Marked as picked up.',
        backend.ButlerRequestStatus.onTheWay => 'Marked as on the way.',
        backend.ButlerRequestStatus.delivered => 'Marked as delivered.',
        _ => 'Status updated.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update status: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _nextStepLabel => switch (widget.request.status) {
    backend.ButlerRequestStatus.assigned => 'Mark picked up',
    backend.ButlerRequestStatus.pickedUp => 'Mark on the way',
    backend.ButlerRequestStatus.onTheWay => 'Mark delivered',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final canAdvance =
        req.status == backend.ButlerRequestStatus.assigned ||
        req.status == backend.ButlerRequestStatus.pickedUp ||
        req.status == backend.ButlerRequestStatus.onTheWay;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                req.requestType == backend.ButlerRequestType.buySomething
                    ? Icons.shopping_cart_outlined
                    : Icons.local_shipping_outlined,
                size: 18,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req.requestType == backend.ButlerRequestType.buySomething
                      ? 'Buy something'
                      : 'Deliver your stuff',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  req.status.name,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyValueRow(label: 'Pickup', value: req.pickupLocation),
          const SizedBox(height: 4),
          _KeyValueRow(label: 'Drop-off', value: req.dropoffLocation),
          const SizedBox(height: 4),
          _KeyValueRow(label: 'Items', value: req.itemDescription),
          if (canAdvance) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _advance,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text(_loading ? 'Updating…' : _nextStepLabel),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin: Butler requests panel
// ---------------------------------------------------------------------------

class _AdminButlerRequestsPanel extends StatelessWidget {
  const _AdminButlerRequestsPanel();

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.instance.isReady) return const SizedBox.shrink();
    return StreamBuilder<List<backend.ButlerRequest>>(
      stream: ButlerService().watchAllRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final requests = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Butler requests',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (requests.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'No Butler requests yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ...requests.map((req) => _AdminButlerRequestTile(request: req)),
          ],
        );
      },
    );
  }
}

class _AdminButlerRequestTile extends StatefulWidget {
  const _AdminButlerRequestTile({required this.request});

  final backend.ButlerRequest request;

  @override
  State<_AdminButlerRequestTile> createState() =>
      _AdminButlerRequestTileState();
}

class _AdminButlerRequestTileState extends State<_AdminButlerRequestTile> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ButlerService().cancelRequest(widget.request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Butler request cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Color _statusColor(backend.ButlerRequestStatus s) => switch (s) {
    backend.ButlerRequestStatus.delivered => Colors.green.shade700,
    backend.ButlerRequestStatus.cancelled => Colors.red.shade700,
    backend.ButlerRequestStatus.assigned ||
    backend.ButlerRequestStatus.pickedUp ||
    backend.ButlerRequestStatus.onTheWay => Colors.blue.shade700,
    _ => kDeepGold,
  };

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  req.requestType == backend.ButlerRequestType.buySomething
                      ? 'Buy something'
                      : 'Deliver your stuff',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(req.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  req.status.name,
                  style: TextStyle(
                    color: _statusColor(req.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyValueRow(label: 'Pickup', value: req.pickupLocation),
          const SizedBox(height: 4),
          _KeyValueRow(label: 'Drop-off', value: req.dropoffLocation),
          const SizedBox(height: 4),
          _KeyValueRow(label: 'Items', value: req.itemDescription),
          if (req.assignedWorkerName != null &&
              req.assignedWorkerName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _KeyValueRow(label: 'Worker', value: req.assignedWorkerName!),
          ],
          if (req.customerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            _KeyValueRow(label: 'Customer', value: req.customerName),
          ],
          if (req.isActive) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _cancelling ? null : _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                minimumSize: const Size.fromHeight(38),
              ),
              child: Text(_cancelling ? 'Cancelling…' : 'Cancel request'),
            ),
          ],
        ],
      ),
    );
  }
}
