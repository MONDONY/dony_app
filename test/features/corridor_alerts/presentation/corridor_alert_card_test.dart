import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _now = DateTime(2026, 9, 4);

CorridorAlertModel _alert({
  AlertDirection direction = AlertDirection.senderWantsTrips,
  bool active = true,
  int matches = 0,
  int fresh = 0,
  DateTime? dateFrom,
  DateTime? dateTo,
  double? minWeightKg,
  List<String> categories = const [],
  int? radiusKm,
  String? centerLabel,
}) => CorridorAlertModel(
  id: 'a1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  direction: direction,
  active: active,
  matchCount: matches,
  newMatchCount: fresh,
  dateFrom: dateFrom,
  dateTo: dateTo,
  minWeightKg: minWeightKg,
  contentCategories: categories,
  centerLat: radiusKm != null ? 48.85 : null,
  centerLng: radiusKm != null ? 2.35 : null,
  radiusKm: radiusKm,
  centerLabel: centerLabel,
  createdAt: DateTime(2026, 6, 20),
);

class _Calls {
  int tap = 0;
  int menu = 0;
  int resume = 0;
  int extend = 0;
}

Widget _pump(CorridorAlertModel a, _Calls calls) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: CorridorAlertCard(
      alert: a,
      now: _now,
      onTap: () => calls.tap++,
      onMenu: () => calls.menu++,
      onResume: () => calls.resume++,
      onExtend: () => calls.extend++,
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('dateLabel', () {
    test('même mois : « 15 au 30 sept »', () {
      expect(
        CorridorAlertCard.dateLabel(
          _alert(
            dateFrom: DateTime(2026, 9, 15),
            dateTo: DateTime(2026, 9, 30),
          ),
        ),
        '15 au 30 sept.',
      );
    });

    test('mois différents, borne seule, aucune borne', () {
      expect(
        CorridorAlertCard.dateLabel(
          _alert(
            dateFrom: DateTime(2026, 9, 28),
            dateTo: DateTime(2026, 10, 3),
          ),
        ),
        '28 sept. au 3 oct.',
      );
      expect(
        CorridorAlertCard.dateLabel(_alert(dateFrom: DateTime(2026, 9, 15))),
        'À partir du 15 sept.',
      );
      expect(
        CorridorAlertCard.dateLabel(_alert(dateTo: DateTime(2026, 9, 30))),
        'Jusqu\'au 30 sept.',
      );
      expect(CorridorAlertCard.dateLabel(_alert()), 'Toute date');
    });

    test('weightLabel', () {
      expect(CorridorAlertCard.weightLabel(_alert()), 'Tout poids');
      expect(CorridorAlertCard.weightLabel(_alert(minWeightKg: 3)), '≥ 3 kg');
      expect(
        CorridorAlertCard.weightLabel(_alert(minWeightKg: 2.5)),
        '≥ 2.5 kg',
      );
    });
  });

  testWidgets('trajets, rien de neuf : corridor, chips, total, menu', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _pump(_alert(matches: 5, radiusKm: 20, centerLabel: 'Montreuil'), calls),
    );

    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('Toute date'), findsOneWidget);
    expect(find.text('≤ 20 km · Montreuil'), findsOneWidget);
    // Une alerte trajets ne parle jamais de poids.
    expect(find.textContaining('poids'), findsNothing);
    expect(find.text('Rien de neuf · 5 trajets au total'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alert-card-menu-a1')));
    expect(calls.menu, 1);
    await tester.tap(find.text('Paris → Dakar'));
    expect(calls.tap, 1);
  });

  testWidgets('colis : poids et catégories en chips, singulier « colis »', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pump(
        _alert(
          direction: AlertDirection.travelerWantsPackages,
          minWeightKg: 3,
          categories: const ['Documents', 'Vêtements'],
          matches: 1,
        ),
        _Calls(),
      ),
    );

    expect(find.text('≥ 3 kg'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('Rien de neuf · 1 colis au total'), findsOneWidget);
  });

  testWidgets('aucune correspondance → « Aucun trajet pour l\'instant »', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(_alert(), _Calls()));
    expect(find.text('Aucun trajet pour l\'instant'), findsOneWidget);
  });

  testWidgets('nouveautés : ligne ambre et « Voir » ouvre les matchs', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_pump(_alert(matches: 4, fresh: 2), calls));

    expect(find.text('2 nouveaux trajets'), findsOneWidget);
    final text = tester.widget<Text>(find.byKey(const Key('alert-card-news')));
    expect(text.style?.color, DonyColors.amberDark);

    await tester.tap(find.text('Voir'));
    expect(calls.tap, 1);
  });

  testWidgets('un seul nouveau : « 1 nouveau trajet »', (tester) async {
    await tester.pumpWidget(_pump(_alert(matches: 1, fresh: 1), _Calls()));
    expect(find.text('1 nouveau trajet'), findsOneWidget);
  });

  testWidgets('en pause : atténuée, « Reprendre » rappelle onResume', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(_pump(_alert(active: false, fresh: 3), calls));

    // La pause prime sur les nouveautés : l'utilisateur a coupé l'alerte.
    expect(find.text('En pause · aucune notification'), findsOneWidget);
    expect(find.textContaining('nouveaux'), findsNothing);
    expect(find.byType(Opacity), findsOneWidget);

    await tester.tap(find.text('Reprendre'));
    expect(calls.resume, 1);
  });

  testWidgets('expirée : date en avertissement, « Prolonger » édite', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _pump(_alert(dateTo: DateTime(2026, 8, 31), fresh: 2), calls),
    );

    expect(find.text('Expirée le 31 août'), findsOneWidget);
    expect(find.textContaining('nouveaux'), findsNothing);

    await tester.tap(find.text('Prolonger'));
    expect(calls.extend, 1);
  });

  testWidgets('dateTo aujourd\'hui : pas encore expirée', (tester) async {
    await tester.pumpWidget(
      _pump(_alert(dateTo: DateTime(2026, 9, 4), matches: 2), _Calls()),
    );
    expect(find.textContaining('Expirée'), findsNothing);
    expect(find.text('Jusqu\'au 4 sept.'), findsOneWidget);
  });
}
