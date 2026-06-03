part of '../../main.dart';

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8A6D00)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirebaseDriverNearbyQueue extends StatelessWidget {
  const _FirebaseDriverNearbyQueue({
    required this.jobService,
    required this.marketplaceService,
    required this.driverPoint,
    required this.selectedJob,
    required this.selectedMarketplaceJob,
    required this.onSelectJob,
    required this.onOpenJobDetail,
    required this.onSelectMarketplaceJob,
    required this.onOpenMarketplaceDetail,
  });

  final JobService jobService;
  final MarketplaceService marketplaceService;
  final DemoMapPoint driverPoint;
  final DemoServiceJob? selectedJob;
  final MarketplaceDeliveryJob? selectedMarketplaceJob;
  final ValueChanged<DemoServiceJob> onSelectJob;
  final ValueChanged<DemoServiceJob> onOpenJobDetail;
  final ValueChanged<MarketplaceDeliveryJob> onSelectMarketplaceJob;
  final ValueChanged<MarketplaceDeliveryJob> onOpenMarketplaceDetail;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.JobOffer>>(
      stream: jobService.watchNearbyJobs(
        workerLat: driverPoint.latitude,
        workerLng: driverPoint.longitude,
        radiusMiles: 50,
      ),
      builder: (context, jobSnapshot) {
        return StreamBuilder<List<backend.MarketplaceOrder>>(
          stream: marketplaceService.watchAvailableDeliveryOrders(),
          builder: (context, orderSnapshot) {
            if (jobSnapshot.hasError || orderSnapshot.hasError) {
              return _StateMessage(
                icon: Icons.cloud_off_outlined,
                text:
                    'Could not load nearby OMW offers. Check your connection.',
              );
            }
            final jobs = (jobSnapshot.data ?? const [])
                .map(demoServiceJobFromBackend)
                .toList();
            final marketplaceJobs = (orderSnapshot.data ?? const [])
                .map((order) {
                  final store = MarketplaceService.sampleStores.firstWhere(
                    (candidate) => candidate.id == order.storeId,
                    orElse: () => MarketplaceService.sampleStores.first,
                  );
                  return MarketplaceDeliveryJob(order: order, store: store);
                })
                .where(
                  (job) =>
                      demoDistanceKm(driverPoint, job.pickupPoint) <= 80.47,
                )
                .toList();
            return _DriverNearbyOffersPanel(
              jobs: jobs,
              marketplaceJobs: marketplaceJobs,
              driverPoint: driverPoint,
              selectedJob: selectedJob,
              selectedMarketplaceJob: selectedMarketplaceJob,
              onSelect: onSelectJob,
              onOpenDetail: onOpenJobDetail,
              onSelectMarketplace: onSelectMarketplaceJob,
              onOpenMarketplaceDetail: onOpenMarketplaceDetail,
            );
          },
        );
      },
    );
  }
}

class _DriverNearbyOffersPanel extends StatelessWidget {
  const _DriverNearbyOffersPanel({
    required this.jobs,
    this.marketplaceJobs = const [],
    required this.driverPoint,
    required this.selectedJob,
    this.selectedMarketplaceJob,
    required this.onSelect,
    required this.onOpenDetail,
    this.onSelectMarketplace,
    this.onOpenMarketplaceDetail,
  });

  final List<DemoServiceJob> jobs;
  final List<MarketplaceDeliveryJob> marketplaceJobs;
  final DemoMapPoint driverPoint;
  final DemoServiceJob? selectedJob;
  final MarketplaceDeliveryJob? selectedMarketplaceJob;
  final ValueChanged<DemoServiceJob> onSelect;
  final ValueChanged<DemoServiceJob> onOpenDetail;
  final ValueChanged<MarketplaceDeliveryJob>? onSelectMarketplace;
  final ValueChanged<MarketplaceDeliveryJob>? onOpenMarketplaceDetail;

  @override
  Widget build(BuildContext context) {
    final activeJob = selectedJob ?? (jobs.isEmpty ? null : jobs.first);
    final activeMarketplaceJob =
        selectedMarketplaceJob ??
        (activeJob == null && marketplaceJobs.isNotEmpty
            ? marketplaceJobs.first
            : null);
    final markers = [
      ...jobs.map(
        (job) => DemoMapMarker(
          id: job.offer.id,
          point: job.pickupPoint,
          label: '\$${job.offer.offerAmount}',
          icon: serviceIcon(job.offer.service),
        ),
      ),
      ...marketplaceJobs.map(
        (job) => DemoMapMarker(
          id: job.order.id,
          point: job.pickupPoint,
          label: 'MKT',
          icon: Icons.shopping_bag_outlined,
        ),
      ),
    ];
    final selectedMarkerId =
        selectedJob?.offer.id ?? selectedMarketplaceJob?.id;
    final mapPickup =
        activeJob?.pickupPoint ??
        activeMarketplaceJob?.pickupPoint ??
        driverPoint;
    final mapDestination =
        activeJob?.destinationPoint ?? activeMarketplaceJob?.destinationPoint;
    final routePoints = activeJob != null
        ? [driverPoint, activeJob.pickupPoint, activeJob.destinationPoint]
        : activeMarketplaceJob == null
        ? const <DemoMapPoint>[]
        : [
            driverPoint,
            activeMarketplaceJob.pickupPoint,
            activeMarketplaceJob.destinationPoint,
          ];
    final totalItems = jobs.length + marketplaceJobs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nearby OMW Offers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Within 50 miles',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppMap(
            pickup: mapPickup,
            destination: mapDestination,
            driver: driverPoint,
            offerMarkers: markers,
            selectedMarkerId: selectedMarkerId,
            onMarkerTap: (id) {
              DemoServiceJob? match;
              for (final job in jobs) {
                if (job.offer.id == id) {
                  match = job;
                  break;
                }
              }
              if (match != null) {
                onOpenDetail(match);
                return;
              }
              MarketplaceDeliveryJob? marketplaceMatch;
              for (final job in marketplaceJobs) {
                if (job.id == id) {
                  marketplaceMatch = job;
                  break;
                }
              }
              if (marketplaceMatch != null) {
                onOpenMarketplaceDetail?.call(marketplaceMatch);
              }
            },
            routePoints: routePoints,
            height: 230,
            showRoute: activeJob != null || activeMarketplaceJob != null,
            gesturesEnabled: false, // embedded in scroll view
          ),
        ),
        const SizedBox(height: 12),
        if (totalItems == 0)
          _StateMessage(
            icon: Icons.radar,
            text:
                'No OMW offers nearby yet. Ride, courier, and marketplace requests will appear here.',
          )
        else ...[
          Text(
            'Showing offers within 50 miles',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 430),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: totalItems,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= jobs.length) {
                  final marketplaceJob = marketplaceJobs[index - jobs.length];
                  return _DriverMarketplaceOrderCard(
                    job: marketplaceJob,
                    selected: selectedMarketplaceJob?.id == marketplaceJob.id,
                    onTap: () => onSelectMarketplace?.call(marketplaceJob),
                    onOpenDetail: () =>
                        onOpenMarketplaceDetail?.call(marketplaceJob),
                  );
                }
                final job = jobs[index];
                return _DriverNearbyOfferCard(
                  job: job,
                  selected: selectedJob?.offer.id == job.offer.id,
                  onTap: () => onSelect(job),
                  onOpenDetail: () => onOpenDetail(job),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _DriverNearbyOfferCard extends StatelessWidget {
  const _DriverNearbyOfferCard({
    required this.job,
    required this.selected,
    required this.onTap,
    required this.onOpenDetail,
  });

  final DemoServiceJob job;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final offer = job.offer;
    final distanceKm = demoDistanceKm(
      demoDriverAvailability.location,
      job.pickupPoint,
    );
    return Card(
      elevation: selected ? 3 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: selected ? kAccentBlue.withValues(alpha: 0.07) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(serviceIcon(offer.service), color: kAccentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${serviceLabel(offer.service)} offer',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '\$${offer.offerAmount}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _KeyValueRow(
                label: 'Status',
                value: serviceJobStatusLabel(job.status),
              ),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Pickup', value: offer.pickup),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Destination', value: offer.destination),
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
              Text(
                '${distanceKm.toStringAsFixed(1)} km away - ${math.max(2, (distanceKm / 35 * 60).round())} min to pickup',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Open details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverMarketplaceOrderCard extends StatelessWidget {
  const _DriverMarketplaceOrderCard({
    required this.job,
    required this.selected,
    required this.onTap,
    required this.onOpenDetail,
  });

  final MarketplaceDeliveryJob job;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final order = job.order;
    final distanceKm = demoDistanceKm(
      demoDriverAvailability.location,
      job.pickupPoint,
    );
    return Card(
      elevation: selected ? 3 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: selected ? kAccentYellow.withValues(alpha: 0.14) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: kDeepGold),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Marketplace Order',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '\$${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _KeyValueRow(label: 'Store', value: order.storeName),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Items', value: '${order.itemCount} items'),
              const SizedBox(height: 8),
              _KeyValueRow(
                label: 'Products',
                value: marketplaceItemSummary(order.items),
              ),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Pickup', value: job.storeAddress),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Deliver to', value: order.deliveryLabel),
              const SizedBox(height: 8),
              _KeyValueRow(
                label: 'Payment',
                value: paymentLabel(
                  paymentMethodFromBackend(order.paymentMethod),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${distanceKm.toStringAsFixed(1)} km away - ${math.max(2, (distanceKm / 35 * 60).round())} min to store',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Open details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDeepGold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverDashboardSummary extends StatelessWidget {
  const _DriverDashboardSummary({required this.summary});

  final DriverEarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'OMW earnings dashboard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _MetricCard(
              label: 'Today',
              value: '\$${summary.netEarnings.toStringAsFixed(2)}',
            ),
            _MetricCard(
              label: 'This week',
              value: '\$${summary.netEarnings.toStringAsFixed(2)}',
            ),
            _MetricCard(label: 'Completed', value: '${summary.completedJobs}'),
            _MetricCard(
              label: 'Acceptance %',
              value: '${summary.acceptanceRate.round()}%',
            ),
            _MetricCard(
              label: 'Cash',
              value: '\$${summary.cashCollected.toStringAsFixed(2)}',
            ),
            _MetricCard(
              label: 'Card',
              value: '\$${summary.cardPayments.toStringAsFixed(2)}',
            ),
            _MetricCard(
              label: 'Total earned',
              value: '\$${summary.netEarnings.toStringAsFixed(2)}',
            ),
            _MetricCard(
              label: 'Unpaid',
              value: '\$${summary.unpaidBalance.toStringAsFixed(2)}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _CompactMoneyRow(label: 'Gross fare', value: summary.grossFare),
              _CompactMoneyRow(
                label: 'Platform fee / commission',
                value: summary.platformCommission,
              ),
              _CompactMoneyRow(
                label: 'Total earned',
                value: summary.netEarnings,
              ),
              _CompactMoneyRow(
                label: 'Unpaid balance',
                value: summary.unpaidBalance,
              ),
              _CompactMoneyRow(
                label: 'Paid balance',
                value: summary.paidBalance,
              ),
              const SizedBox(height: 8),
              Text(
                'Payout method: ${payoutMethodLabel(demoWorkerProfile.payoutMethod)} - ${demoWorkerProfile.payoutDisplayName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Payouts are processed by On My Way according to your approved payout method.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
