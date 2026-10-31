// Tête de l'écran du trajet vu par son voyageur (TripOwnerHeader, ex-corps
// de détail) : billet, badges, pastilles kilos et prix, jauge des valises.
// Les sections déplacées sont testées sur leur nouvelle surface :
// lieux, dépôt (PROD-1R), paiements, conditions dans `trip_tile_sheets_test`,
// l'encart « espèces seules » dans `trip_todo_tiles_test` /
// `trip_todo_sheets_test`, les compteurs de colis (FLUTTER-HK) par la ligne
// Colis (`trip_parcels_line_test`) et le sheet « Colis »
// (`trip_activity_sheets_test`).
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_header.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../../helpers/l10n_test_helpers.dart';
import 'trip_card_harness.dart' show loadAppFonts;

AnnouncementModel _full() => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 12),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 7,
  status: 'ACTIVE',
  bidsCount: 5,
  confirmedParcelCount: 3,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  pickupAddress: const AddressData(
    label: '12 rue de Paris, 75001',
    lat: 48.85,
    lng: 2.35,
  ),
  deliveryAddress: const AddressData(
    label: 'Marché Sandaga, Dakar',
    lat: 14.67,
    lng: -17.43,
  ),
  handoverDeadline: DateTime(2026, 8, 10, 18),
  acceptedPaymentMethods: const {
    BidPaymentMethod.cash,
    BidPaymentMethod.stripe,
  },
  acceptedContentTypes: const ['Vêtements', 'Documents'],
  refusedTypes: const ['Liquides'],
  description: 'Pas de produits fragiles svp.',
);

AnnouncementModel _minimal() => AnnouncementModel(
  id: 'ann-2',
  travelerId: 'trav-1',
  departureCity: 'Lyon',
  arrivalCity: 'Bamako',
  departureDate: DateTime(2026, 9, 2),
  availableKg: 5,
  totalKg: 5,
  pricePerKg: 6,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  acceptedPaymentMethods: const <BidPaymentMethod>{},
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  Widget host(AnnouncementModel a) => MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    home: Scaffold(
      body: SingleChildScrollView(child: TripOwnerHeader(a: a)),
    ),
  );

  // FLUTTER-GE : escales affichées sur le détail, rien si non renseignées.
  testWidgets('escales : pastille si renseignées, absente sinon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AnnouncementModel.fromJson({
          'id': 'ann-3',
          'travelerId': 'trav-1',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'departureDate': DateTime(2026, 9, 2).toIso8601String(),
          'availableKg': 5,
          'totalKg': 5,
          'pricePerKg': 6,
          'status': 'ACTIVE',
          'transportMode': 'PLANE',
          'stopsCount': 2,
          'createdAt': DateTime(2026, 7).toIso8601String(),
          'updatedAt': DateTime(2026, 7).toIso8601String(),
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-stops-chip')), findsOneWidget);
    expect(find.text('2 escales et +'), findsOneWidget);

    await tester.pumpWidget(host(_minimal()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-stops-chip')), findsNothing);
  });

  AnnouncementModel suitcases({
    required String unit,
    required double total,
    required double available,
  }) => AnnouncementModel.fromJson({
    'id': 'ann-4',
    'travelerId': 'trav-1',
    'departureCity': 'Madrid',
    'arrivalCity': 'Abidjan',
    'departureDate': DateTime(2026, 9, 2).toIso8601String(),
    'availableKg': available,
    'totalKg': total,
    'capacityUnit': unit,
    'pricePerKg': 6,
    'status': 'ACTIVE',
    'createdAt': DateTime(2026, 7).toIso8601String(),
    'updatedAt': DateTime(2026, 7).toIso8601String(),
  });

  testWidgets('valises : jauge avec les kilos restants dans chacune', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(suitcases(unit: 'SUITCASE_23KG', total: 46, available: 32)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-suitcase-gauge')), findsOneWidget);
    expect(find.text('2 valises 23 kg'), findsWidgets);
    expect(find.text('9 / 23 kg'), findsOneWidget);
    expect(find.text('23 / 23 kg'), findsOneWidget);
  });

  testWidgets('personnalisé ou total non multiple : pas de jauge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(suitcases(unit: 'CUSTOM', total: 30, available: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-suitcase-gauge')), findsNothing);

    await tester.pumpWidget(
      host(suitcases(unit: 'SUITCASE_23KG', total: 50, available: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-suitcase-gauge')), findsNothing);
  });

  testWidgets('modèle complet ACTIVE → corridor, badge, pastilles ; les '
      'sections et les compteurs sont ailleurs', (tester) async {
    await tester.pumpWidget(host(_full()));
    await tester.pumpAndSettle();

    // Corridor
    expect(find.bySemanticsLabel('Paris → Dakar'), findsOneWidget);
    // Status badge ACTIF
    expect(find.text('● ACTIF'), findsOneWidget);
    // Pastilles kilos et prix.
    expect(find.text('10 kg'), findsOneWidget);
    expect(find.textContaining('€/kg'), findsOneWidget);
    // Sections passées dans les sheets « Votre trajet ».
    expect(find.text('LIEUX DE REMISE'), findsNothing);
    expect(find.text('DÉPÔT DES COLIS'), findsNothing);
    expect(find.text('PAIEMENTS ACCEPTÉS'), findsNothing);
    expect(find.text('CE QUE J\'ACCEPTE'), findsNothing);
    expect(find.text('NOTE AUX EXPÉDITEURS'), findsNothing);
    // Compteurs remplacés par les cartes Demandes et Colis.
    expect(find.byKey(const Key('parcel-stat-accepted')), findsNothing);
    expect(find.byKey(const Key('parcel-stat-pending')), findsNothing);
  });

  testWidgets('affiche le prix dans la devise du trajet, pas toujours en EUR', (
    tester,
  ) async {
    final announcement = AnnouncementModel(
      id: 'ann-3',
      travelerId: 'trav-1',
      departureCity: 'Toronto',
      arrivalCity: 'Paris',
      departureDate: DateTime(2026, 8, 19),
      availableKg: 15,
      totalKg: 15,
      pricePerKg: 8,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      acceptedPaymentMethods: const <BidPaymentMethod>{},
      currency: 'CAD',
    );

    await tester.pumpWidget(host(announcement));
    await tester.pumpAndSettle();

    expect(find.textContaining('CA\$'), findsOneWidget);
    expect(find.textContaining('8€/kg'), findsNothing);
  });

  testWidgets('modèle minimal → corridor et badge présents', (tester) async {
    await tester.pumpWidget(host(_minimal()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Lyon → Bamako'), findsOneWidget);
    expect(find.text('● ACTIF'), findsOneWidget);
  });

  testWidgets('date de départ proche → badge urgent affiché', (tester) async {
    final urgent = AnnouncementModel(
      id: 'ann-urgent',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now().add(const Duration(days: 1)),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      acceptedPaymentMethods: const <BidPaymentMethod>{},
    );
    await tester.pumpWidget(host(urgent));
    await tester.pumpAndSettle();

    expect(find.text('🔥 Urgent'), findsOneWidget);
  });

  testWidgets('date de départ lointaine → badge urgent absent', (tester) async {
    final notUrgent = AnnouncementModel(
      id: 'ann-not-urgent',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now().add(const Duration(days: 30)),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      acceptedPaymentMethods: const <BidPaymentMethod>{},
    );
    await tester.pumpWidget(host(notUrgent));
    await tester.pumpAndSettle();

    expect(find.text('🔥 Urgent'), findsNothing);
  });

  testWidgets('FLUTTER-PY : billet clair, statut et urgence dans son en-tête', (
    tester,
  ) async {
    await tester.pumpWidget(host(_full()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-billet-card')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('trip-billet-card')),
        matching: find.text('● ACTIF'),
      ),
      findsOneWidget,
    );
    // FLUTTER-Q1 : le billet ne prend plus la couleur du fond de l'écran,
    // il est bordé et porte un bandeau teinté en tête.
    final theme = AppTheme.light();
    final billet = tester.widget<Container>(
      find.byKey(const Key('trip-billet-card')),
    );
    final deco = billet.decoration! as BoxDecoration;
    expect(deco.color, isNot(theme.scaffoldBackgroundColor));
    expect(deco.color, theme.colorScheme.surface);
    expect(deco.border, isNotNull);
    expect(find.byKey(const Key('trip-billet-header')), findsOneWidget);
    // Plus aucun dégradé : l'ancien en-tête bleu nuit faisait « généré ».
    final gradients = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.gradient != null);
    expect(gradients, isEmpty);
  });

  testWidgets(
    'date de départ (billet) en français, jour de la semaine compris',
    (tester) async {
      final announcement = _minimal();
      await tester.pumpWidget(host(announcement));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          DateFormat.MMMEd('fr').format(announcement.departureDate),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('date de départ (billet) en anglais (ordre anglais)', (
    tester,
  ) async {
    useEnglish();
    final announcement = _minimal();
    await tester.pumpWidget(host(announcement));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        DateFormat.MMMEd('en').format(announcement.departureDate),
      ),
      findsOneWidget,
    );
  });

  // Situations qui ne changent que les pastilles (cible validée) : kilo
  // libre, grille de prix, prix absent ; et la ligne surplus.
  AnnouncementModel pills(Map<String, Object?> extra) =>
      AnnouncementModel.fromJson({
        'id': 'ann-5',
        'travelerId': 'trav-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'departureDate': DateTime(2026, 9, 2).toIso8601String(),
        'availableKg': 12,
        'totalKg': 20,
        'pricePerKg': 6,
        'status': 'ACTIVE',
        'createdAt': DateTime(2026, 7).toIso8601String(),
        'updatedAt': DateTime(2026, 7).toIso8601String(),
        ...extra,
      });

  testWidgets('kilo libre : « Kg libre », pas de jauge', (tester) async {
    await tester.pumpWidget(host(pills({'capacityUnit': 'KG_FREE'})));
    await tester.pumpAndSettle();
    expect(find.text('Kg libre'), findsOneWidget);
    expect(find.byKey(const Key('trip-suitcase-gauge')), findsNothing);
  });

  testWidgets('grille de prix : « Par article »', (tester) async {
    await tester.pumpWidget(host(pills({'pricingMode': 'MIXED'})));
    await tester.pumpAndSettle();
    expect(find.text('Par article'), findsOneWidget);
    expect(find.textContaining('€/kg'), findsNothing);
  });

  testWidgets('pas de prix au kilo : « Indisponible »', (tester) async {
    await tester.pumpWidget(host(pills({'pricePerKg': 0})));
    await tester.pumpAndSettle();
    expect(find.text('Indisponible'), findsOneWidget);
  });

  testWidgets('surplus publié : kilos réservés et ouverts', (tester) async {
    await tester.pumpWidget(
      host(pills({'reservedKg': 8, 'surplusPublished': true})),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('8 kg réservés'), findsOneWidget);
    expect(find.textContaining('12 kg ouverts'), findsOneWidget);

    await tester.pumpWidget(host(pills({'reservedKg': 8})));
    await tester.pumpAndSettle();
    expect(find.textContaining('kg réservés'), findsNothing);
  });

  testWidgets('statut inconnu (REMOVED_BY_ADMIN) : badge brut, sans '
      'exception', (tester) async {
    await tester.pumpWidget(host(pills({'status': 'REMOVED_BY_ADMIN'})));
    await tester.pumpAndSettle();
    expect(find.text('REMOVED_BY_ADMIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('pastille « À traiter · N » du billet', () {
    AnnouncementModel urgentTrip(String status) => AnnouncementModel(
      id: 'ann-todo',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now().add(const Duration(days: 1)),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 7,
      status: status,
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      acceptedPaymentMethods: const <BidPaymentMethod>{},
    );

    Future<void> pumpTodo(
      WidgetTester tester, {
      required int count,
      String status = 'ACTIVE',
      Locale locale = const Locale('fr'),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TripOwnerHeader(a: urgentTrip(status), todoCount: count),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUpAll(() async {
      await initializeDateFormatting('en');
      await loadAppFonts();
    });

    testWidgets('0 : masquée', (tester) async {
      await pumpTodo(tester, count: 0);
      expect(find.byKey(const Key('trip-todo-badge')), findsNothing);
    });

    testWidgets('1 et N : dans l\'en-tête, avant le badge d\'état', (
      tester,
    ) async {
      await pumpTodo(tester, count: 1);
      expect(find.text('À traiter · 1'), findsOneWidget);
      await pumpTodo(tester, count: 7);
      final pill = find.text('À traiter · 7');
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-billet-header')),
          matching: pill,
        ),
        findsOneWidget,
      );
      final status = find.text('● ACTIF');
      expect(
        tester.getTopLeft(pill).dx,
        lessThan(tester.getTopLeft(status).dx),
      );
      // Badge d'état toujours calé à droite du bandeau.
      expect(
        tester.getTopRight(find.byKey(const Key('trip-billet-header'))).dx -
            tester.getTopRight(status).dx,
        lessThan(40),
      );
    });

    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final status in const ['ACTIVE', 'IN_PROGRESS', 'COMPLETED']) {
        testWidgets('${locale.languageCode} $status, urgent, 12 actions, '
            '360 dp × 1,3 : sans débordement', (tester) async {
          await pumpTodo(
            tester,
            count: 12,
            status: status,
            locale: locale,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('trip-todo-badge')), findsOneWidget);
        });
      }
    }
  });
}
