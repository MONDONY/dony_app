import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/billet/trip_billet_card.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_header.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _trip({
  TransportMode? mode = TransportMode.car,
  String capacityUnit = 'KG_EXACT',
  double availableKg = 1200,
  double totalKg = 1500,
  ItemSize? size,
  double? maxParcelKg,
  DateTime? arrival,
}) => AnnouncementModel(
  id: 'a1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  departureDate: DateTime(2026, 11, 14, 18),
  arrivalDate: arrival,
  availableKg: availableKg,
  totalKg: totalKg,
  capacityUnit: capacityUnit,
  pricePerKg: 5,
  status: 'ACTIVE',
  transportMode: mode,
  maxItemSize: size,
  maxParcelWeightKg: maxParcelKg,
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
  traveler: const TravelerProfile(
    id: 't1',
    displayName: 'Awa Konaté',
    averageRating: 4.7,
    totalTrips: 21,
    kycVerified: true,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppL10n.fr,
  double width = 360,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  // La pastille d'état de TripCard pulse sans fin : pas de pumpAndSettle.
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(seconds: 1));
}

TravelerCard _card(AnnouncementModel a, {bool compact = false}) => TravelerCard(
  announcement: a,
  index: 0,
  isOwnAnnouncement: false,
  compact: compact,
  onTap: () {},
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  for (final compact in [false, true]) {
    final layout = compact ? 'compacte' : 'normale';
    group('TravelerCard $layout', () {
      testWidgets('route : « 1 200 kg dispo, jusqu\'à taille L » et '
          '« 5 jours de route »', (tester) async {
        await _pump(
          tester,
          _card(
            _trip(size: ItemSize.l, arrival: DateTime(2026, 11, 19)),
            compact: compact,
          ),
        );
        expect(find.textContaining('dispo, jusqu\'à taille L'), findsOneWidget);
        expect(find.textContaining('1 200 kg dispo'), findsOneWidget);
        expect(find.textContaining('5 jours de route'), findsOneWidget);
        expect(find.textContaining('→'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('avion : affichage inchangé, ni taille ni durée', (
        tester,
      ) async {
        await _pump(
          tester,
          _card(
            _trip(
              mode: TransportMode.plane,
              availableKg: 23,
              totalKg: 30,
              size: ItemSize.m,
              arrival: DateTime(2026, 11, 15),
            ),
            compact: compact,
          ),
        );
        expect(find.text('23 kg dispo'), findsOneWidget);
        expect(find.textContaining('taille'), findsNothing);
        expect(find.textContaining('jour'), findsNothing);
        expect(find.textContaining('→'), findsNothing);
      });

      testWidgets('route sans taille (ancien trajet) : kilos seuls', (
        tester,
      ) async {
        await _pump(tester, _card(_trip(), compact: compact));
        expect(find.textContaining('1 200 kg dispo'), findsOneWidget);
        expect(find.textContaining('taille'), findsNothing);
        expect(find.textContaining('jours de route'), findsNothing);
      });

      testWidgets('kilo libre route : « Kilos libres, jusqu\'à taille XL »', (
        tester,
      ) async {
        await _pump(
          tester,
          _card(
            _trip(capacityUnit: 'KG_FREE', size: ItemSize.xl),
            compact: compact,
          ),
        );
        expect(find.text('Kilos libres, jusqu\'à taille XL'), findsOneWidget);
      });

      for (final locale in [AppL10n.fr, AppL10n.en]) {
        testWidgets(
          '360 dp ${locale.languageCode} : 999 999 kg, taille et durée sans '
          'débordement',
          (tester) async {
            await _pump(
              tester,
              _card(
                _trip(
                  availableKg: 999999,
                  totalKg: 999999,
                  size: ItemSize.xl,
                  arrival: DateTime(2026, 12, 20),
                ),
                compact: compact,
              ),
              locale: locale,
            );
            expect(tester.takeException(), isNull);
            expect(
              find.textContaining(
                locale == AppL10n.fr ? 'jusqu\'à taille XL' : 'up to size XL',
              ),
              findsOneWidget,
            );
          },
        );
      }
    });
  }

  group('TripCard (mes trajets)', () {
    testWidgets('route : pied « 1 200 kg disponibles, jusqu\'à taille M »', (
      tester,
    ) async {
      await _pump(
        tester,
        TripCard(
          index: 0,
          announcement: _trip(size: ItemSize.m),
          onTap: () {},
        ),
        settle: false,
      );
      expect(
        find.textContaining('disponibles, jusqu\'à taille M'),
        findsOneWidget,
      );
      expect(find.textContaining('1 200 kg'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avion : pied inchangé', (tester) async {
      await _pump(
        tester,
        TripCard(
          index: 0,
          announcement: _trip(
            mode: TransportMode.plane,
            availableKg: 23,
            totalKg: 30,
          ),
          onTap: () {},
        ),
        settle: false,
      );
      expect(find.text('23 kg disponibles'), findsOneWidget);
      expect(find.textContaining('taille'), findsNothing);
    });
  });

  group('Fiche trajet (billet)', () {
    testWidgets('route : « 20 kg max par colis » et taille dans la puce', (
      tester,
    ) async {
      await _pump(
        tester,
        TripBilletCard(announcement: _trip(size: ItemSize.l, maxParcelKg: 20)),
      );
      expect(find.text('20 kg max par colis'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('detail-capacity-chip')),
          matching: find.textContaining('jusqu\'à taille L'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('anglais : « 20 kg max per parcel »', (tester) async {
      await _pump(
        tester,
        TripBilletCard(announcement: _trip(size: ItemSize.l, maxParcelKg: 20)),
        locale: AppL10n.en,
      );
      expect(find.text('20 kg max per parcel'), findsOneWidget);
      expect(find.textContaining('up to size L'), findsOneWidget);
    });

    testWidgets('sans poids max ni taille, ou en avion : rien de plus', (
      tester,
    ) async {
      await _pump(tester, TripBilletCard(announcement: _trip()));
      expect(find.byKey(const Key('detail-max-parcel-chip')), findsNothing);
      await _pump(
        tester,
        TripBilletCard(
          announcement: _trip(
            mode: TransportMode.plane,
            maxParcelKg: 20,
            size: ItemSize.l,
          ),
        ),
      );
      expect(find.byKey(const Key('detail-max-parcel-chip')), findsNothing);
      expect(find.textContaining('taille'), findsNothing);
    });

    testWidgets('360 dp fr et en, 999 999 kg : aucun débordement', (
      tester,
    ) async {
      for (final locale in [AppL10n.fr, AppL10n.en]) {
        await _pump(
          tester,
          TripBilletCard(
            announcement: _trip(
              availableKg: 999999,
              totalKg: 999999,
              size: ItemSize.xl,
              maxParcelKg: 999999,
            ),
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('En-tête du trajet vu par son voyageur', () {
    testWidgets('route : tonnes groupées, taille et poids max', (tester) async {
      await _pump(
        tester,
        TripOwnerHeader(a: _trip(size: ItemSize.l, maxParcelKg: 120)),
      );
      expect(find.text('1 200 kg'), findsOneWidget);
      expect(
        find.text('Jusqu\'à taille L  ·  120 kg max par colis'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('avion : pas de ligne de limites', (tester) async {
      await _pump(
        tester,
        TripOwnerHeader(
          a: _trip(mode: TransportMode.plane, availableKg: 23, totalKg: 30),
        ),
      );
      expect(find.byKey(const Key('trip-owner-parcel-limits')), findsNothing);
      expect(find.text('23 kg'), findsOneWidget);
    });
  });
}
