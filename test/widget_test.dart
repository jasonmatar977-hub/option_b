import 'package:flutter_test/flutter_test.dart';

import 'package:option_b/main.dart';

void main() {
  testWidgets('Option B home shows map and sheet', (WidgetTester tester) async {
    await tester.pumpWidget(const OptionBApp());
    await tester.pumpAndSettle();

    expect(find.text('Option B'), findsOneWidget);
    expect(find.text('Send Offer'), findsOneWidget);
    expect(find.textContaining('Ride'), findsWidgets);
  });
}
