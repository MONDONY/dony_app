// Step 1 widget test — avion verrouillé, trajet (villes + date + tolérance).
//
// Le poids du colis a été retiré de l'étape 1 : il est saisi à l'étape 2
// (FormStep2Submitted). L'étape 1 ne traite que le trajet + le mode (avion).
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../../../helpers/mock_recent_city_store.dart';

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockCityRepo extends Mock implements CityRepository {}

void main() {
  late _MockPackageRepo packageRepo;
  late _MockCityRepo cityRepo;

  setUpAll(registerCityFallbackValues);

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

  group('Step1TrajetColis — avion lock + trajet (poids retiré)', () {
    // 1. Weight input field is NO LONGER in step 1 (moved to step 2)
    testWidgets('weight input is removed from step 1', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.byKey(const Key('weight-input')), findsNothing);
    });

    // 2. No weight preset chips remain in step 1
    testWidgets('weight preset chips are removed from step 1', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('23'), findsNothing);
      expect(find.text('32'), findsNothing);
    });

    // 3. No "Poids du colis" label / kg helper text remains in step 1
    testWidgets('no weight label or helper text in step 1', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('Poids du colis'), findsNothing);
      expect(find.textContaining('23 kg'), findsNothing);
    });

    // 4. No S/M/L size selector (no interactive size chip labelled 'M')
    testWidgets('no S/M/L size selector — M is not a visible chip', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('M'), findsNothing);
      expect(find.text('S'), findsNothing);
      expect(find.text('L'), findsNothing);
    });

    // 5. Airplane lock indicator is visible
    testWidgets('airplane lock indicator is visible', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'plane'),
        findsOneWidget,
      );
      expect(find.text('Avion'), findsOneWidget);
    });

    // 6. Section label and title are still present
    testWidgets('section label and title are present', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('TRAJET & COLIS'), findsOneWidget);
      expect(find.text("D'où vers où ?"), findsOneWidget);
    });

    // 7. No editable transport mode picker (no OptionButton widgets)
    testWidgets('no interactive transport mode picker', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.byType(OptionButton), findsNothing);
    });

    // 8. Submit still works with snackbar when date is missing
    testWidgets('date manquante : message sous le champ, pas de snackbar', (
      tester,
    ) async {
      // Le refus passe désormais par le grisage du bouton et un message posé
      // sous le champ concerné, au lieu d'un bandeau après le clic.
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrap(Step1TrajetColis(key: key)));
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Choisis une date souhaitée'), findsNothing);
      expect(find.text('Date de départ obligatoire'), findsOneWidget);
    });
  });
}
