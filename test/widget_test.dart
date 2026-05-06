import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:option_b/main.dart';
import 'package:option_b/widgets/app_map.dart';

void main() {
  setUp(_resetDemoState);

  testWidgets('customer can verify and reach map home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OptionBApp());
    await tester.pumpAndSettle();

    expect(find.text('Option B'), findsOneWidget);
    expect(find.text('I need a service'), findsOneWidget);

    await tester.tap(find.text('I need a service'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '70123456');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Make an offer'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Send Offer'), findsOneWidget);
    expect(find.textContaining('Ride'), findsWidgets);
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
    demoWorkerProfile.fullName = 'Option B Driver';
    demoWorkerProfile.phoneNumber = 'Demo driver';
    demoWorkerProfile.plateNumber = 'DEMO-123';
    demoWorkerProfile.cityArea = 'Beirut';
    for (final name in kWorkerDocumentNames) {
      demoWorkerProfile.documents[name] = DocumentStatus.approved;
    }
    demoDriverAvailability.isOnline = true;

    expect(onlineDriversFor(ServiceType.ride), isNotEmpty);
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

void _resetDemoState() {
  demoHistory.clear();
  demoDriverJobs.clear();
  demoServiceJobs.clear();
  demoDriverAvailability.isOnline = false;
  demoDriverAvailability.location = const DemoMapPoint(33.8898, 35.4948);
  demoDriverAvailability.locationLabel = 'Demo driver location';
  demoWorkerProfile.reset();
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
