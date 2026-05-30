part of '../../main.dart';

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMoneyRow extends StatelessWidget {
  const _CompactMoneyRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.summary});

  final DriverEarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Payout',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _CompactMoneyRow(
            label: 'Unpaid balance',
            value: summary.unpaidBalance,
          ),
          _CompactMoneyRow(label: 'Paid balance', value: summary.paidBalance),
          _CompactMoneyRow(
            label: 'Cash collected',
            value: summary.cashCollected,
          ),
          _CompactMoneyRow(
            label: 'Platform fee owed',
            value: summary.platformFeeOwed,
          ),
          _CompactMoneyRow(label: 'Card payment', value: summary.cardPayments),
          const SizedBox(height: 10),
          const Text(
            'Owner/Admin marks worker payouts as paid after manual settlement.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OnlineStatusCard extends StatelessWidget {
  const _OnlineStatusCard({
    required this.online,
    required this.enabled,
    required this.onChanged,
  });

  final bool online;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: online
            ? kAccentYellow.withValues(alpha: 0.22)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.radio_button_checked : Icons.radio_button_off,
            color: online ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              online ? 'Online and visible for OMW requests' : 'Offline',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Switch(value: online, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class OmwNotificationsCard extends StatelessWidget {
  const OmwNotificationsCard({
    super.key,
    required this.roleTarget,
    this.userId,
    this.title = 'Notifications',
    this.limit = 5,
  });

  final String roleTarget;
  final String? userId;
  final String title;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return StreamBuilder<List<AppNotification>>(
      stream: service.watchDashboardNotifications(
        userId: userId,
        roleTarget: roleTarget,
        limit: limit,
      ),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kAccentYellow.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      color: kBrandBlack,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kAccentYellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: const TextStyle(
                          color: kBrandBlack,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => service.markAllAsRead(
                        userId: userId,
                        roleTarget: roleTarget,
                      ),
                      child: const Text('Mark read'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  notifications.isEmpty)
                const LinearProgressIndicator()
              else if (notifications.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No notifications yet.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else
                ...notifications.map(
                  (notification) => _NotificationRow(
                    notification: notification,
                    onMarkRead: notification.isRead
                        ? null
                        : () => service.markAsRead(notification.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class OmwNotificationBell extends StatelessWidget {
  const OmwNotificationBell({
    super.key,
    required this.roleTarget,
    this.userId,
    this.limit = 20,
  });

  final String roleTarget;
  final String? userId;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return StreamBuilder<List<AppNotification>>(
      stream: service.watchDashboardNotifications(
        userId: userId,
        roleTarget: roleTarget,
        limit: limit,
      ),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _showNotificationsSheet(
                  context,
                  userId: userId,
                  roleTarget: roleTarget,
                  limit: limit,
                ),
                icon: Icon(
                  unreadCount > 0
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: kAccentYellow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kBrandBlack, width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: kBrandBlack,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
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

Future<void> _showNotificationsSheet(
  BuildContext context, {
  required String roleTarget,
  String? userId,
  int limit = 20,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => _NotificationsSheet(
      roleTarget: roleTarget,
      userId: userId,
      limit: limit,
    ),
  );
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.roleTarget,
    required this.userId,
    required this.limit,
  });

  final String roleTarget;
  final String? userId;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: StreamBuilder<List<AppNotification>>(
          stream: service.watchDashboardNotifications(
            userId: userId,
            roleTarget: roleTarget,
            limit: limit,
          ),
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? const <AppNotification>[];
            final unreadCount = notifications
                .where((notification) => !notification.isRead)
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: () => service.markAllAsRead(
                            userId: userId,
                            roleTarget: roleTarget,
                          ),
                          child: const Text('Mark read'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      snapshot.connectionState == ConnectionState.waiting &&
                          notifications.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : notifications.isEmpty
                      ? const _NotificationsEmptyState()
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _NotificationRow(
                              notification: notification,
                              onMarkRead: notification.isRead
                                  ? null
                                  : () => service.markAsRead(notification.id),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: kAccentYellow.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.notifications_none, color: kBrandBlack),
            ),
            const SizedBox(height: 12),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Order, ride, and delivery updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OmwNotificationPermissionPrompt extends StatefulWidget {
  const OmwNotificationPermissionPrompt({super.key});

  @override
  State<OmwNotificationPermissionPrompt> createState() =>
      _OmwNotificationPermissionPromptState();
}

class _OmwNotificationPermissionPromptState
    extends State<OmwNotificationPermissionPrompt> {
  final NotificationPermissionService _service =
      const NotificationPermissionService();
  bool _visible = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dismissed = await _service.wasPromptDismissed();
    final status = await _service.status();
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      _visible = !dismissed && status == OmwNotificationPermissionStatus.prompt;
    });
  }

  Future<void> _allow() async {
    await _service.requestPermission();
    if (!mounted) {
      return;
    }
    setState(() => _visible = false);
  }

  Future<void> _later() async {
    await _service.dismissPrompt();
    if (!mounted) {
      return;
    }
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_visible) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentYellow.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kAccentYellow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_outlined),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Allow notifications to get order, ride, and delivery updates.',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _later,
                  child: const Text('Maybe later'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _allow,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccentYellow,
                    foregroundColor: kBrandBlack,
                  ),
                  child: const Text('Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, this.onMarkRead});

  final AppNotification notification;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final read = notification.isRead;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: read
            ? Colors.grey.shade50
            : kAccentYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: read
              ? Colors.grey.shade200
              : kAccentYellow.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            read ? Icons.notifications_none : Icons.notifications_active,
            size: 20,
            color: read ? Colors.grey.shade600 : kDeepGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _dateLabel(notification.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onMarkRead != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Mark as read',
              onPressed: onMarkRead,
              icon: const Icon(Icons.done, size: 19),
            ),
        ],
      ),
    );
  }
}

class _DriverJobsPreview extends StatelessWidget {
  const _DriverJobsPreview({required this.jobs});

  final List<DemoJob> jobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Jobs history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DriverJobsHistoryScreen(),
                  ),
                );
              },
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (jobs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No OMW driver jobs yet. Go online, accept a request, and complete it to build earnings.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          )
        else
          ...jobs
              .take(3)
              .map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DriverJobCard(job: job),
                ),
              ),
      ],
    );
  }
}
