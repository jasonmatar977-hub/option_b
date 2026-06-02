import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

DateTime? _dateFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Object? _dateToValue(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

List<String> _stringList(Object? value) {
  if (value is Iterable) return value.whereType<String>().toList();
  return const [];
}

enum AppRole {
  customer,
  worker,
  storeOwner,
  owner;

  static AppRole fromValue(Object? value) => AppRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AppRole.customer,
  );
}

enum WorkerStatus {
  incomplete,
  pending,
  approved,
  rejected,
  suspended;

  String get firestoreValue => switch (this) {
    WorkerStatus.pending => 'pending_approval',
    _ => name,
  };

  static WorkerStatus fromValue(Object? value) {
    if (value == 'pending_approval') return WorkerStatus.pending;
    return WorkerStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WorkerStatus.incomplete,
    );
  }
}

enum BackendServiceType {
  ride,
  moto,
  courier;

  static BackendServiceType fromValue(Object? value) =>
      BackendServiceType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => BackendServiceType.ride,
      );
}

enum BackendPaymentMethod {
  cash,
  card;

  static BackendPaymentMethod fromValue(Object? value) =>
      BackendPaymentMethod.values.firstWhere(
        (method) => method.name == value,
        orElse: () => BackendPaymentMethod.cash,
      );
}

enum JobStatus {
  pending,
  accepted,
  active,
  completed,
  rejected,
  cancelled;

  static JobStatus fromValue(Object? value) => JobStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => JobStatus.pending,
  );
}

enum MarketplaceOrderStatus {
  pending,
  accepted,
  shopping,
  pickedUp,
  onTheWay,
  delivered,
  cancelled;

  static MarketplaceOrderStatus fromValue(Object? value) =>
      MarketplaceOrderStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => MarketplaceOrderStatus.pending,
      );
}

enum WorkerDocumentType {
  id,
  governmentId,
  driverLicense,
  vehicleRegistration,
  vehiclePhoto,
  insurance,
  profilePhoto,
  backgroundCheck;

  static WorkerDocumentType fromValue(Object? value) =>
      WorkerDocumentType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => WorkerDocumentType.id,
      );
}

enum WorkerDocumentStatus {
  missing,
  uploaded,
  pendingReview,
  approved,
  rejected;

  String get firestoreValue => switch (this) {
    WorkerDocumentStatus.uploaded ||
    WorkerDocumentStatus.pendingReview => 'pending_review',
    _ => name,
  };

  static WorkerDocumentStatus fromValue(Object? value) {
    if (value == 'pending_review') return WorkerDocumentStatus.pendingReview;
    return WorkerDocumentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WorkerDocumentStatus.missing,
    );
  }
}

enum WorkerDocumentsStatus {
  incomplete,
  pendingReview,
  approved,
  rejected;

  String get firestoreValue => switch (this) {
    WorkerDocumentsStatus.pendingReview => 'pending_review',
    _ => name,
  };

  static WorkerDocumentsStatus fromValue(Object? value) {
    if (value == 'pending_review') return WorkerDocumentsStatus.pendingReview;
    return WorkerDocumentsStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WorkerDocumentsStatus.incomplete,
    );
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.phoneNumber,
    required this.displayName,
    this.email,
    required this.roles,
    required this.activeRole,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
    required this.isActive,
    this.whatsappNumber = '',
    this.whatsappVerified = false,
    this.whatsappVerifiedAt,
    this.authProvider = '',
    this.emailVerified = false,
  });

  final String uid;
  final String phoneNumber;
  final String displayName;
  final String? email;
  final List<AppRole> roles;
  final AppRole activeRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastLoginAt;
  final bool isActive;
  final String whatsappNumber;
  final bool whatsappVerified;
  final DateTime? whatsappVerifiedAt;
  final String authProvider;
  final bool emailVerified;

  String get phone => phoneNumber;
  AppRole get role => activeRole;

  factory AppUser.fromMap(String uid, Map<String, Object?> data) {
    final now = DateTime.now();
    final legacyRole = AppRole.fromValue(data['role']);
    final parsedRoles = _stringList(
      data['roles'],
    ).map(AppRole.fromValue).toSet().toList();
    final roles = parsedRoles.isEmpty ? <AppRole>[legacyRole] : parsedRoles;
    final activeRole = AppRole.fromValue(data['activeRole'] ?? data['role']);
    return AppUser(
      uid: uid,
      phoneNumber:
          data['phoneNumber'] as String? ?? data['phone'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String?,
      roles: roles,
      activeRole: roles.contains(activeRole) ? activeRole : roles.first,
      createdAt: _dateFromValue(data['createdAt']) ?? now,
      updatedAt: _dateFromValue(data['updatedAt']) ?? now,
      lastLoginAt: _dateFromValue(data['lastLoginAt']) ?? now,
      isActive: data['isActive'] as bool? ?? true,
      whatsappNumber: data['whatsappNumber'] as String? ?? '',
      whatsappVerified: data['whatsappVerified'] as bool? ?? false,
      whatsappVerifiedAt: _dateFromValue(data['whatsappVerifiedAt']),
      authProvider: data['authProvider'] as String? ?? '',
      emailVerified: data['emailVerified'] as bool? ?? false,
    );
  }

  Map<String, Object?> toMap() => {
    'uid': uid,
    'phoneNumber': phoneNumber,
    'phone': phoneNumber,
    'displayName': displayName,
    'email': email,
    'roles': roles.map((role) => role.name).toList(),
    'activeRole': activeRole.name,
    'role': activeRole.name,
    'createdAt': _dateToValue(createdAt),
    'updatedAt': _dateToValue(updatedAt),
    'lastLoginAt': _dateToValue(lastLoginAt),
    'isActive': isActive,
    'whatsappNumber': whatsappNumber,
    'whatsappVerified': whatsappVerified,
    'whatsappVerifiedAt': _dateToValue(whatsappVerifiedAt),
    'authProvider': authProvider,
    'emailVerified': emailVerified,
  };

  AppUser copyWith({
    String? phoneNumber,
    String? displayName,
    String? email,
    List<AppRole>? roles,
    AppRole? activeRole,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    bool? isActive,
    String? whatsappNumber,
    bool? whatsappVerified,
    DateTime? whatsappVerifiedAt,
    String? authProvider,
    bool? emailVerified,
  }) {
    return AppUser(
      uid: uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      whatsappVerified: whatsappVerified ?? this.whatsappVerified,
      whatsappVerifiedAt: whatsappVerifiedAt ?? this.whatsappVerifiedAt,
      authProvider: authProvider ?? this.authProvider,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

class WorkerProfile {
  const WorkerProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    this.email,
    required this.serviceTypes,
    required this.vehicleType,
    required this.plateNumber,
    required this.operatingArea,
    required this.status,
    this.documentsStatus = WorkerDocumentsStatus.incomplete,
    required this.isOnline,
    this.currentLat,
    this.currentLng,
    required this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.approvedAt,
    this.approvedByAdminId,
    this.rejectedAt,
    this.rejectionReason,
    this.suspendedAt,
    this.agreementAccepted = false,
    this.agreementAcceptedAt,
    this.agreementVersion = '',
    this.platformCommissionRate = 0.15,
    this.workerPayoutRate = 0.85,
    this.payoutMethod = '',
    this.payoutDetails = '',
    this.payoutDisplayName = '',
    this.payoutPhoneNumber = '',
    this.bankDetails = '',
    this.payoutNotes = '',
  });

  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String? email;
  final List<String> serviceTypes;
  final String vehicleType;
  final String plateNumber;
  final String operatingArea;
  final WorkerStatus status;
  final WorkerDocumentsStatus documentsStatus;
  final bool isOnline;
  final double? currentLat;
  final double? currentLng;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? approvedByAdminId;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? suspendedAt;
  final bool agreementAccepted;
  final DateTime? agreementAcceptedAt;
  final String agreementVersion;
  final double platformCommissionRate;
  final double workerPayoutRate;
  final String payoutMethod;
  final String payoutDetails;
  final String payoutDisplayName;
  final String payoutPhoneNumber;
  final String bankDetails;
  final String payoutNotes;

  String get uid => userId;
  String get displayName => fullName;
  String get phoneNumber => phone;
  List<String> get servicesOffered => serviceTypes;
  WorkerStatus get workerStatus => status;
  String get payoutPhone => payoutPhoneNumber;

  factory WorkerProfile.fromMap(String id, Map<String, Object?> data) {
    return WorkerProfile(
      id: id,
      userId: data['uid'] as String? ?? data['userId'] as String? ?? id,
      fullName:
          data['displayName'] as String? ?? data['fullName'] as String? ?? '',
      phone: data['phoneNumber'] as String? ?? data['phone'] as String? ?? '',
      email: data['email'] as String?,
      serviceTypes: _stringList(
        data['servicesOffered'] ?? data['serviceTypes'],
      ),
      vehicleType: data['vehicleType'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      operatingArea: data['operatingArea'] as String? ?? '',
      status: WorkerStatus.fromValue(data['workerStatus'] ?? data['status']),
      documentsStatus: WorkerDocumentsStatus.fromValue(data['documentsStatus']),
      isOnline: data['isOnline'] as bool? ?? false,
      currentLat: (data['currentLat'] as num?)?.toDouble(),
      currentLng: (data['currentLng'] as num?)?.toDouble(),
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromValue(data['updatedAt']),
      submittedAt: _dateFromValue(data['submittedAt']),
      approvedAt: _dateFromValue(data['approvedAt']),
      approvedByAdminId: data['approvedByAdminId'] as String?,
      rejectedAt: _dateFromValue(data['rejectedAt']),
      rejectionReason: data['rejectionReason'] as String?,
      suspendedAt: _dateFromValue(data['suspendedAt']),
      agreementAccepted: data['agreementAccepted'] as bool? ?? false,
      agreementAcceptedAt: _dateFromValue(data['agreementAcceptedAt']),
      agreementVersion: data['agreementVersion'] as String? ?? '',
      platformCommissionRate:
          (data['platformCommissionRate'] as num?)?.toDouble() ?? 0.15,
      workerPayoutRate: (data['workerPayoutRate'] as num?)?.toDouble() ?? 0.85,
      payoutMethod: data['payoutMethod'] as String? ?? '',
      payoutDetails: data['payoutDetails'] as String? ?? '',
      payoutDisplayName: data['payoutDisplayName'] as String? ?? '',
      payoutPhoneNumber:
          data['payoutPhone'] as String? ??
          data['payoutPhoneNumber'] as String? ??
          '',
      bankDetails: data['bankDetails'] as String? ?? '',
      payoutNotes:
          data['payoutNotes'] as String? ??
          data['payoutDetails'] as String? ??
          '',
    );
  }

  Map<String, Object?> toMap() => {
    'uid': userId,
    'userId': userId,
    'displayName': fullName,
    'fullName': fullName,
    'phoneNumber': phone,
    'phone': phone,
    'email': email,
    'servicesOffered': serviceTypes,
    'serviceTypes': serviceTypes,
    'vehicleType': vehicleType,
    'plateNumber': plateNumber,
    'operatingArea': operatingArea,
    'status': status.name,
    'workerStatus': status.firestoreValue,
    'documentsStatus': documentsStatus.firestoreValue,
    'isOnline': isOnline,
    'currentLat': currentLat,
    'currentLng': currentLng,
    'createdAt': _dateToValue(createdAt),
    'updatedAt': _dateToValue(updatedAt ?? DateTime.now()),
    'submittedAt': _dateToValue(submittedAt),
    'approvedAt': _dateToValue(approvedAt),
    'approvedByAdminId': approvedByAdminId,
    'rejectedAt': _dateToValue(rejectedAt),
    'rejectionReason': rejectionReason,
    'suspendedAt': _dateToValue(suspendedAt),
    'agreementAccepted': agreementAccepted,
    'agreementAcceptedAt': _dateToValue(agreementAcceptedAt),
    'agreementVersion': agreementVersion,
    'platformCommissionRate': platformCommissionRate,
    'workerPayoutRate': workerPayoutRate,
    'payoutMethod': payoutMethod,
    'payoutDetails': payoutDetails,
    'payoutDisplayName': payoutDisplayName,
    'payoutPhoneNumber': payoutPhoneNumber,
    'payoutPhone': payoutPhoneNumber,
    'bankDetails': bankDetails,
    'payoutNotes': payoutNotes,
  };

  WorkerProfile copyWith({
    String? fullName,
    String? phone,
    String? email,
    List<String>? serviceTypes,
    String? vehicleType,
    String? plateNumber,
    String? operatingArea,
    WorkerStatus? status,
    WorkerDocumentsStatus? documentsStatus,
    bool? isOnline,
    double? currentLat,
    double? currentLng,
    DateTime? updatedAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approvedByAdminId,
    DateTime? rejectedAt,
    String? rejectionReason,
    DateTime? suspendedAt,
    bool? agreementAccepted,
    DateTime? agreementAcceptedAt,
    String? agreementVersion,
    double? platformCommissionRate,
    double? workerPayoutRate,
    String? payoutMethod,
    String? payoutDetails,
    String? payoutDisplayName,
    String? payoutPhoneNumber,
    String? bankDetails,
    String? payoutNotes,
  }) {
    return WorkerProfile(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      vehicleType: vehicleType ?? this.vehicleType,
      plateNumber: plateNumber ?? this.plateNumber,
      operatingArea: operatingArea ?? this.operatingArea,
      status: status ?? this.status,
      documentsStatus: documentsStatus ?? this.documentsStatus,
      isOnline: isOnline ?? this.isOnline,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedByAdminId: approvedByAdminId ?? this.approvedByAdminId,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      agreementAccepted: agreementAccepted ?? this.agreementAccepted,
      agreementAcceptedAt: agreementAcceptedAt ?? this.agreementAcceptedAt,
      agreementVersion: agreementVersion ?? this.agreementVersion,
      platformCommissionRate:
          platformCommissionRate ?? this.platformCommissionRate,
      workerPayoutRate: workerPayoutRate ?? this.workerPayoutRate,
      payoutMethod: payoutMethod ?? this.payoutMethod,
      payoutDetails: payoutDetails ?? this.payoutDetails,
      payoutDisplayName: payoutDisplayName ?? this.payoutDisplayName,
      payoutPhoneNumber: payoutPhoneNumber ?? this.payoutPhoneNumber,
      bankDetails: bankDetails ?? this.bankDetails,
      payoutNotes: payoutNotes ?? this.payoutNotes,
    );
  }
}

class WorkerDocument {
  const WorkerDocument({
    required this.id,
    required this.workerId,
    required this.type,
    required this.status,
    required this.fileUrl,
    this.fileName = '',
    this.storagePath = '',
    this.mimeType,
    this.fileSize,
    this.uploadedAt,
    this.reviewedAt,
    this.reviewedByAdminId,
    this.rejectionReason,
  });

  final String id;
  final String workerId;
  final WorkerDocumentType type;
  final WorkerDocumentStatus status;
  final String fileUrl;
  final String fileName;
  final String storagePath;
  final String? mimeType;
  final int? fileSize;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewedByAdminId;
  final String? rejectionReason;

  String get documentType => type.name;
  String get downloadUrl => fileUrl;
  DateTime? get createdAt => uploadedAt;

  factory WorkerDocument.fromMap(String id, Map<String, Object?> data) {
    return WorkerDocument(
      id: id,
      workerId: data['workerId'] as String? ?? '',
      type: WorkerDocumentType.fromValue(data['type'] ?? data['documentType']),
      status: WorkerDocumentStatus.fromValue(data['status']),
      fileUrl:
          data['fileUrl'] as String? ?? data['downloadUrl'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      mimeType: data['mimeType'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      uploadedAt: _dateFromValue(data['uploadedAt'] ?? data['createdAt']),
      reviewedAt: _dateFromValue(data['reviewedAt']),
      reviewedByAdminId: data['reviewedByAdminId'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'workerId': workerId,
    'type': type.name,
    'documentType': type.name,
    'status': status.firestoreValue,
    'fileUrl': fileUrl,
    'downloadUrl': fileUrl,
    'fileName': fileName,
    'storagePath': storagePath,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'uploadedAt': _dateToValue(uploadedAt),
    'reviewedAt': _dateToValue(reviewedAt),
    'reviewedByAdminId': reviewedByAdminId,
    'rejectionReason': rejectionReason,
  };

  WorkerDocument copyWith({
    WorkerDocumentStatus? status,
    String? fileUrl,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    DateTime? uploadedAt,
    DateTime? reviewedAt,
    String? reviewedByAdminId,
    String? rejectionReason,
  }) {
    return WorkerDocument(
      id: id,
      workerId: workerId,
      type: type,
      status: status ?? this.status,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedByAdminId: reviewedByAdminId ?? this.reviewedByAdminId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

const List<WorkerDocumentType> requiredWorkerDocumentTypes = [
  WorkerDocumentType.profilePhoto,
  WorkerDocumentType.governmentId,
  WorkerDocumentType.driverLicense,
  WorkerDocumentType.vehicleRegistration,
  WorkerDocumentType.vehiclePhoto,
];

WorkerDocumentsStatus documentsStatusFor(List<WorkerDocument> documents) {
  if (documents.isEmpty) return WorkerDocumentsStatus.incomplete;
  var hasPending = false;
  for (final type in requiredWorkerDocumentTypes) {
    final matches = documents.where((document) => document.type == type);
    if (matches.isEmpty) return WorkerDocumentsStatus.incomplete;
    final status = matches.first.status;
    if (status == WorkerDocumentStatus.rejected) {
      return WorkerDocumentsStatus.rejected;
    }
    if (status != WorkerDocumentStatus.approved) {
      hasPending = true;
    }
  }
  return hasPending
      ? WorkerDocumentsStatus.pendingReview
      : WorkerDocumentsStatus.approved;
}

extension WorkerReadiness on WorkerProfile {
  bool canGoOnline(List<WorkerDocument> documents) {
    return agreementAccepted &&
        payoutMethod.trim().isNotEmpty &&
        documentsStatusFor(documents) == WorkerDocumentsStatus.approved &&
        status == WorkerStatus.approved;
  }
}

class JobOffer {
  const JobOffer({
    required this.id,
    required this.customerId,
    required this.customerPhone,
    required this.customerName,
    required this.serviceType,
    required this.pickupLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLabel,
    required this.destinationLat,
    required this.destinationLng,
    required this.offerAmount,
    required this.paymentMethod,
    required this.status,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.assignedWorkerPhone,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.rejectedAt,
    this.gross,
    this.platformCommission,
    this.workerPayout,
    this.paymentStatus = 'manual',
    this.workerPayoutStatus = 'unpaid',
    this.workerPaidAt,
    this.ownerNet,
    this.payoutNote,
  });

  final String id;
  final String customerId;
  final String customerPhone;
  final String customerName;
  final BackendServiceType serviceType;
  final String pickupLabel;
  final double pickupLat;
  final double pickupLng;
  final String destinationLabel;
  final double destinationLat;
  final double destinationLng;
  final double offerAmount;
  final BackendPaymentMethod paymentMethod;
  final JobStatus status;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final String? assignedWorkerPhone;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? rejectedAt;
  final double? gross;
  final double? platformCommission;
  final double? workerPayout;
  final String paymentStatus;
  final String workerPayoutStatus;
  final DateTime? workerPaidAt;
  final double? ownerNet;
  final String? payoutNote;

  factory JobOffer.fromMap(String id, Map<String, Object?> data) {
    return JobOffer(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      serviceType: BackendServiceType.fromValue(data['serviceType']),
      pickupLabel: data['pickupLabel'] as String? ?? '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0,
      pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0,
      destinationLabel: data['destinationLabel'] as String? ?? '',
      destinationLat: (data['destinationLat'] as num?)?.toDouble() ?? 0,
      destinationLng: (data['destinationLng'] as num?)?.toDouble() ?? 0,
      offerAmount: (data['offerAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: BackendPaymentMethod.fromValue(data['paymentMethod']),
      status: JobStatus.fromValue(data['status']),
      assignedWorkerId: data['assignedWorkerId'] as String?,
      assignedWorkerName: data['assignedWorkerName'] as String?,
      assignedWorkerPhone: data['assignedWorkerPhone'] as String?,
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      acceptedAt: _dateFromValue(data['acceptedAt']),
      startedAt: _dateFromValue(data['startedAt']),
      completedAt: _dateFromValue(data['completedAt']),
      cancelledAt: _dateFromValue(data['cancelledAt']),
      rejectedAt: _dateFromValue(data['rejectedAt']),
      gross: (data['gross'] as num?)?.toDouble(),
      platformCommission: (data['platformCommission'] as num?)?.toDouble(),
      workerPayout: (data['workerPayout'] as num?)?.toDouble(),
      paymentStatus: data['paymentStatus'] as String? ?? 'manual',
      workerPayoutStatus: data['workerPayoutStatus'] as String? ?? 'unpaid',
      workerPaidAt: _dateFromValue(data['workerPaidAt']),
      ownerNet: (data['ownerNet'] as num?)?.toDouble(),
      payoutNote: data['payoutNote'] as String?,
    );
  }

  factory JobOffer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return JobOffer.fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  factory JobOffer.fromJson(Map<String, Object?> json) {
    return JobOffer.fromMap(json['id'] as String? ?? '', json);
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'customerPhone': customerPhone,
    'customerName': customerName,
    'serviceType': serviceType.name,
    'pickupLabel': pickupLabel,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'destinationLabel': destinationLabel,
    'destinationLat': destinationLat,
    'destinationLng': destinationLng,
    'offerAmount': offerAmount,
    'paymentMethod': paymentMethod.name,
    'status': status.name,
    'assignedWorkerId': assignedWorkerId,
    'assignedWorkerName': assignedWorkerName,
    'assignedWorkerPhone': assignedWorkerPhone,
    'createdAt': _dateToValue(createdAt),
    'acceptedAt': _dateToValue(acceptedAt),
    'startedAt': _dateToValue(startedAt),
    'completedAt': _dateToValue(completedAt),
    'cancelledAt': _dateToValue(cancelledAt),
    'rejectedAt': _dateToValue(rejectedAt),
    'gross': gross,
    'platformCommission': platformCommission,
    'workerPayout': workerPayout,
    'paymentStatus': paymentStatus,
    'workerPayoutStatus': workerPayoutStatus,
    'workerPaidAt': _dateToValue(workerPaidAt),
    'ownerNet': ownerNet,
    'payoutNote': payoutNote,
  };

  Map<String, Object?> toFirestore() => toMap();
  Map<String, Object?> toJson() => {'id': id, ...toMap()};

  JobOffer copyWith({
    String? id,
    String? customerId,
    String? customerPhone,
    String? customerName,
    BackendServiceType? serviceType,
    String? pickupLabel,
    double? pickupLat,
    double? pickupLng,
    String? destinationLabel,
    double? destinationLat,
    double? destinationLng,
    double? offerAmount,
    BackendPaymentMethod? paymentMethod,
    JobStatus? status,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? assignedWorkerPhone,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? rejectedAt,
    double? gross,
    double? platformCommission,
    double? workerPayout,
    String? paymentStatus,
    String? workerPayoutStatus,
    DateTime? workerPaidAt,
    double? ownerNet,
    String? payoutNote,
  }) {
    return JobOffer(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      serviceType: serviceType ?? this.serviceType,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      offerAmount: offerAmount ?? this.offerAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      assignedWorkerPhone: assignedWorkerPhone ?? this.assignedWorkerPhone,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      gross: gross ?? this.gross,
      platformCommission: platformCommission ?? this.platformCommission,
      workerPayout: workerPayout ?? this.workerPayout,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      workerPayoutStatus: workerPayoutStatus ?? this.workerPayoutStatus,
      workerPaidAt: workerPaidAt ?? this.workerPaidAt,
      ownerNet: ownerNet ?? this.ownerNet,
      payoutNote: payoutNote ?? this.payoutNote,
    );
  }
}

class ActiveJob {
  const ActiveJob({required this.job});

  final JobOffer job;

  String get id => job.id;
  String? get assignedWorkerId => job.assignedWorkerId;
}

class DriverLocation {
  const DriverLocation({
    required this.workerId,
    required this.workerName,
    required this.workerPhone,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    required this.isOnline,
    this.activeJobId,
    required this.updatedAt,
  });

  final String workerId;
  final String workerName;
  final String workerPhone;
  final double lat;
  final double lng;
  final double heading;
  final double speed;
  final bool isOnline;
  final String? activeJobId;
  final DateTime updatedAt;

  factory DriverLocation.fromMap(String workerId, Map<String, Object?> data) {
    return DriverLocation(
      workerId: workerId,
      workerName: data['workerName'] as String? ?? '',
      workerPhone: data['workerPhone'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      heading: (data['heading'] as num?)?.toDouble() ?? 0,
      speed: (data['speed'] as num?)?.toDouble() ?? 0,
      isOnline: data['isOnline'] as bool? ?? false,
      activeJobId: data['activeJobId'] as String?,
      updatedAt: _dateFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
    'workerName': workerName,
    'workerPhone': workerPhone,
    'lat': lat,
    'lng': lng,
    'heading': heading,
    'speed': speed,
    'isOnline': isOnline,
    'activeJobId': activeJobId,
    'updatedAt': _dateToValue(updatedAt),
  };

  factory DriverLocation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return DriverLocation.fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  factory DriverLocation.fromJson(Map<String, Object?> json) {
    return DriverLocation.fromMap(json['workerId'] as String? ?? '', json);
  }

  Map<String, Object?> toFirestore() => toMap();
  Map<String, Object?> toJson() => {'workerId': workerId, ...toMap()};

  DriverLocation copyWith({
    String? workerName,
    String? workerPhone,
    double? lat,
    double? lng,
    double? heading,
    double? speed,
    bool? isOnline,
    String? activeJobId,
    DateTime? updatedAt,
  }) {
    return DriverLocation(
      workerId: workerId,
      workerName: workerName ?? this.workerName,
      workerPhone: workerPhone ?? this.workerPhone,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      isOnline: isOnline ?? this.isOnline,
      activeJobId: activeJobId ?? this.activeJobId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String jobId;
  final String senderId;
  final AppRole senderRole;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ChatMessage.fromMap(String id, Map<String, Object?> data) {
    return ChatMessage(
      id: id,
      jobId: data['jobId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderRole: AppRole.fromValue(data['senderRole']),
      message: data['message'] as String? ?? '',
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      readAt: _dateFromValue(data['readAt']),
    );
  }

  Map<String, Object?> toMap() => {
    'jobId': jobId,
    'senderId': senderId,
    'senderRole': senderRole.name,
    'message': message,
    'createdAt': _dateToValue(createdAt),
    'readAt': _dateToValue(readAt),
  };
}

class RevenueSummary {
  const RevenueSummary({
    required this.grossRevenue,
    required this.platformCommission,
    required this.workerPayouts,
    required this.cashCollected,
    required this.cardCollected,
    required this.platformFeeOwed,
    this.dateRange = 'all',
  });

  final double grossRevenue;
  final double platformCommission;
  final double workerPayouts;
  final double cashCollected;
  final double cardCollected;
  final double platformFeeOwed;
  final String dateRange;

  double get gross => grossRevenue;
  double get workerPayout => workerPayouts;
}

class OwnerStats {
  const OwnerStats({
    required this.totalOffers,
    required this.pendingOffers,
    required this.activeJobs,
    required this.completedJobs,
    required this.rejectedJobs,
    required this.grossRevenue,
    required this.platformCommission,
    required this.workerPayouts,
    required this.cashCollected,
    required this.cardCollected,
    required this.platformFeeOwed,
    required this.dateRange,
    required this.onlineWorkers,
  });

  final int totalOffers;
  final int pendingOffers;
  final int activeJobs;
  final int completedJobs;
  final int rejectedJobs;
  final double grossRevenue;
  final double platformCommission;
  final double workerPayouts;
  final double cashCollected;
  final double cardCollected;
  final double platformFeeOwed;
  final String dateRange;
  final int onlineWorkers;

  int get totalJobs => totalOffers;
  int get pendingJobs => pendingOffers;
  RevenueSummary get revenue => RevenueSummary(
    grossRevenue: grossRevenue,
    platformCommission: platformCommission,
    workerPayouts: workerPayouts,
    cashCollected: cashCollected,
    cardCollected: cardCollected,
    platformFeeOwed: platformFeeOwed,
    dateRange: dateRange,
  );

  static OwnerStats fromJobs(
    List<JobOffer> jobs, {
    int onlineWorkers = 0,
    String dateRange = 'all',
  }) {
    var pending = 0;
    var active = 0;
    var completed = 0;
    var rejected = 0;
    var gross = 0.0;
    var commission = 0.0;
    var payout = 0.0;
    var cash = 0.0;
    var card = 0.0;

    for (final job in jobs) {
      switch (job.status) {
        case JobStatus.pending:
          pending++;
        case JobStatus.accepted:
        case JobStatus.active:
          active++;
        case JobStatus.completed:
          completed++;
        case JobStatus.rejected:
        case JobStatus.cancelled:
          rejected++;
      }

      if (job.status == JobStatus.accepted ||
          job.status == JobStatus.active ||
          job.status == JobStatus.completed) {
        final jobGross = job.gross ?? job.offerAmount;
        gross += jobGross;
        commission +=
            job.platformCommission ?? AppConfig.platformCommissionFor(jobGross);
        payout += job.workerPayout ?? AppConfig.workerPayoutFor(jobGross);
        if (job.paymentMethod == BackendPaymentMethod.cash) {
          cash += jobGross;
        } else {
          card += jobGross;
        }
      }
    }

    return OwnerStats(
      totalOffers: jobs.length,
      pendingOffers: pending,
      activeJobs: active,
      completedJobs: completed,
      rejectedJobs: rejected,
      grossRevenue: gross,
      platformCommission: commission,
      workerPayouts: payout,
      cashCollected: cash,
      cardCollected: card,
      platformFeeOwed: cash == 0 ? 0 : commission,
      dateRange: dateRange,
      onlineWorkers: onlineWorkers,
    );
  }
}

class MarketplaceStore {
  const MarketplaceStore({
    required this.id,
    this.ownerId = '',
    required this.name,
    this.description = '',
    this.phone = '',
    required this.category,
    required this.imageUrl,
    this.coverUrl = '',
    this.status = 'active',
    required this.rating,
    required this.isOpen,
    required this.lat,
    required this.lng,
    required this.address,
    required this.deliveryEstimateMinutes,
    this.categories = const [],
    this.deliveryAvailable = true,
    this.pickupAvailable = true,
    this.openingHours,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedByAdminId,
    this.rejectionReason,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String phone;
  final String category;
  final String imageUrl;
  final String coverUrl;
  final String status;
  final double rating;
  final bool isOpen;
  final double lat;
  final double lng;
  final String address;
  final int deliveryEstimateMinutes;
  final List<String> categories;
  final bool deliveryAvailable;
  final bool pickupAvailable;
  final String? openingHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedByAdminId;
  final String? rejectionReason;

  bool get isCustomerVisible {
    final normalized = status.trim().isEmpty ? 'active' : status;
    return name.trim().isNotEmpty &&
        normalized != 'rejected' &&
        normalized != 'suspended' &&
        normalized != 'paused';
  }

  bool get isCustomerOrderable => isCustomerVisible && isOpen;

  factory MarketplaceStore.fromMap(String id, Map<String, Object?> data) {
    final categoryList = _stringList(data['categories']);
    return MarketplaceStore(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['storeName'] as String? ?? data['name'] as String? ?? '',
      description:
          data['storeDescription'] as String? ??
          data['description'] as String? ??
          '',
      phone: data['storePhone'] as String? ?? data['phone'] as String? ?? '',
      category:
          data['category'] as String? ??
          (categoryList.isEmpty ? '' : categoryList.first),
      imageUrl:
          data['storeLogoUrl'] as String? ?? data['imageUrl'] as String? ?? '',
      coverUrl: data['storeCoverUrl'] as String? ?? '',
      status:
          data['storeStatus'] as String? ??
          data['status'] as String? ??
          'active',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      isOpen: data['isOpen'] as bool? ?? true,
      lat:
          (data['storeLat'] as num?)?.toDouble() ??
          (data['lat'] as num?)?.toDouble() ??
          0,
      lng:
          (data['storeLng'] as num?)?.toDouble() ??
          (data['lng'] as num?)?.toDouble() ??
          0,
      address:
          data['storeAddress'] as String? ?? data['address'] as String? ?? '',
      deliveryEstimateMinutes:
          (data['deliveryEstimateMinutes'] as num?)?.toInt() ?? 30,
      categories: _stringList(data['categories']),
      deliveryAvailable: data['deliveryAvailable'] as bool? ?? true,
      pickupAvailable: data['pickupAvailable'] as bool? ?? true,
      openingHours: data['openingHours'] as String?,
      createdAt: _dateFromValue(data['createdAt']),
      updatedAt: _dateFromValue(data['updatedAt']),
      approvedAt: _dateFromValue(data['approvedAt']),
      approvedByAdminId: data['approvedByAdminId'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  factory MarketplaceStore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return MarketplaceStore.fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'ownerId': ownerId,
    'storeName': name,
    'name': name,
    'storeDescription': description,
    'description': description,
    'storePhone': phone,
    'phone': phone,
    'category': category,
    'storeLogoUrl': imageUrl,
    'imageUrl': imageUrl,
    'storeCoverUrl': coverUrl,
    'storeStatus': status,
    'status': status,
    'rating': rating,
    'isOpen': isOpen,
    'storeLat': lat,
    'lat': lat,
    'storeLng': lng,
    'lng': lng,
    'storeAddress': address,
    'address': address,
    'deliveryEstimateMinutes': deliveryEstimateMinutes,
    'categories': categories,
    'deliveryAvailable': deliveryAvailable,
    'pickupAvailable': pickupAvailable,
    'openingHours': openingHours,
    'createdAt': _dateToValue(createdAt),
    'updatedAt': _dateToValue(updatedAt),
    'approvedAt': _dateToValue(approvedAt),
    'approvedByAdminId': approvedByAdminId,
    'rejectionReason': rejectionReason,
  };

  Map<String, Object?> toFirestore() => toMap();

  MarketplaceStore copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? phone,
    String? category,
    String? imageUrl,
    String? coverUrl,
    String? status,
    double? rating,
    bool? isOpen,
    double? lat,
    double? lng,
    String? address,
    int? deliveryEstimateMinutes,
    List<String>? categories,
    bool? deliveryAvailable,
    bool? pickupAvailable,
    String? openingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedByAdminId,
    String? rejectionReason,
  }) {
    return MarketplaceStore(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      isOpen: isOpen ?? this.isOpen,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      deliveryEstimateMinutes:
          deliveryEstimateMinutes ?? this.deliveryEstimateMinutes,
      categories: categories ?? this.categories,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
      pickupAvailable: pickupAvailable ?? this.pickupAvailable,
      openingHours: openingHours ?? this.openingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedByAdminId: approvedByAdminId ?? this.approvedByAdminId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.storeId,
    this.storeOwnerId = '',
    required this.name,
    required this.description,
    this.categoryId,
    required this.price,
    this.cost,
    required this.imageUrl,
    required this.category,
    this.stockQuantity = 10,
    this.lowStockThreshold = 2,
    required this.isAvailable,
    this.isVisibleToCustomers = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String storeId;
  final String storeOwnerId;
  final String name;
  final String description;
  final String? categoryId;
  final double price;
  final double? cost;
  final String imageUrl;
  final String category;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isAvailable;
  final bool isVisibleToCustomers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get stockStatus {
    if (stockQuantity <= 0) return 'out_of_stock';
    if (stockQuantity <= lowStockThreshold) return 'low_stock';
    return 'in_stock';
  }

  bool get canCustomerOrder =>
      isAvailable && isVisibleToCustomers && stockStatus != 'out_of_stock';

  factory MarketplaceProduct.fromMap(String id, Map<String, Object?> data) {
    return MarketplaceProduct(
      id: id,
      storeId: data['storeId'] as String? ?? '',
      storeOwnerId: data['storeOwnerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      cost: (data['cost'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'] as String? ?? '',
      category:
          data['categoryName'] as String? ?? data['category'] as String? ?? '',
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 10,
      lowStockThreshold: (data['lowStockThreshold'] as num?)?.toInt() ?? 2,
      isAvailable: data['isAvailable'] as bool? ?? true,
      isVisibleToCustomers: data['isVisibleToCustomers'] as bool? ?? true,
      createdAt: _dateFromValue(data['createdAt']),
      updatedAt: _dateFromValue(data['updatedAt']),
    );
  }

  factory MarketplaceProduct.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return MarketplaceProduct.fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'storeId': storeId,
    'storeOwnerId': storeOwnerId,
    'name': name,
    'description': description,
    'categoryId': categoryId,
    'categoryName': category,
    'price': price,
    'cost': cost,
    'imageUrl': imageUrl,
    'category': category,
    'stockQuantity': stockQuantity,
    'lowStockThreshold': lowStockThreshold,
    'stockStatus': stockStatus,
    'isAvailable': isAvailable,
    'isVisibleToCustomers': isVisibleToCustomers,
    'createdAt': _dateToValue(createdAt),
    'updatedAt': _dateToValue(updatedAt),
  };

  Map<String, Object?> toFirestore() => toMap();

  MarketplaceProduct copyWith({
    String? id,
    String? storeId,
    String? storeOwnerId,
    String? name,
    String? description,
    String? categoryId,
    double? price,
    double? cost,
    String? imageUrl,
    String? category,
    int? stockQuantity,
    int? lowStockThreshold,
    bool? isAvailable,
    bool? isVisibleToCustomers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MarketplaceProduct(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      storeOwnerId: storeOwnerId ?? this.storeOwnerId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isAvailable: isAvailable ?? this.isAvailable,
      isVisibleToCustomers: isVisibleToCustomers ?? this.isVisibleToCustomers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MarketplaceCartItem {
  const MarketplaceCartItem({
    required this.productId,
    required this.storeId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.productImageUrl,
  });

  final String productId;
  final String storeId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? productImageUrl;

  double get total => unitPrice * quantity;

  factory MarketplaceCartItem.fromMap(Map<String, Object?> data) {
    return MarketplaceCartItem(
      productId: data['productId'] as String? ?? '',
      storeId: data['storeId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      productImageUrl: data['productImageUrl'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'productId': productId,
    'storeId': storeId,
    'productName': productName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'total': total,
    'productImageUrl': productImageUrl,
  };

  MarketplaceCartItem copyWith({int? quantity}) {
    return MarketplaceCartItem(
      productId: productId,
      storeId: storeId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      productImageUrl: productImageUrl,
    );
  }
}

class MarketplaceOrder {
  const MarketplaceOrder({
    required this.id,
    required this.customerId,
    required this.customerPhone,
    required this.storeId,
    required this.storeName,
    this.storeAddress = '',
    this.storeLat = 0,
    this.storeLng = 0,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    required this.deliveryLabel,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.status,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.assignedWorkerPhone,
    required this.createdAt,
    this.acceptedAt,
    this.deliveredAt,
    this.gross,
    this.platformCommission,
    this.workerPayout,
    this.paymentStatus = 'manual',
    this.workerPayoutStatus = 'unpaid',
    this.workerPaidAt,
    this.ownerNet,
    this.payoutNote,
    this.inventoryDeducted = false,
    this.inventoryRestored = false,
    this.inventoryRestoredAt,
  });

  final String id;
  final String customerId;
  final String customerPhone;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final double storeLat;
  final double storeLng;
  final List<MarketplaceCartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final BackendPaymentMethod paymentMethod;
  final String deliveryLabel;
  final double deliveryLat;
  final double deliveryLng;
  final MarketplaceOrderStatus status;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final String? assignedWorkerPhone;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final double? gross;
  final double? platformCommission;
  final double? workerPayout;
  final String paymentStatus;
  final String workerPayoutStatus;
  final DateTime? workerPaidAt;
  final double? ownerNet;
  final String? payoutNote;
  final bool inventoryDeducted;
  final bool inventoryRestored;
  final DateTime? inventoryRestoredAt;

  int get itemCount => items.fold(0, (total, item) => total + item.quantity);

  factory MarketplaceOrder.fromMap(String id, Map<String, Object?> data) {
    final rawItems = data['items'];
    return MarketplaceOrder(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      storeId: data['storeId'] as String? ?? '',
      storeName: data['storeName'] as String? ?? '',
      storeAddress: data['storeAddress'] as String? ?? '',
      storeLat: (data['storeLat'] as num?)?.toDouble() ?? 0,
      storeLng: (data['storeLng'] as num?)?.toDouble() ?? 0,
      items: rawItems is Iterable
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      MarketplaceCartItem.fromMap(item.cast<String, Object?>()),
                )
                .toList()
          : const [],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: BackendPaymentMethod.fromValue(data['paymentMethod']),
      deliveryLabel: data['deliveryLabel'] as String? ?? '',
      deliveryLat: (data['deliveryLat'] as num?)?.toDouble() ?? 0,
      deliveryLng: (data['deliveryLng'] as num?)?.toDouble() ?? 0,
      status: MarketplaceOrderStatus.fromValue(data['status']),
      assignedWorkerId: data['assignedWorkerId'] as String?,
      assignedWorkerName: data['assignedWorkerName'] as String?,
      assignedWorkerPhone: data['assignedWorkerPhone'] as String?,
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      acceptedAt: _dateFromValue(data['acceptedAt']),
      deliveredAt: _dateFromValue(data['deliveredAt']),
      gross: (data['gross'] as num?)?.toDouble(),
      platformCommission: (data['platformCommission'] as num?)?.toDouble(),
      workerPayout: (data['workerPayout'] as num?)?.toDouble(),
      paymentStatus: data['paymentStatus'] as String? ?? 'manual',
      workerPayoutStatus: data['workerPayoutStatus'] as String? ?? 'unpaid',
      workerPaidAt: _dateFromValue(data['workerPaidAt']),
      ownerNet: (data['ownerNet'] as num?)?.toDouble(),
      payoutNote: data['payoutNote'] as String?,
      inventoryDeducted: data['inventoryDeducted'] as bool? ?? false,
      inventoryRestored: data['inventoryRestored'] as bool? ?? false,
      inventoryRestoredAt: _dateFromValue(data['inventoryRestoredAt']),
    );
  }

  factory MarketplaceOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return MarketplaceOrder.fromMap(snapshot.id, snapshot.data() ?? const {});
  }

  Map<String, Object?> toMap() => {
    'customerId': customerId,
    'customerPhone': customerPhone,
    'storeId': storeId,
    'storeName': storeName,
    'storeAddress': storeAddress,
    'storeLat': storeLat,
    'storeLng': storeLng,
    'items': items.map((item) => item.toMap()).toList(),
    'itemCount': itemCount,
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'total': total,
    'paymentMethod': paymentMethod.name,
    'deliveryLabel': deliveryLabel,
    'deliveryLat': deliveryLat,
    'deliveryLng': deliveryLng,
    'status': status.name,
    'assignedWorkerId': assignedWorkerId,
    'assignedWorkerName': assignedWorkerName,
    'assignedWorkerPhone': assignedWorkerPhone,
    'createdAt': _dateToValue(createdAt),
    'acceptedAt': _dateToValue(acceptedAt),
    'deliveredAt': _dateToValue(deliveredAt),
    'gross': gross,
    'platformCommission': platformCommission,
    'workerPayout': workerPayout,
    'paymentStatus': paymentStatus,
    'workerPayoutStatus': workerPayoutStatus,
    'workerPaidAt': _dateToValue(workerPaidAt),
    'ownerNet': ownerNet,
    'payoutNote': payoutNote,
    'inventoryDeducted': inventoryDeducted,
    'inventoryRestored': inventoryRestored,
    'inventoryRestoredAt': _dateToValue(inventoryRestoredAt),
  };

  Map<String, Object?> toFirestore() => toMap();

  MarketplaceOrder copyWith({
    String? id,
    MarketplaceOrderStatus? status,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? assignedWorkerPhone,
    DateTime? acceptedAt,
    DateTime? deliveredAt,
    double? gross,
    double? platformCommission,
    double? workerPayout,
    String? paymentStatus,
    String? workerPayoutStatus,
    DateTime? workerPaidAt,
    double? ownerNet,
    String? payoutNote,
    bool? inventoryDeducted,
    bool? inventoryRestored,
    DateTime? inventoryRestoredAt,
  }) {
    return MarketplaceOrder(
      id: id ?? this.id,
      customerId: customerId,
      customerPhone: customerPhone,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      storeLat: storeLat,
      storeLng: storeLng,
      items: items,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      paymentMethod: paymentMethod,
      deliveryLabel: deliveryLabel,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      status: status ?? this.status,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      assignedWorkerPhone: assignedWorkerPhone ?? this.assignedWorkerPhone,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      gross: gross ?? this.gross,
      platformCommission: platformCommission ?? this.platformCommission,
      workerPayout: workerPayout ?? this.workerPayout,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      workerPayoutStatus: workerPayoutStatus ?? this.workerPayoutStatus,
      workerPaidAt: workerPaidAt ?? this.workerPaidAt,
      ownerNet: ownerNet ?? this.ownerNet,
      payoutNote: payoutNote ?? this.payoutNote,
      inventoryDeducted: inventoryDeducted ?? this.inventoryDeducted,
      inventoryRestored: inventoryRestored ?? this.inventoryRestored,
      inventoryRestoredAt: inventoryRestoredAt ?? this.inventoryRestoredAt,
    );
  }
}
