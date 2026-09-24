import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/kg_sold_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/presentation/widgets/kg_sold_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockKgSoldCubit extends MockCubit<KgSoldState> implements KgSoldCubit {}

final _model = KgSoldModel(
  period: '30d',
  totalKg: 16,
  parcels: 6,
  trips: [
    KgSoldTripModel(
      tripId: 't1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      date: DateTime(2026, 9, 12),
      parcels: 2,
      kg: 6,
    ),
    KgSoldTripModel(
      tripId: 't2',
      departureCity: 'Lyon',
      arrivalCity: 'Abidjan',
      date: DateTime(2026, 9, 5),
      parcels: 1,
      kg: 2.5,
    ),
  ],
);

Widget _harness(KgSoldCubit cubit) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider<KgSoldCubit>.value(
        value: cubit,
        child: const SingleChildScrollView(
          child: KgSoldSheet(period: StatsPeriod.thirtyDays),
        ),
      ),
    ),
  );
}

void main() {
  late _MockKgSoldCubit cubit;

  setUpAll(() {
    registerFallbackValue(StatsPeriod.thirtyDays);
    initializeDateFormatting('fr');
  });

  setUp(() {
    cubit = _MockKgSoldCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
  });

  testWidgets('chargement : squelettes', (tester) async {
    whenListen(
      cubit,
      const Stream<KgSoldState>.empty(),
      initialState: const KgSoldState(status: KgSoldStatus.loading),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.text('16 kg'), findsNothing);
    expect(find.textContaining('kg'), findsNothing);
  });

  testWidgets('chargé : total, colis et une ligne par trajet', (tester) async {
    whenListen(
      cubit,
      const Stream<KgSoldState>.empty(),
      initialState: KgSoldState(status: KgSoldStatus.loaded, details: _model),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('16 kg'), findsOneWidget);
    expect(find.text('6 colis livrés'), findsOneWidget);
    expect(find.text('2 trajets'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.textContaining('12 sept.'), findsOneWidget);
    expect(find.textContaining('2 colis'), findsOneWidget);
    expect(find.text('6 kg'), findsOneWidget);
    expect(find.text('2,5 kg'), findsOneWidget);
  });

  testWidgets('une ligne rend son tripId au parent', (tester) async {
    whenListen(
      cubit,
      const Stream<KgSoldState>.empty(),
      initialState: KgSoldState(status: KgSoldStatus.loaded, details: _model),
    );

    late Future<String?> result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  result = Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider<KgSoldCubit>.value(
                        value: cubit,
                        child: const Scaffold(
                          body: KgSoldSheet(period: StatsPeriod.thirtyDays),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kg-trip-t1')));
    await tester.pumpAndSettle();

    expect(await result, 't1');
  });

  testWidgets('aucun trajet : état vide « Aucune livraison sur la période »', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<KgSoldState>.empty(),
      initialState: const KgSoldState(
        status: KgSoldStatus.loaded,
        details: KgSoldModel(period: '30d', totalKg: 0, parcels: 0, trips: []),
      ),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Aucune livraison sur la période'), findsOneWidget);
  });

  testWidgets('en anglais, les textes de la feuille sont traduits', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    useEnglish();
    whenListen(
      cubit,
      const Stream<KgSoldState>.empty(),
      initialState: KgSoldState(status: KgSoldStatus.loaded, details: _model),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('6 parcels delivered'), findsOneWidget);
    expect(find.text('2 trips'), findsOneWidget);
    // Vérifie le mot traduit lui-même, pas seulement la date : une
    // régression qui laisserait « Départ le » en anglais passerait
    // inaperçue avec un seul textContaining('Sep 12').
    expect(find.textContaining('Departed Sep 12'), findsOneWidget);
  });

  testWidgets('erreur : « Détail indisponible », « Réessayer » recharge', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<KgSoldState>.empty(),
      initialState: const KgSoldState(status: KgSoldStatus.error),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Détail indisponible'), findsOneWidget);
    await tester.tap(find.byKey(const Key('kg-retry')));
    await tester.pump();

    verify(() => cubit.load(StatsPeriod.thirtyDays)).called(1);
  });
}
