import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

final _suggestions = [
  RematchSuggestionModel(
    suggestionId: 'sug-1',
    announcementId: 'ann-2',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2024, 2, 1),
    availableKg: 5.0,
    pricePerKg: 12.0,
  ),
];

Widget _wrap(CancellationBloc bloc, {required String cancellationId}) => MaterialApp(
      home: BlocProvider<CancellationBloc>.value(
        value: bloc,
        child: RematchSearchScreen(cancellationId: cancellationId),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(RematchSuggestionsRequested('fallback'));
  });

  late _MockCancellationBloc bloc;

  setUp(() {
    bloc = _MockCancellationBloc();
  });

  testWidgets('déclenche le fetch avec le bon cancellationId au démarrage', (tester) async {
    when(() => bloc.state).thenReturn(CancellationInitial());

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-42'));

    verify(() => bloc.add(any(
          that: isA<RematchSuggestionsRequested>()
              .having((e) => e.cancellationId, 'cancellationId', 'canc-42'),
        ))).called(1);
  });

  testWidgets('affiche un loader pendant CancellationLoading', (tester) async {
    when(() => bloc.state).thenReturn(CancellationLoading());

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('rend la liste des suggestions sur RematchSuggestionsLoaded', (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(_suggestions));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Paris → Dakar'), findsOneWidget);
    expect(find.text('1 voyageur disponible'), findsOneWidget);
    // Pas de compteur d'expéditeurs remboursés dans le chemin self-fetching.
    expect(find.text('Votre remboursement est en cours.'), findsOneWidget);
  });

  testWidgets('affiche un état vide explicite quand aucune suggestion', (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(const []));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Aucun voyageur disponible'), findsOneWidget);
  });

  testWidgets('affiche une erreur avec retry sur CancellationError, et le retry redispatch',
      (tester) async {
    when(() => bloc.state)
        .thenReturn(CancellationError(const NetworkException('boom')));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Réessayer'), findsOneWidget);

    // Le fetch initial (initState) a déjà eu lieu — on réinitialise le compteur
    // d'appels avant de taper "Réessayer" pour ne vérifier que le retry.
    clearInteractions(bloc);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(() => bloc.add(any(
          that: isA<RematchSuggestionsRequested>()
              .having((e) => e.cancellationId, 'cancellationId', 'canc-1'),
        ))).called(1);
  });
}
