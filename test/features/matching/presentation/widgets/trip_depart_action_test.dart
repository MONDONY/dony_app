// « Je pars » : bouton sur le cubit ambiant (`TripDepartAction`, pied du
// sheet de la tuile « Je pars », cubit fourni par l'écran du trajet).
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/presentation/widgets/trip_depart_action.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

class _FakeContext extends Fake implements BuildContext {}

void main() {
  late _MockDepart cubit;
  late StreamController<TripDepartState> states;
  late List<String> createdIds;

  setUpAll(() => registerFallbackValue(_FakeContext()));

  setUp(() async {
    DonySnackbar.clearDedup();
    states = StreamController<TripDepartState>.broadcast();
    addTearDown(states.close);
    cubit = _MockDepart();
    whenListen(cubit, states.stream, initialState: const TripDepartState());
    when(() => cubit.depart(any())).thenAnswer((_) async {});
    createdIds = [];
    await getIt.reset();
    getIt.registerFactoryParam<TripDepartCubit, String, void>((id, _) {
      createdIds.add(id);
      return cubit;
    });
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  Finder button() => find.byKey(const Key('trip-depart-button'));

  group('TripDepartAction (cubit ambiant)', () {
    Widget action() => BlocProvider<TripDepartCubit>.value(
      value: cubit,
      child: const TripDepartAction(),
    );

    testWidgets('départ confirmé : confirmation, bouton visible mais éteint', (
      tester,
    ) async {
      await pump(tester, action());

      states.add(const TripDepartState(departed: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("C'est noté, bon voyage !"), findsOneWidget);
      expect(tester.widget<DonyButton>(button()).onPressed, isNull);
      expect(createdIds, isEmpty);
    });

    testWidgets('chargement : bouton en chargement, éteint', (tester) async {
      await pump(tester, action());

      states.add(const TripDepartState(loading: true));
      // Livraison de l'état, puis l'image reconstruite (indicateur infini :
      // pas de pumpAndSettle).
      await tester.pump();
      await tester.pump();

      final b = tester.widget<DonyButton>(button());
      expect(b.isLoading, isTrue);
      expect(b.onPressed, isNull);
    });
  });
}
