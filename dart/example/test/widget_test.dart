// Smoke test of the demo screen. It makes no network call: the buttons are
// only rendered, not tapped, and no credentials are needed.
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the demo actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('PayWay Partner Demo'), findsOneWidget);
    expect(
        find.widgetWithText(TextButton, 'register merchant'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'check merchant'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'get mc info'), findsOneWidget);
  });
}
