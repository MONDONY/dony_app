import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/features/matching/presentation/widgets/trip_suitcase_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../a11y/contrast_helpers.dart';

TripCapacity _capacity({required double total, required double available}) =>
    TripCapacity.fromAnnouncement(
      AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 6, 15),
        availableKg: available,
        totalKg: total,
        capacityUnit: 'SUITCASE_23KG',
        pricePerKg: 12,
        status: 'ACTIVE',
        createdAt: DateTime(2026, 5),
        updatedAt: DateTime(2026, 5),
      ),
    )!;

void main() {
  Future<void> pump(WidgetTester tester, TripCapacity capacity) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TripSuitcaseGauge(capacity: capacity)),
        ),
      );

  testWidgets('une ligne par valise avec ses kilos restants', (tester) async {
    await pump(tester, _capacity(total: 46, available: 32));
    await tester.pumpAndSettle();

    expect(find.text('V1'), findsOneWidget);
    expect(find.text('V2'), findsOneWidget);
    expect(find.text('9 / 23 kg'), findsOneWidget);
    expect(find.text('23 / 23 kg'), findsOneWidget);
    expect(find.text('Restant'), findsOneWidget);
    expect(find.text('Réservé'), findsOneWidget);
  });

  testWidgets('une valise sans kilo libre est « pleine »', (tester) async {
    await pump(tester, _capacity(total: 46, available: 16));
    await tester.pumpAndSettle();

    expect(find.text('pleine'), findsOneWidget);
    expect(find.text('16 / 23 kg'), findsOneWidget);
  });

  group('barre bleue des kilos libres réellement peinte', () {
    Size track(WidgetTester tester, int i) =>
        tester.getSize(find.byKey(Key('trip-suitcase-track-$i')));
    Size free(WidgetTester tester, int i) =>
        tester.getSize(find.byKey(Key('trip-suitcase-free-$i')));
    Color freeColor(WidgetTester tester, int i) => tester
        .widget<ColoredBox>(find.byKey(Key('trip-suitcase-free-$i')))
        .color;

    testWidgets('largeur = kilos libres / taille de la valise, toute la '
        'hauteur de la piste, calée à gauche', (tester) async {
      // V1 : 9 kg libres sur 23 ; V2 : entièrement libre.
      await pump(tester, _capacity(total: 46, available: 32));
      await tester.pumpAndSettle();
      final w = track(tester, 1).width;
      expect(w, greaterThan(0));
      expect(free(tester, 1).height, 12);
      expect(free(tester, 1).width, closeTo(w * 9 / 23, 0.01));
      expect(
        tester.getTopLeft(find.byKey(const Key('trip-suitcase-free-1'))).dx,
        tester.getTopLeft(find.byKey(const Key('trip-suitcase-track-1'))).dx,
      );
      // Valise entièrement libre : toute la piste en bleu.
      expect(free(tester, 2).height, 12);
      expect(free(tester, 2).width, closeTo(track(tester, 2).width, 0.01));
      final context = tester.element(
        find.byKey(const Key('trip-suitcase-free-1')),
      );
      expect(freeColor(tester, 1), Theme.of(context).colorScheme.primary);
    });

    testWidgets('valise pleine : aucune largeur bleue', (tester) async {
      // V1 pleine, V2 16 / 23.
      await pump(tester, _capacity(total: 46, available: 16));
      await tester.pumpAndSettle();
      expect(free(tester, 1).width, 0);
      expect(free(tester, 2).height, 12);
      expect(
        free(tester, 2).width,
        closeTo(track(tester, 2).width * 16 / 23, 0.01),
      );
    });

    test('bleu lisible sur la piste grise, thèmes clair et sombre', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final cs = theme.colorScheme;
        // Élément graphique (WCAG 1.4.11) : 3:1 au moins.
        expectContrast(cs.primary, cs.outline, 3, '${theme.brightness}');
      }
    });
  });
}
