import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_audience_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTripAudienceCubit extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

Future<void> _pump(WidgetTester tester, TripAudienceCubit cubit) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<TripAudienceCubit>.value(
            value: cubit,
            child: const TripAudienceSection(announcementId: 'ann-1'),
          ),
        ),
      ),
    );

void main() {
  late _MockTripAudienceCubit cubit;

  setUp(() {
    cubit = _MockTripAudienceCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
  });

  testWidgets('charge l’audience du trajet à l’affichage', (tester) async {
    when(() => cubit.state).thenReturn(const TripAudienceState.initial());

    await _pump(tester, cubit);

    verify(() => cubit.load('ann-1')).called(1);
  });

  testWidgets('personnes et vues de l’affiche', (tester) async {
    when(() => cubit.state).thenReturn(
      const TripAudienceState.loaded(
        TripAudienceModel(uniqueViewerCount: 12, shareViewCount: 7),
      ),
    );

    await _pump(tester, cubit);

    expect(find.text('12 personnes ont vu votre trajet'), findsOneWidget);
    expect(find.text('7 vues de votre affiche partagée'), findsOneWidget);
  });

  testWidgets('une personne, affiche jamais consultée : pas de ligne affiche', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(
      const TripAudienceState.loaded(
        TripAudienceModel(uniqueViewerCount: 1, shareViewCount: 0),
      ),
    );

    await _pump(tester, cubit);

    expect(find.text('1 personne a vu votre trajet'), findsOneWidget);
    expect(find.textContaining('affiche'), findsNothing);
  });

  testWidgets('personne encore : la carte le dit, avec 0', (tester) async {
    when(() => cubit.state).thenReturn(
      const TripAudienceState.loaded(
        TripAudienceModel(uniqueViewerCount: 0, shareViewCount: 0),
      ),
    );

    await _pump(tester, cubit);

    expect(find.byKey(const Key('trip-audience-card')), findsOneWidget);
    expect(find.text("Personne n'a encore vu votre trajet"), findsOneWidget);
    expect(find.textContaining('affiche'), findsNothing);
  });

  testWidgets(
    'personne dans l’app mais l’affiche consultée : seule la ligne affiche',
    (tester) async {
      when(() => cubit.state).thenReturn(
        const TripAudienceState.loaded(
          TripAudienceModel(uniqueViewerCount: 0, shareViewCount: 3),
        ),
      );

      await _pump(tester, cubit);

      expect(find.text('3 vues de votre affiche partagée'), findsOneWidget);
      expect(find.textContaining('ton trajet'), findsNothing);
    },
  );

  for (final (label, state) in [
    ('chargement', const TripAudienceState.loading()),
    ('échec ou ancien back', const TripAudienceState.hidden()),
  ]) {
    testWidgets('rien n’est affiché : $label', (tester) async {
      when(() => cubit.state).thenReturn(state);

      await _pump(tester, cubit);

      expect(find.textContaining('ton trajet'), findsNothing);
      expect(find.textContaining('affiche'), findsNothing);
    });
  }
}
