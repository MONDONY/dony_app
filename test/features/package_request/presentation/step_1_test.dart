// Step 1 widget test — avion verrouillé, saisie poids directe + presets, S/M/L retiré.
//
// Ce fichier est placé dans test/features/package_request/presentation/
// conformément à la spec tâche 6.
import 'package:dony/core/design/design_system.dart';
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

class _MockPackageRepo extends Mock implements PackageRequestRepository {}

class _MockCityRepo extends Mock implements CityRepository {}

void main() {
  late _MockPackageRepo packageRepo;
  late _MockCityRepo cityRepo;

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
          create: (_) => PackageRequestFormBloc(packageRepo),
          child: Scaffold(body: child),
        ),
      );

  group('Step1TrajetColis — avion lock + weight input + presets', () {
    // 1. Weight input field
    testWidgets('weight input field exists with key weight-input', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.byKey(const Key('weight-input')), findsOneWidget);
    });

    // 2. Preset chips 23 and 32
    testWidgets('preset chips 23 and 32 are present', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('23'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
    });

    // 3. No S/M/L size selector (no interactive size chip labelled 'M')
    testWidgets('no S/M/L size selector — M is not a visible chip', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      // "M" should not appear as a standalone size-chip label
      expect(find.text('M'), findsNothing);
      expect(find.text('S'), findsNothing);
      expect(find.text('L'), findsNothing);
    });

    // 4. Airplane lock indicator is visible
    testWidgets('airplane lock indicator is visible', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
      expect(find.text('Avion'), findsOneWidget);
    });

    // 5. Section label and title are still present
    testWidgets('section label and title are present', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('TRAJET & COLIS'), findsOneWidget);
      expect(find.text("D'où vers où ?"), findsOneWidget);
    });

    // 6. No editable transport mode picker (no OptionButton widgets)
    testWidgets('no interactive transport mode picker', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.byType(OptionButton), findsNothing);
    });

    // 7. Tapping a preset chip updates the weight field
    testWidgets('tapping preset 23 fills weight input', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      // Scroll down so the chip is visible
      await tester.ensureVisible(find.text('23'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('23'), warnIfMissed: false);
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('weight-input')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, '23');
    });

    // 8. Hint text shows 23 kg / 32 kg info
    testWidgets('hint text shows 23 kg = standard luggage info', (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.textContaining('23 kg'), findsWidgets);
    });

    // 9. Submit still works with snackbar when date is missing
    testWidgets('snackbar if date is missing at submit', (tester) async {
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrap(Step1TrajetColis(key: key)));
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Choisis une date souhaitée'), findsOneWidget);
    });
  });
}
