part of '../../main.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  OwnerTimeFilter _filter = OwnerTimeFilter.today;

  void _approve() {
    setState(() {
      demoWorkerProfile.status = WorkerApplicationStatus.approved;
      for (final name in kWorkerDocumentNames) {
        if (demoWorkerProfile.documents[name] == DocumentStatus.uploaded) {
          demoWorkerProfile.documents[name] = DocumentStatus.approved;
        }
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Worker approved')));
  }

  void _cancelJob(DemoServiceJob job) {
    setState(() {
      job.status = DemoServiceJobStatus.cancelled;
      job.rejectedAt = DateTime.now();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Offer cancelled')));
  }

  void _suspendWorker() {
    setState(() {
      demoDriverAvailability.isOnline = false;
      demoWorkerProfile.status = WorkerApplicationStatus.rejected;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Worker suspended in demo mode')),
    );
  }

  void _reject() {
    setState(() {
      demoWorkerProfile.status = WorkerApplicationStatus.rejected;
      demoDriverAvailability.isOnline = false;
      for (final name in kWorkerDocumentNames) {
        if (demoWorkerProfile.documents[name] == DocumentStatus.uploaded) {
          demoWorkerProfile.documents[name] = DocumentStatus.rejected;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Application rejected. Please update documents and resubmit.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = demoWorkerProfile;
    final jobs = filteredOwnerJobs(_filter);
    final metrics = ownerMetricsFor(jobs);
    final pending = profile.status == WorkerApplicationStatus.pending;
    final approved = profile.status == WorkerApplicationStatus.approved;
    final rejected = profile.status == WorkerApplicationStatus.rejected;
    if (useFirebaseJobs) {
      return StreamBuilder<List<backend.JobOffer>>(
        stream: JobService().watchOwnerJobs(),
        builder: (context, snapshot) {
          final firebaseJobs = (snapshot.data ?? const [])
              .where((job) => _isInOwnerFilter(job.createdAt, _filter))
              .map(demoServiceJobFromBackend)
              .toList();
          return _OwnerFirebaseDashboard(
            filter: _filter,
            jobs: firebaseJobs,
            loading: snapshot.connectionState == ConnectionState.waiting,
            hasError: snapshot.hasError,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onCancelJob: (job) async {
              try {
                await JobService().cancelJob(job.offer.id);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not cancel this OMW offer.'),
                    ),
                  );
                }
              }
            },
            onSignOut: widget.onSignOut,
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('OMW Control Center'),
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
              'OMW Control Center',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor live OMW offers, worker approvals, active jobs, and local test revenue.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _OwnerTimeFilterChips(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 18),
            _OwnerMetricsGrid(metrics: metrics),
            const SizedBox(height: 18),
            OmwNotificationsCard(
              userId: AuthService().currentUser?.uid,
              roleTarget: 'owner',
            ),
            const SizedBox(height: 18),
            _OwnerChartPanel(metrics: metrics),
            const SizedBox(height: 18),
            _OwnerRevenuePanel(metrics: metrics),
            const SizedBox(height: 18),
            _OwnerFinancialDashboard(jobs: jobs, filter: _filter),
            const SizedBox(height: 18),
            const _OwnerMarketplacePanel(),
            const SizedBox(height: 18),
            _OwnerLiveMapPreview(jobs: jobs),
            const SizedBox(height: 18),
            _OwnerJobSection(
              title: 'Pending OMW offers',
              emptyText: 'No pending OMW offers in this period.',
              jobs: jobs
                  .where((job) => job.status == DemoServiceJobStatus.pending)
                  .toList(),
              onCancel: _cancelJob,
            ),
            _OwnerJobSection(
              title: 'Active jobs',
              emptyText: 'No active jobs in this period.',
              jobs: jobs
                  .where(
                    (job) =>
                        job.status == DemoServiceJobStatus.accepted ||
                        job.status == DemoServiceJobStatus.active,
                  )
                  .toList(),
              onCancel: _cancelJob,
            ),
            _OwnerJobSection(
              title: 'Completed jobs',
              emptyText: 'No completed jobs in this period.',
              jobs: jobs
                  .where((job) => job.status == DemoServiceJobStatus.completed)
                  .toList(),
              onCancel: _cancelJob,
            ),
            _OwnerJobSection(
              title: 'Rejected / cancelled jobs',
              emptyText: 'No rejected or cancelled jobs in this period.',
              jobs: jobs
                  .where(
                    (job) =>
                        job.status == DemoServiceJobStatus.rejected ||
                        job.status == DemoServiceJobStatus.cancelled,
                  )
                  .toList(),
              onCancel: _cancelJob,
            ),
            const SizedBox(height: 16),
            const Text(
              'Workers',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AdminCountCard(
                    label: 'Pending',
                    count: pending ? 1 : 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminCountCard(
                    label: 'Approved',
                    count: approved ? 1 : 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminCountCard(
                    label: 'Rejected',
                    count: rejected ? 1 : 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile.status == WorkerApplicationStatus.notStarted ||
                profile.status == WorkerApplicationStatus.incomplete)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'No pending OMW worker applications yet.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            else
              _WorkerApplicationCard(
                profile: profile,
                onApprove: pending || rejected ? _approve : null,
                onReject: pending || approved ? _reject : null,
              ),
            const SizedBox(height: 12),
            _OwnerWorkerPerformanceCard(
              profile: profile,
              summary: driverEarningsSummary(),
              onApprove: pending || rejected ? _approve : null,
              onReject: pending || approved ? _reject : null,
              onSuspend: approved ? _suspendWorker : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerFirebaseDashboard extends StatelessWidget {
  const _OwnerFirebaseDashboard({
    required this.filter,
    required this.jobs,
    required this.loading,
    required this.hasError,
    required this.onFilterChanged,
    required this.onCancelJob,
    required this.onSignOut,
  });

  final OwnerTimeFilter filter;
  final List<DemoServiceJob> jobs;
  final bool loading;
  final bool hasError;
  final ValueChanged<OwnerTimeFilter> onFilterChanged;
  final ValueChanged<DemoServiceJob> onCancelJob;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.DriverLocation>>(
      stream: LocationSyncService().watchOnlineDriversForOwner(),
      builder: (context, driverSnapshot) {
        final onlineDrivers = driverSnapshot.data ?? const [];
        final metrics = ownerMetricsFor(
          jobs,
          onlineWorkersOverride: onlineDrivers.length,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('OMW Control Center'),
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
                const Text(
                  'OMW Control Center',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Live Firestore offers, revenue, and job status.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (hasError) ...[
                  const SizedBox(height: 12),
                  _StateMessage(
                    icon: Icons.cloud_off_outlined,
                    text:
                        'Could not load live OMW jobs. Check Firestore permissions and connection.',
                  ),
                ],
                const SizedBox(height: 16),
                _OwnerTimeFilterChips(
                  selected: filter,
                  onChanged: onFilterChanged,
                ),
                const SizedBox(height: 18),
                _OwnerMetricsGrid(metrics: metrics),
                const SizedBox(height: 18),
                OmwNotificationsCard(
                  userId: AuthService().currentUser?.uid,
                  roleTarget: 'owner',
                ),
                const SizedBox(height: 18),
                _OwnerChartPanel(metrics: metrics),
                const SizedBox(height: 18),
                _OwnerRevenuePanel(metrics: metrics),
                const SizedBox(height: 18),
                _OwnerFinancialDashboard(jobs: jobs, filter: filter),
                const SizedBox(height: 18),
                const _OwnerMarketplacePanel(),
                const SizedBox(height: 18),
                const _OwnerStoreHealthPanel(),
                const SizedBox(height: 18),
                const _OwnerServiceRequestsPanel(),
                const SizedBox(height: 18),
                const _FirebaseWorkerApprovalPanel(),
                const SizedBox(height: 18),
                _OwnerLiveMapPreview(jobs: jobs, onlineDrivers: onlineDrivers),
                const SizedBox(height: 18),
                _OwnerJobSection(
                  title: 'Pending OMW offers',
                  emptyText: 'No pending OMW offers in this period.',
                  jobs: jobs
                      .where(
                        (job) => job.status == DemoServiceJobStatus.pending,
                      )
                      .toList(),
                  onCancel: onCancelJob,
                ),
                _OwnerJobSection(
                  title: 'Active jobs',
                  emptyText: 'No active jobs in this period.',
                  jobs: jobs
                      .where(
                        (job) =>
                            job.status == DemoServiceJobStatus.accepted ||
                            job.status == DemoServiceJobStatus.active,
                      )
                      .toList(),
                  onCancel: onCancelJob,
                ),
                _OwnerJobSection(
                  title: 'Completed jobs',
                  emptyText: 'No completed jobs in this period.',
                  jobs: jobs
                      .where(
                        (job) => job.status == DemoServiceJobStatus.completed,
                      )
                      .toList(),
                  onCancel: onCancelJob,
                ),
                _OwnerJobSection(
                  title: 'Rejected / cancelled jobs',
                  emptyText: 'No rejected or cancelled jobs in this period.',
                  jobs: jobs
                      .where(
                        (job) =>
                            job.status == DemoServiceJobStatus.rejected ||
                            job.status == DemoServiceJobStatus.cancelled,
                      )
                      .toList(),
                  onCancel: onCancelJob,
                ),
                const SizedBox(height: 12),
                const Text(
                  'TODO: Firestore rules must ensure customers read/write only their jobs, approved workers read pending jobs, assigned workers update assigned jobs, and owners manage all jobs.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminCountCard extends StatelessWidget {
  const _AdminCountCard({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBrandSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: kAccentYellow,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerTimeFilterChips extends StatelessWidget {
  const _OwnerTimeFilterChips({
    required this.selected,
    required this.onChanged,
  });

  final OwnerTimeFilter selected;
  final ValueChanged<OwnerTimeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: OwnerTimeFilter.values
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(ownerFilterLabel(filter)),
                  selected: selected == filter,
                  onSelected: (_) => onChanged(filter),
                  selectedColor: kAccentYellow.withValues(alpha: 0.55),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OwnerMetricsGrid extends StatelessWidget {
  const _OwnerMetricsGrid({required this.metrics});

  final OwnerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Total OMW offers', '${metrics.totalOffers}'),
      ('Pending OMW offers', '${metrics.pendingOffers}'),
      ('Active jobs', '${metrics.acceptedJobs}'),
      ('Completed jobs', '${metrics.completedJobs}'),
      ('Rejected jobs', '${metrics.rejectedJobs}'),
      ('Online workers', '${metrics.onlineWorkers}'),
      ('Gross revenue', '\$${metrics.grossRevenue.toStringAsFixed(2)}'),
      (
        'Platform commission',
        '\$${metrics.platformCommission.toStringAsFixed(2)}',
      ),
      ('Worker payouts', '\$${metrics.workerPayouts.toStringAsFixed(2)}'),
      ('Net platform', '\$${metrics.netPlatformEarnings.toStringAsFixed(2)}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.78,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            for (final card in cards)
              _MetricCard(label: card.$1, value: card.$2),
          ],
        ),
      ],
    );
  }
}

class _OwnerChartPanel extends StatelessWidget {
  const _OwnerChartPanel({required this.metrics});

  final OwnerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final maxJobs = math.max(
      1,
      math.max(
        metrics.completedJobs,
        math.max(
          metrics.acceptedJobs,
          math.max(metrics.pendingOffers, metrics.rejectedJobs),
        ),
      ),
    );
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
            'Charts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _BarMeter(
            label: 'Gross revenue',
            valueLabel: '\$${metrics.grossRevenue.toStringAsFixed(2)}',
            percent: metrics.grossRevenue == 0 ? 0 : 1,
            color: kDeepGold,
          ),
          _BarMeter(
            label: 'Pending',
            valueLabel: '${metrics.pendingOffers}',
            percent: metrics.pendingOffers / maxJobs,
            color: Colors.orange,
          ),
          _BarMeter(
            label: 'Active jobs',
            valueLabel: '${metrics.acceptedJobs}',
            percent: metrics.acceptedJobs / maxJobs,
            color: kDeepGold,
          ),
          _BarMeter(
            label: 'Completed jobs',
            valueLabel: '${metrics.completedJobs}',
            percent: metrics.completedJobs / maxJobs,
            color: Colors.green,
          ),
          _BarMeter(
            label: 'Rejected',
            valueLabel: '${metrics.rejectedJobs}',
            percent: metrics.rejectedJobs / maxJobs,
            color: Colors.red,
          ),
          _BarMeter(
            label: 'Workload',
            valueLabel: '${metrics.workloadPercent.round()}%',
            percent: metrics.workloadPercent / 100,
            color: Colors.grey.shade700,
          ),
          _BarMeter(
            label: 'Acceptance %',
            valueLabel: '${metrics.acceptanceRate.round()}%',
            percent: metrics.acceptanceRate / 100,
            color: kAccentYellow,
          ),
        ],
      ),
    );
  }
}

class _BarMeter extends StatelessWidget {
  const _BarMeter({
    required this.label,
    required this.valueLabel,
    required this.percent,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final widthFactor = percent.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: widthFactor,
              color: color,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerRevenuePanel extends StatelessWidget {
  const _OwnerRevenuePanel({required this.metrics});

  final OwnerMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Revenue',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _CompactMoneyRow(label: 'Gross revenue', value: metrics.grossRevenue),
          _CompactMoneyRow(
            label: 'Platform commission',
            value: metrics.platformCommission,
          ),
          _CompactMoneyRow(
            label: 'Worker payouts',
            value: metrics.workerPayouts,
          ),
          _CompactMoneyRow(
            label: 'Cash collected',
            value: metrics.cashCollected,
          ),
          _CompactMoneyRow(
            label: 'Card collected',
            value: metrics.cardCollected,
          ),
          const SizedBox(height: 6),
          const Text(
            'Cash jobs: worker collected cash and owes commission. Card jobs: platform collected fare and owes worker payout.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OwnerFinancialDashboard extends StatefulWidget {
  const _OwnerFinancialDashboard({required this.jobs, required this.filter});

  final List<DemoServiceJob> jobs;
  final OwnerTimeFilter filter;

  @override
  State<_OwnerFinancialDashboard> createState() =>
      _OwnerFinancialDashboardState();
}

class _OwnerFinancialDashboardState extends State<_OwnerFinancialDashboard> {
  Future<void> _markJob(String id, String status) async {
    if (useFirebaseJobs) {
      await JobService().updateWorkerPayoutStatus(jobId: id, status: status);
      return;
    }
    final job = findServiceJob(id);
    if (job != null) {
      setState(() {
        job.workerPayoutStatus = status;
        job.workerPaidAt = status == 'paid' ? DateTime.now() : null;
      });
    }
  }

  Future<void> _markMarketplace(String id, String status) async {
    await MarketplaceService().updateWorkerPayoutStatus(
      orderId: id,
      status: status,
    );
    if (!useFirebaseJobs) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.MarketplaceOrder>>(
      stream: MarketplaceService().watchOwnerMarketplaceOrders(),
      builder: (context, snapshot) {
        final orders =
            (snapshot.data ?? MarketplaceService.localMarketplaceOrders)
                .where(
                  (order) => _isInOwnerFilter(order.createdAt, widget.filter),
                )
                .toList();
        final summary = ownerFinancialSummaryFor(
          jobs: widget.jobs,
          marketplaceOrders: orders,
        );
        final completedJobs = widget.jobs
            .where((job) => job.status == DemoServiceJobStatus.completed)
            .toList();
        final completedOrders = orders
            .where(
              (order) =>
                  order.status == backend.MarketplaceOrderStatus.delivered,
            )
            .toList();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kBrandSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Financial overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All customer payments are tracked as collected by On My Way first. Worker payouts are manual until marked paid by owner/admin.',
                style: TextStyle(
                  color: kMutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _DarkMoneyCard(
                    label: 'Gross Revenue',
                    value: summary.grossRevenue,
                  ),
                  _DarkMoneyCard(label: 'Owner Net', value: summary.ownerNet),
                  _DarkMoneyCard(
                    label: 'Worker Payouts Owed',
                    value: summary.workerPayoutsOwed,
                  ),
                  _DarkMoneyCard(
                    label: 'Paid to Workers',
                    value: summary.paidToWorkers,
                  ),
                  _DarkMoneyCard(
                    label: 'Unpaid Balance',
                    value: summary.unpaidWorkerBalance,
                  ),
                  _DarkMoneyCard(
                    label: 'Cash/manual',
                    value: summary.manualPayments,
                  ),
                  _DarkCountCard(
                    label: 'Completed Jobs',
                    value: '${summary.completedJobs}',
                  ),
                  _DarkCountCard(
                    label: 'Completed Marketplace',
                    value: '${summary.completedMarketplaceOrders}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Worker Payouts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (completedJobs.isEmpty && completedOrders.isEmpty)
                const Text(
                  'No completed payout items yet.',
                  style: TextStyle(
                    color: kMutedText,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else ...[
                ...completedJobs.map(
                  (job) => _OwnerPayoutItemCard(
                    title:
                        '${serviceLabel(job.offer.service)} ${job.assignedWorkerName ?? 'worker'}',
                    subtitle: job.offer.destination,
                    amount: job.workerPayout,
                    status: job.workerPayoutStatus,
                    onPaid: () => _markJob(job.offer.id, 'paid'),
                    onDisputed: () => _markJob(job.offer.id, 'disputed'),
                  ),
                ),
                ...completedOrders.map(
                  (order) => _OwnerPayoutItemCard(
                    title:
                        'Marketplace ${order.assignedWorkerName ?? 'courier'}',
                    subtitle: order.storeName,
                    amount:
                        order.workerPayout ??
                        AppConfig.workerPayoutFor(order.gross ?? order.total),
                    status: order.workerPayoutStatus,
                    onPaid: () => _markMarketplace(order.id, 'paid'),
                    onDisputed: () => _markMarketplace(order.id, 'disputed'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DarkMoneyCard extends StatelessWidget {
  const _DarkMoneyCard({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) =>
      _DarkCountCard(label: label, value: '\$${value.toStringAsFixed(2)}');
}

class _DarkCountCard extends StatelessWidget {
  const _DarkCountCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kMutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerPayoutItemCard extends StatelessWidget {
  const _OwnerPayoutItemCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.onPaid,
    required this.onDisputed,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final VoidCallback onPaid;
  final VoidCallback onDisputed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(label: status, status: status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Worker payout: \$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: status == 'paid' ? null : onDisputed,
                  child: const Text('Mark Disputed'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: status == 'paid' ? null : onPaid,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccentYellow,
                    foregroundColor: kBrandBlack,
                  ),
                  child: const Text('Mark Paid'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerMarketplacePanel extends StatelessWidget {
  const _OwnerMarketplacePanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.MarketplaceOrder>>(
      stream: MarketplaceService().watchOwnerMarketplaceOrders(),
      builder: (context, snapshot) {
        final orders =
            snapshot.data ?? MarketplaceService.localMarketplaceOrders;
        final pending = orders
            .where(
              (order) => order.status == backend.MarketplaceOrderStatus.pending,
            )
            .length;
        final active = orders
            .where(
              (order) =>
                  order.status == backend.MarketplaceOrderStatus.accepted ||
                  order.status == backend.MarketplaceOrderStatus.shopping ||
                  order.status == backend.MarketplaceOrderStatus.pickedUp ||
                  order.status == backend.MarketplaceOrderStatus.onTheWay,
            )
            .length;
        final completed = orders
            .where(
              (order) =>
                  order.status == backend.MarketplaceOrderStatus.delivered,
            )
            .length;
        final gross = orders.fold<double>(0, (sum, order) => sum + order.total);
        final deliveryRevenue = orders.fold<double>(
          0,
          (sum, order) => sum + order.deliveryFee,
        );
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kBrandSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Marketplace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Firestore-ready marketplace order metrics.',
                style: TextStyle(
                  color: kMutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniMetricChip(label: 'Orders', value: '${orders.length}'),
                  _MiniMetricChip(label: 'Pending', value: '$pending'),
                  _MiniMetricChip(label: 'Active', value: '$active'),
                  _MiniMetricChip(label: 'Completed', value: '$completed'),
                  _MiniMetricChip(
                    label: 'Gross',
                    value: '\$${gross.toStringAsFixed(0)}',
                  ),
                  _MiniMetricChip(
                    label: 'Delivery',
                    value: '\$${deliveryRevenue.toStringAsFixed(0)}',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerStoreHealthPanel extends StatelessWidget {
  const _OwnerStoreHealthPanel();

  @override
  Widget build(BuildContext context) {
    final service = StoreCrmService();
    return StreamBuilder<List<backend.MarketplaceStore>>(
      stream: service.watchAllStores(),
      builder: (context, storeSnapshot) {
        final stores = storeSnapshot.data ?? MarketplaceService.sampleStores;
        return StreamBuilder<List<backend.MarketplaceProduct>>(
          stream: service.watchAllProducts(),
          builder: (context, productSnapshot) {
            final products =
                productSnapshot.data ?? const <backend.MarketplaceProduct>[];
            final pending = stores
                .where((store) => store.status == 'pending_approval')
                .length;
            final active = stores
                .where((store) => store.status == 'active')
                .length;
            final paused = stores
                .where((store) => store.status == 'paused')
                .length;
            final lowStock = products
                .where((product) => product.stockStatus == 'low_stock')
                .length;
            final outOfStock = products
                .where((product) => product.stockStatus == 'out_of_stock')
                .length;
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
                  const Text(
                    'Store health',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _OwnerRequestCountChip(
                        label: 'Total stores',
                        value: stores.length,
                      ),
                      _OwnerRequestCountChip(label: 'Pending', value: pending),
                      _OwnerRequestCountChip(label: 'Active', value: active),
                      _OwnerRequestCountChip(label: 'Paused', value: paused),
                      _OwnerRequestCountChip(
                        label: 'Low stock',
                        value: lowStock,
                      ),
                      _OwnerRequestCountChip(
                        label: 'Out of stock',
                        value: outOfStock,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...stores
                      .take(5)
                      .map(
                        (store) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: kAccentYellow,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: kBrandBlack,
                            ),
                          ),
                          title: Text(
                            store.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${store.status} - ${store.isOpen ? 'Open' : 'Closed'} - ${store.address}',
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                onPressed: () => service.updateStoreStatus(
                                  storeId: store.id,
                                  status: 'active',
                                  adminId: AuthService().currentUser?.uid,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                tooltip: 'Approve',
                              ),
                              IconButton(
                                onPressed: () => service.updateStoreStatus(
                                  storeId: store.id,
                                  status: 'suspended',
                                  adminId: AuthService().currentUser?.uid,
                                ),
                                icon: const Icon(Icons.block),
                                tooltip: 'Suspend',
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OwnerServiceRequestsPanel extends StatelessWidget {
  const _OwnerServiceRequestsPanel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequest>>(
      stream: RequestService().watchOwnerRequests(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <ServiceRequest>[];
        final pending = requests
            .where(
              (request) => request.status == ServiceRequestStatus.requested,
            )
            .toList();
        final assigned = requests
            .where(
              (request) =>
                  request.assignedWorkerId?.trim().isNotEmpty == true &&
                  !request.isDone,
            )
            .toList();
        final completed = requests
            .where(
              (request) => request.status == ServiceRequestStatus.completed,
            )
            .toList();
        final canceled = requests
            .where((request) => request.status == ServiceRequestStatus.canceled)
            .toList();
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
                  const Expanded(
                    child: Text(
                      'Service request monitor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OwnerRequestCountChip(
                    label: 'Pending',
                    value: pending.length,
                  ),
                  _OwnerRequestCountChip(
                    label: 'Assigned',
                    value: assigned.length,
                  ),
                  _OwnerRequestCountChip(
                    label: 'Completed',
                    value: completed.length,
                  ),
                  _OwnerRequestCountChip(
                    label: 'Canceled',
                    value: canceled.length,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (requests.isEmpty)
                Text(
                  'Customer ride, moto, courier, and marketplace delivery requests will appear here.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                ...requests
                    .take(8)
                    .map(
                      (request) => _OwnerServiceRequestTile(request: request),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerRequestCountChip extends StatelessWidget {
  const _OwnerRequestCountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: kAccentYellow.withValues(alpha: 0.25),
      label: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _OwnerServiceRequestTile extends StatelessWidget {
  const _OwnerServiceRequestTile({required this.request});

  final ServiceRequest request;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyValueRow(
            label: 'Customer',
            value: request.customerName.trim().isEmpty
                ? request.customerPhone
                : request.customerName,
          ),
          const SizedBox(height: 6),
          _KeyValueRow(
            label: 'Worker',
            value: request.assignedWorkerName?.trim().isNotEmpty == true
                ? request.assignedWorkerName!
                : 'Unassigned',
          ),
          const SizedBox(height: 6),
          _KeyValueRow(
            label: 'Route',
            value: '${request.pickupAddress} to ${request.dropoffAddress}',
          ),
          const SizedBox(height: 6),
          _KeyValueRow(label: 'Created', value: _dateLabel(request.createdAt)),
          if (request.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _KeyValueRow(label: 'Notes', value: request.notes!),
          ],
        ],
      ),
    );
  }
}

class _FirebaseWorkerApprovalPanel extends StatelessWidget {
  const _FirebaseWorkerApprovalPanel();

  Future<void> _updateWorker(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this worker.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.WorkerProfile>>(
      stream: WorkerService().watchWorkers(),
      builder: (context, snapshot) {
        final workers = snapshot.data ?? const <backend.WorkerProfile>[];
        final pending = workers
            .where((worker) => worker.status == backend.WorkerStatus.pending)
            .length;
        final approved = workers
            .where((worker) => worker.status == backend.WorkerStatus.approved)
            .length;
        final online = workers.where((worker) => worker.isOnline).length;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Worker approvals',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Firestore worker applications and approval status.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LightMetricChip(
                    label: 'Workers',
                    value: '${workers.length}',
                  ),
                  _LightMetricChip(label: 'Pending', value: '$pending'),
                  _LightMetricChip(label: 'Approved', value: '$approved'),
                  _LightMetricChip(label: 'Online', value: '$online'),
                ],
              ),
              const SizedBox(height: 12),
              if (workers.isEmpty)
                const _StateMessage(
                  icon: Icons.badge_outlined,
                  text: 'No worker applications in Firestore yet.',
                )
              else
                ...workers.map(
                  (worker) => _FirebaseWorkerCard(
                    worker: worker,
                    onApprove: () => _updateWorker(
                      context,
                      () => WorkerService().approveWorker(
                        worker.id,
                        adminId: AuthService().currentUser?.uid,
                      ),
                      'Worker approved.',
                    ),
                    onReject: () => _updateWorker(
                      context,
                      () => WorkerService().rejectWorker(
                        worker.id,
                        rejectionReason: 'Rejected by owner/admin.',
                      ),
                      'Worker rejected.',
                    ),
                    onSuspend: () => _updateWorker(
                      context,
                      () => WorkerService().suspendWorker(worker.id),
                      'Worker suspended.',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LightMetricChip extends StatelessWidget {
  const _LightMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FirebaseWorkerCard extends StatelessWidget {
  const _FirebaseWorkerCard({
    required this.worker,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
  });

  final backend.WorkerProfile worker;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;

  Future<void> _viewDocument(
    BuildContext context,
    backend.WorkerDocument document,
  ) async {
    final uri = Uri.tryParse(document.fileUrl);
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

  Future<void> _reviewDocument(
    BuildContext context,
    backend.WorkerDocument document,
    backend.WorkerDocumentStatus status, {
    String? reason,
  }) async {
    try {
      await WorkerService().reviewWorkerDocument(
        workerId: worker.id,
        type: document.type,
        status: status,
        rejectionReason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${workerDocumentLabel(document.type)} updated.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not review this document.')),
        );
      }
    }
  }

  Future<void> _rejectDocument(
    BuildContext context,
    backend.WorkerDocument document,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason optional',
            hintText: 'Example: image is blurry',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) {
      return;
    }
    if (context.mounted) {
      await _reviewDocument(
        context,
        document,
        backend.WorkerDocumentStatus.rejected,
        reason: reason,
      );
    }
  }

  Color get _statusColor {
    switch (worker.status) {
      case backend.WorkerStatus.pending:
        return Colors.amber.shade700;
      case backend.WorkerStatus.approved:
        return Colors.green.shade700;
      case backend.WorkerStatus.rejected:
        return Colors.red.shade700;
      case backend.WorkerStatus.suspended:
      case backend.WorkerStatus.incomplete:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<backend.WorkerDocument>>(
      stream: WorkerService().watchWorkerDocuments(worker.id),
      builder: (context, snapshot) {
        final documents = snapshot.data ?? const <backend.WorkerDocument>[];
        final docsApproved = requiredWorkerDocumentsApproved(documents);
        return Container(
          margin: const EdgeInsets.only(top: 10),
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
                      worker.fullName.isEmpty
                          ? 'Unnamed worker'
                          : worker.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      worker.status.name,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _KeyValueRow(label: 'Phone', value: worker.phone),
              const SizedBox(height: 6),
              _KeyValueRow(label: 'Vehicle', value: worker.vehicleType),
              const SizedBox(height: 6),
              _KeyValueRow(label: 'Plate', value: worker.plateNumber),
              const SizedBox(height: 6),
              _KeyValueRow(label: 'Area', value: worker.operatingArea),
              const SizedBox(height: 6),
              _KeyValueRow(
                label: 'Payout',
                value:
                    '${payoutMethodLabel(worker.payoutMethod)} - ${worker.payoutDisplayName} - ${worker.payoutPhoneNumber}',
              ),
              const SizedBox(height: 6),
              _KeyValueRow(
                label: 'Agreement',
                value: worker.agreementAccepted
                    ? 'Accepted v${worker.agreementVersion}'
                    : 'Not accepted',
              ),
              const SizedBox(height: 12),
              const Text(
                'Documents',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ...kWorkerDocumentRequirements.map((requirement) {
                final document = documentForRequirement(documents, requirement);
                final status =
                    document?.status ?? backend.WorkerDocumentStatus.missing;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${requirement.label}${requirement.required ? ' *' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _StatusChip(label: status.name, status: status.name),
                        ],
                      ),
                      if (document?.fileName.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          document!.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: document?.fileUrl.isNotEmpty == true
                                  ? () => _viewDocument(context, document!)
                                  : null,
                              child: const Text('View'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: document == null
                                  ? null
                                  : () => _rejectDocument(context, document),
                              child: const Text('Reject doc'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: document == null
                                  ? null
                                  : () => _reviewDocument(
                                      context,
                                      document,
                                      backend.WorkerDocumentStatus.approved,
                                    ),
                              style: FilledButton.styleFrom(
                                backgroundColor: kAccentYellow,
                                foregroundColor: kBrandBlack,
                              ),
                              child: const Text('Approve doc'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSuspend,
                      child: const Text('Suspend'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!worker.agreementAccepted ||
                            worker.payoutMethod.isEmpty ||
                            worker.payoutDisplayName.isEmpty ||
                            worker.payoutPhoneNumber.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Worker agreement and payout method must be completed before approval.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (!docsApproved) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Required documents must be approved before approving this worker.',
                              ),
                            ),
                          );
                          return;
                        }
                        onApprove();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kAccentYellow,
                        foregroundColor: kBrandBlack,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniMetricChip extends StatelessWidget {
  const _MiniMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: kMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerLiveMapPreview extends StatelessWidget {
  const _OwnerLiveMapPreview({
    required this.jobs,
    this.onlineDrivers = const [],
  });

  final List<DemoServiceJob> jobs;
  final List<backend.DriverLocation> onlineDrivers;

  @override
  Widget build(BuildContext context) {
    final activeJob = jobs
        .where(
          (job) =>
              job.status == DemoServiceJobStatus.active ||
              job.status == DemoServiceJobStatus.accepted,
        )
        .cast<DemoServiceJob?>()
        .firstWhere((job) => job != null, orElse: () => null);
    final pendingJob = jobs
        .where((job) => job.status == DemoServiceJobStatus.pending)
        .cast<DemoServiceJob?>()
        .firstWhere((job) => job != null, orElse: () => null);
    final selected = activeJob ?? pendingJob;
    final driverPoint = onlineDrivers.isNotEmpty
        ? DemoMapPoint(onlineDrivers.first.lat, onlineDrivers.first.lng)
        : demoDriverAvailability.isOnline
        ? demoDriverAvailability.location
        : null;
    final offerMarkers = jobs
        .where((job) => job.status == DemoServiceJobStatus.pending)
        .map(
          (job) => DemoMapMarker(
            id: job.offer.id,
            point: job.pickupPoint,
            label: '\$${job.offer.offerAmount}',
            icon: serviceIcon(job.offer.service),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'OMW live map',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppMap(
            pickup: selected?.pickupPoint ?? kDemoPickupPoint,
            destination: selected?.destinationPoint,
            driver: driverPoint,
            offerMarkers: offerMarkers,
            selectedMarkerId: selected?.offer.id,
            routePoints: selected == null
                ? const []
                : [
                    ?driverPoint,
                    selected.pickupPoint,
                    selected.destinationPoint,
                  ],
            height: 220,
            showRoute: selected != null,
          ),
        ),
        const SizedBox(height: 8),
        if (onlineDrivers.isNotEmpty) ...[
          Text(
            '${onlineDrivers.length} online worker${onlineDrivers.length == 1 ? '' : 's'} visible',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          ...onlineDrivers
              .take(3)
              .map(
                (driver) => Text(
                  '${driver.workerName.isEmpty ? 'OMW Driver' : driver.workerName}'
                  '${driver.activeJobId == null ? '' : ' - active job ${driver.activeJobId}'}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],
        Text(
          selected == null
              ? 'No live OMW offers selected. Online workers and active jobs use this shared map.'
              : '${serviceJobStatusLabel(selected.status)}: ${selected.offer.pickup} to ${selected.offer.destination}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OwnerJobSection extends StatelessWidget {
  const _OwnerJobSection({
    required this.title,
    required this.emptyText,
    required this.jobs,
    required this.onCancel,
  });

  final String title;
  final String emptyText;
  final List<DemoServiceJob> jobs;
  final ValueChanged<DemoServiceJob> onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (jobs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                emptyText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            ...jobs.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OwnerJobCard(job: job, onCancel: () => onCancel(job)),
              ),
            ),
        ],
      ),
    );
  }
}

class _OwnerJobCard extends StatelessWidget {
  const _OwnerJobCard({required this.job, required this.onCancel});

  final DemoServiceJob job;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final o = job.offer;
    final isPending = job.status == DemoServiceJobStatus.pending;
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
                _StatusChip(
                  label: serviceJobStatusLabel(job.status),
                  status: job.status.name,
                ),
              ],
            ),
            const Divider(height: 22),
            _KeyValueRow(label: 'Service', value: serviceLabel(o.service)),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Customer', value: job.customerName),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Phone', value: job.customerPhone),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Pickup', value: o.pickup),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Destination', value: o.destination),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Offer', value: '\$${o.offerAmount}'),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Payment',
              value: paymentLabel(o.paymentMethod),
            ),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Worker',
              value: job.assignedWorkerName ?? 'Unassigned',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Time', value: _dateLabel(job.createdAt)),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Revenue',
              value:
                  'Gross \$${job.gross.toStringAsFixed(2)} / Commission \$${job.commission.toStringAsFixed(2)} / Payout \$${job.workerPayout.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Viewing ${o.id}')));
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(isPending ? 'View' : 'View summary'),
                ),
                if (isPending)
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  )
                else if (job.status == DemoServiceJobStatus.active ||
                    job.status == DemoServiceJobStatus.accepted)
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Track demo job')),
                      );
                    },
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Track'),
                  )
                else if (job.status == DemoServiceJobStatus.rejected ||
                    job.status == DemoServiceJobStatus.cancelled)
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reason: demo rejection/cancellation'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('View reason'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => showDemoCallDialog(
                    context,
                    title:
                        'Calling ${job.assignedWorkerName ?? job.customerName}',
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('Contact'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerWorkerPerformanceCard extends StatelessWidget {
  const _OwnerWorkerPerformanceCard({
    required this.profile,
    required this.summary,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
  });

  final WorkerProfile profile;
  final DriverEarningsSummary summary;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSuspend;

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
                const Icon(Icons.engineering_outlined, color: kAccentBlue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'OMW worker performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusChip(
                  label: demoDriverAvailability.isOnline ? 'Online' : 'Offline',
                  status: demoDriverAvailability.isOnline
                      ? 'approved'
                      : 'missing',
                ),
              ],
            ),
            const Divider(height: 22),
            _KeyValueRow(
              label: 'Name',
              value: profile.fullName.isEmpty ? 'OMW Driver' : profile.fullName,
            ),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Service', value: profile.serviceType),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Vehicle',
              value: '${profile.vehicleType} / ${profile.plateNumber}',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'City/area', value: profile.cityArea),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Completed',
              value: '${summary.completedJobs} jobs',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Earnings',
              value: '\$${summary.netEarnings.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _KeyValueRow(
              label: 'Acceptance',
              value: '${summary.acceptanceRate.round()}%',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onApprove,
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  child: const Text('Reject'),
                ),
                OutlinedButton(
                  onPressed: onSuspend,
                  child: const Text('Suspend demo'),
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Viewing worker performance'),
                      ),
                    );
                  },
                  child: const Text('View performance'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerApplicationCard extends StatelessWidget {
  const _WorkerApplicationCard({
    required this.profile,
    required this.onApprove,
    required this.onReject,
  });

  final WorkerProfile profile;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

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
                const Icon(Icons.badge_outlined, color: kAccentBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    profile.fullName.isEmpty
                        ? 'OMW worker application'
                        : profile.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(
                  label: applicationStatusLabel(profile.status),
                  status: profile.status.name,
                ),
              ],
            ),
            const Divider(height: 24),
            _KeyValueRow(label: 'Phone', value: profile.phoneNumber),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Vehicle', value: profile.vehicleType),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Service', value: profile.serviceType),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Plate', value: profile.plateNumber),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'City/area', value: profile.cityArea),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Documents', value: profile.documentsSummary),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.documents.entries
                  .map(
                    (entry) => _StatusChip(
                      label:
                          '${entry.key}: ${documentStatusLabel(entry.value)}',
                      status: entry.value.name,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
