import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  String status = 'ACTIVE',
  double totalKg = 20,
  double availableKg = 13,
  String? capacityUnit,
  int pendingBidCount = 0,
  int confirmedParcelCount = 0,
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
  String? departureFlag,
  String? arrivalFlag,
  String pricingMode = 'KG',
  double pricePerKg = 8.0,
  List<Map<String, dynamic>>? priceGridItems,
  String currency = 'EUR',
}) {
  return AnnouncementModel.fromJson({
    'id': 'a1',
    'travelerId': 't1',
    'departureCity': departureCity,
    'arrivalCity': arrivalCity,
    'departureFlag': ?departureFlag,
    'arrivalFlag': ?arrivalFlag,
    'departureDate': DateTime.now()
        .add(const Duration(days: 3))
        .toIso8601String(),
    'totalKg': totalKg,
    'availableKg': availableKg,
    'pricePerKg': pricePerKg,
    'pricingMode': pricingMode,
    'priceGridItems': ?priceGridItems,
    'currency': currency,
    'status': status,
    'capacityUnit': ?capacityUnit,
    'pendingBidCount': pendingBidCount,
    'confirmedParcelCount': confirmedParcelCount,
    'createdAt': '2024-01-01T00:00:00Z',
    'updatedAt': '2024-01-01T00:00:00Z',
  });
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche route, drapeaux, progression et prix', (tester) async {
    await tester.pumpWidget(
      _wrap(TripCard(announcement: _announcement(), onTap: () {}, index: 0)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('🇫🇷'), findsOneWidget);
    expect(find.text('🇸🇳'), findsOneWidget);
    expect(find.textContaining('7 kg vendus sur 20 kg'), findsOneWidget);
    expect(find.textContaining('13 kg'), findsWidgets);
    expect(find.textContaining('8'), findsWidgets);
    expect(find.textContaining('€'), findsWidgets);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('affiche le prix dans la devise du trajet, pas toujours en EUR', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(currency: 'CAD'),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('CA\$'), findsOneWidget);
    expect(find.textContaining('8 €'), findsNothing);
  });

  testWidgets('mode grille (MIXED) : affiche "dès X €", jamais "0 € / kg"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(
            pricingMode: 'MIXED',
            pricePerKg: 0,
            priceGridItems: const [
              {
                'id': 'g1',
                'label': '1 valise 23kg',
                'unitPriceNet': 25.0,
                'unitPriceDisplay': 28.0,
              },
              {
                'id': 'g2',
                'label': '1 valise 32kg',
                'unitPriceNet': 35.0,
                'unitPriceDisplay': 39.0,
              },
            ],
          ),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('dès 25'), findsOneWidget);
    expect(find.textContaining('0 €'), findsNothing);
    expect(find.textContaining('/ kg'), findsNothing);
  });

  testWidgets('mode grille sans items : libellé "Grille tarifaire"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(pricingMode: 'MIXED', pricePerKg: 0),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Grille tarifaire'), findsOneWidget);
    expect(find.textContaining('0 €'), findsNothing);
  });

  testWidgets('utilise le drapeau backend pour une ville hors map (New York)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(
            departureCity: 'New York',
            arrivalCity: 'Tokyo',
            departureFlag: '🇺🇸',
            arrivalFlag: '🇯🇵',
          ),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('🇺🇸'), findsOneWidget);
    expect(find.text('🇯🇵'), findsOneWidget);
  });

  testWidgets('le drapeau backend prime sur la map hardcodée des villes', (
    tester,
  ) async {
    // Paris est dans la map → 🇫🇷, mais le backend renvoie 🇺🇸 : on doit
    // afficher la valeur backend, pas celle de la map.
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(departureFlag: '🇺🇸'),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('🇺🇸'), findsOneWidget);
    expect(find.text('🇫🇷'), findsNothing);
    // Pas de flag backend pour l'arrivée → fallback map → 🇸🇳
    expect(find.text('🇸🇳'), findsOneWidget);
  });

  testWidgets('carte terminée : footer condensé, pas de progression', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(status: 'COMPLETED', availableKg: 0),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Terminé'), findsOneWidget);
    expect(find.textContaining('vendus sur'), findsNothing);
    expect(find.textContaining('20 kg vendus'), findsOneWidget);
    expect(find.textContaining('160'), findsOneWidget);
    expect(find.textContaining('gagnés'), findsOneWidget);
  });

  // ── KG_FREE tests ──────────────────────────────────────────────────────────

  testWidgets(
    'KG_FREE actif : affiche "Kg libre", cache la barre de progression et vendus sur',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            announcement: _announcement(
              capacityUnit: 'KG_FREE',
              availableKg: 1,
            ),
            onTap: () {},
            index: 0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Should show "Kg libre" instead of raw kg numbers
      expect(find.text('Kg libre'), findsOneWidget);

      // Must NOT show the "vendus sur" progress label
      expect(find.textContaining('vendus sur'), findsNothing);

      // Must NOT show "1 kg disponibles" (raw availableKg)
      expect(find.textContaining('1 kg disponibles'), findsNothing);
    },
  );

  testWidgets(
    'KG_FREE terminé : footer condensé affiche "Kg libre" au lieu de vendus',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            announcement: _announcement(
              status: 'COMPLETED',
              capacityUnit: 'KG_FREE',
              availableKg: 0,
              totalKg: 1,
            ),
            onTap: () {},
            index: 0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Terminé'), findsOneWidget);
      // Must NOT show "{kg} vendus" for KG_FREE past trips
      expect(find.textContaining('vendus'), findsNothing);
      // Should show "Kg libre" instead
      expect(find.text('Kg libre'), findsOneWidget);
    },
  );

  // ── Demandes stats row ───────────────────────────────────────────────────

  testWidgets(
    'trajet actif : affiche les chips acceptées + en attente (pluriel)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            announcement: _announcement(
              confirmedParcelCount: 2,
              pendingBidCount: 3,
            ),
            onTap: () {},
            index: 0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('2 acceptées'), findsOneWidget);
      expect(find.text('3 en attente'), findsOneWidget);
    },
  );

  testWidgets('trajet actif : aucun chip quand les deux compteurs sont à 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(TripCard(announcement: _announcement(), onTap: () {}, index: 0)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('acceptée'), findsNothing);
    expect(find.textContaining('en attente'), findsNothing);
  });

  testWidgets('trajet actif : singulier "1 acceptée" (pas "acceptées")', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(confirmedParcelCount: 1),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('1 acceptée'), findsOneWidget);
    expect(find.text('1 acceptées'), findsNothing);
  });

  testWidgets(
    'trajet terminé : la ligne de stats est absente même si compteurs > 0',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          TripCard(
            announcement: _announcement(
              status: 'COMPLETED',
              availableKg: 0,
              confirmedParcelCount: 2,
              pendingBidCount: 3,
            ),
            onTap: () {},
            index: 0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('acceptée'), findsNothing);
      expect(find.textContaining('en attente'), findsNothing);
    },
  );

  testWidgets('affiche le badge Brouillon pour un trajet DRAFT', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(status: 'DRAFT'),
          onTap: () {},
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Brouillon'), findsOneWidget);
  });

  testWidgets('onTap déclenché', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        TripCard(
          announcement: _announcement(),
          onTap: () => tapped = true,
          index: 0,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(TripCard));
    expect(tapped, isTrue);
  });
}
