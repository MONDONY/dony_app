import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
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

  testWidgets('sans colis remis : pas de bandeau de retour', (tester) async {
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
  });

  testWidgets(
    'colis déjà remis : la feuille et la confirmation annoncent leur retour',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => CancellationBottomSheet.show(
                ctx,
                announcementId: 'ann-1',
                handedOverParcels: 2,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
          bloc,
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '2 colis vous ont déjà été remis : vous devrez les rendre à leurs '
          'expéditeurs sous 3 jours, contre leur code de retour.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Vol annulé'));
      await tester.pump();
      await tester.tap(find.text("Confirmer l'annulation"));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Cette action annulera votre trajet et remboursera intégralement '
          'tous les expéditeurs concernés. Les 2 colis déjà remis devront '
          'être rendus à leurs expéditeurs sous 3 jours.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('un seul colis remis, en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => CancellationBottomSheet.show(
              ctx,
              announcementId: 'ann-1',
              handedOverParcels: 1,
            ),
            child: const Text('Open'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "A parcel was already handed to you: you'll need to return it to its "
        'sender within 3 days, against its return code.',
      ),
      findsOneWidget,
    );
  });

  group('motif de tête selon le mode du trajet', () {
    Future<void> openFor(
      WidgetTester tester,
      TransportMode? mode, {
      String open = 'Ouvrir',
    }) async {
      await tester.pumpWidget(
        _wrapWithRouter(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => CancellationBottomSheet.show(
                ctx,
                announcementId: 'ann-1',
                transportMode: mode,
              ),
              child: Text(open),
            ),
          ),
          bloc,
        ),
      );
      await tester.tap(find.text(open));
      await tester.pumpAndSettle();
    }

    testWidgets('route : « Panne ou contretemps », valeur envoyée inchangée', (
      tester,
    ) async {
      await openFor(tester, TransportMode.car);

      expect(find.text('Vol annulé'), findsNothing);
      expect(find.text('Panne ou contretemps'), findsOneWidget);
      await tester.tap(find.text('Panne ou contretemps'));
      await tester.pump();
      await tester.tap(find.text("Confirmer l'annulation"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as CancellationTripRequested;
      expect(event.reason, 'Vol annulé');
    });

    testWidgets('bateau : « Transport annulé »', (tester) async {
      await openFor(tester, TransportMode.boat);

      expect(find.text('Transport annulé'), findsOneWidget);
      expect(find.text('Vol annulé'), findsNothing);
    });

    testWidgets('avion ou mode absent : « Vol annulé »', (tester) async {
      await openFor(tester, TransportMode.plane);
      expect(find.text('Vol annulé'), findsOneWidget);
    });

    testWidgets('anglais : route', (tester) async {
      useEnglish();
      await openFor(tester, TransportMode.car, open: 'Open');

      expect(find.text('Breakdown or setback'), findsOneWidget);
    });

    for (final english in [false, true]) {
      testWidgets('bouton sur une ligne à 360 dp (${english ? 'en' : 'fr'})', (
        tester,
      ) async {
        if (english) useEnglish();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await openFor(
          tester,
          TransportMode.car,
          open: english ? 'Open' : 'Ouvrir',
        );

        final label = find.descendant(
          of: find.byType(DonyButton),
          matching: find.byType(Text),
        );
        expect(tester.takeException(), isNull);
        final fontSize = tester.widget<Text>(label).style?.fontSize ?? 14;
        expect(tester.getSize(label).height, lessThanOrEqualTo(fontSize * 1.7));
      });
    }
  });
}
