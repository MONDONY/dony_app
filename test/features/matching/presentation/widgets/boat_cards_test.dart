// Cartes de résultat d'un trajet bateau : `TravelerCard` (recherche, feuilles,
// alternatives) et `TripCard` (Mes trajets, favoris). Un trajet au m³ n'affiche
// jamais de kilos (`availableKg` y vaut 0 par repli), ni ne se montre
// « complet » faute de kilos : il dit son volume restant, son prix au m³ et une
// fourchette d'arrivée.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/plane_icon_expectations.dart';
import 'trip_owner/trip_card_harness.dart' show loadAppFonts;

DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

/// Jour tel que la carte l'écrit : l'année seulement si elle n'est pas
/// l'année courante.
String _day(DateTime d, String locale) {
  final format = d.year == DateTime.now().year
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  return format.format(d);
}

AnnouncementModel _boat({
  bool perM3 = true,
  double? availableVolumeM3 = 0.4,
  double? volumeCapacityM3 = 12,
  double? pricePerM3Display = 600,
  double? pricePerM3 = 500,
  DateTime? arrivalDate,
  DateTime? arrivalDateMax,
  String status = 'ACTIVE',
  double availableKg = 0,
  double totalKg = 0,
  double? pricePerKg,
  TransportMode? mode = TransportMode.boat,
  String currency = 'EUR',
}) => AnnouncementModel(
  id: 'boat-1',
  travelerId: 'trav-1',
  departureCity: 'Marseille',
  arrivalCity: 'Dakar',
  departureDate: _inDays(20),
  arrivalDate: arrivalDate ?? _inDays(45),
  arrivalDateMax: arrivalDateMax ?? _inDays(60),
  availableKg: availableKg,
  totalKg: totalKg,
  pricePerKg: pricePerKg,
  pricePerKgDisplay: pricePerKg,
  transportMode: mode,
  status: status,
  currency: currency,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  volumeCapacityM3: perM3 ? volumeCapacityM3 : null,
  availableVolumeM3: perM3 ? availableVolumeM3 : null,
  pricePerM3Display: perM3 ? pricePerM3Display : null,
  pricePerM3: perM3 ? pricePerM3 : null,
  traveler: const TravelerProfile(
    id: 'trav-1',
    displayName: 'Moussa Diop',
    averageRating: 4.8,
    totalTrips: 12,
    gpPro: true,
    kycVerified: true,
  ),
);

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

TravelerCard _traveler(AnnouncementModel a, {bool compact = false}) =>
    TravelerCard(
      announcement: a,
      index: 0,
      isOwnAnnouncement: false,
      compact: compact,
      onTap: () {},
    );

Future<void> _pumpCard(
  WidgetTester tester,
  Widget card, {
  double? width,
}) async {
  await tester.pumpWidget(_wrap(card, width: width ?? 400));
  // `flutter_animate` : plusieurs pas plutôt qu'un `pumpAndSettle`.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

Finder _text(String value) => find.text(value);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('TravelerCard bateau', () {
    for (final compact in [false, true]) {
      testWidgets('boatCard_showsRangeAndVolume : fourchette, volume, prix au '
          'm³, icône du bateau, aucun kilo (compact $compact)', (tester) async {
        final a = _boat();
        await _pumpCard(tester, _traveler(a, compact: compact));

        expect(tester.takeException(), isNull);
        expect(
          _text(
            'Arrivée estimée du ${_day(a.arrivalDate!, 'fr')} au '
            '${_day(a.arrivalDateMax!, 'fr')}',
          ),
          findsOneWidget,
        );
        expect(_text('0,4 m³ restants'), findsOneWidget);
        expect(find.textContaining('600'), findsOneWidget);
        expect(find.textContaining('/m³'), findsOneWidget);
        expect(find.textContaining('/kg'), findsNothing);
        expect(find.textContaining(' kg'), findsNothing);
        expect(_text('Complet'), findsNothing);
        // Icône du mode sur la fourchette et sur le trait du trajet.
        expect(
          find.descendant(
            of: find.byKey(const Key('traveler-card-boat-arrival')),
            matching: findDonyIcon('ship'),
          ),
          findsOneWidget,
        );
        expect(findDonyIcon('ship'), findsWidgets);
        expectNoPlaneIcon(tester);
        // Pas de prix converti : aucun équivalent au m³ n'est servi.
        expect(find.textContaining('≈'), findsNothing);
      });
    }

    testWidgets('volume restant arrondi vers le bas, jamais vers le haut', (
      tester,
    ) async {
      await _pumpCard(tester, _traveler(_boat(availableVolumeM3: 0.355)));
      expect(_text('0,35 m³ restants'), findsOneWidget);
      expect(_text('0,4 m³ restants'), findsNothing);
    });

    testWidgets('un trajet au m³ sans kilos n\'est pas « complet »', (
      tester,
    ) async {
      // availableKg = 0 par repli : la carte ne lit que le statut du serveur.
      await _pumpCard(tester, _traveler(_boat()));
      expect(_text('Complet'), findsNothing);
      final opacity = tester.widget<Opacity>(
        find.byKey(const Key('traveler-card-opacity')),
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('statut FULL du serveur : pastille « Complet » gardée', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _traveler(_boat(status: 'FULL', availableVolumeM3: 0)),
      );
      expect(_text('Complet'), findsOneWidget);
    });

    testWidgets('date d\'arrivée seule : « Arrivée estimée le … »', (
      tester,
    ) async {
      final arrival = _inDays(50);
      final a = AnnouncementModel(
        id: 'boat-2',
        travelerId: 't',
        departureCity: 'Marseille',
        arrivalCity: 'Dakar',
        departureDate: _inDays(20),
        arrivalDate: arrival,
        availableKg: 0,
        totalKg: 0,
        transportMode: TransportMode.boat,
        status: 'ACTIVE',
        createdAt: DateTime(2026, 10),
        updatedAt: DateTime(2026, 10),
        volumeCapacityM3: 5,
        availableVolumeM3: 5,
        pricePerM3Display: 300,
      );
      await _pumpCard(tester, _traveler(a));
      expect(
        _text('Arrivée estimée le ${_day(arrival, 'fr')}'),
        findsOneWidget,
      );
    });

    testWidgets('prix au m³ non servi : « Prix indisponible »', (tester) async {
      await _pumpCard(
        tester,
        _traveler(_boat(pricePerM3Display: null, pricePerM3: null)),
      );
      expect(_text('Prix indisponible'), findsOneWidget);
      expect(find.textContaining('/m³'), findsNothing);
    });

    testWidgets('bateau au kilo : kilos, prix au kilo et fourchette gardés', (
      tester,
    ) async {
      final a = _boat(
        perM3: false,
        availableKg: 300,
        totalKg: 500,
        pricePerKg: 4,
      );
      await _pumpCard(tester, _traveler(a));
      expect(find.textContaining('/kg'), findsOneWidget);
      expect(find.textContaining('300'), findsWidgets);
      expect(find.textContaining('m³'), findsNothing);
      expect(
        _text(
          'Arrivée estimée du ${_day(a.arrivalDate!, 'fr')} au '
          '${_day(a.arrivalDateMax!, 'fr')}',
        ),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('planeFiltersUnchanged : avion et route, ni fourchette ni '
        'volume', (tester) async {
      for (final mode in [TransportMode.plane, TransportMode.car, null]) {
        final a = _boat(
          perM3: false,
          mode: mode,
          availableKg: 20,
          totalKg: 23,
          pricePerKg: 8,
        );
        await _pumpCard(tester, _traveler(a));
        expect(
          find.byKey(const Key('traveler-card-boat-arrival')),
          findsNothing,
          reason: '$mode',
        );
        expect(find.textContaining('Arrivée estimée'), findsNothing);
        expect(find.textContaining('/kg'), findsOneWidget);
        expect(find.textContaining('m³'), findsNothing);
      }
    });

    for (final english in [false, true]) {
      testWidgets('360 dp ${english ? 'EN' : 'FR'} : carte bateau sans '
          'débordement, fourchette lisible', (tester) async {
        if (english) useEnglish();
        await loadAppFonts();
        final a = _boat(volumeCapacityM3: 1234.5, availableVolumeM3: 1234.5);
        for (final compact in [false, true]) {
          await _pumpCard(tester, _traveler(a, compact: compact), width: 360);
          expect(tester.takeException(), isNull);
          final locale = english ? 'en' : 'fr';
          final line = english
              ? 'Estimated arrival ${_day(a.arrivalDate!, locale)} to '
                    '${_day(a.arrivalDateMax!, locale)}'
              : 'Arrivée estimée du ${_day(a.arrivalDate!, locale)} au '
                    '${_day(a.arrivalDateMax!, locale)}';
          expect(_text(line), findsOneWidget);
          final grouped = NumberFormat('#,##0.##', locale).format(1234.5);
          expect(
            _text(english ? '$grouped m³ left' : '$grouped m³ restants'),
            findsOneWidget,
          );
          // Une ligne de plus au plus : le texte ne se coupe pas en deux.
          expect(tester.getSize(_text(line)).height, lessThan(14 * 1.5 * 2));
        }
      });

      testWidgets('360 dp ${english ? 'EN' : 'FR'} : fourchette d\'années '
          'différentes jamais coupée d\'une ellipse', (tester) async {
        if (english) useEnglish();
        await loadAppFonts();
        final nextYear = DateTime.now().year + 1;
        final a = _boat(
          arrivalDate: DateTime(nextYear, 1, 12),
          arrivalDateMax: DateTime(nextYear + 1, 2, 25),
        );
        final locale = english ? 'en' : 'fr';
        final line = english
            ? 'Estimated arrival ${_day(a.arrivalDate!, locale)} to '
                  '${_day(a.arrivalDateMax!, locale)}'
            : 'Arrivée estimée du ${_day(a.arrivalDate!, locale)} au '
                  '${_day(a.arrivalDateMax!, locale)}';
        for (final compact in [false, true]) {
          await _pumpCard(tester, _traveler(a, compact: compact), width: 360);
          expect(tester.takeException(), isNull);
          expect(_text(line), findsOneWidget, reason: 'compact=$compact');
          final paragraph = tester.renderObject<RenderParagraph>(
            find
                .descendant(of: _text(line), matching: find.byType(RichText))
                .first,
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.maxLines,
            isNull,
            reason: 'compact=$compact : ni ligne unique ni ellipse',
          );
          expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
        }
      });
    }
  });

  group('TripCard bateau (Mes trajets, favoris)', () {
    testWidgets('favoris (vue expéditeur) : le prix au m³ frais inclus, '
        'jamais le net', (tester) async {
      final cubit = FavoriteIdsCubit(_MockFavoriteRepository())
        ..emitSeed(trips: {}, requests: {});
      addTearDown(cubit.close);
      await _pumpCard(
        tester,
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: TripCard(
            announcement: _boat(availableVolumeM3: 4.5),
            onTap: () {},
            index: 0,
            showFavorite: true,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('600'), findsOneWidget);
      expect(find.textContaining('500'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('au m³ : volume vendu, volume restant, prix au m³, aucun '
        'kilo', (tester) async {
      final a = _boat(availableVolumeM3: 4.5);
      await _pumpCard(
        tester,
        TripCard(announcement: a, onTap: () {}, index: 0),
      );

      expect(tester.takeException(), isNull);
      expect(_text('7,5 m³ vendus sur 12 m³'), findsOneWidget);
      expect(_text('4,5 m³ restants'), findsOneWidget);
      expect(find.textContaining('/m³'), findsOneWidget);
      // Le voyageur lit son prix net.
      expect(find.textContaining('500'), findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
      expect(find.textContaining('Grille tarifaire'), findsNothing);
      expectNoPlaneIcon(tester);
      expect(findDonyIcon('ship'), findsOneWidget);
    });

    testWidgets('vendu et restant : mêmes décimales, ils somment la capacité', (
      tester,
    ) async {
      final a = _boat(availableVolumeM3: 0.29);
      await _pumpCard(
        tester,
        TripCard(announcement: a, onTap: () {}, index: 0),
      );
      expect(_text('11,71 m³ vendus sur 12 m³'), findsOneWidget);
      expect(_text('0,29 m³ restants'), findsOneWidget);

      final b = _boat(availableVolumeM3: 8.2);
      await _pumpCard(
        tester,
        TripCard(announcement: b, onTap: () {}, index: 0),
      );
      expect(_text('3,8 m³ vendus sur 12 m³'), findsOneWidget);
      expect(_text('8,2 m³ restants'), findsOneWidget);
    });

    testWidgets('trajet passé au m³ : volume vendu, jamais « 0 kg vendus »', (
      tester,
    ) async {
      final a = _boat(
        status: 'COMPLETED',
        volumeCapacityM3: 10,
        availableVolumeM3: 2,
      );
      await _pumpCard(
        tester,
        TripCard(announcement: a, onTap: () {}, index: 0),
      );
      expect(find.textContaining('8 m³'), findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
    });

    testWidgets('au kilo : barre et pied en kilos, inchangés', (tester) async {
      final a = _boat(
        perM3: false,
        availableKg: 13,
        totalKg: 20,
        pricePerKg: 8,
      );
      await _pumpCard(
        tester,
        TripCard(announcement: a, onTap: () {}, index: 0),
      );
      expect(find.textContaining('/ kg'), findsOneWidget);
      expect(find.textContaining('m³'), findsNothing);
      expect(find.textContaining('13'), findsWidgets);
    });
  });

  group('formats', () {
    testWidgets('formatVolumeRemainingM3 : deux décimales, vers le bas', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) {
              final l = context.l10n;
              expect(formatVolumeRemainingM3(l, 0.4), '0,4 m³');
              expect(formatVolumeRemainingM3(l, 0.399), '0,39 m³');
              expect(formatVolumeRemainingM3(l, 0), '0 m³');
              expect(
                formatVolumeRemainingM3(l, 1234.5),
                '${NumberFormat('#,##0.##', 'fr').format(1234.5)} m³',
              );
              expect(formatVolumeRemainingM3(l, 0.0099), '0 m³');
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('tripBoatArrivalText : année seulement si elle change', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) {
              l = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      final now = DateTime(2026, 11, 13);
      AnnouncementModel trip({DateTime? max, DateTime? arrival}) => _boat(
        arrivalDate: arrival ?? DateTime(2026, 12, 12),
        arrivalDateMax: max ?? DateTime(2027, 1, 5),
      );
      expect(
        tripBoatArrivalText(l, trip(), now: now),
        'Arrivée estimée du 12 déc. au 5 janv. 2027',
      );
      expect(
        tripBoatArrivalText(l, trip(max: DateTime(2026, 12, 12)), now: now),
        'Arrivée estimée le 12 déc.',
      );
      // Pas bateau, pas de ligne.
      expect(
        tripBoatArrivalText(l, _boat(mode: TransportMode.plane), now: now),
        isNull,
      );
      expect(tripBoatArrivalText(l, _boat(mode: null), now: now), isNull);
    });
  });
}
