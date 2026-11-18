import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockCancellationBloc extends Mock implements CancellationBloc {}

class _FakeCancellationEvent extends Fake implements CancellationEvent {}

Widget _wrap(Widget child, CancellationBloc bloc) => MaterialApp(
  home: BlocProvider<CancellationBloc>.value(value: bloc, child: child),
);

Widget _wrapWithRouter(Widget child, CancellationBloc bloc) =>
    BlocProvider<CancellationBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(body: child),
            ),
            GoRoute(
              path: '/announcements',
              builder: (_, _) => const Scaffold(body: Text('announcements')),
            ),
          ],
        ),
      ),
    );

void main() {
  late CancellationBloc bloc;

  setUpAll(() => registerFallbackValue(_FakeCancellationEvent()));

  setUp(() {
    bloc = _MockCancellationBloc();
    when(() => bloc.state).thenReturn(CancellationInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche les 5 options de raison', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Vol annulé'), findsOneWidget);
    expect(find.text('Urgence personnelle'), findsOneWidget);
    expect(find.text('Autre'), findsOneWidget);
  });

  testWidgets('le bouton Confirmer est présent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text("Confirmer l'annulation"), findsOneWidget);
  });

  testWidgets('titre et motifs traduits en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Open'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this trip?'), findsOneWidget);
    expect(find.text('Flight canceled'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Confirm cancellation'), findsOneWidget);
  });

  // FLUTTER-FH : la feuille se ferme avant l'envoi, c'est l'écran du trajet
  // qui écoute le succès (snackbar et rechargement, voir
  // trip_owner_detail_screen_test).
  testWidgets('confirmation : ferme la feuille puis envoie l\'annulation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithRouter(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vol annulé'));
    await tester.pump();
    await tester.tap(find.text("Confirmer l'annulation"));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cette action annulera votre trajet et remboursera automatiquement '
        'tous les expéditeurs concernés.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.single, isA<CancellationTripRequested>());
    final event = captured.single as CancellationTripRequested;
    expect(event.announcementId, 'ann-1');
    expect(event.reason, 'Vol annulé');
  });

  testWidgets(
    'aucun bandeau de colis remis : l\'annulation est refusée avec des colis engagés',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
              child: const Text('Ouvrir'),
            ),
          ),
          bloc,
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cancellation-handed-over-notice')),
        findsNothing,
      );
    },
  );
}
