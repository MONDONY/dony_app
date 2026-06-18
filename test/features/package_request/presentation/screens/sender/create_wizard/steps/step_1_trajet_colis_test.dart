import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../../../../helpers/mock_analytics_backend.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockCityRepo extends Mock implements CityRepository {}

void main() {
  late _MockPackageRepo packageRepo;
  late _MockCityRepo cityRepo;

  setUpAll(() => initializeDateFormatting('fr'));

  setUp(() {
    packageRepo = _MockPackageRepo();
    cityRepo = _MockCityRepo();
    if (GetIt.I.isRegistered<CitySearchBloc>()) {
      GetIt.I.unregister<CitySearchBloc>();
    }
    GetIt.I.registerFactory<CitySearchBloc>(() => CitySearchBloc(cityRepo));
  });

  tearDown(() async {
    if (GetIt.I.isRegistered<CitySearchBloc>()) {
      GetIt.I.unregister<CitySearchBloc>();
    }
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
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
      expect(find.text('TRAJET & COLIS'), findsOneWidget);
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
      expect(find.text('Tolérance'), findsOneWidget);
      // "Mode de transport" supprimé — remplacé par le bloc avion verrouillé.
      // Le poids du colis a été retiré de l'étape 1 (il est saisi à l'étape 2).
      expect(find.text('Poids du colis'), findsNothing);
    });

    testWidgets('snackbar si date manquante au submit', (tester) async {
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrap(Step1TrajetColis(key: key)));
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Choisis une date souhaitée'), findsOneWidget);
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
            theme: AppTheme.light,
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
  });
}
