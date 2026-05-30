import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:option_b/main.dart';
import 'package:option_b/models/backend_models.dart' as backend;
import 'package:option_b/services/marketplace_service.dart';
import 'package:option_b/widgets/app_map.dart';

void main() {
  setUp(_resetDemoState);

  testWidgets('customer can verify and reach customer home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OptionBApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to On My Way'), findsOneWidget);
    expect(find.text('I need a service'), findsOneWidget);

    await tester.tap(find.text('I need a service'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '70123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('What do you need today?'), findsOneWidget);
    expect(find.text('Ride'), findsOneWidget);
    expect(find.text('Moto'), findsOneWidget);
    expect(find.text('Courier'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
  });

  testWidgets('ride card opens map request flow', (WidgetTester tester) async {
    await _loginCustomer(tester);

    await tester.tap(find.text('Ride'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby OMW Offers'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Send OMW Offer'), findsOneWidget);
    expect(find.text('Marketplace'), findsNothing);
  });

  testWidgets('map menu switch account returns to role selection', (
    WidgetTester tester,
  ) async {
    await _loginCustomer(tester);

    await tester.tap(find.text('Ride'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to On My Way'), findsOneWidget);
    expect(find.text('I need a service'), findsOneWidget);
    expect(find.text('Nearby OMW Offers'), findsNothing);
  });

  testWidgets('marketplace card opens shopping home', (
    WidgetTester tester,
  ) async {
    await _loginCustomer(tester);

    final marketplaceCard = find.byKey(
      const ValueKey('customer-service-marketplace'),
    );
    await tester.ensureVisible(marketplaceCard);
    await tester.tap(marketplaceCard);
    await tester.pumpAndSettle();

    expect(find.text('OMW Marketplace'), findsOneWidget);
    expect(find.text('On My Way Marketplace'), findsOneWidget);
    expect(find.text('Featured stores'), findsOneWidget);
    expect(find.text('OMW Grocery'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Popular products'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Popular products'), findsOneWidget);
  });

  test('owner revenue excludes pending offers until accepted or active', () {
    final offer = _demoOffer('OPT-B-1001', 20);
    final pending = upsertServiceJob(offer: offer, customerPhone: '70123456');

    var metrics = ownerMetricsFor([pending]);
    expect(metrics.pendingOffers, 1);
    expect(metrics.grossRevenue, 0);
    expect(metrics.platformCommission, 0);
    expect(metrics.workerPayouts, 0);

    assignServiceJob(offer, demoDrivers(ServiceType.ride).first);
    metrics = ownerMetricsFor([pending]);
    expect(metrics.pendingOffers, 0);
    expect(metrics.acceptedJobs, 1);
    expect(metrics.grossRevenue, 20);
    expect(metrics.platformCommission, 3);
    expect(metrics.workerPayouts, 17);
  });

  test('matching fallback creates an approved online demo driver', () {
    expect(onlineDriversFor(ServiceType.ride), isEmpty);

    demoWorkerProfile.status = WorkerApplicationStatus.approved;
    demoWorkerProfile.fullName = 'OMW Driver';
    demoWorkerProfile.phoneNumber = 'Demo driver';
    demoWorkerProfile.plateNumber = 'DEMO-123';
    demoWorkerProfile.cityArea = 'Beirut';
    for (final name in kWorkerDocumentNames) {
      demoWorkerProfile.documents[name] = DocumentStatus.approved;
    }
    demoDriverAvailability.isOnline = true;

    expect(onlineDriversFor(ServiceType.ride), isNotEmpty);
  });

  test(
    'local marketplace order is visible and assignable for courier queue',
    () async {
      final service = MarketplaceService();
      final order = backend.MarketplaceOrder(
        id: '',
        customerId: 'local-customer',
        customerPhone: '70123456',
        storeId: 'omw-grocery',
        storeName: 'OMW Grocery',
        storeAddress: 'Beirut Central',
        storeLat: 33.895,
        storeLng: 35.503,
        items: const [
          backend.MarketplaceCartItem(
            productId: 'water',
            storeId: 'omw-grocery',
            productName: 'Water bottle',
            quantity: 2,
            unitPrice: 1.25,
          ),
        ],
        subtotal: 2.5,
        deliveryFee: 3,
        total: 5.5,
        paymentMethod: backend.BackendPaymentMethod.cash,
        deliveryLabel: 'Current Location',
        deliveryLat: kDemoPickupPoint.latitude,
        deliveryLng: kDemoPickupPoint.longitude,
        status: backend.MarketplaceOrderStatus.pending,
        createdAt: DateTime.now(),
      );

      final id = await service.createMarketplaceOrder(order);
      final pending = await service.watchPendingMarketplaceOrders().first;

      expect(id, isNotNull);
      expect(pending, hasLength(1));
      expect(pending.first.storeName, 'OMW Grocery');

      await service.acceptMarketplaceOrder(
        id!,
        'demo-worker-1',
        workerName: 'OMW Driver',
        workerPhone: 'Demo driver',
      );

      final ownerOrders = await service.watchOwnerMarketplaceOrders().first;
      expect(ownerOrders.first.status, backend.MarketplaceOrderStatus.accepted);
      expect(ownerOrders.first.assignedWorkerName, 'OMW Driver');
    },
  );

  testWidgets('driver nearby offers shows pending marketplace order', (
    WidgetTester tester,
  ) async {
    await _seedMarketplaceOrder();
    _approveDemoWorkerOnline();

    await tester.pumpWidget(
      MaterialApp(
        home: DriverHomeScreen(userPhone: 'Demo driver', onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Marketplace Order'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Marketplace Order'), findsOneWidget);
    expect(find.text('OMW Grocery'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
  });

  testWidgets('customer destination suggestion updates estimate UI', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const OptionBApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('I need a service'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '70123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ride'));
    await tester.pumpAndSettle();

    final destinationField = find.ancestor(
      of: find.byIcon(Icons.place_outlined),
      matching: find.byType(TextField),
    );
    await tester.enterText(destinationField, 'za');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zalka').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Estimated distance'), findsOneWidget);
    expect(find.textContaining('Estimated time'), findsOneWidget);
  });
}

Future<void> _loginCustomer(WidgetTester tester) async {
  await tester.pumpWidget(const OptionBApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('I need a service'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '70123456');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '1234');
  await tester.tap(find.text('Verify'));
  await tester.pumpAndSettle();
}

void _resetDemoState() {
  demoHistory.clear();
  demoDriverJobs.clear();
  demoServiceJobs.clear();
  MarketplaceService.localMarketplaceOrders.clear();
  demoDriverAvailability.isOnline = false;
  demoDriverAvailability.location = const DemoMapPoint(33.8898, 35.4948);
  demoDriverAvailability.locationLabel = 'Demo driver location';
  demoWorkerProfile.reset();
}

void _approveDemoWorkerOnline() {
  demoWorkerProfile.status = WorkerApplicationStatus.approved;
  demoWorkerProfile.fullName = 'OMW Driver';
  demoWorkerProfile.phoneNumber = 'Demo driver';
  demoWorkerProfile.plateNumber = 'DEMO-123';
  demoWorkerProfile.cityArea = 'Beirut';
  for (final name in kWorkerDocumentNames) {
    demoWorkerProfile.documents[name] = DocumentStatus.approved;
  }
  demoDriverAvailability.isOnline = true;
}

Future<String?> _seedMarketplaceOrder() {
  return MarketplaceService().createMarketplaceOrder(
    backend.MarketplaceOrder(
      id: '',
      customerId: 'local-customer',
      customerPhone: '70123456',
      storeId: 'omw-grocery',
      storeName: 'OMW Grocery',
      storeAddress: 'Beirut Central',
      storeLat: 33.895,
      storeLng: 35.503,
      items: const [
        backend.MarketplaceCartItem(
          productId: 'water',
          storeId: 'omw-grocery',
          productName: 'Water bottle',
          quantity: 2,
          unitPrice: 1.25,
        ),
      ],
      subtotal: 2.5,
      deliveryFee: 3,
      total: 5.5,
      paymentMethod: backend.BackendPaymentMethod.cash,
      deliveryLabel: 'Current Location',
      deliveryLat: kDemoPickupPoint.latitude,
      deliveryLng: kDemoPickupPoint.longitude,
      status: backend.MarketplaceOrderStatus.pending,
      createdAt: DateTime.now(),
    ),
  );
}

OfferPayload _demoOffer(String id, int amount) {
  return OfferPayload(
    id: id,
    service: ServiceType.ride,
    pickup: 'Current Location',
    destination: 'Zalka',
    offerAmount: amount,
    paymentMethod: PaymentMethod.cash,
    pickupPoint: kDemoPickupPoint,
    destinationPoint: const DemoMapPoint(33.9142, 35.5791),
  );
}
