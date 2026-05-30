import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _requestDateFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Object? _requestDateToValue(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

List<String> _requestStringList(Object? value) {
  if (value is Iterable) return value.whereType<String>().toList();
  return const [];
}

enum ServiceRequestStatus {
  requested,
  accepted,
  workerOnWay,
  arrived,
  inProgress,
  pickupStarted,
  pickedUp,
  deliveryStarted,
  onTheWay,
  delivered,
  completed,
  canceled;

  String get firestoreValue => switch (this) {
    ServiceRequestStatus.workerOnWay => 'worker_on_way',
    ServiceRequestStatus.inProgress => 'in_progress',
    ServiceRequestStatus.pickupStarted => 'pickup_started',
    ServiceRequestStatus.pickedUp => 'picked_up',
    ServiceRequestStatus.deliveryStarted => 'delivery_started',
    ServiceRequestStatus.onTheWay => 'on_the_way',
    _ => name,
  };

  static ServiceRequestStatus fromValue(Object? value) {
    return switch (value) {
      'worker_on_way' => ServiceRequestStatus.workerOnWay,
      'in_progress' => ServiceRequestStatus.inProgress,
      'pickup_started' => ServiceRequestStatus.pickupStarted,
      'picked_up' => ServiceRequestStatus.pickedUp,
      'delivery_started' => ServiceRequestStatus.deliveryStarted,
      'on_the_way' => ServiceRequestStatus.onTheWay,
      _ => ServiceRequestStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ServiceRequestStatus.requested,
      ),
    };
  }
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.serviceType,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    required this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.packageDetails,
    this.notes,
    required this.status,
    this.totalAmount,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.assignedWorkerPhone,
    this.rejectedWorkerIds = const [],
    this.acceptedAt,
    this.completedAt,
    this.canceledAt,
    required this.createdAt,
    required this.updatedAt,
    this.storeId,
    this.storeName,
    this.marketplaceOrderId,
  });

  final String id;
  final String serviceType;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? packageDetails;
  final String? notes;
  final ServiceRequestStatus status;
  final double? totalAmount;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final String? assignedWorkerPhone;
  final List<String> rejectedWorkerIds;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? storeId;
  final String? storeName;
  final String? marketplaceOrderId;

  bool get isAssigned => assignedWorkerId?.trim().isNotEmpty == true;
  bool get isOpen => status == ServiceRequestStatus.requested && !isAssigned;
  bool get isDone =>
      status == ServiceRequestStatus.completed ||
      status == ServiceRequestStatus.canceled;

  factory ServiceRequest.fromMap(String id, Map<String, Object?> data) {
    final now = DateTime.now();
    return ServiceRequest(
      id: id,
      serviceType: data['serviceType'] as String? ?? 'ride',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      pickupAddress: data['pickupAddress'] as String? ?? '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      dropoffAddress: data['dropoffAddress'] as String? ?? '',
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble(),
      packageDetails: data['packageDetails'] as String?,
      notes: data['notes'] as String?,
      status: ServiceRequestStatus.fromValue(data['status']),
      totalAmount: (data['totalAmount'] as num?)?.toDouble(),
      assignedWorkerId: data['assignedWorkerId'] as String?,
      assignedWorkerName: data['assignedWorkerName'] as String?,
      assignedWorkerPhone: data['assignedWorkerPhone'] as String?,
      rejectedWorkerIds: _requestStringList(data['rejectedWorkerIds']),
      acceptedAt: _requestDateFromValue(data['acceptedAt']),
      completedAt: _requestDateFromValue(data['completedAt']),
      canceledAt: _requestDateFromValue(data['canceledAt']),
      createdAt: _requestDateFromValue(data['createdAt']) ?? now,
      updatedAt: _requestDateFromValue(data['updatedAt']) ?? now,
      storeId: data['storeId'] as String?,
      storeName: data['storeName'] as String?,
      marketplaceOrderId: data['marketplaceOrderId'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'serviceType': serviceType,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'pickupAddress': pickupAddress,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'dropoffAddress': dropoffAddress,
    'dropoffLat': dropoffLat,
    'dropoffLng': dropoffLng,
    'packageDetails': packageDetails,
    'notes': notes,
    'status': status.firestoreValue,
    'totalAmount': totalAmount,
    'assignedWorkerId': assignedWorkerId,
    'assignedWorkerName': assignedWorkerName,
    'assignedWorkerPhone': assignedWorkerPhone,
    'rejectedWorkerIds': rejectedWorkerIds,
    'acceptedAt': _requestDateToValue(acceptedAt),
    'completedAt': _requestDateToValue(completedAt),
    'canceledAt': _requestDateToValue(canceledAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'storeId': storeId,
    'storeName': storeName,
    'marketplaceOrderId': marketplaceOrderId,
  };

  ServiceRequest copyWith({
    String? id,
    String? serviceType,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
    String? packageDetails,
    String? notes,
    ServiceRequestStatus? status,
    double? totalAmount,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? assignedWorkerPhone,
    List<String>? rejectedWorkerIds,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? canceledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? storeId,
    String? storeName,
    String? marketplaceOrderId,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      serviceType: serviceType ?? this.serviceType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      packageDetails: packageDetails ?? this.packageDetails,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      assignedWorkerPhone: assignedWorkerPhone ?? this.assignedWorkerPhone,
      rejectedWorkerIds: rejectedWorkerIds ?? this.rejectedWorkerIds,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      canceledAt: canceledAt ?? this.canceledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      marketplaceOrderId: marketplaceOrderId ?? this.marketplaceOrderId,
    );
  }
}
