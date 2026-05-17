// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:undersound_mobile/main.dart';

void main() {
  testWidgets('Home screen opens', (WidgetTester tester) async {
    await tester.pumpWidget(const UnderSoundMobileApp());

    expect(find.text('UnderSound Mobile'), findsOneWidget);
    expect(
      find.text(
        'Join an UnderSound event, listen to live channel audio, and keep your favorite listener links ready.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(find.text('My favorites'), findsOneWidget);
    expect(find.text('Version 0.2.1'), findsOneWidget);
    expect(find.text('GitHub repository'), findsOneWidget);
    expect(find.text('Manual link'), findsNothing);
  });
}
