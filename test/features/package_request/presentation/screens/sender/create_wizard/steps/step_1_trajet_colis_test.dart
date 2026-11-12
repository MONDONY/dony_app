import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../../../helpers/mock_analytics_backend.dart';
import '../../../../../../../helpers/mock_recent_city_store.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockCityRepo extends Mock implements CityRepository {}

void main() {
  late _MockPackageRepo packageRepo;
  late _MockCityRepo cityRepo;

  setUpAll(() {
    initializeDateFormatting('fr');
    registerCityFallbackValues();
  });

  setUp(() {
    packageRepo = _MockPackageRepo();
    cityRepo = _MockCityRepo();
    if (GetIt.I.isRegistered<CitySearchBloc>()) {
      GetIt.I.unregister<CitySearchBloc>();
    }
    GetIt.I.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
    registerFakeRecentCityStore();
  });

  tearDown(() async {
    resetTransportModesForTest();
    if (GetIt.I.isRegistered<CitySearchBloc>()) {
      GetIt.I.unregister<CitySearchBloc>();
    }
    unregisterFakeRecentCityStore();
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider(
      create: (_) => PackageRequestFormBloc(
        packageRepo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      ),
      child: Scaffold(body: child),
    ),
  );

  PackageRequest editingReq({
    DateTime? date,
    int tolerance = 2,
    TransportMode? mode = TransportMode.plane,
  }) => PackageRequest(
    id: 'r-edit',
    senderId: 's-1',
    departureCity: 'Lyon',
    arrivalCity: 'Bamako',
    desiredDate: date,
    dateToleranceDays: tolerance,
    weightKg: 8,
    parcelSize: ParcelSize.medium,
    transportMode: mode,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
  );

  Widget wrapEditing(
    PackageRequest req, {
    GlobalKey<Step1TrajetColisState>? key,
    ValueNotifier<bool>? canContinue,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider(
      create: (_) => PackageRequestFormBloc(
        packageRepo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: req,
      ),
      child: Scaffold(
        body: Step1TrajetColis(key: key, canContinueNotifier: canContinue),
      ),
    ),
  );

  PackageRequestFormBloc blocOf(WidgetTester tester) => tester
      .element(find.byType(Step1TrajetColis))
      .read<PackageRequestFormBloc>();

  final farDate = DateTime.now().add(const Duration(days: 30));

  group('Step1TrajetColis', () {
    testWidgets('rend le label section + titre, sans bloc mode (avion seul)', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('TRAJET'), findsOneWidget);
      expect(find.text("D'où vers où ?"), findsOneWidget);
      // Avion seul : plus de bloc « avion verrouillé », aucun choix à faire.
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'plane'),
        findsNothing,
      );
      expect(find.text('Avion'), findsNothing);
      expect(find.byKey(const Key('request-mode-selector')), findsNothing);
      expect(find.textContaining('seul mode'), findsNothing);
      expect(find.byType(OptionButton), findsNothing);
    });

    testWidgets('rend les labels de section Départ / Arrivée / Date', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('DÉPART'), findsOneWidget);
      expect(find.text('ARRIVÉE'), findsOneWidget);
      // La date est facultative : le libellé le dit, le champ vide garde
      // « Date » en placeholder.
      expect(find.text('Date (facultatif)'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      // « Tolérance » nommait le réglage ; « Souplesse » nomme ce qu'il fait.
      expect(find.text('Souplesse'), findsOneWidget);
      expect(find.text('Tolérance'), findsNothing);
      // Le mode de transport n'est proposé que si le serveur ouvre un autre mode.
      // Le poids du colis a été retiré de l'étape 1 (il est saisi à l'étape 2).
      expect(find.text('Poids du colis'), findsNothing);
    });

    testWidgets(
      'étape incomplète : canContinue reste faux et rien n\'est dispatché',
      (tester) async {
        // Le refus ne passe plus par un snackbar après coup : le bouton
        // « Continuer » de la coque est grisé tant que l'étape est incomplète.
        final key = GlobalKey<Step1TrajetColisState>();
        final canContinue = ValueNotifier<bool>(true);
        addTearDown(canContinue.dispose);

        await tester.pumpWidget(
          wrap(Step1TrajetColis(key: key, canContinueNotifier: canContinue)),
        );
        await tester.pump();

        expect(canContinue.value, isFalse);

        key.currentState!.submit();
        await tester.pump();

        // Les messages se révèlent sous les champs concernés ; la date,
        // facultative, n'en a plus.
        expect(find.text('Date de départ obligatoire'), findsNothing);
        expect(canContinue.value, isFalse);
      },
    );

    testWidgets('sans date : aide « 60 jours » et souplesse inactive', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pump();
      expect(
        find.text(
          'Sans date, tous les voyageurs du trajet peuvent proposer. '
          'La demande reste visible 60 jours.',
        ),
        findsOneWidget,
      );
      expect(find.text('± 2 j'), findsNothing);
      expect(find.byKey(const Key('step1-date-clear')), findsNothing);

      // Champ souplesse grisé : aucun choix ne s'ouvre.
      await tester.tap(find.byKey(const Key('step1-tolerance')));
      await tester.pumpAndSettle();
      expect(find.text('Date exacte'), findsNothing);
    });

    testWidgets('sans date : aide traduite en anglais', (tester) async {
      useEnglish();
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pump();
      expect(find.text('Date (optional)'), findsOneWidget);
      expect(
        find.textContaining('every traveler on this route can make an offer'),
        findsOneWidget,
      );
    });

    testWidgets('avec une date, la souplesse est expliquée en dates', (
      tester,
    ) async {
      await tester.pumpWidget(wrapEditing(editingReq(date: farDate)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Les voyageurs partant du'), findsOneWidget);
      expect(find.textContaining('60 jours'), findsNothing);
    });

    testWidgets('trajet rempli sans date : Continuer actif, envoi sans date', (
      tester,
    ) async {
      final key = GlobalKey<Step1TrajetColisState>();
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);

      await tester.pumpWidget(
        wrapEditing(editingReq(), key: key, canContinue: canContinue),
      );
      await tester.pumpAndSettle();
      expect(canContinue.value, isTrue);

      key.currentState!.submit();
      await tester.pumpAndSettle();

      final state = blocOf(tester).state;
      expect(state.currentStep, 1);
      expect(state.departureCity, 'Lyon');
      expect(state.desiredDate, isNull);
      expect(state.dateToleranceDays, isNull);
      expect(key.currentState!.draftInput['desiredDate'], isNull);
      expect(key.currentState!.draftInput['dateToleranceDays'], isNull);
    });

    testWidgets('le bouton × efface la date choisie', (tester) async {
      final key = GlobalKey<Step1TrajetColisState>();
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);

      await tester.pumpWidget(
        wrapEditing(
          editingReq(date: farDate, tolerance: 3),
          key: key,
          canContinue: canContinue,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('± 3 j'), findsOneWidget);

      await tester.tap(find.byKey(const Key('step1-date-clear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('step1-date-clear')), findsNothing);
      expect(find.text('± 3 j'), findsNothing);
      expect(find.textContaining('60 jours'), findsOneWidget);
      expect(canContinue.value, isTrue);
      final state = blocOf(tester).state;
      expect(state.desiredDate, isNull);
      expect(state.dateToleranceDays, isNull);

      key.currentState!.submit();
      await tester.pumpAndSettle();
      expect(blocOf(tester).state.currentStep, 1);
      expect(blocOf(tester).state.desiredDate, isNull);
    });

    testWidgets('trajet rempli avec date : envoi date + souplesse', (
      tester,
    ) async {
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(
        wrapEditing(editingReq(date: farDate, tolerance: 3), key: key),
      );
      await tester.pumpAndSettle();

      key.currentState!.submit();
      await tester.pumpAndSettle();

      final state = blocOf(tester).state;
      expect(state.currentStep, 1);
      expect(state.desiredDate, farDate);
      expect(state.dateToleranceDays, 3);
    });

    // Le lieu de remise n'est plus demandé à la publication : il se convient
    // entre les deux parties une fois la négociation engagée.
    testWidgets('le lieu de remise n\'est plus demandé', (tester) async {
      final key = GlobalKey<Step1TrajetColisState>();
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);

      await tester.pumpWidget(
        wrap(Step1TrajetColis(key: key, canContinueNotifier: canContinue)),
      );
      await tester.pump();

      expect(find.byKey(const Key('pickup-neighborhood-field')), findsNothing);
      expect(find.textContaining('Où remettez-vous'), findsNothing);
    });

    testWidgets('l\'en-tête fourni défile avec le contenu', (tester) async {
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);

      await tester.pumpWidget(
        wrap(
          Step1TrajetColis(
            canContinueNotifier: canContinue,
            header: const Text('en-tête devise'),
          ),
        ),
      );
      await tester.pump();

      // Posé sous le SingleChildScrollView de l'étape, pas au-dessus : la
      // bannière de devise restait sinon figée pendant toute la saisie.
      expect(find.text('en-tête devise'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('en-tête devise'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'mode édition : pré-remplit les villes depuis l\'état du bloc',
      (tester) async {
        final req = PackageRequest(
          id: 'r-edit',
          senderId: 's-1',
          departureCity: 'Lyon',
          arrivalCity: 'Bamako',
          desiredDate: DateTime(2026, 7, 20),
          dateToleranceDays: 3,
          weightKg: 8,
          parcelSize: ParcelSize.medium,
          transportMode: TransportMode.plane,
          categories: const ['Vêtements'],
          status: PackageRequestStatus.open,
          createdAt: DateTime(2026, 5, 10),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: BlocProvider(
              create: (_) => PackageRequestFormBloc(
                packageRepo,
                analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
                editing: req,
              ),
              child: const Scaffold(body: Step1TrajetColis()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lyon'), findsOneWidget);
        expect(find.text('Bamako'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------
    // Task 5 — Feedback informatif « sera signalée urgente » sous la date
    // souhaitée.
    // -------------------------------------------------------------------
    testWidgets('date proche (demain) → le hint urgent est affiché', (
      tester,
    ) async {
      final req = PackageRequest(
        id: 'r-urgent',
        senderId: 's-1',
        departureCity: 'Lyon',
        arrivalCity: 'Bamako',
        desiredDate: DateTime.now().add(const Duration(days: 1)),
        dateToleranceDays: 2,
        weightKg: 8,
        parcelSize: ParcelSize.medium,
        transportMode: TransportMode.plane,
        categories: const ['Vêtements'],
        status: PackageRequestStatus.open,
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BlocProvider(
            create: (_) => PackageRequestFormBloc(
              packageRepo,
              analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
              editing: req,
            ),
            child: const Scaffold(body: Step1TrajetColis()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('🔥 Date proche, cette demande sera signalée urgente'),
        findsOneWidget,
      );
    });

    testWidgets('date lointaine → le hint urgent reste absent', (tester) async {
      final req = PackageRequest(
        id: 'r-far',
        senderId: 's-1',
        departureCity: 'Lyon',
        arrivalCity: 'Bamako',
        desiredDate: DateTime.now().add(const Duration(days: 60)),
        dateToleranceDays: 2,
        weightKg: 8,
        parcelSize: ParcelSize.medium,
        transportMode: TransportMode.plane,
        categories: const ['Vêtements'],
        status: PackageRequestStatus.open,
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: BlocProvider(
            create: (_) => PackageRequestFormBloc(
              packageRepo,
              analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
              editing: req,
            ),
            child: const Scaffold(body: Step1TrajetColis()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('🔥 Date proche, cette demande sera signalée urgente'),
        findsNothing,
      );
    });

    testWidgets('pas de date sélectionnée → le hint urgent est absent', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pumpAndSettle();

      expect(
        find.text('🔥 Date proche, cette demande sera signalée urgente'),
        findsNothing,
      );
    });

    testWidgets(
      'la feuille de tolérance liste les options en jours (français)',
      (tester) async {
        await tester.pumpWidget(wrapEditing(editingReq(date: farDate)));
        await tester.pumpAndSettle();

        // Tolérance par défaut = 2 jours : pill compact « ± 2 j ».
        await tester.tap(find.text('± 2 j'));
        await tester.pumpAndSettle();

        expect(find.text('Date exacte'), findsOneWidget);
        expect(find.text('± 1 jour'), findsOneWidget);
        expect(find.text('± 3 jours'), findsOneWidget);
      },
    );

    testWidgets(
      'la feuille de tolérance (requestCreateDateFlex) est traduite en '
      'anglais',
      (tester) async {
        useEnglish();
        await tester.pumpWidget(wrapEditing(editingReq(date: farDate)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('± 2 d'));
        await tester.pumpAndSettle();

        expect(find.text('Exact date'), findsOneWidget);
        expect(find.text('± 1 day'), findsOneWidget);
        expect(find.text('± 3 days'), findsOneWidget);
        expect(find.text('Date exacte'), findsNothing);
        expect(find.text('± 3 jours'), findsNothing);
      },
    );

    testWidgets('date exacte : seul le jour choisi est permis', (tester) async {
      await tester.pumpWidget(wrapEditing(editingReq(date: farDate)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('± 2 j'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date exacte'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Seuls les voyageurs partant exactement ce jour-là pourront répondre.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Step1TrajetColis — mode de transport', () {
    void openAllModes() => setTransportModes(
      const TransportModesAvailability(road: true, boat: true),
    );

    Finder chip(String mode) => find.byKey(Key('request-mode-$mode'));

    testWidgets('avion seul : pas de bloc mode, soumission PLANE', (
      tester,
    ) async {
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrapEditing(editingReq(mode: null), key: key));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('request-mode-selector')), findsNothing);

      key.currentState!.submit();
      await tester.pumpAndSettle();

      final state = blocOf(tester).state;
      expect(state.transportMode, TransportMode.plane);
      expect(state.transportModeAny, isFalse);
      expect(key.currentState!.draftInput['transportMode'], 'PLANE');
    });

    testWidgets(
      'route allumée : Peu importe pré-sélectionné, tap Route → CAR',
      (tester) async {
        setTransportModes(
          const TransportModesAvailability(road: true, boat: false),
        );
        await tester.pumpWidget(wrap(const Step1TrajetColis()));
        await tester.pump();

        expect(find.text('Mode de transport'), findsOneWidget);
        expect(chip('any'), findsOneWidget);
        expect(chip('plane'), findsOneWidget);
        expect(chip('car'), findsOneWidget);
        expect(chip('boat'), findsNothing);
        expect(
          find.text('Tous les voyageurs de ce trajet verront votre demande.'),
          findsOneWidget,
        );

        await tester.tap(chip('car'));
        await tester.pump();

        final state = blocOf(tester).state;
        expect(state.transportMode, TransportMode.car);
        expect(state.transportModeAny, isFalse);
        expect(
          find.text(
            'Seuls les voyageurs en voiture, car ou camion verront votre '
            'demande.',
          ),
          findsOneWidget,
        );

        await tester.tap(chip('any'));
        await tester.pump();
        expect(blocOf(tester).state.transportModeAny, isTrue);
        expect(blocOf(tester).state.transportMode, isNull);
      },
    );

    testWidgets('aide sous les puces selon le choix', (tester) async {
      openAllModes();
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pump();

      await tester.tap(chip('plane'));
      await tester.pump();
      expect(
        find.text('Seuls les voyageurs en avion verront votre demande.'),
        findsOneWidget,
      );

      await tester.tap(chip('boat'));
      await tester.pump();
      expect(
        find.text(
          'Seuls les bateaux (groupage en conteneur) verront votre demande.',
        ),
        findsOneWidget,
      );
      expect(blocOf(tester).state.transportMode, TransportMode.boat);
    });

    testWidgets('les puces portent les icônes de chaque mode', (tester) async {
      openAllModes();
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pump();

      for (final entry in {
        'any': 'layout-grid',
        'plane': 'plane',
        'boat': 'ship',
        'car': 'car',
      }.entries) {
        expect(
          find.descendant(
            of: chip(entry.key),
            matching: find.byWidgetPredicate(
              (w) => w is DonyIcon && w.name == entry.value,
            ),
          ),
          findsOneWidget,
          reason: entry.key,
        );
      }
    });

    testWidgets('modification d\'une demande « peu importe » : reste ANY', (
      tester,
    ) async {
      openAllModes();
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrapEditing(editingReq(mode: null), key: key));
      await tester.pumpAndSettle();

      expect(
        find.text('Tous les voyageurs de ce trajet verront votre demande.'),
        findsOneWidget,
      );
      expect(key.currentState!.draftInput['transportMode'], 'ANY');

      key.currentState!.submit();
      await tester.pumpAndSettle();

      final state = blocOf(tester).state;
      expect(state.currentStep, 1);
      expect(state.transportMode, isNull);
      expect(state.transportModeAny, isTrue);
      expect(state.requestTransportMode, isNull);
    });

    testWidgets('modification d\'une demande bateau : le mode est gardé', (
      tester,
    ) async {
      openAllModes();
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(
        wrapEditing(editingReq(mode: TransportMode.boat), key: key),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.draftInput['transportMode'], 'BOAT');

      key.currentState!.submit();
      await tester.pumpAndSettle();

      expect(blocOf(tester).state.transportMode, TransportMode.boat);
      expect(blocOf(tester).state.transportModeAny, isFalse);
    });

    testWidgets('revenir à « Peu importe » après un choix : soumet ANY', (
      tester,
    ) async {
      openAllModes();
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrapEditing(editingReq(mode: null), key: key));
      await tester.pumpAndSettle();
      // Le mode choisi à l'écran passe par le bloc : le changer puis revenir
      // à « Peu importe » doit soumettre ANY.
      await tester.tap(chip('plane'));
      await tester.pump();
      await tester.tap(chip('any'));
      await tester.pump();

      key.currentState!.submit();
      await tester.pumpAndSettle();
      expect(blocOf(tester).state.transportModeAny, isTrue);
    });

    for (final locale in ['fr', 'en']) {
      testWidgets('360 dp $locale : les 4 puces sans débordement', (
        tester,
      ) async {
        if (locale == 'en') useEnglish();
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        openAllModes();
        await tester.pumpWidget(wrap(const Step1TrajetColis()));
        await tester.pump();

        final heights = <double>{};
        for (final mode in ['any', 'plane', 'boat', 'car']) {
          final rect = tester.getRect(chip(mode));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
          heights.add(rect.height);
        }
        // Libellés sur une ligne : toutes les puces ont la même hauteur.
        expect(heights, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('anglais : libellés et aide traduits', (tester) async {
      useEnglish();
      openAllModes();
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pump();

      expect(find.text('Transport mode'), findsOneWidget);
      expect(find.text('Any'), findsOneWidget);
      expect(find.text('Plane'), findsOneWidget);
      expect(find.text('Boat'), findsOneWidget);
      expect(find.text('Road'), findsOneWidget);
      expect(
        find.text('All travelers on this route will see your request.'),
        findsOneWidget,
      );
    });
  });
}
