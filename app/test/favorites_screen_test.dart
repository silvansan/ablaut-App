import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ablaut_app/screens/favorites_screen.dart';

String _favorite(String id, String name, String url, String updatedAt) {
  return jsonEncode({
    'id': id,
    'name': name,
    'url': url,
    'createdAt': updatedAt,
    'updatedAt': updatedAt,
  });
}

void main() {
  testWidgets('a saved event shows its saved channels as chips', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ablaut.favoriteChannels.v1': [
        _favorite('e', 'Sunday Service', 'https://voice.example.com/listen/sunday', '2026-01-03T00:00:00.000'),
        _favorite('en', 'Sunday Service - English', 'https://voice.example.com/listen/sunday/en', '2026-01-02T00:00:00.000'),
        _favorite('y', 'Youth Night - English', 'https://voice.example.com/listen/youth/en', '2026-01-01T00:00:00.000'),
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Service'), findsOneWidget);
    expect(find.text('Event · choose a channel'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'English'), findsOneWidget);
    // The grouped channel is not repeated as a row of its own.
    expect(find.text('Sunday Service - English'), findsNothing);
    // A channel of an event that is not saved keeps its own row.
    expect(find.text('Youth Night - English'), findsOneWidget);
  });
}
