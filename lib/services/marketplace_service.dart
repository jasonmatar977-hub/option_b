import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/backend_models.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class MarketplaceService {
  MarketplaceService({
    FirebaseService? firebaseService,
    NotificationService? notificationService,
  }) : _firebaseService = firebaseService ?? FirebaseService.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseService _firebaseService;
  final NotificationService _notificationService;

  static const storesCollection = 'stores';
  static const productsCollection = 'products';
  static const ordersCollection = 'marketplaceOrders';
  static final List<MarketplaceStore> localMarketplaceStores = [];
  static final List<MarketplaceProduct> localMarketplaceProducts = [];
  static final StreamController<List<MarketplaceProduct>>
  _localProductsController =
      StreamController<List<MarketplaceProduct>>.broadcast();

  static void syncLocalProduct(MarketplaceProduct product) {
    final index = localMarketplaceProducts.indexWhere(
      (entry) => entry.id == product.id,
    );
    if (index == -1) {
      localMarketplaceProducts.insert(0, product);
    } else {
      localMarketplaceProducts[index] = product;
    }
    _localProductsController.add(
      List<MarketplaceProduct>.of(localMarketplaceProducts),
    );
  }

  static Stream<List<MarketplaceProduct>> watchLocalProductsByStore(
    String storeId,
  ) async* {
    yield localMarketplaceProducts
        .where((product) => product.storeId == storeId)
        .toList();
    yield* _localProductsController.stream.map(
      (products) =>
          products.where((product) => product.storeId == storeId).toList(),
    );
  }

  Stream<List<MarketplaceStore>> watchStores() {
    if (!_firebaseService.isReady) {
      final stores = localMarketplaceStores
          .where((store) => store.isCustomerVisible)
          .toList();
      return Stream.value(stores.isEmpty ? sampleStores : stores);
    }
    return _firebaseService.firestore.collection(storesCollection).snapshots().map((
      snapshot,
    ) {
      if (snapshot.docs.isEmpty) {
        return <MarketplaceStore>[];
      }
      final stores = snapshot.docs
          .map(MarketplaceStore.fromFirestore)
          .where((store) => store.isCustomerVisible)
          .toList();
      debugPrint(
        'OMW marketplace stores loaded: ${stores.length} ${stores.map((store) => '${store.name}:${store.id}:${store.status}:${store.isOpen}').join(', ')}',
      );
      return stores;
    });
  }

  Stream<List<MarketplaceProduct>> watchProductsByStore(String storeId) {
    if (!_firebaseService.isReady) {
      final hasLocalStore = localMarketplaceStores.any(
        (store) => store.id == storeId,
      );
      if (!hasLocalStore) {
        return Stream.value(sampleProductsForStore(storeId));
      }
      return watchLocalProductsByStore(storeId).map(
        (products) =>
            products.where((product) => product.isVisibleToCustomers).toList(),
      );
    }
    return _firebaseService.firestore
        .collection(productsCollection)
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs
              .map(MarketplaceProduct.fromFirestore)
              .where((product) => product.isVisibleToCustomers)
              .toList();
          debugPrint(
            'OMW marketplace products loaded for $storeId: ${products.length}',
          );
          return products;
        });
  }

  Future<String?> createMarketplaceOrder(MarketplaceOrder order) async {
    if (!_firebaseService.isReady) {
      final id = order.id.isEmpty
          ? 'OMW-MKT-${DateTime.now().millisecondsSinceEpoch}'
          : order.id;
      final updatedProducts = <MarketplaceProduct>[];
      for (final item in order.items) {
        final index = localMarketplaceProducts.indexWhere(
          (product) => product.id == item.productId,
        );
        if (index == -1) {
          throw StateError('${item.productName} is unavailable.');
        }
        final product = localMarketplaceProducts[index];
        if (product.storeId != order.storeId) {
          throw StateError('${product.name} is unavailable from this store.');
        }
        if (!product.canCustomerOrder) {
          throw StateError('${product.name} is out of stock.');
        }
        if (product.stockQuantity < item.quantity) {
          throw StateError('Not enough stock for ${product.name}.');
        }
        final nextStock = product.stockQuantity - item.quantity;
        updatedProducts.add(
          product.copyWith(
            stockQuantity: nextStock,
            isAvailable: nextStock <= 0 ? false : product.isAvailable,
            updatedAt: DateTime.now(),
          ),
        );
      }
      for (final product in updatedProducts) {
        syncLocalProduct(product);
      }
      localMarketplaceOrders.insert(
        0,
        order.copyWith(
          id: id,
          inventoryDeducted: true,
          inventoryRestored: false,
        ),
      );
      return id;
    }
    final collection = _firebaseService.firestore.collection(ordersCollection);
    final ref = order.id.isEmpty ? collection.doc() : collection.doc(order.id);
    final storeRef = _firebaseService.firestore
        .collection(storesCollection)
        .doc(order.storeId);
    final productRefs = order.items
        .map(
          (item) => _firebaseService.firestore
              .collection(productsCollection)
              .doc(item.productId),
        )
        .toList();
    await _firebaseService.firestore.runTransaction((transaction) async {
      final storeSnapshot = await transaction.get(storeRef);
      if (!storeSnapshot.exists) {
        throw StateError('This store is not available right now.');
      }
      final store = MarketplaceStore.fromMap(
        storeSnapshot.id,
        storeSnapshot.data() ?? const <String, Object?>{},
      );
      if (!store.isCustomerOrderable) {
        throw StateError('This store is closed or unavailable today.');
      }
      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final productRef in productRefs) {
        productSnapshots.add(await transaction.get(productRef));
      }
      for (final item in order.items) {
        final snapshot = productSnapshots.firstWhere(
          (productSnapshot) => productSnapshot.id == item.productId,
          orElse: () => throw StateError('${item.productName} is unavailable.'),
        );
        if (!snapshot.exists) {
          throw StateError('${item.productName} is unavailable.');
        }
        final product = MarketplaceProduct.fromMap(
          snapshot.id,
          snapshot.data() ?? const <String, Object?>{},
        );
        if (!product.canCustomerOrder) {
          throw StateError('${product.name} is out of stock.');
        }
        if (product.stockQuantity < item.quantity) {
          throw StateError('Not enough stock for ${product.name}.');
        }
        final nextStock = product.stockQuantity - item.quantity;
        final nextAvailable = nextStock <= 0 ? false : product.isAvailable;
        final nextStatus = nextStock <= 0
            ? 'out_of_stock'
            : nextStock <= product.lowStockThreshold
            ? 'low_stock'
            : 'in_stock';
        transaction.update(snapshot.reference, {
          'stockQuantity': nextStock,
          'stockStatus': nextStatus,
          'isAvailable': nextAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final savedOrder = order.copyWith(id: ref.id);
      transaction.set(ref, {
        ...savedOrder.toFirestore(),
        'status': MarketplaceOrderStatus.pending.name,
        'orderStatus': 'placed',
        'inventoryDeducted': true,
        'inventoryRestored': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    final storeSnapshot = await storeRef.get();
    final store = MarketplaceStore.fromMap(
      storeSnapshot.id,
      storeSnapshot.data() ?? const <String, Object?>{},
    );
    await _notificationService.create(
      type: 'marketplace_order_placed',
      title: 'Marketplace order placed',
      message: 'Your order with ${order.storeName} was placed.',
      userId: order.customerId,
      roleTarget: 'customer',
      relatedId: ref.id,
      relatedCollection: ordersCollection,
      data: {'orderId': ref.id, 'storeId': order.storeId},
    );
    await _notificationService.create(
      type: 'store_marketplace_order_received',
      title: 'New marketplace order',
      message: 'A customer placed an order with ${order.storeName}.',
      userId: store.ownerId.isEmpty ? null : store.ownerId,
      roleTarget: 'store_owner',
      relatedId: ref.id,
      relatedCollection: ordersCollection,
      data: {'orderId': ref.id, 'storeId': order.storeId},
    );
    await _notificationService.create(
      type: 'owner_marketplace_order_created',
      title: 'New marketplace order',
      message: '${order.storeName} received a marketplace order.',
      roleTarget: 'owner',
      relatedId: ref.id,
      relatedCollection: ordersCollection,
      data: {'orderId': ref.id, 'storeId': order.storeId},
    );
    await _notifyStockAlertsAfterCheckout(order);
    return ref.id;
  }

  Stream<List<MarketplaceOrder>> watchCustomerMarketplaceOrders(
    String customerId,
  ) {
    if (!_firebaseService.isReady) {
      return Stream.value(
        localMarketplaceOrders
            .where((order) => order.customerId == customerId)
            .toList(),
      );
    }
    return _firebaseService.firestore
        .collection(ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  Stream<MarketplaceOrder?> watchMarketplaceOrder(String orderId) {
    if (orderId.isEmpty) {
      return Stream.value(null);
    }
    if (!_firebaseService.isReady) {
      return Stream.periodic(const Duration(seconds: 1), (_) {
        for (final order in localMarketplaceOrders) {
          if (order.id == orderId) {
            return order;
          }
        }
        return null;
      }).asBroadcastStream();
    }
    return _firebaseService.firestore
        .collection(ordersCollection)
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }
          return MarketplaceOrder.fromFirestore(snapshot);
        });
  }

  Stream<List<MarketplaceOrder>> watchPendingMarketplaceOrders() {
    if (!_firebaseService.isReady) {
      return Stream.value(
        localMarketplaceOrders
            .where((order) => order.status == MarketplaceOrderStatus.pending)
            .toList(),
      );
    }
    return _firebaseService.firestore
        .collection(ordersCollection)
        .where('status', isEqualTo: MarketplaceOrderStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  Stream<List<MarketplaceOrder>> watchOwnerMarketplaceOrders() {
    if (!_firebaseService.isReady) {
      return Stream.value(localMarketplaceOrders);
    }
    return _firebaseService.firestore
        .collection(ordersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_ordersFromSnapshot);
  }

  Future<void> acceptMarketplaceOrder(
    String orderId,
    String workerId, {
    String? workerName,
    String? workerPhone,
  }) async {
    if (!_firebaseService.isReady) {
      final index = localMarketplaceOrders.indexWhere(
        (order) => order.id == orderId,
      );
      if (index == -1) return;
      final current = localMarketplaceOrders[index];
      if (current.status != MarketplaceOrderStatus.pending) {
        throw StateError('This order was already accepted.');
      }
      localMarketplaceOrders[index] = current.copyWith(
        status: MarketplaceOrderStatus.accepted,
        assignedWorkerId: workerId,
        assignedWorkerName: workerName,
        assignedWorkerPhone: workerPhone,
        acceptedAt: DateTime.now(),
      );
      return;
    }

    final ref = _firebaseService.firestore
        .collection(ordersCollection)
        .doc(orderId);
    await _firebaseService.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw StateError('Marketplace order was not found.');
      }
      final current = MarketplaceOrder.fromMap(
        snapshot.id,
        snapshot.data() ?? const {},
      );
      if (current.status != MarketplaceOrderStatus.pending) {
        throw StateError('This order was already accepted.');
      }
      transaction.set(ref, {
        'status': MarketplaceOrderStatus.accepted.name,
        'assignedWorkerId': workerId,
        'assignedWorkerName': workerName,
        'assignedWorkerPhone': workerPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateMarketplaceOrderStatus(
    String orderId,
    MarketplaceOrderStatus status, {
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? assignedWorkerPhone,
  }) async {
    if (!_firebaseService.isReady) {
      final index = localMarketplaceOrders.indexWhere(
        (order) => order.id == orderId,
      );
      if (index == -1) return;
      final current = localMarketplaceOrders[index];
      var restored = current.inventoryRestored;
      DateTime? restoredAt = current.inventoryRestoredAt;
      if (status == MarketplaceOrderStatus.cancelled &&
          current.inventoryDeducted &&
          !current.inventoryRestored) {
        for (final item in current.items) {
          final productIndex = localMarketplaceProducts.indexWhere(
            (product) => product.id == item.productId,
          );
          if (productIndex == -1) continue;
          final product = localMarketplaceProducts[productIndex];
          syncLocalProduct(
            product.copyWith(
              stockQuantity: product.stockQuantity + item.quantity,
              isAvailable: product.stockQuantity + item.quantity > 0
                  ? true
                  : product.isAvailable,
              updatedAt: DateTime.now(),
            ),
          );
        }
        restored = true;
        restoredAt = DateTime.now();
      }
      localMarketplaceOrders[index] = current.copyWith(
        status: status,
        assignedWorkerId: assignedWorkerId,
        assignedWorkerName: assignedWorkerName,
        assignedWorkerPhone: assignedWorkerPhone,
        acceptedAt: status == MarketplaceOrderStatus.accepted
            ? DateTime.now()
            : null,
        deliveredAt: status == MarketplaceOrderStatus.delivered
            ? DateTime.now()
            : null,
        gross: status == MarketplaceOrderStatus.delivered
            ? localMarketplaceOrders[index].total
            : null,
        platformCommission: status == MarketplaceOrderStatus.delivered
            ? AppConfig.platformCommissionFor(
                localMarketplaceOrders[index].total,
              )
            : null,
        workerPayout: status == MarketplaceOrderStatus.delivered
            ? AppConfig.workerPayoutFor(localMarketplaceOrders[index].total)
            : null,
        ownerNet: status == MarketplaceOrderStatus.delivered
            ? AppConfig.platformCommissionFor(
                localMarketplaceOrders[index].total,
              )
            : null,
        paymentStatus: 'manual',
        workerPayoutStatus: status == MarketplaceOrderStatus.delivered
            ? 'unpaid'
            : null,
        inventoryRestored: restored,
        inventoryRestoredAt: restoredAt,
      );
      return;
    }
    if (status == MarketplaceOrderStatus.cancelled) {
      await _restoreInventoryAndUpdateCancelledOrder(
        orderId,
        assignedWorkerId: assignedWorkerId,
        assignedWorkerName: assignedWorkerName,
        assignedWorkerPhone: assignedWorkerPhone,
      );
      final snapshot = await _firebaseService.firestore
          .collection(ordersCollection)
          .doc(orderId)
          .get();
      final order = MarketplaceOrder.fromMap(
        snapshot.id,
        snapshot.data() ?? const <String, Object?>{},
      );
      await _notifyMarketplaceOrderStatus(order, status);
      return;
    }
    final updates = <String, Object?>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (assignedWorkerId != null) {
      updates['assignedWorkerId'] = assignedWorkerId;
    }
    if (assignedWorkerName != null) {
      updates['assignedWorkerName'] = assignedWorkerName;
    }
    if (assignedWorkerPhone != null) {
      updates['assignedWorkerPhone'] = assignedWorkerPhone;
    }
    if (status == MarketplaceOrderStatus.accepted) {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    if (status == MarketplaceOrderStatus.delivered) {
      final snapshot = await _firebaseService.firestore
          .collection(ordersCollection)
          .doc(orderId)
          .get();
      final order = MarketplaceOrder.fromMap(
        snapshot.id,
        snapshot.data() ?? const {},
      );
      final gross = order.total;
      final commission = AppConfig.platformCommissionFor(gross);
      updates['deliveredAt'] = FieldValue.serverTimestamp();
      updates['gross'] = gross;
      updates['platformCommission'] = commission;
      updates['workerPayout'] = AppConfig.workerPayoutFor(gross);
      updates['ownerNet'] = commission;
      updates['paymentStatus'] = 'manual';
      updates['workerPayoutStatus'] = 'unpaid';
    }
    await _firebaseService.firestore
        .collection(ordersCollection)
        .doc(orderId)
        .set(updates, SetOptions(merge: true));
    final orderSnapshot = await _firebaseService.firestore
        .collection(ordersCollection)
        .doc(orderId)
        .get();
    final order = MarketplaceOrder.fromMap(
      orderSnapshot.id,
      orderSnapshot.data() ?? const <String, Object?>{},
    );
    await _notifyMarketplaceOrderStatus(order, status);
  }

  Future<void> _restoreInventoryAndUpdateCancelledOrder(
    String orderId, {
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? assignedWorkerPhone,
  }) async {
    final orderRef = _firebaseService.firestore
        .collection(ordersCollection)
        .doc(orderId);
    await _firebaseService.firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw StateError('Marketplace order was not found.');
      }
      final order = MarketplaceOrder.fromMap(
        orderSnapshot.id,
        orderSnapshot.data() ?? const <String, Object?>{},
      );
      if (order.inventoryDeducted && !order.inventoryRestored) {
        final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final item in order.items) {
          final productRef = _firebaseService.firestore
              .collection(productsCollection)
              .doc(item.productId);
          productSnapshots.add(await transaction.get(productRef));
        }
        for (final item in order.items) {
          final productSnapshot = productSnapshots.firstWhere(
            (snapshot) => snapshot.id == item.productId,
            orElse: () => throw StateError('${item.productName} is missing.'),
          );
          if (!productSnapshot.exists) continue;
          final product = MarketplaceProduct.fromMap(
            productSnapshot.id,
            productSnapshot.data() ?? const <String, Object?>{},
          );
          final restoredStock = product.stockQuantity + item.quantity;
          final restoredStatus = restoredStock <= 0
              ? 'out_of_stock'
              : restoredStock <= product.lowStockThreshold
              ? 'low_stock'
              : 'in_stock';
          transaction.update(productSnapshot.reference, {
            'stockQuantity': restoredStock,
            'stockStatus': restoredStatus,
            'isAvailable': restoredStock > 0 ? true : product.isAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      final cancellationUpdates = <String, Object?>{
        'status': MarketplaceOrderStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (assignedWorkerId != null) {
        cancellationUpdates['assignedWorkerId'] = assignedWorkerId;
      }
      if (assignedWorkerName != null) {
        cancellationUpdates['assignedWorkerName'] = assignedWorkerName;
      }
      if (assignedWorkerPhone != null) {
        cancellationUpdates['assignedWorkerPhone'] = assignedWorkerPhone;
      }
      if (order.inventoryDeducted && !order.inventoryRestored) {
        cancellationUpdates['inventoryRestored'] = true;
        cancellationUpdates['inventoryRestoredAt'] =
            FieldValue.serverTimestamp();
      }
      transaction.set(orderRef, cancellationUpdates, SetOptions(merge: true));
    });
  }

  Future<void> completeMarketplaceOrder(String orderId) {
    return updateMarketplaceOrderStatus(
      orderId,
      MarketplaceOrderStatus.delivered,
    );
  }

  Future<void> _notifyStockAlertsAfterCheckout(MarketplaceOrder order) async {
    if (!_firebaseService.isReady) return;
    final storeSnapshot = await _firebaseService.firestore
        .collection(storesCollection)
        .doc(order.storeId)
        .get();
    final store = MarketplaceStore.fromMap(
      storeSnapshot.id,
      storeSnapshot.data() ?? const <String, Object?>{},
    );
    for (final item in order.items) {
      final snapshot = await _firebaseService.firestore
          .collection(productsCollection)
          .doc(item.productId)
          .get();
      if (!snapshot.exists) continue;
      final product = MarketplaceProduct.fromMap(
        snapshot.id,
        snapshot.data() ?? const <String, Object?>{},
      );
      if (product.stockStatus == 'low_stock') {
        await _notificationService.create(
          type: 'product_low_stock',
          title: 'Low stock',
          message: '${product.name} is low on stock.',
          userId: store.ownerId.isEmpty ? product.storeOwnerId : store.ownerId,
          roleTarget: 'store_owner',
          relatedId: product.id,
          relatedCollection: productsCollection,
          data: {'productId': product.id, 'storeId': product.storeId},
        );
        await _notificationService.create(
          type: 'owner_product_low_stock',
          title: 'Low-stock product',
          message: '${product.name} is low on stock at ${order.storeName}.',
          roleTarget: 'owner',
          relatedId: product.id,
          relatedCollection: productsCollection,
          data: {'productId': product.id, 'storeId': product.storeId},
        );
      }
      if (product.stockStatus == 'out_of_stock') {
        await _notificationService.create(
          type: 'product_out_of_stock',
          title: 'Out of stock',
          message: '${product.name} is out of stock.',
          userId: store.ownerId.isEmpty ? product.storeOwnerId : store.ownerId,
          roleTarget: 'store_owner',
          relatedId: product.id,
          relatedCollection: productsCollection,
          data: {'productId': product.id, 'storeId': product.storeId},
        );
        await _notificationService.create(
          type: 'owner_product_out_of_stock',
          title: 'Out-of-stock product',
          message: '${product.name} is out of stock at ${order.storeName}.',
          roleTarget: 'owner',
          relatedId: product.id,
          relatedCollection: productsCollection,
          data: {'productId': product.id, 'storeId': product.storeId},
        );
      }
    }
  }

  Future<void> _notifyMarketplaceOrderStatus(
    MarketplaceOrder order,
    MarketplaceOrderStatus status,
  ) async {
    if (order.id.isEmpty) return;
    final label = switch (status) {
      MarketplaceOrderStatus.accepted => 'accepted your order',
      MarketplaceOrderStatus.shopping => 'started preparing your order',
      MarketplaceOrderStatus.pickedUp => 'marked your order ready',
      MarketplaceOrderStatus.delivered => 'completed your order',
      MarketplaceOrderStatus.cancelled => 'canceled your order',
      MarketplaceOrderStatus.onTheWay => 'marked your order on the way',
      MarketplaceOrderStatus.pending => 'updated your order',
    };
    await _notificationService.create(
      type: 'marketplace_order_status_updated',
      title: 'Marketplace order updated',
      message: '${order.storeName} $label.',
      userId: order.customerId,
      roleTarget: 'customer',
      relatedId: order.id,
      relatedCollection: ordersCollection,
      data: {'orderId': order.id, 'status': status.name},
    );
  }

  Future<void> updateWorkerPayoutStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    if (!_firebaseService.isReady) {
      final index = localMarketplaceOrders.indexWhere(
        (order) => order.id == orderId,
      );
      if (index == -1) return;
      localMarketplaceOrders[index] = localMarketplaceOrders[index].copyWith(
        workerPayoutStatus: status,
        workerPaidAt: status == 'paid' ? DateTime.now() : null,
        payoutNote: note,
      );
      return;
    }
    await _firebaseService.firestore
        .collection(ordersCollection)
        .doc(orderId)
        .set({
          'workerPayoutStatus': status,
          'payoutNote': note,
          if (status == 'paid') 'workerPaidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  List<MarketplaceOrder> _ordersFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(MarketplaceOrder.fromFirestore).toList();
  }

  static final List<MarketplaceOrder> localMarketplaceOrders = [];

  static const List<MarketplaceStore> sampleStores = [
    MarketplaceStore(
      id: 'omw-grocery',
      name: 'OMW Grocery',
      category: 'Grocery',
      imageUrl: '',
      rating: 4.8,
      isOpen: true,
      lat: 33.895,
      lng: 35.503,
      address: 'Beirut Central',
      deliveryEstimateMinutes: 25,
    ),
    MarketplaceStore(
      id: 'omw-pharmacy',
      name: 'OMW Pharmacy',
      category: 'Pharmacy',
      imageUrl: '',
      rating: 4.9,
      isOpen: true,
      lat: 33.9,
      lng: 35.507,
      address: 'Hamra',
      deliveryEstimateMinutes: 20,
    ),
    MarketplaceStore(
      id: 'omw-market',
      name: 'OMW Market',
      category: 'Convenience',
      imageUrl: '',
      rating: 4.6,
      isOpen: true,
      lat: 33.889,
      lng: 35.51,
      address: 'Achrafieh',
      deliveryEstimateMinutes: 30,
    ),
    MarketplaceStore(
      id: 'omw-restaurant',
      name: 'OMW Restaurant',
      category: 'Restaurants',
      imageUrl: '',
      rating: 4.7,
      isOpen: true,
      lat: 33.894,
      lng: 35.49,
      address: 'Gemmayze',
      deliveryEstimateMinutes: 35,
    ),
    MarketplaceStore(
      id: 'omw-electronics',
      name: 'OMW Electronics',
      category: 'Electronics',
      imageUrl: '',
      rating: 4.5,
      isOpen: false,
      lat: 33.886,
      lng: 35.498,
      address: 'Verdun',
      deliveryEstimateMinutes: 40,
    ),
  ];

  static List<MarketplaceProduct> sampleProductsForStore(String storeId) {
    final products = _sampleProducts
        .where((product) => product.storeId == storeId)
        .toList();
    return products.isEmpty
        ? _sampleProducts
              .map(
                (product) => MarketplaceProduct(
                  id: '$storeId-${product.id}',
                  storeId: storeId,
                  name: product.name,
                  description: product.description,
                  price: product.price,
                  imageUrl: product.imageUrl,
                  category: product.category,
                  isAvailable: product.isAvailable,
                ),
              )
              .take(4)
              .toList()
        : products;
  }

  static const List<MarketplaceProduct> _sampleProducts = [
    MarketplaceProduct(
      id: 'water',
      storeId: 'omw-grocery',
      name: 'Water bottle',
      description: '1.5L mineral water',
      price: 1.25,
      imageUrl: '',
      category: 'Grocery',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'bread',
      storeId: 'omw-grocery',
      name: 'Bread',
      description: 'Fresh daily bread',
      price: 1.75,
      imageUrl: '',
      category: 'Grocery',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'milk',
      storeId: 'omw-grocery',
      name: 'Milk',
      description: '1L milk carton',
      price: 2.2,
      imageUrl: '',
      category: 'Grocery',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'eggs',
      storeId: 'omw-market',
      name: 'Eggs',
      description: 'Pack of 12',
      price: 3.5,
      imageUrl: '',
      category: 'Convenience',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'medicine',
      storeId: 'omw-pharmacy',
      name: 'Medicine placeholder',
      description: 'Confirm availability with pharmacy',
      price: 6,
      imageUrl: '',
      category: 'Pharmacy',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'charger',
      storeId: 'omw-electronics',
      name: 'Phone charger',
      description: 'USB-C fast charger',
      price: 12,
      imageUrl: '',
      category: 'Electronics',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'snacks',
      storeId: 'omw-market',
      name: 'Snacks',
      description: 'Assorted chips',
      price: 2,
      imageUrl: '',
      category: 'Convenience',
      isAvailable: true,
    ),
    MarketplaceProduct(
      id: 'coffee',
      storeId: 'omw-restaurant',
      name: 'Coffee',
      description: 'Fresh hot coffee',
      price: 2.5,
      imageUrl: '',
      category: 'Restaurants',
      isAvailable: true,
    ),
  ];
}
