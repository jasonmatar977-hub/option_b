part of '../../main.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({
    super.key,
    required this.userPhone,
    required this.onSignOut,
  });

  final String userPhone;
  final VoidCallback onSignOut;

  void _openRequest(BuildContext context, ServiceType service) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MainMapScreen(
          userPhone: userPhone,
          onSignOut: onSignOut,
          initialService: service,
        ),
      ),
    );
  }

  void _openMarketplace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceHomeScreen(
          userPhone: userPhone,
          deliveryLabel: kCurrentPickup,
          deliveryPoint: kDemoPickupPoint,
          onSwitchAccount: onSignOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text(kBrandName),
        actions: [
          TextButton.icon(
            onPressed: () => switchAccountFrom(context, onSignOut),
            icon: const Icon(Icons.logout),
            label: const Text('Switch'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kBrandBlack,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const OwmBrandMark(size: 58, badge: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'On My Way',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back${userPhone.isEmpty ? '' : ', $userPhone'}',
                          style: const TextStyle(
                            color: kMutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'What do you need today?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.05,
              children: [
                _CustomerServiceCard(
                  key: const ValueKey('customer-service-ride'),
                  icon: Icons.directions_car_filled_outlined,
                  title: 'Ride',
                  subtitle: 'Book a car',
                  onTap: () => _openRequest(context, ServiceType.ride),
                ),
                _CustomerServiceCard(
                  key: const ValueKey('customer-service-moto'),
                  icon: Icons.two_wheeler,
                  title: 'Moto',
                  subtitle: 'Fast moto ride',
                  onTap: () => _openRequest(context, ServiceType.moto),
                ),
                _CustomerServiceCard(
                  key: const ValueKey('customer-service-courier'),
                  icon: Icons.local_shipping_outlined,
                  title: 'Courier',
                  subtitle: 'Send a package',
                  onTap: () => _openRequest(context, ServiceType.courier),
                ),
                _CustomerServiceCard(
                  key: const ValueKey('customer-service-marketplace'),
                  icon: Icons.shopping_bag_outlined,
                  title: 'Marketplace',
                  subtitle: 'Shop online & get delivery',
                  highlighted: true,
                  onTap: () => _openMarketplace(context),
                ),
              ],
            ),
            const SizedBox(height: 22),
            CustomerActiveRequestsSection(
              userPhone: userPhone,
              onSwitchAccount: onSignOut,
            ),
            const SizedBox(height: 22),
            OmwNotificationsCard(userId: userId, roleTarget: 'customer'),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _CustomerMiniActionCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'My Orders',
                    onTap: () => _showComingSoon(context, 'My Orders'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CustomerMiniActionCard(
                    icon: Icons.history,
                    title: 'My Rides',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CustomerMiniActionCard(
                    icon: Icons.support_agent,
                    title: 'Support',
                    onTap: () => _showComingSoon(context, 'Support'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label coming soon.')));
  }
}

class _CustomerServiceCard extends StatelessWidget {
  const _CustomerServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted ? kBrandBlack : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? kAccentYellow.withValues(alpha: 0.7)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: highlighted
                  ? kAccentYellow
                  : kAccentYellow.withValues(alpha: 0.24),
              foregroundColor: kBrandBlack,
              child: Icon(icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: highlighted ? Colors.white : kBrandBlack,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlighted ? kMutedText : Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: highlighted ? kAccentYellow : Colors.grey.shade500,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerActiveRequestsSection extends StatelessWidget {
  const CustomerActiveRequestsSection({
    super.key,
    required this.userPhone,
    required this.onSwitchAccount,
  });

  final String userPhone;
  final VoidCallback onSwitchAccount;

  bool _isVisibleJob(DemoServiceJob job) {
    return job.status == DemoServiceJobStatus.pending ||
        job.status == DemoServiceJobStatus.accepted ||
        job.status == DemoServiceJobStatus.active ||
        job.status == DemoServiceJobStatus.completed;
  }

  bool _isVisibleMarketplace(backend.MarketplaceOrder order) {
    return order.status != backend.MarketplaceOrderStatus.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    if (useFirebaseJobs && user != null) {
      return StreamBuilder<List<ServiceRequest>>(
        stream: RequestService().watchCustomerRequests(user.uid),
        builder: (context, requestSnapshot) {
          return StreamBuilder<List<backend.JobOffer>>(
            stream: JobService().watchCustomerJobs(user.uid),
            builder: (context, jobSnapshot) {
              return StreamBuilder<List<backend.MarketplaceOrder>>(
                stream: MarketplaceService().watchCustomerMarketplaceOrders(
                  user.uid,
                ),
                builder: (context, orderSnapshot) {
                  final serviceRequests =
                      (requestSnapshot.data ?? const <ServiceRequest>[])
                          .where((request) => !request.isDone)
                          .toList();
                  final jobs = (jobSnapshot.data ?? const <backend.JobOffer>[])
                      .where(
                        (job) =>
                            job.status != backend.JobStatus.cancelled &&
                            job.status != backend.JobStatus.rejected,
                      )
                      .map(demoServiceJobFromBackend)
                      .toList();
                  final orders =
                      (orderSnapshot.data ?? const <backend.MarketplaceOrder>[])
                          .where(_isVisibleMarketplace)
                          .toList();
                  return _CustomerActiveRequestsPanel(
                    serviceRequests: serviceRequests,
                    jobs: jobs,
                    marketplaceOrders: orders,
                    onSwitchAccount: onSwitchAccount,
                    loading:
                        requestSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        jobSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        orderSnapshot.connectionState ==
                            ConnectionState.waiting,
                  );
                },
              );
            },
          );
        },
      );
    }

    final jobs = demoServiceJobs
        .where((job) => job.customerPhone == userPhone || userPhone.isEmpty)
        .where(_isVisibleJob)
        .toList();
    final orders = MarketplaceService.localMarketplaceOrders
        .where((order) => order.customerPhone == userPhone || userPhone.isEmpty)
        .where(_isVisibleMarketplace)
        .toList();
    return _CustomerActiveRequestsPanel(
      serviceRequests: const [],
      jobs: jobs,
      marketplaceOrders: orders,
      onSwitchAccount: onSwitchAccount,
    );
  }
}

class _CustomerActiveRequestsPanel extends StatelessWidget {
  const _CustomerActiveRequestsPanel({
    required this.serviceRequests,
    required this.jobs,
    required this.marketplaceOrders,
    required this.onSwitchAccount,
    this.loading = false,
  });

  final List<ServiceRequest> serviceRequests;
  final List<DemoServiceJob> jobs;
  final List<backend.MarketplaceOrder> marketplaceOrders;
  final VoidCallback onSwitchAccount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final visibleRequests = serviceRequests.take(3).toList();
    final visibleJobs = jobs.take(3).toList();
    final visibleOrders = marketplaceOrders.take(3).toList();
    if (!loading &&
        visibleRequests.isEmpty &&
        visibleJobs.isEmpty &&
        visibleOrders.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Active orders & rides',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
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
        ...visibleRequests.map(
          (request) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CustomerServiceRequestCard(request: request),
          ),
        ),
        ...visibleJobs.map(
          (job) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CustomerActiveJobCard(job: job),
          ),
        ),
        ...visibleOrders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CustomerActiveMarketplaceCard(
              order: order,
              onSwitchAccount: onSwitchAccount,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerActiveJobCard extends StatelessWidget {
  const _CustomerActiveJobCard({required this.job});

  final DemoServiceJob job;

  String get _headline {
    switch (job.status) {
      case DemoServiceJobStatus.pending:
        return 'Waiting for driver';
      case DemoServiceJobStatus.accepted:
      case DemoServiceJobStatus.active:
        return 'Driver accepted your ${serviceLabel(job.offer.service).toLowerCase()}';
      case DemoServiceJobStatus.completed:
        return 'Completed';
      case DemoServiceJobStatus.rejected:
      case DemoServiceJobStatus.cancelled:
        return 'Not active';
    }
  }

  void _track(BuildContext context) {
    if (job.status == DemoServiceJobStatus.pending) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OfferMatchingScreen(offer: job.offer),
        ),
      );
      return;
    }
    final driver = job.assignedWorkerName == null
        ? demoDrivers(job.offer.service).first
        : DriverInfo(
            name: job.assignedWorkerName!,
            rating: 4.8,
            vehicle: serviceLabel(job.offer.service),
            distanceKm: 1.2,
            etaMin: 5,
          );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(
          offer: job.offer,
          driver: driver,
          initialStep: job.status == DemoServiceJobStatus.completed ? 5 : 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CustomerActiveCardShell(
      icon: serviceIcon(job.offer.service),
      title: _headline,
      subtitle: serviceLabel(job.offer.service),
      details: [
        if (job.assignedWorkerName != null) 'Driver: ${job.assignedWorkerName}',
        job.offer.destination,
        '\$${job.offer.offerAmount} - ${paymentLabel(job.offer.paymentMethod)}',
      ],
      onTrack: () => _track(context),
    );
  }
}

class _CustomerServiceRequestCard extends StatelessWidget {
  const _CustomerServiceRequestCard({required this.request});

  final ServiceRequest request;

  Future<void> _cancel(BuildContext context) async {
    try {
      await RequestService().cancelRequest(
        request.id,
        customerId: request.customerId,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OMW request canceled.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel this request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = request.assignedWorkerName?.trim().isNotEmpty == true;
    final canCancel =
        request.status != ServiceRequestStatus.completed &&
        request.status != ServiceRequestStatus.canceled;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: kBrandBlack,
                child: Icon(Icons.route_outlined, color: kAccentYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceRequestStatusLabel(request.status),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      serviceRequestLabel(request.serviceType),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${request.pickupAddress} - ${request.dropoffAddress}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (assigned) ...[
            const SizedBox(height: 6),
            Text(
              'Worker: ${request.assignedWorkerName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (request.totalAmount != null) ...[
            const SizedBox(height: 6),
            Text(
              '\$${request.totalAmount!.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _cancel(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerActiveMarketplaceCard extends StatelessWidget {
  const _CustomerActiveMarketplaceCard({
    required this.order,
    required this.onSwitchAccount,
  });

  final backend.MarketplaceOrder order;
  final VoidCallback onSwitchAccount;

  String get _headline {
    switch (order.status) {
      case backend.MarketplaceOrderStatus.pending:
        return 'Waiting for courier';
      case backend.MarketplaceOrderStatus.accepted:
        return 'Courier accepted your marketplace order';
      case backend.MarketplaceOrderStatus.shopping:
        return 'Shopping/preparing';
      case backend.MarketplaceOrderStatus.pickedUp:
        return 'Picked up';
      case backend.MarketplaceOrderStatus.onTheWay:
        return 'On the way';
      case backend.MarketplaceOrderStatus.delivered:
        return 'Delivered';
      case backend.MarketplaceOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _track(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceTrackingScreen(
          order: order,
          onSwitchAccount: onSwitchAccount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CustomerActiveCardShell(
      icon: Icons.shopping_bag_outlined,
      title: _headline,
      subtitle: 'Marketplace - ${order.storeName}',
      details: [
        if (order.assignedWorkerName != null)
          'Courier: ${order.assignedWorkerName}',
        order.deliveryLabel,
        '${order.itemCount} items - \$${order.total.toStringAsFixed(2)}',
      ],
      onTrack: () => _track(context),
    );
  }
}

class _CustomerActiveCardShell extends StatelessWidget {
  const _CustomerActiveCardShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.onTrack,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> details;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kBrandBlack,
            child: Icon(icon, color: kAccentYellow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details
                      .where((detail) => detail.trim().isNotEmpty)
                      .join(' - '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onTrack,
            style: FilledButton.styleFrom(
              backgroundColor: kAccentYellow,
              foregroundColor: kBrandBlack,
            ),
            child: const Text('Track'),
          ),
        ],
      ),
    );
  }
}

class _CustomerMiniActionCard extends StatelessWidget {
  const _CustomerMiniActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kDeepGold),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({
    super.key,
    required this.userPhone,
    required this.onSignOut,
    this.initialService = ServiceType.ride,
  });

  final String userPhone;
  final VoidCallback onSignOut;
  final ServiceType initialService;

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  final GooglePlacesService _placesService = const GooglePlacesService();
  final DirectionsService _directionsService = const DirectionsService();
  final AuthService _authService = AuthService();
  final JobService _jobService = JobService();
  late ServiceType _service;
  final TextEditingController _destinationCtrl = TextEditingController();
  final TextEditingController _offerCtrl = TextEditingController();
  Timer? _destinationDebounce;
  String? _destinationError;
  String? _offerError;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String _pickupLabel = kCurrentPickup;
  DemoMapPoint _pickupPoint = kDemoPickupPoint;
  DemoMapPoint? _selectedDestinationPoint;
  String? _selectedDestinationText;
  List<PlaceSuggestion> _suggestions = const [];
  bool _loadingSuggestions = false;
  String? _placesMessage;
  RouteEstimate? _routeEstimate;
  bool _loadingEstimate = false;
  int _mapCameraKey = 0;
  bool _locating = false;
  bool _showLowOfferWarning = false;

  @override
  void initState() {
    super.initState();
    _service = widget.initialService;
    _setOffer(bandFor(_service).recommended);
  }

  @override
  void dispose() {
    _destinationDebounce?.cancel();
    _destinationCtrl.dispose();
    _offerCtrl.dispose();
    super.dispose();
  }

  DemoMapPoint? get _destinationPoint {
    if (_selectedDestinationPoint != null &&
        _destinationCtrl.text.trim() == _selectedDestinationText) {
      return _selectedDestinationPoint;
    }
    return null;
  }

  bool get _destinationWasManual {
    final typed = _destinationCtrl.text.trim();
    return typed.isNotEmpty && typed != _selectedDestinationText;
  }

  PriceBand get _activePriceBand {
    final base = bandFor(_service);
    final estimate = _routeEstimate;
    if (estimate == null) {
      return base;
    }
    final adjustment = switch (_service) {
      ServiceType.ride => 2.0,
      ServiceType.moto => 1.4,
      ServiceType.courier => 2.4,
    };
    final minimum = math.max(
      base.minimum,
      (5 + estimate.distanceKm * adjustment).round(),
    );
    final recommended = math.max(minimum + 2, (minimum * 1.35).round());
    final fast = math.max(recommended + 4, (recommended * 1.28).round());
    return PriceBand(
      minimum: minimum,
      maximum: math.max(base.maximum, fast + 10),
      recommended: recommended,
      fast: fast,
    );
  }

  double get _averageSpeedKmh {
    return switch (_service) {
      ServiceType.ride => 28,
      ServiceType.moto => 35,
      ServiceType.courier => 25,
    };
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      if (result.point != null) {
        _pickupPoint = result.point!;
        _pickupLabel = 'GPS current location';
        _mapCameraKey++;
      }
    });
    if (result.point != null && _destinationPoint != null) {
      await _updateEstimate();
      if (!mounted) {
        return;
      }
    }
    final message =
        result.message ??
        (result.status == DemoLocationStatus.allowed
            ? 'Current location detected'
            : null);
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String get _destinationHint {
    if (_service == ServiceType.courier) {
      return 'Delivery drop-off';
    }
    return 'Where to?';
  }

  int? get _offerAmount => int.tryParse(_offerCtrl.text.trim());

  void _setOffer(int value) {
    final band = _activePriceBand;
    final clamped = value.clamp(band.minimum, band.maximum).toInt();
    _offerCtrl.text = clamped.toString();
    _offerCtrl.selection = TextSelection.collapsed(
      offset: _offerCtrl.text.length,
    );
    _offerError = null;
    _showLowOfferWarning = clamped < band.minimum;
  }

  void _onDestinationChanged(String value) {
    if (_destinationError != null) {
      _destinationError = null;
    }
    _selectedDestinationPoint = null;
    _selectedDestinationText = null;
    _routeEstimate = null;
    _placesMessage = null;
    _destinationDebounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _loadingSuggestions = false;
      });
      return;
    }

    setState(() => _loadingSuggestions = true);
    _destinationDebounce = Timer(const Duration(milliseconds: 400), () async {
      final localResults = _placesService.localSuggestions(query);
      if (!mounted || _destinationCtrl.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = localResults.take(5).toList();
        _loadingSuggestions = false;
        _placesMessage = localResults.isEmpty
            ? 'No matching places found. You can type manually.'
            : 'Showing local suggestions.';
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingSuggestions = true;
      _suggestions = const [];
      _placesMessage = null;
    });
    setState(() {
      _destinationCtrl.text = suggestion.mainText;
      _selectedDestinationText = suggestion.mainText;
      _selectedDestinationPoint = suggestion.localPoint;
      _loadingSuggestions = false;
      _mapCameraKey++;
    });
    await _updateEstimate();
  }

  Future<void> _updateEstimate({bool useFallbackOnly = false}) async {
    final destination = _destinationPoint;
    if (destination == null) {
      return;
    }

    setState(() => _loadingEstimate = true);
    RouteEstimate estimate;
    try {
      estimate = useFallbackOnly
          ? _directionsService.fallback(
              pickup: _pickupPoint,
              destination: destination,
              averageSpeedKmh: _averageSpeedKmh,
            )
          : await _directionsService.route(
              pickup: _pickupPoint,
              destination: destination,
              averageSpeedKmh: _averageSpeedKmh,
            );
    } catch (_) {
      estimate = _directionsService.fallback(
        pickup: _pickupPoint,
        destination: destination,
        averageSpeedKmh: _averageSpeedKmh,
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _routeEstimate = estimate;
      _loadingEstimate = false;
      _mapCameraKey++;
      final band = _activePriceBand;
      if (_offerAmount == null ||
          _offerAmount == bandFor(_service).recommended) {
        _setOffer(band.recommended);
      }
    });
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                subtitle: const Text('Completed OMW offers'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final booked = await Navigator.of(context)
                      .push<BookAgainPayload>(
                        MaterialPageRoute<BookAgainPayload>(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                  if (booked != null) {
                    setState(() {
                      _service = booked.service;
                      _destinationCtrl.text = booked.destination;
                      _setOffer(booked.offerAmount);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_taxi_outlined),
                title: const Text('OMW Driver'),
                subtitle: const Text('Go online for local testing'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DriverHomeScreen(
                        userPhone: widget.userPhone,
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() => _mapCameraKey++);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Switch account'),
                subtitle: Text(widget.userPhone),
                onTap: () {
                  Navigator.of(ctx).pop();
                  switchAccountFrom(context, widget.onSignOut);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendOffer() async {
    final dest = _destinationCtrl.text.trim();
    final amount = _offerAmount;
    final band = _activePriceBand;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var payloadDestinationPoint = _destinationPoint;
    var payloadRouteEstimate = _routeEstimate;

    setState(() {
      _destinationError = dest.isEmpty ? 'Destination is required' : null;
      _offerError = amount == null ? 'Offer amount is required' : null;
      _showLowOfferWarning = amount != null && amount < band.minimum;
    });

    if (_destinationError != null || _offerError != null || amount == null) {
      return;
    }

    if (_destinationWasManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a suggestion for accurate ETA, or continue manually.',
          ),
        ),
      );
      payloadDestinationPoint ??= kDemoDestinationPoint;
      payloadRouteEstimate ??= _directionsService.fallback(
        pickup: _pickupPoint,
        destination: payloadDestinationPoint,
        averageSpeedKmh: _averageSpeedKmh,
      );
      if (!mounted) {
        return;
      }
    }

    if (amount < band.minimum) {
      final keepGoing = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Low offer'),
          content: Text(
            'The suggested minimum for ${serviceLabel(_service).toLowerCase()} is \$${band.minimum}. '
            'Drivers may ignore lower offers. Send it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Edit offer'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Send anyway'),
            ),
          ],
        ),
      );
      if (keepGoing != true) {
        return;
      }
    }

    final payload = OfferPayload(
      id: 'OPT-B-${1000 + math.Random().nextInt(9000)}',
      service: _service,
      pickup: _pickupLabel,
      destination: dest,
      offerAmount: amount,
      paymentMethod: _paymentMethod,
      pickupPoint: _pickupPoint,
      destinationPoint: payloadDestinationPoint,
      routePoints: payloadRouteEstimate?.routePoints ?? const [],
      distanceText: payloadRouteEstimate?.distanceText,
      durationText: payloadRouteEstimate?.durationText,
      manualDestination: _destinationWasManual,
    );
    if (useFirebaseJobs) {
      final user = _authService.currentUser;
      if (user == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to send an OMW offer.'),
          ),
        );
        return;
      }
      try {
        final jobId = await _jobService.createJobOffer(
          backendJobFromOffer(offer: payload, user: user),
        );
        final requestId = await RequestService().createRequest(
          ServiceRequest(
            id: '',
            serviceType: canonicalServiceTypeFor(payload.service),
            customerId: user.uid,
            customerName: user.displayName ?? 'OMW Customer',
            customerPhone: user.phoneNumber ?? '',
            pickupAddress: payload.pickup,
            pickupLat: payload.pickupPoint?.latitude,
            pickupLng: payload.pickupPoint?.longitude,
            dropoffAddress: payload.destination,
            dropoffLat: payload.destinationPoint?.latitude,
            dropoffLng: payload.destinationPoint?.longitude,
            packageDetails: payload.service == ServiceType.courier
                ? payload.destination
                : null,
            notes: payload.service == ServiceType.courier
                ? 'Courier request'
                : null,
            status: ServiceRequestStatus.requested,
            totalAmount: payload.offerAmount.toDouble(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (!context.mounted) {
          return;
        }
        if (jobId == null && requestId == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not send your OMW offer. Please try again.'),
            ),
          );
          return;
        }
        final firestorePayload = OfferPayload(
          id: jobId ?? requestId ?? payload.id,
          service: payload.service,
          pickup: payload.pickup,
          destination: payload.destination,
          offerAmount: payload.offerAmount,
          paymentMethod: payload.paymentMethod,
          pickupPoint: payload.pickupPoint,
          destinationPoint: payload.destinationPoint,
          routePoints: payload.routePoints,
          distanceText: payload.distanceText,
          durationText: payload.durationText,
          manualDestination: payload.manualDestination,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Your On My Way offer has been sent')),
        );
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => OfferMatchingScreen(offer: firestorePayload),
          ),
        );
        return;
      } on FirebaseException catch (error) {
        if (!context.mounted) {
          return;
        }
        final message = error.code == 'permission-denied'
            ? 'You do not have permission to create this offer yet.'
            : 'Network error while sending your OMW offer. Please try again.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not send your OMW offer. Please try again.'),
          ),
        );
        return;
      }
    }
    upsertServiceJob(offer: payload, customerPhone: widget.userPhone);
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfferMatchingScreen(offer: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = _activePriceBand;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              pickup: _pickupPoint,
              destination: _destinationPoint,
              driver: demoDriverAvailability.isOnline
                  ? demoDriverAvailability.location
                  : null,
              routePoints: _routeEstimate?.routePoints ?? const [],
              cameraUpdateKey: _mapCameraKey,
              showRoute: _destinationPoint != null,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: kBrandBlack,
                      foregroundColor: kAccentYellow,
                    ),
                    onPressed: _openMenu,
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _locating ? null : _useCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: kBrandBlack,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_locating)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.my_location,
                              size: 18,
                              color: kAccentYellow,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _pickupLabel == kCurrentPickup
                                ? 'Current location'
                                : 'GPS location',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.42,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9F8F2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Row(
                        children: [
                          OwmBrandMark(size: 44, badge: true),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nearby OMW Offers',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ride  Moto  Courier',
                                  style: TextStyle(
                                    color: kDeepGold,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a service, set your price, and nearby OMW workers can accept.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('Service'),
                      Row(
                        children: [
                          ...ServiceType.values.map(
                            (s) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _ServiceOption(
                                  service: s,
                                  selected: _service == s,
                                  onTap: () {
                                    setState(() {
                                      _service = s;
                                      _setOffer(_activePriceBand.recommended);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Pickup'),
                      TextFormField(
                        key: ValueKey(_pickupLabel),
                        initialValue: _pickupLabel,
                        readOnly: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.my_location,
                            color: kAccentBlue,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _locating ? null : _useCurrentLocation,
                            icon: const Icon(Icons.gps_fixed),
                            tooltip: 'Use current location',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SectionLabel('Destination'),
                      TextField(
                        controller: _destinationCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: _destinationHint,
                          errorText: _destinationError,
                          prefixIcon: const Icon(
                            Icons.place_outlined,
                            color: kAccentBlue,
                          ),
                        ),
                        onChanged: (_) {
                          _onDestinationChanged(_destinationCtrl.text);
                        },
                      ),
                      if (_loadingSuggestions) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _PlacesSuggestionList(
                          suggestions: _suggestions,
                          onSelected: _selectSuggestion,
                        ),
                      ] else if (_placesMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _placesMessage!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_destinationWasManual &&
                          _destinationCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Select a suggestion for accurate ETA, or continue manually.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_loadingEstimate || _routeEstimate != null) ...[
                        _EstimateCard(
                          estimate: _routeEstimate,
                          loading: _loadingEstimate,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SectionLabel('Suggested price'),
                      Row(
                        children: [
                          Expanded(
                            child: _PriceCard(
                              label: 'Minimum',
                              amount: band.minimum,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PriceCard(
                              label: 'Maximum',
                              amount: band.maximum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _RecommendedOfferCard(amount: band.recommended),
                      const SizedBox(height: 12),
                      _OfferSlider(
                        amount: (_offerAmount ?? band.recommended)
                            .clamp(band.minimum, band.maximum)
                            .toInt(),
                        band: band,
                        onChanged: (value) => setState(() => _setOffer(value)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _offerCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Your offer',
                          errorText: _offerError,
                          prefixText: '\$ ',
                          prefixIcon: const Icon(
                            Icons.payments_outlined,
                            color: kAccentBlue,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _offerError = value.trim().isEmpty
                                ? 'Offer amount is required'
                                : null;
                            final amount = int.tryParse(value.trim());
                            _showLowOfferWarning =
                                amount != null && amount < band.minimum;
                          });
                        },
                      ),
                      if (_showLowOfferWarning) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Below suggested minimum. You can still send it, but acceptance is less likely.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PriceChip(
                            label: 'Minimum',
                            value: band.minimum,
                            selected: _offerAmount == band.minimum,
                            onTap: () =>
                                setState(() => _setOffer(band.minimum)),
                          ),
                          _PriceChip(
                            label: 'Recommended',
                            value: band.recommended,
                            selected: _offerAmount == band.recommended,
                            onTap: () =>
                                setState(() => _setOffer(band.recommended)),
                          ),
                          _PriceChip(
                            label: 'Fast pickup',
                            value: band.fast,
                            selected: _offerAmount == band.fast,
                            onTap: () => setState(() => _setOffer(band.fast)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Payment'),
                      _PaymentSelector(
                        selected: _paymentMethod,
                        onChanged: (method) {
                          setState(() => _paymentMethod = method);
                        },
                      ),
                      const SizedBox(height: 16),
                      _OnlineDriverPreview(service: _service),
                      const SizedBox(height: 20),
                      PrimaryCtaButton(
                        label: 'Send OMW Offer',
                        onPressed: _sendOffer,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  const _ServiceOption({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceType service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? kAccentYellow.withValues(alpha: 0.32)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kDeepGold : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              serviceIcon(service),
              color: selected ? kBrandBlack : Colors.grey.shade700,
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                serviceLabel(service),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? kBrandBlack : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
