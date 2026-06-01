import 'dart:convert';

import 'package:dony/features/matching/presentation/widgets/map_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveMapStyle', () {
    test('light → null (style Google par défaut)', () {
      expect(resolveMapStyle(Brightness.light), isNull);
    });
    test('dark → kGoogleNightMapStyle', () {
      expect(resolveMapStyle(Brightness.dark), kGoogleNightMapStyle);
    });
  });

  test('kGoogleNightMapStyle is valid JSON (a non-empty array)', () {
    final decoded = jsonDecode(kGoogleNightMapStyle);
    expect(decoded, isA<List>());
    expect((decoded as List), isNotEmpty);
  });
}
