// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_helper/main.dart';

void main() {
  testWidgets('Main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Помощник обработки накладных'), findsOneWidget);

    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });
}
