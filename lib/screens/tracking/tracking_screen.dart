part of '../../main.dart';

class OfferMatchingScreen extends StatefulWidget {
  const OfferMatchingScreen({super.key, required this.offer});

  final OfferPayload offer;

  @override
  State<OfferMatchingScreen> createState() => _OfferMatchingScreenState();
}

class _OfferMatchingScreenState extends State<OfferMatchingScreen> {
  final JobService _jobService = JobService();
  DriverInfo? _selectedDriver;
  Timer? _jobWatchTimer;

  @override
  void initState() {
    super.initState();
    if (!useFirebaseJobs) {
      _jobWatchTimer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => _openTrackingIfAccepted(),
      );
    }
  }

  @override
  void dispose() {
    _jobWatchTimer?.cancel();
    super.dispose();
  }

  void _openTrackingIfAccepted() {
    if (!mounted) {
      return;
    }
    final job = findServiceJob(widget.offer.id);
    if (job == null ||
        (job.status != DemoServiceJobStatus.accepted &&
            job.status != DemoServiceJobStatus.active)) {
      return;
    }
    final driver = onlineDriversFor(widget.offer.service).isEmpty
        ? demoDrivers(widget.offer.service).first
        : onlineDriversFor(widget.offer.service).first;
    _jobWatchTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(offer: widget.offer, driver: driver),
      ),
    );
  }

  void _accept() {
    final drivers = onlineDriversFor(widget.offer.service);
    if (drivers.isEmpty) {
      return;
    }
    final selected =
        _selectedDriver ??
        drivers.reduce((a, b) => a.distanceKm <= b.distanceKm ? a : b);
    assignServiceJob(widget.offer, selected);
    upsertDemoJob(widget.offer, DemoJobStatus.accepted);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your OMW driver accepted the request')),
    );
    _jobWatchTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(offer: widget.offer, driver: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useFirebaseJobs) {
      return _buildFirebaseMatching();
    }
    final drivers = onlineDriversFor(widget.offer.service);

    return Scaffold(
      appBar: AppBar(title: const Text('Finding OMW drivers')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.offer.id,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${serviceLabel(widget.offer.service)} - \$${widget.offer.offerAmount}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: 28),
            _KeyValueRow(label: 'Pickup', value: widget.offer.pickup),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Destination', value: widget.offer.destination),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Payment',
              value: paymentLabel(widget.offer.paymentMethod),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: kAccentBlue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for OMW drivers to accept your offer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              drivers.isEmpty
                  ? 'No OMW drivers online right now'
                  : 'Online OMW drivers',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (drivers.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No OMW drivers online right now. A test driver can go online from OMW Driver.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    demoWorkerProfile.status = WorkerApplicationStatus.approved;
                    demoWorkerProfile.fullName =
                        demoWorkerProfile.fullName.trim().isEmpty
                        ? 'OMW Driver'
                        : demoWorkerProfile.fullName;
                    demoWorkerProfile.phoneNumber =
                        demoWorkerProfile.phoneNumber.trim().isEmpty
                        ? 'Demo driver'
                        : demoWorkerProfile.phoneNumber;
                    demoWorkerProfile.plateNumber =
                        demoWorkerProfile.plateNumber.trim().isEmpty
                        ? 'DEMO-123'
                        : demoWorkerProfile.plateNumber;
                    demoWorkerProfile.cityArea =
                        demoWorkerProfile.cityArea.trim().isEmpty
                        ? 'Beirut'
                        : demoWorkerProfile.cityArea;
                    for (final name in kWorkerDocumentNames) {
                      demoWorkerProfile.documents[name] =
                          DocumentStatus.approved;
                    }
                    demoDriverAvailability.isOnline = true;
                    demoDriverAvailability.locationLabel =
                        'Demo driver location';
                  });
                },
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Simulate approved OMW driver online'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: kAccentBlue,
                ),
              ),
            ] else
              ...drivers.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DriverCard(
                    driver: d,
                    selected: _selectedDriver == d,
                    selectable: true,
                    onTap: () => setState(() => _selectedDriver = d),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryCtaButton(
              label: 'Simulate OMW Driver Accepts',
              onPressed: drivers.isEmpty ? null : _accept,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseMatching() {
    return StreamBuilder<backend.JobOffer?>(
      stream: _jobService.watchJob(widget.offer.id),
      builder: (context, snapshot) {
        final job = snapshot.data;
        final status = job?.status ?? backend.JobStatus.pending;
        if (status == backend.JobStatus.accepted ||
            status == backend.JobStatus.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => TrackingScreen(
                  offer: job == null ? widget.offer : offerFromBackendJob(job),
                  driver: job == null
                      ? demoDrivers(widget.offer.service).first
                      : driverInfoFromBackendJob(job, widget.offer.service),
                ),
              ),
            );
          });
        }
        final statusText = switch (status) {
          backend.JobStatus.pending =>
            'Waiting for OMW drivers to accept your offer',
          backend.JobStatus.accepted ||
          backend.JobStatus.active => 'Your OMW driver accepted the request',
          backend.JobStatus.completed => 'This OMW job is completed',
          backend.JobStatus.rejected => 'This OMW offer was rejected',
          backend.JobStatus.cancelled => 'This OMW offer was cancelled',
        };
        return Scaffold(
          appBar: AppBar(title: const Text('Finding OMW drivers')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.offer.id,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${serviceLabel(widget.offer.service)} - \$${widget.offer.offerAmount}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 28),
                _KeyValueRow(label: 'Pickup', value: widget.offer.pickup),
                const SizedBox(height: 8),
                _KeyValueRow(
                  label: 'Destination',
                  value: widget.offer.destination,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kAccentYellow.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        const Icon(Icons.radar, color: kDeepGold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.hasError) ...[
                  const SizedBox(height: 16),
                  _StateMessage(
                    icon: Icons.cloud_off_outlined,
                    text:
                        'Could not load live offer status. Please check your connection.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.driver,
    this.selected = false,
    this.selectable = false,
    this.onTap,
  });

  final DriverInfo driver;
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: selected ? 3 : 1,
      borderRadius: BorderRadius.circular(16),
      color: selected ? kAccentBlue.withValues(alpha: 0.08) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kAccentBlue : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: kAccentYellow.withValues(alpha: 0.65),
                child: Text(
                  driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: Color(0xFFFFA000),
                        ),
                        Text(
                          '${driver.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '- ${driver.vehicle}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${driver.distanceKm} km away - ETA ${driver.etaMin} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectable)
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? kAccentBlue : Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> kTrackingSteps = [
  'Your On My Way offer has been sent',
  'Your OMW driver accepted the request',
  'OMW driver on the way',
  'Arrived at pickup',
  'In progress',
  'Completed',
];

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    required this.offer,
    required this.driver,
    this.initialStep = 2,
  });

  final OfferPayload offer;
  final DriverInfo driver;
  final int initialStep;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final JobService _jobService = JobService();
  final LocationSyncService _locationSyncService = LocationSyncService();
  late int _stepIndex;
  bool _savedHistory = false;

  @override
  void initState() {
    super.initState();
    _stepIndex = widget.initialStep.clamp(0, kTrackingSteps.length - 1);
  }

  DemoMapPoint get _pickupPoint => widget.offer.pickupPoint ?? kDemoPickupPoint;
  DemoMapPoint get _destinationPoint =>
      widget.offer.destinationPoint ?? kDemoDestinationPoint;

  DemoMapPoint get _driverPoint {
    final progress = (_stepIndex / (kTrackingSteps.length - 1)).clamp(0.0, 1.0);
    if (_stepIndex <= 3) {
      return DemoMapPoint.lerp(
        const DemoMapPoint(33.8898, 35.4948),
        _pickupPoint,
        progress / 0.6,
      );
    }
    return DemoMapPoint.lerp(
      _pickupPoint,
      _destinationPoint,
      (progress - 0.6).clamp(0.0, 1.0) / 0.4,
    );
  }

  List<DemoMapPoint> _routePointsFor(DemoMapPoint driverPoint) {
    final baseRoute = widget.offer.routePoints.isEmpty
        ? <DemoMapPoint>[_pickupPoint, _destinationPoint]
        : widget.offer.routePoints;
    return [driverPoint, ...baseRoute];
  }

  void _advance() {
    if (_stepIndex >= kTrackingSteps.length - 1) {
      if (!_savedHistory) {
        saveCompletedOfferHistory(widget.offer, widget.driver);
        _savedHistory = true;
      }
      if (useFirebaseJobs) {
        _jobService.completeJob(widget.offer.id);
      }
      completeServiceJob(widget.offer);
      upsertDemoJob(widget.offer, DemoJobStatus.completed);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('OMW trip complete'),
          content: const Text(
            'This completed OMW offer is now saved in History.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _stepIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final status = kTrackingSteps[_stepIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('On My Way Tracking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Row(
              children: [
                OwmBrandMark(size: 42, badge: true),
                SizedBox(width: 10),
                Text(
                  'OMW live tracking',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DriverCard(driver: widget.driver),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showDemoCallDialog(
                      context,
                      title: 'Calling ${widget.driver.name}',
                    ),
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
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DemoChatScreen(
                          title: widget.driver.name,
                          meLabel: 'You',
                          themLabel: widget.driver.name,
                        ),
                      ),
                    ),
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
            const SizedBox(height: 16),
            _TrackingMapCard(
              fallbackDriverPoint: _driverPoint,
              pickupPoint: _pickupPoint,
              destinationPoint: _destinationPoint,
              routePointsFor: _routePointsFor,
              jobId: widget.offer.id,
              jobService: _jobService,
              locationSyncService: _locationSyncService,
              cameraUpdateKey: _stepIndex,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route, color: kAccentBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.offer.pickup} to ${widget.offer.destination} - \$${widget.offer.offerAmount}'
                          '${widget.offer.durationText == null ? '' : ' - ${widget.offer.durationText}'}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payment: ${paymentLabel(widget.offer.paymentMethod)} - Approx. route',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Timeline',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...List.generate(kTrackingSteps.length, (i) {
              final completed = i < _stepIndex;
              final active = i == _stepIndex;
              final pending = i > _stepIndex;
              return _TimelineRow(
                label: kTrackingSteps[i],
                completed: completed,
                active: active,
                pending: pending,
                isLast: i == kTrackingSteps.length - 1,
              );
            }),
            const SizedBox(height: 12),
            PrimaryCtaButton(label: 'Simulate next step', onPressed: _advance),
          ],
        ),
      ),
    );
  }
}

class _TrackingMapCard extends StatelessWidget {
  const _TrackingMapCard({
    required this.fallbackDriverPoint,
    required this.pickupPoint,
    required this.destinationPoint,
    required this.routePointsFor,
    required this.jobId,
    required this.jobService,
    required this.locationSyncService,
    required this.cameraUpdateKey,
  });

  final DemoMapPoint fallbackDriverPoint;
  final DemoMapPoint pickupPoint;
  final DemoMapPoint destinationPoint;
  final List<DemoMapPoint> Function(DemoMapPoint driverPoint) routePointsFor;
  final String jobId;
  final JobService jobService;
  final LocationSyncService locationSyncService;
  final int cameraUpdateKey;

  @override
  Widget build(BuildContext context) {
    if (!useFirebaseJobs) {
      return _map(fallbackDriverPoint, 'Driver location updated just now');
    }
    return StreamBuilder<backend.JobOffer?>(
      stream: jobService.watchJob(jobId),
      builder: (context, jobSnapshot) {
        final assignedWorkerId = jobSnapshot.data?.assignedWorkerId;
        if (assignedWorkerId == null || assignedWorkerId.isEmpty) {
          return _map(
            fallbackDriverPoint,
            'Waiting for assigned driver location',
          );
        }
        return StreamBuilder<backend.DriverLocation?>(
          stream: locationSyncService.watchDriverLocation(assignedWorkerId),
          builder: (context, locationSnapshot) {
            final location = locationSnapshot.data;
            final stale =
                location == null ||
                DateTime.now().difference(location.updatedAt) >
                    const Duration(minutes: 2);
            final driverPoint = location == null
                ? fallbackDriverPoint
                : DemoMapPoint(location.lat, location.lng);
            final message = location == null || stale
                ? 'Driver location is temporarily unavailable'
                : location.isOnline
                ? 'Driver location updated just now'
                : 'Driver is temporarily offline';
            return _map(driverPoint, message);
          },
        );
      },
    );
  }

  Widget _map(DemoMapPoint driverPoint, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 178,
            child: AppMap(
              pickup: pickupPoint,
              destination: destinationPoint,
              driver: driverPoint,
              routePoints: routePointsFor(driverPoint),
              cameraUpdateKey: cameraUpdateKey ^ driverPoint.hashCode,
              showRoute: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.completed,
    required this.active,
    required this.pending,
    required this.isLast,
  });

  final String label;
  final bool completed;
  final bool active;
  final bool pending;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = completed || active ? kDeepGold : Colors.grey.shade400;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_checked,
                color: color,
                size: 22,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade200),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: pending ? Colors.grey.shade500 : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: useFirebaseJobs && user != null
            ? StreamBuilder<List<ServiceRequest>>(
                stream: RequestService().watchCustomerRequests(user.uid),
                builder: (context, snapshot) {
                  final requests = snapshot.data ?? const <ServiceRequest>[];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (requests.isEmpty) {
                    return const _HistoryEmptyState(
                      title: 'No OMW requests yet',
                      message:
                          'Ride, moto, courier, and marketplace delivery requests will appear here.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: requests.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _ServiceRequestHistoryCard(
                        request: requests[index],
                      );
                    },
                  );
                },
              )
            : demoHistory.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 42,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No completed offers yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Finish a demo trip and it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: demoHistory.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = demoHistory[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                serviceIcon(item.offer.service),
                                color: kAccentBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  serviceLabel(item.offer.service),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${item.offer.offerAmount}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          _KeyValueRow(
                            label: 'Destination',
                            value: item.offer.destination,
                          ),
                          const SizedBox(height: 8),
                          _KeyValueRow(label: 'Status', value: item.status),
                          const SizedBox(height: 8),
                          _KeyValueRow(
                            label: 'Driver',
                            value: item.driver.name,
                          ),
                          const SizedBox(height: 8),
                          _KeyValueRow(
                            label: 'Payment',
                            value: paymentLabel(item.offer.paymentMethod),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  BookAgainPayload(
                                    service: item.offer.service,
                                    destination: item.offer.destination,
                                    offerAmount: item.offer.offerAmount,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.replay),
                              label: const Text('Book Again'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                foregroundColor: kAccentBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRequestHistoryCard extends StatelessWidget {
  const _ServiceRequestHistoryCard({required this.request});

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.route_outlined, color: kAccentBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    serviceRequestLabel(request.serviceType),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (request.totalAmount != null)
                  Text(
                    '\$${request.totalAmount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const Divider(height: 22),
            _KeyValueRow(
              label: 'Status',
              value: serviceRequestStatusLabel(request.status),
            ),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Pickup', value: request.pickupAddress),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Drop-off', value: request.dropoffAddress),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Worker',
              value: request.assignedWorkerName?.trim().isNotEmpty == true
                  ? request.assignedWorkerName!
                  : 'Unassigned',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Date', value: _dateLabel(request.createdAt)),
          ],
        ),
      ),
    );
  }
}
