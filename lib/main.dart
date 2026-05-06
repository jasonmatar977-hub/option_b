import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/directions_service.dart';
import 'services/google_places_service.dart';
import 'services/location_service.dart';
import 'widgets/app_map.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OptionBApp());
}

const Color kAccentYellow = Color(0xFFFFD000);
const Color kAccentBlue = Color(0xFF1565C0);
const String kCurrentPickup = 'Current Location';
const DemoMapPoint kDemoPickupPoint = DemoMapPoint(33.8938, 35.5018);
const DemoMapPoint kDemoDestinationPoint = DemoMapPoint(33.9006, 35.5144);

enum ServiceType { ride, moto, courier }

enum DemoRole { customer, driver, admin }

enum PaymentMethod { cash, card }

enum DemoJobStatus { accepted, completed, rejected }

enum DemoServiceJobStatus {
  pending,
  accepted,
  active,
  completed,
  rejected,
  cancelled,
}

enum OwnerTimeFilter { today, week, month, year, all }

enum WorkerApplicationStatus {
  notStarted,
  incomplete,
  pending,
  approved,
  rejected,
}

enum DocumentStatus { missing, uploaded, approved, rejected }

String applicationStatusLabel(WorkerApplicationStatus status) {
  switch (status) {
    case WorkerApplicationStatus.notStarted:
      return 'Not started';
    case WorkerApplicationStatus.incomplete:
      return 'Missing documents';
    case WorkerApplicationStatus.pending:
      return 'Pending approval';
    case WorkerApplicationStatus.approved:
      return 'Approved';
    case WorkerApplicationStatus.rejected:
      return 'Rejected';
  }
}

String documentStatusLabel(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.missing:
      return 'Missing';
    case DocumentStatus.uploaded:
      return 'Uploaded';
    case DocumentStatus.approved:
      return 'Approved';
    case DocumentStatus.rejected:
      return 'Rejected';
  }
}

String paymentLabel(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'Cash';
    case PaymentMethod.card:
      return 'Card';
  }
}

String serviceLabel(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return 'Ride';
    case ServiceType.moto:
      return 'Moto';
    case ServiceType.courier:
      return 'Courier';
  }
}

IconData serviceIcon(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return Icons.directions_car_filled_outlined;
    case ServiceType.moto:
      return Icons.two_wheeler_outlined;
    case ServiceType.courier:
      return Icons.local_shipping_outlined;
  }
}

class PriceBand {
  const PriceBand({
    required this.minimum,
    required this.maximum,
    required this.recommended,
    required this.fast,
  });

  final int minimum;
  final int maximum;
  final int recommended;
  final int fast;
}

PriceBand bandFor(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return const PriceBand(
        minimum: 12,
        maximum: 38,
        recommended: 19,
        fast: 29,
      );
    case ServiceType.moto:
      return const PriceBand(
        minimum: 8,
        maximum: 24,
        recommended: 13,
        fast: 19,
      );
    case ServiceType.courier:
      return const PriceBand(
        minimum: 15,
        maximum: 48,
        recommended: 24,
        fast: 36,
      );
  }
}

class DriverInfo {
  const DriverInfo({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.distanceKm,
    required this.etaMin,
  });

  final String name;
  final double rating;
  final String vehicle;
  final double distanceKm;
  final int etaMin;
}

class OfferPayload {
  OfferPayload({
    required this.id,
    required this.service,
    required this.pickup,
    required this.destination,
    required this.offerAmount,
    required this.paymentMethod,
    this.pickupPoint,
    this.destinationPoint,
    this.routePoints = const [],
    this.distanceText,
    this.durationText,
    this.manualDestination = false,
  });

  final String id;
  final ServiceType service;
  final String pickup;
  final String destination;
  final int offerAmount;
  final PaymentMethod paymentMethod;
  final DemoMapPoint? pickupPoint;
  final DemoMapPoint? destinationPoint;
  final List<DemoMapPoint> routePoints;
  final String? distanceText;
  final String? durationText;
  final bool manualDestination;
}

class CompletedOffer {
  const CompletedOffer({
    required this.offer,
    required this.driver,
    required this.status,
  });

  final OfferPayload offer;
  final DriverInfo driver;
  final String status;
}

class BookAgainPayload {
  const BookAgainPayload({
    required this.service,
    required this.destination,
    required this.offerAmount,
  });

  final ServiceType service;
  final String destination;
  final int offerAmount;
}

final List<CompletedOffer> demoHistory = <CompletedOffer>[];

void saveCompletedOfferHistory(OfferPayload offer, DriverInfo driver) {
  final alreadySaved = demoHistory.any((item) => item.offer.id == offer.id);
  if (alreadySaved) {
    return;
  }
  demoHistory.insert(
    0,
    CompletedOffer(offer: offer, driver: driver, status: 'Completed'),
  );
}

const List<String> kWorkerDocumentNames = [
  'Driver license / ID',
  'Vehicle registration',
  'Insurance',
  'Profile photo',
  'Background check',
];

class WorkerProfile {
  WorkerProfile();

  String fullName = '';
  String phoneNumber = '';
  String vehicleType = 'Car';
  String serviceType = 'Ride';
  String plateNumber = '';
  String cityArea = '';
  WorkerApplicationStatus status = WorkerApplicationStatus.notStarted;
  final Map<String, DocumentStatus> documents = {
    for (final name in kWorkerDocumentNames) name: DocumentStatus.missing,
  };

  bool get hasProfileDetails =>
      fullName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      vehicleType.trim().isNotEmpty &&
      serviceType.trim().isNotEmpty &&
      plateNumber.trim().isNotEmpty &&
      cityArea.trim().isNotEmpty;

  bool get allDocumentsUploaded => documents.values.every(
    (status) =>
        status == DocumentStatus.uploaded || status == DocumentStatus.approved,
  );

  bool get canSubmit => hasProfileDetails && allDocumentsUploaded;

  String get documentsSummary {
    final uploaded = documents.values
        .where(
          (status) =>
              status == DocumentStatus.uploaded ||
              status == DocumentStatus.approved,
        )
        .length;
    return '$uploaded/${documents.length} documents uploaded';
  }

  void reset() {
    fullName = '';
    phoneNumber = '';
    vehicleType = 'Car';
    serviceType = 'Ride';
    plateNumber = '';
    cityArea = '';
    status = WorkerApplicationStatus.notStarted;
    for (final name in kWorkerDocumentNames) {
      documents[name] = DocumentStatus.missing;
    }
    demoDriverAvailability.isOnline = false;
  }
}

final WorkerProfile demoWorkerProfile = WorkerProfile();

class DemoJob {
  DemoJob({
    required this.offer,
    required this.status,
    required this.customerName,
    required this.dateTime,
  });

  final OfferPayload offer;
  DemoJobStatus status;
  final String customerName;
  final DateTime dateTime;

  double get grossFare => offer.offerAmount.toDouble();
  double get platformCommission => grossFare * 0.15;
  double get driverPayout => grossFare * 0.85;
}

final List<DemoJob> demoDriverJobs = <DemoJob>[];

String jobStatusLabel(DemoJobStatus status) {
  switch (status) {
    case DemoJobStatus.accepted:
      return 'Accepted';
    case DemoJobStatus.completed:
      return 'Completed';
    case DemoJobStatus.rejected:
      return 'Rejected';
  }
}

String serviceJobStatusLabel(DemoServiceJobStatus status) {
  switch (status) {
    case DemoServiceJobStatus.pending:
      return 'Pending';
    case DemoServiceJobStatus.accepted:
      return 'Accepted';
    case DemoServiceJobStatus.active:
      return 'Active';
    case DemoServiceJobStatus.completed:
      return 'Completed';
    case DemoServiceJobStatus.rejected:
      return 'Rejected';
    case DemoServiceJobStatus.cancelled:
      return 'Cancelled';
  }
}

class DemoServiceJob {
  DemoServiceJob({
    required this.offer,
    required this.customerPhone,
    required this.customerName,
    required this.createdAt,
    this.status = DemoServiceJobStatus.pending,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.completedAt,
    this.rejectedAt,
  });

  final OfferPayload offer;
  final String customerPhone;
  final String customerName;
  final DateTime createdAt;
  DemoServiceJobStatus status;
  String? assignedWorkerId;
  String? assignedWorkerName;
  DateTime? completedAt;
  DateTime? rejectedAt;

  double get gross => offer.offerAmount.toDouble();
  double get commission => gross * 0.15;
  double get workerPayout => gross * 0.85;
  DemoMapPoint get pickupPoint => offer.pickupPoint ?? kDemoPickupPoint;
  DemoMapPoint get destinationPoint =>
      offer.destinationPoint ?? kDemoDestinationPoint;
}

final List<DemoServiceJob> demoServiceJobs = <DemoServiceJob>[];

DemoServiceJob? findServiceJob(String id) {
  for (final job in demoServiceJobs) {
    if (job.offer.id == id) {
      return job;
    }
  }
  return null;
}

DemoServiceJob upsertServiceJob({
  required OfferPayload offer,
  required String customerPhone,
  DemoServiceJobStatus status = DemoServiceJobStatus.pending,
}) {
  final existing = findServiceJob(offer.id);
  if (existing != null) {
    existing.status = status;
    return existing;
  }
  final job = DemoServiceJob(
    offer: offer,
    customerPhone: customerPhone,
    customerName: 'Demo Customer',
    createdAt: DateTime.now(),
    status: status,
  );
  demoServiceJobs.insert(0, job);
  return job;
}

void assignServiceJob(OfferPayload offer, DriverInfo driver) {
  final job = upsertServiceJob(
    offer: offer,
    customerPhone: 'Demo customer',
    status: DemoServiceJobStatus.active,
  );
  job.assignedWorkerId = 'demo-worker-1';
  job.assignedWorkerName = driver.name;
}

void rejectServiceJob(OfferPayload offer) {
  final job = upsertServiceJob(
    offer: offer,
    customerPhone: 'Demo customer',
    status: DemoServiceJobStatus.rejected,
  );
  job.rejectedAt = DateTime.now();
}

void completeServiceJob(OfferPayload offer) {
  final job = upsertServiceJob(
    offer: offer,
    customerPhone: 'Demo customer',
    status: DemoServiceJobStatus.completed,
  );
  job.completedAt = DateTime.now();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isInOwnerFilter(DateTime date, OwnerTimeFilter filter) {
  final now = DateTime.now();
  return switch (filter) {
    OwnerTimeFilter.today => _sameDay(date, now),
    OwnerTimeFilter.week => now.difference(date).inDays < 7,
    OwnerTimeFilter.month => date.year == now.year && date.month == now.month,
    OwnerTimeFilter.year => date.year == now.year,
    OwnerTimeFilter.all => true,
  };
}

String ownerFilterLabel(OwnerTimeFilter filter) {
  return switch (filter) {
    OwnerTimeFilter.today => 'Today',
    OwnerTimeFilter.week => 'This week',
    OwnerTimeFilter.month => 'This month',
    OwnerTimeFilter.year => 'This year',
    OwnerTimeFilter.all => 'All time',
  };
}

String _dateLabel(DateTime value) {
  final now = DateTime.now();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  if (_sameDay(value, now)) {
    return 'Today $hour:$minute';
  }
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute';
}

double demoDistanceKm(DemoMapPoint a, DemoMapPoint b) {
  const earthRadiusKm = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final hav =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
}

class OwnerMetrics {
  const OwnerMetrics({
    required this.totalOffers,
    required this.pendingOffers,
    required this.acceptedJobs,
    required this.completedJobs,
    required this.rejectedJobs,
    required this.onlineWorkers,
    required this.grossRevenue,
    required this.platformCommission,
    required this.workerPayouts,
    required this.cashCollected,
    required this.cardCollected,
  });

  final int totalOffers;
  final int pendingOffers;
  final int acceptedJobs;
  final int completedJobs;
  final int rejectedJobs;
  final int onlineWorkers;
  final double grossRevenue;
  final double platformCommission;
  final double workerPayouts;
  final double cashCollected;
  final double cardCollected;

  double get acceptanceRate =>
      totalOffers == 0 ? 0 : (acceptedJobs + completedJobs) / totalOffers * 100;
  double get workloadPercent =>
      totalOffers == 0 ? 0 : (pendingOffers + acceptedJobs) / totalOffers * 100;
  double get netPlatformEarnings => platformCommission;
}

OwnerMetrics ownerMetricsFor(List<DemoServiceJob> jobs) {
  var pending = 0;
  var accepted = 0;
  var completed = 0;
  var rejected = 0;
  var gross = 0.0;
  var commission = 0.0;
  var payout = 0.0;
  var cash = 0.0;
  var card = 0.0;

  for (final job in jobs) {
    if (job.status == DemoServiceJobStatus.pending) {
      pending++;
    } else if (job.status == DemoServiceJobStatus.accepted ||
        job.status == DemoServiceJobStatus.active) {
      accepted++;
    } else if (job.status == DemoServiceJobStatus.completed) {
      completed++;
    } else {
      rejected++;
    }
    if (job.status == DemoServiceJobStatus.accepted ||
        job.status == DemoServiceJobStatus.active ||
        job.status == DemoServiceJobStatus.completed) {
      gross += job.gross;
      commission += job.commission;
      payout += job.workerPayout;
      if (job.offer.paymentMethod == PaymentMethod.cash) {
        cash += job.gross;
      } else {
        card += job.gross;
      }
    }
  }

  final onlineWorkers =
      demoDriverAvailability.isOnline &&
          demoWorkerProfile.status == WorkerApplicationStatus.approved
      ? 1
      : 0;
  return OwnerMetrics(
    totalOffers: jobs.length,
    pendingOffers: pending,
    acceptedJobs: accepted,
    completedJobs: completed,
    rejectedJobs: rejected,
    onlineWorkers: onlineWorkers,
    grossRevenue: gross,
    platformCommission: commission,
    workerPayouts: payout,
    cashCollected: cash,
    cardCollected: card,
  );
}

List<DemoServiceJob> filteredOwnerJobs(OwnerTimeFilter filter) {
  return demoServiceJobs
      .where((job) => _isInOwnerFilter(job.createdAt, filter))
      .toList();
}

DemoJob? findDemoJob(String offerId) {
  for (final job in demoDriverJobs) {
    if (job.offer.id == offerId) {
      return job;
    }
  }
  return null;
}

void upsertDemoJob(OfferPayload offer, DemoJobStatus status) {
  final existing = findDemoJob(offer.id);
  if (existing != null) {
    existing.status = status;
    return;
  }
  demoDriverJobs.insert(
    0,
    DemoJob(
      offer: offer,
      status: status,
      customerName: 'Demo Customer',
      dateTime: DateTime.now(),
    ),
  );
}

class DriverEarningsSummary {
  const DriverEarningsSummary({
    required this.totalJobs,
    required this.acceptedJobs,
    required this.completedJobs,
    required this.rejectedJobs,
    required this.grossFare,
    required this.cashCollected,
    required this.cardPayments,
    required this.platformCommission,
    required this.netEarnings,
  });

  final int totalJobs;
  final int acceptedJobs;
  final int completedJobs;
  final int rejectedJobs;
  final double grossFare;
  final double cashCollected;
  final double cardPayments;
  final double platformCommission;
  final double netEarnings;

  double get acceptanceRate =>
      totalJobs == 0 ? 0 : acceptedJobs / totalJobs * 100;
  double get availablePayout => cardPayments * 0.85;
  double get pendingPayout => availablePayout;
  double get platformFeeOwed => cashCollected * 0.15;
}

DriverEarningsSummary driverEarningsSummary() {
  var accepted = 0;
  var completed = 0;
  var rejected = 0;
  var gross = 0.0;
  var cash = 0.0;
  var card = 0.0;
  var commission = 0.0;
  var net = 0.0;

  for (final job in demoDriverJobs) {
    if (job.status == DemoJobStatus.rejected) {
      rejected++;
      continue;
    }
    accepted++;
    if (job.status == DemoJobStatus.completed) {
      completed++;
      gross += job.grossFare;
      commission += job.platformCommission;
      net += job.driverPayout;
      if (job.offer.paymentMethod == PaymentMethod.cash) {
        cash += job.grossFare;
      } else {
        card += job.grossFare;
      }
    }
  }

  return DriverEarningsSummary(
    totalJobs: demoDriverJobs.length,
    acceptedJobs: accepted,
    completedJobs: completed,
    rejectedJobs: rejected,
    grossFare: gross,
    cashCollected: cash,
    cardPayments: card,
    platformCommission: commission,
    netEarnings: net,
  );
}

class DemoDriverAvailability {
  bool isOnline = false;
  DemoMapPoint location = const DemoMapPoint(33.8898, 35.4948);
  String locationLabel = 'Demo driver location';
}

final DemoDriverAvailability demoDriverAvailability = DemoDriverAvailability();

List<DriverInfo> demoDrivers(ServiceType service) {
  switch (service) {
    case ServiceType.ride:
      return const [
        DriverInfo(
          name: 'Alex M.',
          rating: 4.9,
          vehicle: 'Toyota Prius',
          distanceKm: 0.8,
          etaMin: 3,
        ),
        DriverInfo(
          name: 'Jordan K.',
          rating: 4.8,
          vehicle: 'Honda Civic',
          distanceKm: 1.2,
          etaMin: 5,
        ),
        DriverInfo(
          name: 'Sam R.',
          rating: 5.0,
          vehicle: 'Nissan Leaf',
          distanceKm: 1.5,
          etaMin: 6,
        ),
      ];
    case ServiceType.moto:
      return const [
        DriverInfo(
          name: 'Maya T.',
          rating: 4.9,
          vehicle: 'Yamaha NMAX',
          distanceKm: 0.5,
          etaMin: 2,
        ),
        DriverInfo(
          name: 'Omar H.',
          rating: 4.7,
          vehicle: 'Honda PCX',
          distanceKm: 1.1,
          etaMin: 4,
        ),
        DriverInfo(
          name: 'Rami S.',
          rating: 4.8,
          vehicle: 'Suzuki Burgman',
          distanceKm: 1.7,
          etaMin: 6,
        ),
      ];
    case ServiceType.courier:
      return const [
        DriverInfo(
          name: 'Nour A.',
          rating: 4.9,
          vehicle: 'Courier van',
          distanceKm: 0.9,
          etaMin: 4,
        ),
        DriverInfo(
          name: 'Lina K.',
          rating: 4.8,
          vehicle: 'Box moto',
          distanceKm: 1.3,
          etaMin: 6,
        ),
        DriverInfo(
          name: 'Ziad F.',
          rating: 4.7,
          vehicle: 'Compact van',
          distanceKm: 2.0,
          etaMin: 8,
        ),
      ];
  }
}

List<DriverInfo> onlineDriversFor(ServiceType service) {
  if (!demoDriverAvailability.isOnline ||
      demoWorkerProfile.status != WorkerApplicationStatus.approved) {
    return const [];
  }
  return [demoDrivers(service).first];
}

class OptionBApp extends StatefulWidget {
  const OptionBApp({super.key});

  @override
  State<OptionBApp> createState() => _OptionBAppState();
}

class _OptionBAppState extends State<OptionBApp> {
  DemoRole? _selectedRole;
  String? _phoneNumber;
  bool _isVerified = false;

  void _selectRole(DemoRole role) {
    setState(() {
      _selectedRole = role;
      _phoneNumber = null;
      _isVerified = false;
    });
  }

  void _sendCode(String phone) {
    setState(() => _phoneNumber = phone);
  }

  void _verify() {
    setState(() => _isVerified = true);
  }

  void _signOut() {
    setState(() {
      _selectedRole = null;
      _phoneNumber = null;
      _isVerified = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = _selectedRole;
    final phone = _phoneNumber;
    Widget home;
    if (role == null) {
      home = RoleSelectionScreen(onRoleSelected: _selectRole);
    } else if (role == DemoRole.admin) {
      home = AdminDashboardScreen(onSignOut: _signOut);
    } else if (phone == null) {
      home = PhoneLoginScreen(role: role, onCodeSent: _sendCode);
    } else if (!_isVerified) {
      home = OtpVerificationScreen(
        role: role,
        phoneNumber: phone,
        onVerified: _verify,
      );
    } else if (role == DemoRole.customer) {
      home = MainMapScreen(userPhone: phone, onSignOut: _signOut);
    } else if (demoWorkerProfile.status != WorkerApplicationStatus.approved) {
      home = WorkerOnboardingScreen(
        phoneNumber: phone,
        onChanged: () => setState(() {}),
        onSignOut: _signOut,
      );
    } else {
      home = DriverHomeScreen(userPhone: phone, onSignOut: _signOut);
    }

    return MaterialApp(
      title: 'Option B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccentBlue,
          brightness: Brightness.light,
          primary: kAccentBlue,
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: home,
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  final ValueChanged<DemoRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Option B',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to use the app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.near_me_outlined,
                title: 'I need a service',
                subtitle: 'Request a ride, moto, or courier',
                onTap: () => onRoleSelected(DemoRole.customer),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.work_outline,
                title: 'I want to work',
                subtitle: 'Go online and accept nearby offers',
                onTap: () => onRoleSelected(DemoRole.driver),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Owner / Admin',
                subtitle: 'Approve workers and monitor requests',
                onTap: () => onRoleSelected(DemoRole.admin),
              ),
              const SizedBox(height: 20),
              Text(
                'Live simulation - no real SMS or backend',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
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
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: kAccentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: kAccentBlue, size: 28),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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
  final ValueChanged<String> onCodeSent;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Phone number is required');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Demo code sent: 1234')));
    widget.onCodeSent(phone);
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == DemoRole.driver;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone login')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              isDriver ? Icons.work_outline : Icons.near_me_outlined,
              color: kAccentBlue,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              isDriver ? 'Driver access' : 'Customer access',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your phone number to continue. Demo verification code: 1234',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
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
            PrimaryCtaButton(label: 'Continue', onPressed: _continue),
          ],
        ),
      ),
    );
  }
}

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

class _WorkerOnboardingScreenState extends State<WorkerOnboardingScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _cityCtrl;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final profile = demoWorkerProfile;
    profile.fullName = _nameCtrl.text.trim();
    profile.phoneNumber = _phoneCtrl.text.trim();
    profile.plateNumber = _plateCtrl.text.trim();
    profile.cityArea = _cityCtrl.text.trim();
    if (profile.status == WorkerApplicationStatus.notStarted) {
      profile.status = WorkerApplicationStatus.incomplete;
    }
  }

  void _submit() {
    _saveProfile();
    if (!demoWorkerProfile.canSubmit) {
      setState(() {});
      return;
    }
    setState(() {
      demoWorkerProfile.status = WorkerApplicationStatus.pending;
    });
    widget.onChanged();
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

  @override
  Widget build(BuildContext context) {
    final profile = demoWorkerProfile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker approval'),
        actions: [
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
            const Text(
              'Complete your worker profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit your details so the owner can approve you before you receive offers.',
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
            _DropdownField(
              label: 'Service type',
              value: profile.serviceType,
              options: const ['Ride', 'Moto', 'Courier', 'All services'],
              onChanged: (value) => setState(() {
                profile.serviceType = value;
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
            const SizedBox(height: 20),
            const Text(
              'Required documents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...kWorkerDocumentNames.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentCard(
                  name: name,
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
              onPressed: profile.canSubmit ? _submit : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                profile.reset();
                _nameCtrl.clear();
                _phoneCtrl.text = widget.phoneNumber;
                profile.phoneNumber = widget.phoneNumber;
                _plateCtrl.clear();
                _cityCtrl.clear();
                widget.onChanged();
              }),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset worker application demo'),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.name,
    required this.status,
    required this.onUpload,
  });

  final String name;
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
                _StatusChip(
                  label: documentStatusLabel(status),
                  status: status.name,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: status == DocumentStatus.approved ? null : onUpload,
            child: const Text('Upload demo'),
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
      'uploaded' || 'pending' => kAccentBlue,
      'rejected' => Colors.red,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner / Admin'),
        actions: [
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
            const Text(
              'Command center',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor live offers, worker approvals, active jobs, and local demo revenue.',
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
            _OwnerChartPanel(metrics: metrics),
            const SizedBox(height: 18),
            _OwnerRevenuePanel(metrics: metrics),
            const SizedBox(height: 18),
            _OwnerLiveMapPreview(jobs: jobs),
            const SizedBox(height: 18),
            _OwnerJobSection(
              title: 'Pending offers',
              emptyText: 'No pending offers in this period.',
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
                  'No pending worker applications yet.',
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

class _AdminCountCard extends StatelessWidget {
  const _AdminCountCard({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
      ('Total offers', '${metrics.totalOffers}'),
      ('Pending offers', '${metrics.pendingOffers}'),
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
            color: kAccentBlue,
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
            color: kAccentBlue,
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
            color: const Color(0xFF00796B),
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

class _OwnerLiveMapPreview extends StatelessWidget {
  const _OwnerLiveMapPreview({required this.jobs});

  final List<DemoServiceJob> jobs;

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
    final driverPoint = demoDriverAvailability.isOnline
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
          'Live map',
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
        Text(
          selected == null
              ? 'No live offers selected. Online workers and active jobs use this same shared map.'
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
                    'Worker performance',
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
              value: profile.fullName.isEmpty
                  ? 'Option B Driver'
                  : profile.fullName,
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
                        ? 'Worker application'
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

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.role,
    required this.phoneNumber,
    required this.onVerified,
  });

  final DemoRole role;
  final String phoneNumber;
  final VoidCallback onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _verify() {
    if (_codeCtrl.text.trim() != '1234') {
      setState(() => _error = 'That code is not correct. Use 1234 for demo.');
      return;
    }
    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Enter verification code',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Demo code sent to ${widget.phoneNumber}: 1234',
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
            PrimaryCtaButton(label: 'Verify', onPressed: _verify),
          ],
        ),
      ),
    );
  }
}

class PrimaryCtaButton extends StatelessWidget {
  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kAccentYellow,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
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
  });

  final String userPhone;
  final VoidCallback onSignOut;

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  final GooglePlacesService _placesService = const GooglePlacesService();
  final DirectionsService _directionsService = const DirectionsService();
  ServiceType _service = ServiceType.ride;
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
                subtitle: const Text('Completed demo offers'),
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
                title: const Text('Driver mode'),
                subtitle: const Text('Go online in the local demo'),
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
                title: const Text('Sign out'),
                subtitle: Text(widget.userPhone),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onSignOut();
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
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
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
                        color: Colors.white,
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
                              color: kAccentBlue,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _pickupLabel == kCurrentPickup
                                ? 'Current location'
                                : 'GPS location',
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
                  color: Colors.white,
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
                      const Text(
                        'Make an offer',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a service, set your price, and nearby drivers can accept.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('Service'),
                      Row(
                        children: ServiceType.values
                            .map(
                              (s) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: s == ServiceType.courier ? 0 : 8,
                                  ),
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
                            )
                            .toList(),
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
                        label: 'Send Offer',
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
              ? kAccentBlue.withValues(alpha: 0.09)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccentBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              serviceIcon(service),
              color: selected ? kAccentBlue : Colors.grey.shade700,
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                serviceLabel(service),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? kAccentBlue : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacesSuggestionList extends StatelessWidget {
  const _PlacesSuggestionList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, indent: 54, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              minLeadingWidth: 28,
              leading: const Icon(Icons.place_outlined, color: kAccentBlue),
              title: Text(
                suggestion.mainText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: suggestion.secondaryText.isEmpty
                  ? null
                  : Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.estimate, required this.loading});

  final RouteEstimate? estimate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            const Icon(Icons.route, color: kAccentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? 'Calculating estimate...'
                  : '${estimate!.isFallback ? 'Approx. estimate\n' : ''}'
                        'Estimated distance: ${estimate!.distanceText}\n'
                        'Estimated time: ${estimate!.durationText}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (estimate?.isFallback == true)
            Tooltip(
              message: 'Fallback estimate',
              child: Icon(Icons.info_outline, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$$amount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RecommendedOfferCard extends StatelessWidget {
  const _RecommendedOfferCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentYellow),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF8A6D00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Recommended offer',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '\$$amount',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _OfferSlider extends StatelessWidget {
  const _OfferSlider({
    required this.amount,
    required this.band,
    required this.onChanged,
  });

  final int amount;
  final PriceBand band;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your offer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '\$$amount',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            min: band.minimum.toDouble(),
            max: band.maximum.toDouble(),
            divisions: math.max(1, band.maximum - band.minimum),
            value: amount.toDouble(),
            activeColor: kAccentBlue,
            inactiveColor: Colors.grey.shade300,
            label: '\$$amount',
            onChanged: (value) => onChanged(value.round()),
          ),
          Row(
            children: [
              Text(
                '\$${band.minimum}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '\$${band.maximum}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label - \$$value'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kAccentYellow.withValues(alpha: 0.5),
      checkmarkColor: Colors.black87,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black87 : Colors.grey.shade800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }
}

class _OnlineDriverPreview extends StatelessWidget {
  const _OnlineDriverPreview({required this.service});

  final ServiceType service;

  @override
  Widget build(BuildContext context) {
    final drivers = onlineDriversFor(service);
    if (drivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No drivers online right now - demo driver can go online from Driver mode.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    final driver = drivers.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${driver.name} is online - ${driver.etaMin} min away',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({required this.selected, required this.onChanged});

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentOption(
            method: PaymentMethod.cash,
            selected: selected == PaymentMethod.cash,
            onTap: () => onChanged(PaymentMethod.cash),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentOption(
            method: PaymentMethod.card,
            selected: selected == PaymentMethod.card,
            onTap: () => onChanged(PaymentMethod.card),
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = method == PaymentMethod.cash
        ? Icons.payments_outlined
        : Icons.credit_card;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? kAccentBlue.withValues(alpha: 0.09)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccentBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kAccentBlue : Colors.grey.shade700),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                paymentLabel(method),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? kAccentBlue : Colors.black87,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfferMatchingScreen extends StatefulWidget {
  const OfferMatchingScreen({super.key, required this.offer});

  final OfferPayload offer;

  @override
  State<OfferMatchingScreen> createState() => _OfferMatchingScreenState();
}

class _OfferMatchingScreenState extends State<OfferMatchingScreen> {
  DriverInfo? _selectedDriver;
  Timer? _jobWatchTimer;

  @override
  void initState() {
    super.initState();
    _jobWatchTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _openTrackingIfAccepted(),
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Your offer was accepted')));
    _jobWatchTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(offer: widget.offer, driver: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drivers = onlineDriversFor(widget.offer.service);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finding drivers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
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
                      'Waiting for drivers to accept your offer',
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
                  ? 'No drivers online right now'
                  : 'Online drivers',
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
                  'No drivers online right now - demo driver can go online from Driver mode.',
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
                        ? 'Option B Driver'
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
                label: const Text('Simulate approved driver goes online'),
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
              label: 'Simulate Driver Accepts',
              onPressed: drivers.isEmpty ? null : _accept,
            ),
          ],
        ),
      ),
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
  'Offer sent',
  'Driver accepted',
  'Driver on the way',
  'Arrived at pickup',
  'In progress',
  'Completed',
];

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.offer, required this.driver});

  final OfferPayload offer;
  final DriverInfo driver;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  int _stepIndex = 2;
  bool _savedHistory = false;

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

  List<DemoMapPoint> get _activeRoutePoints {
    final baseRoute = widget.offer.routePoints.isEmpty
        ? <DemoMapPoint>[_pickupPoint, _destinationPoint]
        : widget.offer.routePoints;
    return [_driverPoint, ...baseRoute];
  }

  void _advance() {
    if (_stepIndex >= kTrackingSteps.length - 1) {
      if (!_savedHistory) {
        saveCompletedOfferHistory(widget.offer, widget.driver);
        _savedHistory = true;
      }
      completeServiceJob(widget.offer);
      upsertDemoJob(widget.offer, DemoJobStatus.completed);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trip complete'),
          content: const Text('This completed offer is now saved in History.'),
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
      appBar: AppBar(
        title: const Text('Live trip'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 178,
                child: AppMap(
                  pickup: _pickupPoint,
                  destination: _destinationPoint,
                  driver: _driverPoint,
                  routePoints: _activeRoutePoints,
                  cameraUpdateKey: _stepIndex,
                  showRoute: true,
                ),
              ),
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
    final color = completed || active ? kAccentBlue : Colors.grey.shade400;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: demoHistory.isEmpty
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
  bool _accepted = false;
  bool _rejected = false;
  int _jobStep = 1;
  bool _completionShown = false;
  OfferPayload? _activeOffer;
  DemoServiceJob? _selectedNearbyJob;

  @override
  void initState() {
    super.initState();
    final activeJob = _assignedActiveJob;
    if (activeJob != null) {
      _accepted = true;
      _activeOffer = activeJob.offer;
    }
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
    return [
      _driverPoint,
      _currentOffer.pickupPoint ?? kDemoPickupPoint,
      _currentOffer.destinationPoint ?? kDemoDestinationPoint,
    ];
  }

  String get _jobStatus {
    switch (_jobStep) {
      case 1:
        return 'Driver accepted';
      case 2:
        return 'Driver on the way';
      case 3:
        return 'Arrived at pickup';
      case 4:
        return 'In progress';
      default:
        return 'Completed';
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
        demoDriverAvailability.locationLabel = 'Default demo driver location';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              (result.point != null
                  ? 'Driver location updated'
                  : 'Using default demo driver location'),
        ),
      ),
    );
  }

  void _rejectOffer(OfferPayload offer) {
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

  void _acceptOffer(OfferPayload offer) {
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
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              _KeyValueRow(label: 'Destination', value: offer.destination),
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
              const SizedBox(height: 12),
              Row(
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
            ],
          ),
        ),
      ),
    );
  }

  void _advanceJob(OfferPayload offer) {
    if (_jobStep >= 5) {
      return;
    }
    setState(() => _jobStep++);
    if (_jobStep >= 5) {
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

  @override
  Widget build(BuildContext context) {
    final o = _currentOffer;
    final nearbyJobs = _nearbyPendingJobs;
    final online = demoDriverAvailability.isOnline;
    final summary = driverEarningsSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver home'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
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
            Text(
              'Driver profile',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                          'Option B Driver',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.userPhone,
                          style: TextStyle(
                            color: Colors.grey.shade700,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    online
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: online ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      online ? 'Online and visible to customers' : 'Offline',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Switch(
                    value: online,
                    onChanged:
                        demoWorkerProfile.status !=
                            WorkerApplicationStatus.approved
                        ? null
                        : (value) {
                            setState(() {
                              demoDriverAvailability.isOnline = value;
                              if (value) {
                                _rejected = false;
                              }
                            });
                          },
                  ),
                ],
              ),
            ),
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
                text: 'Go online to receive incoming offers.',
              )
            else if (_rejected)
              _StateMessage(
                icon: Icons.block,
                text: 'Offer rejected. Waiting for the next demo offer.',
              )
            else ...[
              if (!_accepted) ...[
                _DriverNearbyOffersPanel(
                  jobs: nearbyJobs,
                  driverPoint: demoDriverAvailability.location,
                  selectedJob: _selectedNearbyJob,
                  onSelect: (job) => _selectNearbyOffer(job, openDetail: false),
                  onOpenDetail: _selectNearbyOffer,
                ),
              ] else ...[
                const SizedBox(height: 16),
                _StateMessage(
                  icon: Icons.check_circle,
                  text: 'Accepted. Head to pickup and start the active job.',
                ),
                const SizedBox(height: 16),
                _DriverActiveJobPanel(
                  offer: o,
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

class _DriverNearbyOffersPanel extends StatelessWidget {
  const _DriverNearbyOffersPanel({
    required this.jobs,
    required this.driverPoint,
    required this.selectedJob,
    required this.onSelect,
    required this.onOpenDetail,
  });

  final List<DemoServiceJob> jobs;
  final DemoMapPoint driverPoint;
  final DemoServiceJob? selectedJob;
  final ValueChanged<DemoServiceJob> onSelect;
  final ValueChanged<DemoServiceJob> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final activeJob = selectedJob ?? (jobs.isEmpty ? null : jobs.first);
    final markers = jobs
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'Nearby offers',
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
            pickup: activeJob?.pickupPoint ?? driverPoint,
            destination: activeJob?.destinationPoint,
            driver: driverPoint,
            offerMarkers: markers,
            selectedMarkerId: selectedJob?.offer.id,
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
              }
            },
            routePoints: activeJob == null
                ? const []
                : [
                    driverPoint,
                    activeJob.pickupPoint,
                    activeJob.destinationPoint,
                  ],
            height: 230,
            showRoute: activeJob != null,
          ),
        ),
        const SizedBox(height: 12),
        if (jobs.isEmpty)
          _StateMessage(
            icon: Icons.radar,
            text:
                'No nearby offers yet. New customer offers within your area will appear here.',
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
              itemCount: jobs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
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

class _DriverDashboardSummary extends StatelessWidget {
  const _DriverDashboardSummary({required this.summary});

  final DriverEarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Earnings dashboard',
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
              label: 'Net earnings',
              value: '\$${summary.netEarnings.toStringAsFixed(2)}',
            ),
            _MetricCard(
              label: 'Accepted jobs',
              value: '${summary.acceptedJobs}',
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
                label: 'Net earnings',
                value: summary.netEarnings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
            label: 'Available payout',
            value: summary.availablePayout,
          ),
          _CompactMoneyRow(
            label: 'Pending payout',
            value: summary.pendingPayout,
          ),
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
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payout request submitted')),
              );
            },
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Request payout'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.black87,
            ),
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
              'No driver jobs yet. Go online, accept an offer, and complete it to build earnings.',
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

class DriverJobsHistoryScreen extends StatelessWidget {
  const DriverJobsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Earnings')),
      body: SafeArea(
        child: demoDriverJobs.isEmpty
            ? const Center(child: Text('No driver jobs yet.'))
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
    final pickup = offer.pickupPoint ?? kDemoPickupPoint;
    final destination = offer.destinationPoint ?? kDemoDestinationPoint;
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
                '${offer.pickup} to ${offer.destination} - ${paymentLabel(offer.paymentMethod)}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fare: \$${offer.offerAmount.toStringAsFixed(2)} - Expected payout: \$${(offer.offerAmount * 0.85).toStringAsFixed(2)}',
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

class DemoChatScreen extends StatefulWidget {
  const DemoChatScreen({
    super.key,
    required this.title,
    required this.meLabel,
    required this.themLabel,
  });

  final String title;
  final String meLabel;
  final String themLabel;

  @override
  State<DemoChatScreen> createState() => _DemoChatScreenState();
}

class _DemoChatScreenState extends State<DemoChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final List<_ChatMessage> _messages = const [
    _ChatMessage(sender: 'System', text: 'Live simulation chat'),
    _ChatMessage(sender: 'Customer', text: 'I am near the main entrance.'),
    _ChatMessage(
      sender: 'Driver',
      text: 'I am on my way. Please confirm the pickup point.',
    ),
  ].toList();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(sender: widget.meLabel, text: text));
      _messageCtrl.clear();
    });
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            sender: widget.themLabel,
            text: 'Got it. I am on the way.',
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final mine = message.sender == widget.meLabel;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: mine
                            ? kAccentBlue.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.sender,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(message.text),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
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

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});

  final String sender;
  final String text;
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
