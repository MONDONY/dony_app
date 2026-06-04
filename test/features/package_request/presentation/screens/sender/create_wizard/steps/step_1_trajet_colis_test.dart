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

  group('Step1TrajetColis', () {
    testWidgets('rend le label section + titre + avion verrouillé',
        (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('TRAJET & COLIS'), findsOneWidget);
      expect(find.text("D'où vers où ?"), findsOneWidget);
      // Avion verrouillé remplace les 6 OptionButton
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
      expect(find.text('Avion'), findsOneWidget);
      expect(find.byType(OptionButton), findsNothing);
    });

    testWidgets('rend les labels de section Départ / Arrivée / Date',
        (tester) async {
      await tester.pumpWidget(wrap(const Step1TrajetColis()));
      expect(find.text('DÉPART'), findsOneWidget);
      expect(find.text('ARRIVÉE'), findsOneWidget);
      // 'Date' apparaît 2 fois : label + placeholder du DatePickerField (date == null).
      expect(find.text('Date'), findsNWidgets(2));
      expect(find.text('Tolérance'), findsOneWidget);
      // "Mode de transport" supprimé — remplacé par bloc avion verrouillé + champ poids
      expect(find.text('Poids du colis'), findsOneWidget);
    });

    testWidgets('snackbar si date manquante au submit', (tester) async {
      final key = GlobalKey<Step1TrajetColisState>();
      await tester.pumpWidget(wrap(Step1TrajetColis(key: key)));
      key.currentState!.submit();
      await tester.pump();
      expect(find.text('Choisis une date souhaitée'), findsOneWidget);
    });
  });
}
