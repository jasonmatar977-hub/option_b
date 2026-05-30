import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _storeCrmDateFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Object? _storeCrmDateToValue(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String storeId;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductCategory.fromMap(String id, Map<String, Object?> data) {
    final now = DateTime.now();
    return ProductCategory(
      id: id,
      storeId: data['storeId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _storeCrmDateFromValue(data['createdAt']) ?? now,
      updatedAt: _storeCrmDateFromValue(data['updatedAt']) ?? now,
    );
  }

  Map<String, Object?> toMap() => {
    'storeId': storeId,
    'name': name,
    'description': description,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'createdAt': _storeCrmDateToValue(createdAt),
    'updatedAt': _storeCrmDateToValue(updatedAt),
  };
}

class StoreExpense {
  const StoreExpense({
    required this.id,
    required this.storeId,
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String storeId;
  final String title;
  final double amount;
  final String category;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StoreExpense.fromMap(String id, Map<String, Object?> data) {
    final now = DateTime.now();
    return StoreExpense(
      id: id,
      storeId: data['storeId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'General',
      notes: data['notes'] as String?,
      createdAt: _storeCrmDateFromValue(data['createdAt']) ?? now,
      updatedAt: _storeCrmDateFromValue(data['updatedAt']) ?? now,
    );
  }

  Map<String, Object?> toMap() => {
    'storeId': storeId,
    'title': title,
    'amount': amount,
    'category': category,
    'notes': notes,
    'createdAt': _storeCrmDateToValue(createdAt),
    'updatedAt': _storeCrmDateToValue(updatedAt),
  };
}

class StoreMoneySnapshot {
  const StoreMoneySnapshot({
    required this.todaySales,
    required this.totalSales,
    required this.expenses,
    required this.estimatedProductCosts,
    required this.completedOrders,
  });

  final double todaySales;
  final double totalSales;
  final double expenses;
  final double estimatedProductCosts;
  final int completedOrders;

  double get estimatedProfit => totalSales - estimatedProductCosts - expenses;
}
