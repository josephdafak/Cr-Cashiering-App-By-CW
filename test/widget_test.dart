import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cr_cashiering_app/main.dart';  // Use your correct package name

void main() async {
  // Initialize Hive for testing
  await Hive.initFlutter();
  var box = await Hive.openBox('cashierBox');

  testWidgets('Cashiering App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(CashieringApp(box));  // Pass the mock box to the app

    // Verify initial widget state (for example, checking for a TextField)
    expect(find.text('Tae'), findsOneWidget);  // Verify TextField for Tae
    expect(find.text('IHI'), findsOneWidget);  // Verify TextField for IHI
    expect(find.text('Ligo'), findsOneWidget);  // Verify TextField for Ligo
    expect(find.text('Add Record'), findsOneWidget);  // Verify the button

    // Interact with the widget (e.g., enter text and tap the button)
    await tester.enterText(find.byType(TextField).at(0), '5'); // Enter value for Tae
    await tester.enterText(find.byType(TextField).at(1), '2'); // Enter value for IHI
    await tester.enterText(find.byType(TextField).at(2), '15'); // Enter value for Ligo

    // Tap the 'Add Record' button
    await tester.tap(find.text('Add Record'));
    await tester.pump();

    // Verify that the record was added to the cashier records list
    expect(find.text('Tae: 5.0 IHI: 2.0 Ligo: 15.0'), findsOneWidget);  // Verify the added record is displayed

    // Add additional expectations based on your widget's behavior.
  });
}
