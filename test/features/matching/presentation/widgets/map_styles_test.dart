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

  // FLUTTER-FF : à faible zoom, la vue monde n'est que terre et eau. Une base
  // presque noire se confondait avec une carte qui n'a pas chargé.
  group('kGoogleNightMapStyle — lisible à faible zoom', () {
    final rules = (jsonDecode(kGoogleNightMapStyle) as List)
        .cast<Map<String, dynamic>>();

    Color colorOf(bool Function(Map<String, dynamic>) where) {
      final rule = rules.firstWhere(where);
      final stylers = (rule['stylers'] as List).cast<Map<String, dynamic>>();
      final hex =
          stylers.firstWhere((s) => s.containsKey('color'))['color'] as String;
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }

    final land = colorOf(
      (r) => r['featureType'] == null && r['elementType'] == 'geometry',
    );
    final water = colorOf(
      (r) => r['featureType'] == 'water' && r['elementType'] == 'geometry.fill',
    );

    test('la terre n\'est pas quasi noire', () {
      expect(land.computeLuminance(), greaterThan(0.015));
    });

    test('l\'eau n\'est pas quasi noire', () {
      expect(water.computeLuminance(), greaterThan(0.01));
    });

    test('terre et eau restent distinguables', () {
      expect(land, isNot(water));
      expect(
        (land.computeLuminance() - water.computeLuminance()).abs(),
        greaterThan(0.002),
      );
    });

    test('les frontières de pays sont visibles', () {
      expect(
        rules.any(
          (r) =>
              r['featureType'] == 'administrative.country' &&
              (r['stylers'] as List).any(
                (s) => (s as Map)['visibility'] == 'on',
              ),
        ),
        isTrue,
      );
    });
  });
}
