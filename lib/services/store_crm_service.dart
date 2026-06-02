import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/backend_models.dart';
import '../models/store_crm_models.dart';
import 'firebase_service.dart';
import 'marketplace_service.dart';
import 'notification_service.dart';

class StoreCrmService {
  StoreCrmService({
    FirebaseService? firebaseService,
    NotificationService? notificationService,
  }) : _firebaseService = firebaseService ?? FirebaseService.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseService _firebaseService;
  final NotificationService _notificationService;

  static const storesCollection = 'stores';
  static const productsCollection = 'products';
  static const categoriesCollection = 'productCategories';
  static const expensesCollection = 'storeExpenses';

  CollectionReference<Map<String, dynamic>> get _stores =>
      _firebaseService.firestore.collection(storesCollection);
  CollectionReference<Map<String, dynamic>> get _products =>
      _firebaseService.firestore.collection(productsCollection);
  CollectionReference<Map<String, dynamic>> get _categories =>
      _firebaseService.firestore.collection(categoriesCollection);
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firebaseService.firestore.collection(expensesCollection);

  static final List<MarketplaceStore> _localStores = [];
  static final List<MarketplaceProduct> _localProducts = [];
  static final List<ProductCategory> _localCategories = [];
  static final List<StoreExpense> _localExpenses = [];
  static final StreamController<List<MarketplaceStore>> _localStoresController =
      StreamController<List<MarketplaceStore>>.broadcast();
  static final StreamController<List<MarketplaceProduct>>
  _localProductsController =
      StreamController<List<MarketplaceProduct>>.broadcast();
  static final StreamController<List<ProductCategory>>
  _localCategoriesController =
      StreamController<List<ProductCategory>>.broadcast();
  static final StreamController<List<StoreExpense>> _localExpensesController =
      StreamController<List<StoreExpense>>.broadcast();

  Stream<List<T>> _localStream<T>(
    List<T> current,
    StreamController<List<T>> controller,
  ) async* {
    yield List<T>.of(current);
    yield* controller.stream;
  }

  void _emitLocalStores() {
    _localStoresController.add(List<MarketplaceStore>.of(_localStores));
  }

  void _emitLocalProducts() {
    _localProductsController.add(List<MarketplaceProduct>.of(_localProducts));
  }

  void _emitLocalCategories() {
    _localCategoriesController.add(List<ProductCategory>.of(_localCategories));
  }

  void _emitLocalExpenses() {
    _localExpensesController.add(List<StoreExpense>.of(_localExpenses));
  }

  Stream<List<MarketplaceStore>> watchStoresForOwner(String ownerId) {
    if (!_firebaseService.isReady) {
      final local = _localStores
          .where((store) => store.ownerId == ownerId)
          .toList();
      return _localStream<MarketplaceStore>(local, _localStoresController).map(
        (stores) => stores.where((store) => store.ownerId == ownerId).toList(),
      );
    }
    return _stores
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(MarketplaceStore.fromFirestore).toList(),
        );
  }

  Stream<List<MarketplaceStore>> watchAllStores() {
    if (!_firebaseService.isReady) {
      return Stream.value(MarketplaceService.sampleStores);
    }
    return _stores
        .orderBy('storeName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(MarketplaceStore.fromFirestore).toList(),
        );
  }

  Future<String?> upsertStore(MarketplaceStore store) async {
    if (!_firebaseService.isReady) {
      final id = store.id.isEmpty
          ? 'local-store-${DateTime.now().millisecondsSinceEpoch}'
          : store.id;
      final saved = store.copyWith(id: id, updatedAt: DateTime.now());
      final index = _localStores.indexWhere((entry) => entry.id == id);
      if (index == -1) {
        _localStores.insert(0, saved);
      } else {
        _localStores[index] = saved;
      }
      final marketplaceIndex = MarketplaceService.localMarketplaceStores
          .indexWhere((entry) => entry.id == id);
      if (marketplaceIndex == -1) {
        MarketplaceService.localMarketplaceStores.insert(0, saved);
      } else {
        MarketplaceService.localMarketplaceStores[marketplaceIndex] = saved;
      }
      _emitLocalStores();
      return id;
    }
    final now = DateTime.now();
    final currentUid = _firebaseService.auth.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'No authenticated user is available for store profile save.',
      );
    }
    final ownedStore = store.copyWith(ownerId: currentUid);
    final ref = store.id.isEmpty ? _stores.doc() : _stores.doc(store.id);
    final status = ownedStore.status == 'pending_approval'
        ? 'active'
        : ownedStore.status;
    await ref.set({
      ...ownedStore
          .copyWith(
            id: ref.id,
            status: status,
            updatedAt: now,
            createdAt: ownedStore.createdAt ?? now,
          )
          .toMap(),
      'storeStatus': status,
      'status': status,
      'createdAt': ownedStore.createdAt == null
          ? FieldValue.serverTimestamp()
          : ownedStore.toMap()['createdAt'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _notificationService.create(
      type: 'store_profile_updated',
      title: 'Store profile saved',
      message:
          '${ownedStore.name.isEmpty ? 'Store' : ownedStore.name} profile was saved.',
      userId: ownedStore.ownerId,
      roleTarget: 'store_owner',
      relatedId: ref.id,
      relatedCollection: storesCollection,
      data: {'storeId': ref.id},
    );
    return ref.id;
  }

  Future<void> setStoreOpen(String storeId, bool isOpen) async {
    if (!_firebaseService.isReady) {
      final index = _localStores.indexWhere((store) => store.id == storeId);
      if (index != -1) {
        _localStores[index] = _localStores[index].copyWith(isOpen: isOpen);
        final marketplaceIndex = MarketplaceService.localMarketplaceStores
            .indexWhere((store) => store.id == storeId);
        if (marketplaceIndex != -1) {
          MarketplaceService.localMarketplaceStores[marketplaceIndex] =
              MarketplaceService.localMarketplaceStores[marketplaceIndex]
                  .copyWith(isOpen: isOpen);
        }
        _emitLocalStores();
      }
      return;
    }
    await _stores.doc(storeId).set({
      'isOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final storeSnapshot = await _stores.doc(storeId).get();
    final store = MarketplaceStore.fromMap(
      storeSnapshot.id,
      storeSnapshot.data() ?? const <String, Object?>{},
    );
    await _notificationService.create(
      type: 'store_open_status_updated',
      title: isOpen ? 'Store opened' : 'Store closed',
      message:
          '${store.name.isEmpty ? 'Store' : store.name} is now ${isOpen ? 'open' : 'closed'}.',
      userId: store.ownerId,
      roleTarget: 'store_owner',
      relatedId: storeId,
      relatedCollection: storesCollection,
      data: {'storeId': storeId, 'isOpen': isOpen},
    );
  }

  Future<void> updateStoreStatus({
    required String storeId,
    required String status,
    String? adminId,
    String? rejectionReason,
  }) async {
    if (!_firebaseService.isReady) return;
    final storeSnapshot = await _stores.doc(storeId).get();
    final store = MarketplaceStore.fromMap(
      storeSnapshot.id,
      storeSnapshot.data() ?? const <String, Object?>{},
    );
    await _stores.doc(storeId).set({
      'storeStatus': status,
      'status': status,
      'rejectionReason': rejectionReason,
      if (status == 'active') ...{
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedByAdminId': adminId,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _notificationService.create(
      type: 'store_status_updated',
      title: 'Store status updated',
      message: 'Store status changed to $status.',
      userId: store.ownerId.isEmpty ? null : store.ownerId,
      roleTarget: 'store_owner',
      relatedId: storeId,
      relatedCollection: storesCollection,
      data: {'storeId': storeId, 'status': status},
    );
    await _notificationService.create(
      type: 'owner_store_status_updated',
      title: 'Store status updated',
      message:
          '${store.name.isEmpty ? 'A store' : store.name} changed to $status.',
      roleTarget: 'owner',
      relatedId: storeId,
      relatedCollection: storesCollection,
      data: {'storeId': storeId, 'status': status},
    );
  }

  Stream<List<ProductCategory>> watchCategories(String storeId) {
    if (!_firebaseService.isReady) {
      return _localStream<ProductCategory>(
        _localCategories
            .where((category) => category.storeId == storeId)
            .toList(),
        _localCategoriesController,
      ).map(
        (categories) => categories
            .where((category) => category.storeId == storeId)
            .toList(),
      );
    }
    return _categories
        .where('storeId', isEqualTo: storeId)
        .orderBy('sortOrder')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductCategory.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String?> upsertCategory(ProductCategory category) async {
    if (!_firebaseService.isReady) {
      final id = category.id.isEmpty
          ? 'local-category-${DateTime.now().millisecondsSinceEpoch}'
          : category.id;
      final saved = ProductCategory(
        id: id,
        storeId: category.storeId,
        name: category.name,
        description: category.description,
        sortOrder: category.sortOrder,
        isActive: category.isActive,
        createdAt: category.createdAt,
        updatedAt: DateTime.now(),
      );
      final index = _localCategories.indexWhere((entry) => entry.id == id);
      if (index == -1) {
        _localCategories.insert(0, saved);
      } else {
        _localCategories[index] = saved;
      }
      _emitLocalCategories();
      return id;
    }
    final ref = category.id.isEmpty
        ? _categories.doc()
        : _categories.doc(category.id);
    await ref.set({
      ...category.toMap(),
      'createdAt': category.id.isEmpty
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(category.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Stream<List<MarketplaceProduct>> watchProducts(String storeId) {
    if (!_firebaseService.isReady) {
      return MarketplaceService.watchLocalProductsByStore(storeId);
    }
    return _products
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(MarketplaceProduct.fromFirestore).toList(),
        );
  }

  Stream<List<MarketplaceProduct>> watchAllProducts() {
    if (!_firebaseService.isReady) {
      return Stream.value(
        MarketplaceService.sampleStores
            .expand(
              (store) => MarketplaceService.sampleProductsForStore(store.id),
            )
            .toList(),
      );
    }
    return _products.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(MarketplaceProduct.fromFirestore).toList(),
    );
  }

  Future<String?> upsertProduct(MarketplaceProduct product) async {
    if (!_firebaseService.isReady) {
      final id = product.id.isEmpty
          ? 'local-product-${DateTime.now().millisecondsSinceEpoch}'
          : product.id;
      final normalized = product.copyWith(
        id: id,
        isAvailable: product.stockQuantity <= 0 ? false : product.isAvailable,
        createdAt: product.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final index = _localProducts.indexWhere((entry) => entry.id == id);
      if (index == -1) {
        _localProducts.insert(0, normalized);
      } else {
        _localProducts[index] = normalized;
      }
      MarketplaceService.syncLocalProduct(normalized);
      _emitLocalProducts();
      return id;
    }
    final ref = product.id.isEmpty
        ? _products.doc()
        : _products.doc(product.id);
    final normalized = product.copyWith(
      id: ref.id,
      isAvailable: product.stockQuantity <= 0 ? false : product.isAvailable,
      updatedAt: DateTime.now(),
      createdAt: product.createdAt ?? DateTime.now(),
    );
    await ref.set({
      ...normalized.toMap(),
      'createdAt': product.id.isEmpty
          ? FieldValue.serverTimestamp()
          : product.toMap()['createdAt'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (normalized.stockStatus == 'low_stock') {
      await _notificationService.create(
        type: 'product_low_stock',
        title: 'Low stock',
        message: '${normalized.name} is low on stock.',
        userId: normalized.storeOwnerId,
        roleTarget: 'store_owner',
        relatedId: ref.id,
        relatedCollection: productsCollection,
        data: {'productId': ref.id, 'storeId': normalized.storeId},
      );
      await _notificationService.create(
        type: 'owner_product_low_stock',
        title: 'Low-stock product',
        message: '${normalized.name} is low on stock.',
        roleTarget: 'owner',
        relatedId: ref.id,
        relatedCollection: productsCollection,
        data: {'productId': ref.id, 'storeId': normalized.storeId},
      );
    }
    if (normalized.stockStatus == 'out_of_stock') {
      await _notificationService.create(
        type: 'product_out_of_stock',
        title: 'Out of stock',
        message: '${normalized.name} is out of stock.',
        userId: normalized.storeOwnerId,
        roleTarget: 'store_owner',
        relatedId: ref.id,
        relatedCollection: productsCollection,
        data: {'productId': ref.id, 'storeId': normalized.storeId},
      );
      await _notificationService.create(
        type: 'owner_product_out_of_stock',
        title: 'Out-of-stock product',
        message: '${normalized.name} is out of stock.',
        roleTarget: 'owner',
        relatedId: ref.id,
        relatedCollection: productsCollection,
        data: {'productId': ref.id, 'storeId': normalized.storeId},
      );
    }
    return ref.id;
  }

  Stream<List<MarketplaceOrder>> watchOrders(String storeId) {
    if (!_firebaseService.isReady) {
      return Stream.value(
        MarketplaceService.localMarketplaceOrders
            .where((order) => order.storeId == storeId)
            .toList(),
      );
    }
    return _firebaseService.firestore
        .collection(MarketplaceService.ordersCollection)
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(MarketplaceOrder.fromFirestore).toList(),
        );
  }

  Future<void> updateOrderStatus(
    String orderId,
    MarketplaceOrderStatus status,
  ) async {
    await MarketplaceService(
      firebaseService: _firebaseService,
    ).updateMarketplaceOrderStatus(orderId, status);
    final type = switch (status) {
      MarketplaceOrderStatus.accepted => 'store_order_accepted',
      MarketplaceOrderStatus.cancelled => 'store_order_rejected',
      MarketplaceOrderStatus.shopping => 'store_order_preparing',
      MarketplaceOrderStatus.pickedUp => 'store_order_ready',
      MarketplaceOrderStatus.delivered => 'store_order_completed',
      _ => 'store_order_updated',
    };
    await _notificationService.create(
      type: type,
      title: 'Marketplace order updated',
      message: 'Marketplace order status is ${status.name}.',
      roleTarget: 'store_owner',
      relatedId: orderId,
      relatedCollection: MarketplaceService.ordersCollection,
      data: {'orderId': orderId, 'status': status.name},
    );
    await _notificationService.create(
      type: 'owner_marketplace_order_updated',
      title: 'Marketplace order updated',
      message: 'A marketplace order status changed to ${status.name}.',
      roleTarget: 'owner',
      relatedId: orderId,
      relatedCollection: MarketplaceService.ordersCollection,
      data: {'orderId': orderId, 'status': status.name},
    );
  }

  Stream<List<StoreExpense>> watchExpenses(String storeId) {
    if (!_firebaseService.isReady) {
      return _localStream<StoreExpense>(
        _localExpenses.where((expense) => expense.storeId == storeId).toList(),
        _localExpensesController,
      ).map(
        (expenses) =>
            expenses.where((expense) => expense.storeId == storeId).toList(),
      );
    }
    return _expenses
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StoreExpense.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String?> addExpense(StoreExpense expense) async {
    if (!_firebaseService.isReady) {
      final id = expense.id.isEmpty
          ? 'local-expense-${DateTime.now().millisecondsSinceEpoch}'
          : expense.id;
      final saved = StoreExpense(
        id: id,
        storeId: expense.storeId,
        title: expense.title,
        amount: expense.amount,
        category: expense.category,
        notes: expense.notes,
        createdAt: expense.createdAt,
        updatedAt: DateTime.now(),
      );
      final index = _localExpenses.indexWhere((entry) => entry.id == id);
      if (index == -1) {
        _localExpenses.insert(0, saved);
      } else {
        _localExpenses[index] = saved;
      }
      _emitLocalExpenses();
      return id;
    }
    final ref = expense.id.isEmpty
        ? _expenses.doc()
        : _expenses.doc(expense.id);
    await ref.set({
      ...expense.toMap(),
      'createdAt': expense.id.isEmpty
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(expense.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteExpense(String expenseId) async {
    if (!_firebaseService.isReady) {
      _localExpenses.removeWhere((expense) => expense.id == expenseId);
      _emitLocalExpenses();
      return;
    }
    await _expenses.doc(expenseId).delete();
  }

  StoreMoneySnapshot moneySnapshot({
    required List<MarketplaceOrder> orders,
    required List<MarketplaceProduct> products,
    required List<StoreExpense> expenses,
  }) {
    final now = DateTime.now();
    var todaySales = 0.0;
    var totalSales = 0.0;
    var completedOrders = 0;
    var estimatedCosts = 0.0;
    final costsByProduct = {
      for (final product in products) product.id: product.cost ?? 0,
    };
    for (final order in orders) {
      final completed = order.status == MarketplaceOrderStatus.delivered;
      if (!completed) continue;
      completedOrders++;
      totalSales += order.total;
      if (order.createdAt.year == now.year &&
          order.createdAt.month == now.month &&
          order.createdAt.day == now.day) {
        todaySales += order.total;
      }
      for (final item in order.items) {
        estimatedCosts += (costsByProduct[item.productId] ?? 0) * item.quantity;
      }
    }
    final expenseTotal = expenses.fold(
      0.0,
      (runningTotal, item) => runningTotal + item.amount,
    );
    return StoreMoneySnapshot(
      todaySales: todaySales,
      totalSales: totalSales,
      expenses: expenseTotal,
      estimatedProductCosts: estimatedCosts,
      completedOrders: completedOrders,
    );
  }
}
