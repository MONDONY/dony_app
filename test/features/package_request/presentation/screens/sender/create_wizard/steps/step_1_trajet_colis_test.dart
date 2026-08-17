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

  group('Step1TrajetColis', () {
    testWidgets('rend le label section + titre + avion verrouillé', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('TRAJET'), findsOneWidget);
      expect(find.text("D'où vers où ?"), findsOneWidget);
      // Avion verrouillé remplace les 6 OptionButton
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'plane'),
        findsOneWidget,
      );
      expect(find.text('Avion'), findsOneWidget);
      expect(find.byType(OptionButton), findsNothing);
    });

    testWidgets('rend les labels de section Départ / Arrivée / Date', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('DÉPART'), findsOneWidget);
      expect(find.text('ARRIVÉE'), findsOneWidget);
      // 'Date' apparaît 2 fois : label + placeholder du DatePickerField (date == null).
      expect(find.text('Date'), findsNWidgets(2));
      // « Tolérance » nommait le réglage ; « Souplesse » nomme ce qu'il fait.
      expect(find.text('Souplesse'), findsOneWidget);
      expect(find.text('Tolérance'), findsNothing);
      // "Mode de transport" supprimé — remplacé par le bloc avion verrouillé.
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

        // Les messages se révèlent sous les champs concernés.
        expect(find.text('Date de départ obligatoire'), findsOneWidget);
        expect(canContinue.value, isFalse);
      },
    );

    testWidgets('la souplesse est expliquée en dates, pas en jours', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      await tester.pump();
      expect(
        find.textContaining('Plus de souplesse, plus de voyageurs'),
        findsOneWidget,
      );
    });

    testWidgets('le lieu de remise est proposé, et optionnel', (tester) async {
      final key = GlobalKey<Step1TrajetColisState>();
      final canContinue = ValueNotifier<bool>(false);
      addTearDown(canContinue.dispose);

      await tester.pumpWidget(
        wrap(Step1TrajetColis(key: key, canContinueNotifier: canContinue)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pickup-neighborhood-field')),
        findsOneWidget,
      );
      // Laissé vide, il ne bloque pas : seuls villes et date comptent.
      expect(
        find.text('Où remettez-vous le colis ? (optionnel)'),
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
  });
}
