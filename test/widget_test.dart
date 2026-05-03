import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:option_b/main.dart';

void main() {
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
}
