part of '../main.dart';

const String kBrandName = AppConfig.appName;
const String kBrandShort = AppConfig.appShortName;
const String kBrandDelivery = AppConfig.appDeliveryName;
const String kBrandLogoAsset = 'assets/branding/on_my_way_logo.jpeg';
const String kBrandBadgeAsset = 'assets/branding/on_my_way_badge.jpeg';
const Color kBrandBlack = Color(0xFF050505);
const Color kBrandBackground = Color(0xFF0B0B0B);
const Color kBrandSurface = Color(0xFF111111);
const Color kBrandSurfaceAlt = Color(0xFF181818);
const Color kAccentYellow = Color(0xFFFFD21F);
const Color kDeepGold = Color(0xFFD89B00);
const Color kMutedText = Color(0xFFA8A8A8);
const Color kAccentBlue = kDeepGold;
const String kCurrentPickup = 'Current Location';
const DemoMapPoint kDemoPickupPoint = DemoMapPoint(33.8938, 35.5018);
const DemoMapPoint kDemoDestinationPoint = DemoMapPoint(33.9006, 35.5144);

enum ServiceType { ride, moto, courier }

enum DemoRole { customer, driver, storeOwner, admin }

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

const String kWorkerAgreementVersion = '1.0';

enum WorkerApplicationStatus {
  notStarted,
  incomplete,
  pending,
  approved,
  rejected,
}

enum DocumentStatus { missing, uploaded, approved, rejected }

backend.WorkerStatus backendWorkerStatusFor(WorkerApplicationStatus status) {
  switch (status) {
    case WorkerApplicationStatus.notStarted:
    case WorkerApplicationStatus.incomplete:
      return backend.WorkerStatus.incomplete;
    case WorkerApplicationStatus.pending:
      return backend.WorkerStatus.pending;
    case WorkerApplicationStatus.approved:
      return backend.WorkerStatus.approved;
    case WorkerApplicationStatus.rejected:
      return backend.WorkerStatus.rejected;
  }
}

WorkerApplicationStatus workerStatusFromBackend(backend.WorkerStatus status) {
  switch (status) {
    case backend.WorkerStatus.incomplete:
      return WorkerApplicationStatus.incomplete;
    case backend.WorkerStatus.pending:
      return WorkerApplicationStatus.pending;
    case backend.WorkerStatus.approved:
      return WorkerApplicationStatus.approved;
    case backend.WorkerStatus.rejected:
    case backend.WorkerStatus.suspended:
      return WorkerApplicationStatus.rejected;
  }
}

List<String> backendWorkerServiceTypesFor(String serviceType) {
  switch (serviceType) {
    case 'Ride':
      return const ['ride'];
    case 'Moto':
      return const ['moto'];
    case 'Courier':
      return const ['courier'];
    default:
      return const ['ride', 'moto', 'courier'];
  }
}

String serviceTypeLabelFromBackend(List<String> serviceTypes) {
  if (serviceTypes.length > 1) {
    return 'All services';
  }
  if (serviceTypes.contains('moto')) {
    return 'Moto';
  }
  if (serviceTypes.contains('courier')) {
    return 'Courier';
  }
  return 'Ride';
}

void syncDemoWorkerFromBackend(backend.WorkerProfile profile) {
  demoWorkerProfile.fullName = profile.fullName;
  demoWorkerProfile.phoneNumber = profile.phone;
  demoWorkerProfile.vehicleType = profile.vehicleType.isEmpty
      ? demoWorkerProfile.vehicleType
      : profile.vehicleType;
  demoWorkerProfile.serviceType = serviceTypeLabelFromBackend(
    profile.serviceTypes,
  );
  demoWorkerProfile.servicesOffered = profile.serviceTypes.isEmpty
      ? const ['ride']
      : profile.serviceTypes;
  demoWorkerProfile.plateNumber = profile.plateNumber;
  demoWorkerProfile.cityArea = profile.operatingArea;
  demoWorkerProfile.status = workerStatusFromBackend(profile.status);
  demoWorkerProfile.agreementAccepted = profile.agreementAccepted;
  demoWorkerProfile.agreementAcceptedAt = profile.agreementAcceptedAt;
  demoWorkerProfile.agreementVersion = profile.agreementVersion;
  demoWorkerProfile.payoutMethod = profile.payoutMethod;
  demoWorkerProfile.payoutDisplayName = profile.payoutDisplayName;
  demoWorkerProfile.payoutPhoneNumber = profile.payoutPhoneNumber;
  demoWorkerProfile.payoutNotes = profile.payoutNotes;
  demoDriverAvailability.isOnline = profile.isOnline;
  if (profile.currentLat != null && profile.currentLng != null) {
    demoDriverAvailability.location = DemoMapPoint(
      profile.currentLat!,
      profile.currentLng!,
    );
  }
}

class LoginVerificationRequest {
  const LoginVerificationRequest({
    required this.phoneNumber,
    required this.session,
  });

  final String phoneNumber;
  final PhoneVerificationSession session;
}

String _friendlyAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-phone-number':
      return 'That phone number is not valid. Include your country code, for example +961...';
    case 'quota-exceeded':
      return 'SMS quota has been reached. Please try again later.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait and try again.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'invalid-verification-code':
    case 'invalid-verification-id':
      return 'That verification code is not correct. Please try again.';
    case 'session-expired':
    case 'code-expired':
      return 'This verification code expired. Please request a new code.';
    case 'functions/not-found':
    case 'failed-precondition':
    case 'whatsapp-not-configured':
      return 'WhatsApp OTP backend is not configured yet.';
    case 'resource-exhausted':
      return 'Too many attempts. Please wait and try again.';
    case 'unavailable':
      return 'Authentication backend is unavailable. Please try again.';
    case 'missing-custom-token':
      return 'WhatsApp verification could not complete. Please try SMS instead.';
    default:
      return 'Authentication failed. Please try again.';
  }
}

String _friendlyFunctionsError(FirebaseFunctionsException error) {
  switch (error.code) {
    case 'failed-precondition':
      if ((error.message ?? '').contains('test numbers')) {
        return 'WhatsApp OTP test numbers are not configured yet. Please contact OMW admin.';
      }
      return 'WhatsApp OTP provider is not configured.';
    case 'not-found':
      return 'WhatsApp OTP backend is not configured yet.';
    case 'invalid-argument':
      return 'Please include your country code, for example +961...';
    case 'resource-exhausted':
      return 'Too many attempts. Please wait and try again.';
    case 'deadline-exceeded':
      return 'This verification code expired. Please request a new code.';
    case 'unavailable':
      return 'WhatsApp OTP backend is unavailable. Please try again.';
    case 'permission-denied':
      if ((error.message ?? '').contains('not enabled')) {
        return 'This WhatsApp number is not enabled for testing yet.';
      }
      return 'That WhatsApp verification code is not correct. Please try again.';
    default:
      return 'WhatsApp verification failed. Please try again.';
  }
}

String backendRoleNameFor(DemoRole role) => backendRoleFor(role).name;

void switchAccountFrom(BuildContext context, VoidCallback onSignOut) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  onSignOut();
}

void navigateBackOrHome(BuildContext context, {VoidCallback? fallback}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  fallback?.call();
}

class OmwBackButton extends StatelessWidget {
  const OmwBackButton({super.key, this.fallback, this.tooltip = 'Back'});

  final VoidCallback? fallback;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => navigateBackOrHome(context, fallback: fallback),
    );
  }
}

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

String marketplaceItemSummary(List<backend.MarketplaceCartItem> items) {
  if (items.isEmpty) {
    return 'No listed items';
  }
  return items
      .map((item) => '${item.quantity}x ${item.productName}')
      .join(', ');
}

String payoutMethodLabel(String value) {
  return switch (value) {
    'wishMoney' => 'Wish Money',
    'omtPay' => 'OMT Pay',
    'cash' => 'Cash',
    'bankTransfer' => 'Bank Transfer',
    'other' => 'Other',
    _ => value.isEmpty ? 'Not set' : value,
  };
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

String canonicalServiceTypeFor(ServiceType service) {
  switch (service) {
    case ServiceType.ride:
      return 'ride';
    case ServiceType.moto:
      return 'moto';
    case ServiceType.courier:
      return 'courier';
  }
}

String serviceRequestLabel(String serviceType) {
  return switch (serviceType) {
    'ride' => 'Ride',
    'moto' => 'Moto',
    'courier' => 'Courier',
    'marketplace_delivery' => 'Marketplace delivery',
    _ => serviceType.isEmpty ? 'OMW request' : serviceType,
  };
}

String serviceRequestStatusLabel(ServiceRequestStatus status) {
  return switch (status) {
    ServiceRequestStatus.requested => 'Requested',
    ServiceRequestStatus.accepted => 'Accepted',
    ServiceRequestStatus.workerOnWay => 'Worker on way',
    ServiceRequestStatus.arrived => 'Arrived',
    ServiceRequestStatus.inProgress => 'In progress',
    ServiceRequestStatus.pickupStarted => 'Pickup started',
    ServiceRequestStatus.pickedUp => 'Picked up',
    ServiceRequestStatus.deliveryStarted => 'Delivery started',
    ServiceRequestStatus.onTheWay => 'On the way',
    ServiceRequestStatus.delivered => 'Delivered',
    ServiceRequestStatus.completed => 'Completed',
    ServiceRequestStatus.canceled => 'Canceled',
  };
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

bool get useFirebaseJobs => FirebaseService.instance.isReady;

backend.BackendServiceType backendServiceTypeFor(ServiceType service) {
  switch (service) {
    case ServiceType.ride:
      return backend.BackendServiceType.ride;
    case ServiceType.moto:
      return backend.BackendServiceType.moto;
    case ServiceType.courier:
      return backend.BackendServiceType.courier;
  }
}

ServiceType serviceTypeFromBackend(backend.BackendServiceType service) {
  switch (service) {
    case backend.BackendServiceType.ride:
      return ServiceType.ride;
    case backend.BackendServiceType.moto:
      return ServiceType.moto;
    case backend.BackendServiceType.courier:
      return ServiceType.courier;
  }
}

backend.BackendPaymentMethod backendPaymentMethodFor(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return backend.BackendPaymentMethod.cash;
    case PaymentMethod.card:
      return backend.BackendPaymentMethod.card;
  }
}

PaymentMethod paymentMethodFromBackend(backend.BackendPaymentMethod method) {
  switch (method) {
    case backend.BackendPaymentMethod.cash:
      return PaymentMethod.cash;
    case backend.BackendPaymentMethod.card:
      return PaymentMethod.card;
  }
}

DemoServiceJobStatus demoStatusFromBackend(backend.JobStatus status) {
  switch (status) {
    case backend.JobStatus.pending:
      return DemoServiceJobStatus.pending;
    case backend.JobStatus.accepted:
      return DemoServiceJobStatus.accepted;
    case backend.JobStatus.active:
      return DemoServiceJobStatus.active;
    case backend.JobStatus.completed:
      return DemoServiceJobStatus.completed;
    case backend.JobStatus.rejected:
      return DemoServiceJobStatus.rejected;
    case backend.JobStatus.cancelled:
      return DemoServiceJobStatus.cancelled;
  }
}

backend.JobOffer backendJobFromOffer({
  required OfferPayload offer,
  required User user,
  String customerName = '',
}) {
  final pickup = offer.pickupPoint ?? kDemoPickupPoint;
  final destination = offer.destinationPoint ?? kDemoDestinationPoint;
  final gross = offer.offerAmount.toDouble();
  return backend.JobOffer(
    id: offer.id.startsWith('OPT-B') ? '' : offer.id,
    customerId: user.uid,
    customerPhone: user.phoneNumber ?? '',
    customerName: customerName,
    serviceType: backendServiceTypeFor(offer.service),
    pickupLabel: offer.pickup,
    pickupLat: pickup.latitude,
    pickupLng: pickup.longitude,
    destinationLabel: offer.destination,
    destinationLat: destination.latitude,
    destinationLng: destination.longitude,
    offerAmount: gross,
    paymentMethod: backendPaymentMethodFor(offer.paymentMethod),
    status: backend.JobStatus.pending,
    createdAt: DateTime.now(),
    gross: gross,
    platformCommission: AppConfig.platformCommissionFor(gross),
    workerPayout: AppConfig.workerPayoutFor(gross),
  );
}

OfferPayload offerFromBackendJob(backend.JobOffer job) {
  return OfferPayload(
    id: job.id,
    service: serviceTypeFromBackend(job.serviceType),
    pickup: job.pickupLabel,
    destination: job.destinationLabel,
    offerAmount: job.offerAmount.round(),
    paymentMethod: paymentMethodFromBackend(job.paymentMethod),
    pickupPoint: DemoMapPoint(job.pickupLat, job.pickupLng),
    destinationPoint: DemoMapPoint(job.destinationLat, job.destinationLng),
  );
}

DemoServiceJob demoServiceJobFromBackend(backend.JobOffer job) {
  return DemoServiceJob(
      offer: offerFromBackendJob(job),
      customerPhone: job.customerPhone,
      customerName: job.customerName.isEmpty
          ? 'OMW Customer'
          : job.customerName,
      status: demoStatusFromBackend(job.status),
      assignedWorkerId: job.assignedWorkerId,
      assignedWorkerName: job.assignedWorkerName,
      createdAt: job.createdAt,
      workerPayoutStatus: job.workerPayoutStatus,
      workerPaidAt: job.workerPaidAt,
      payoutNote: job.payoutNote,
    )
    ..completedAt = job.completedAt
    ..rejectedAt = job.rejectedAt ?? job.cancelledAt;
}

DriverInfo driverInfoFromBackendJob(backend.JobOffer job, ServiceType service) {
  return DriverInfo(
    name: job.assignedWorkerName?.trim().isNotEmpty == true
        ? job.assignedWorkerName!
        : 'OMW Driver',
    rating: 4.8,
    vehicle: service == ServiceType.moto ? 'Moto' : 'OMW vehicle',
    distanceKm: 1.2,
    etaMin: 5,
  );
}

class MarketplaceDeliveryJob {
  const MarketplaceDeliveryJob({required this.order, required this.store});

  final backend.MarketplaceOrder order;
  final backend.MarketplaceStore store;

  DemoMapPoint get pickupPoint => DemoMapPoint(
    order.storeLat == 0 ? store.lat : order.storeLat,
    order.storeLng == 0 ? store.lng : order.storeLng,
  );
  DemoMapPoint get destinationPoint =>
      DemoMapPoint(order.deliveryLat, order.deliveryLng);
  String get id => order.id;
  String get storeAddress =>
      order.storeAddress.trim().isEmpty ? store.address : order.storeAddress;
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

class WorkerDocumentRequirement {
  const WorkerDocumentRequirement({
    required this.type,
    required this.label,
    required this.required,
  });

  final backend.WorkerDocumentType type;
  final String label;
  final bool required;
}

const List<WorkerDocumentRequirement> kWorkerDocumentRequirements = [
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.profilePhoto,
    label: 'Profile photo',
    required: true,
  ),
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.governmentId,
    label: 'Government ID',
    required: true,
  ),
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.driverLicense,
    label: 'Driver license',
    required: true,
  ),
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.vehicleRegistration,
    label: 'Vehicle registration',
    required: true,
  ),
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.vehiclePhoto,
    label: 'Vehicle photo',
    required: true,
  ),
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.insurance,
    label: 'Insurance',
    required: false,
  ),
  WorkerDocumentRequirement(
    type: backend.WorkerDocumentType.backgroundCheck,
    label: 'Background check',
    required: false,
  ),
];

const List<String> kWorkerDocumentNames = [
  'Profile photo',
  'Government ID',
  'Driver license',
  'Vehicle registration',
  'Vehicle photo',
  'Insurance',
  'Background check',
];

WorkerDocumentRequirement workerRequirementForName(String name) {
  return kWorkerDocumentRequirements.firstWhere(
    (requirement) => requirement.label == name,
    orElse: () => kWorkerDocumentRequirements.first,
  );
}

String workerDocumentLabel(backend.WorkerDocumentType type) {
  return kWorkerDocumentRequirements
      .firstWhere(
        (requirement) => requirement.type == type,
        orElse: () => WorkerDocumentRequirement(
          type: type,
          label: type.name,
          required: false,
        ),
      )
      .label;
}

bool requiredWorkerDocumentsUploaded(List<backend.WorkerDocument> documents) {
  return kWorkerDocumentRequirements
      .where((requirement) => requirement.required)
      .every((requirement) {
        final document = documents.where((doc) => doc.type == requirement.type);
        if (document.isEmpty) {
          return false;
        }
        final current = document.first;
        return current.fileUrl.isNotEmpty &&
            current.status != backend.WorkerDocumentStatus.missing;
      });
}

bool requiredWorkerDocumentsApproved(List<backend.WorkerDocument> documents) {
  return kWorkerDocumentRequirements
      .where((requirement) => requirement.required)
      .every((requirement) {
        final document = documents.where((doc) => doc.type == requirement.type);
        return document.isNotEmpty &&
            document.first.status == backend.WorkerDocumentStatus.approved;
      });
}

backend.WorkerDocument? documentForRequirement(
  List<backend.WorkerDocument> documents,
  WorkerDocumentRequirement requirement,
) {
  for (final document in documents) {
    if (document.type == requirement.type) {
      return document;
    }
  }
  return null;
}

class WorkerProfile {
  WorkerProfile();

  String fullName = '';
  String phoneNumber = '';
  String vehicleType = 'Car';
  String serviceType = 'Ride';
  List<String> servicesOffered = const ['ride'];
  String plateNumber = '';
  String cityArea = '';
  bool agreementAccepted = false;
  DateTime? agreementAcceptedAt;
  String agreementVersion = '';
  String payoutMethod = '';
  String payoutDisplayName = '';
  String payoutPhoneNumber = '';
  String payoutNotes = '';
  WorkerApplicationStatus status = WorkerApplicationStatus.notStarted;
  final Map<String, DocumentStatus> documents = {
    for (final name in kWorkerDocumentNames) name: DocumentStatus.missing,
  };

  bool get hasProfileDetails =>
      fullName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      vehicleType.trim().isNotEmpty &&
      servicesOffered.isNotEmpty &&
      plateNumber.trim().isNotEmpty &&
      cityArea.trim().isNotEmpty &&
      agreementAccepted &&
      payoutMethod.trim().isNotEmpty &&
      payoutDisplayName.trim().isNotEmpty &&
      payoutPhoneNumber.trim().isNotEmpty;

  bool get allDocumentsUploaded => kWorkerDocumentRequirements
      .where((requirement) => requirement.required)
      .every((requirement) {
        final status = documents[requirement.label] ?? DocumentStatus.missing;
        return status == DocumentStatus.uploaded ||
            status == DocumentStatus.approved;
      });

  bool get canSubmit => hasProfileDetails && allDocumentsUploaded;

  String get documentsSummary {
    final required = kWorkerDocumentRequirements
        .where((requirement) => requirement.required)
        .toList();
    final uploaded = required.where((requirement) {
      final status = documents[requirement.label] ?? DocumentStatus.missing;
      return status == DocumentStatus.uploaded ||
          status == DocumentStatus.approved;
    }).length;
    return '$uploaded/${required.length} required documents uploaded';
  }

  void reset() {
    fullName = '';
    phoneNumber = '';
    vehicleType = 'Car';
    serviceType = 'Ride';
    servicesOffered = const ['ride'];
    plateNumber = '';
    cityArea = '';
    agreementAccepted = false;
    agreementAcceptedAt = null;
    agreementVersion = '';
    payoutMethod = '';
    payoutDisplayName = '';
    payoutPhoneNumber = '';
    payoutNotes = '';
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
    this.workerPayoutStatus = 'unpaid',
    this.workerPaidAt,
    this.payoutNote,
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
  String workerPayoutStatus;
  DateTime? workerPaidAt;
  String? payoutNote;

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

OwnerMetrics ownerMetricsFor(
  List<DemoServiceJob> jobs, {
  int? onlineWorkersOverride,
}) {
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
      onlineWorkersOverride ??
      (demoDriverAvailability.isOnline &&
              demoWorkerProfile.status == WorkerApplicationStatus.approved
          ? 1
          : 0);
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
    required this.paidBalance,
    required this.unpaidBalance,
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
  final double paidBalance;
  final double unpaidBalance;

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
  var paid = 0.0;
  var unpaid = 0.0;

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
      if (job.status == DemoJobStatus.completed) {
        final serviceJob = findServiceJob(job.offer.id);
        if (serviceJob?.workerPayoutStatus == 'paid') {
          paid += job.driverPayout;
        } else {
          unpaid += job.driverPayout;
        }
      }
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
    paidBalance: paid,
    unpaidBalance: unpaid,
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
