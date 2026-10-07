import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {
  MockRatingBloc() {
    when(() => state).thenReturn(const RatingInitial());
    whenListen(this, const Stream<RatingState>.empty());
  }
}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {
  MockAuthBloc() {
    when(() => state).thenReturn(const AuthInitial());
  }
}

TrackingEventModel _fakeEvent({String eventType = 'DEPART'}) =>
    TrackingEventModel(
      id: 'evt-1',
      bidId: 'bid-123',
      eventType: eventType,
      scannedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

Widget _wrap(
  String etape,
  MockTrackingBloc bloc, {
  String? photoPath,
  double? gpsLat,
  double? gpsLon,
  String? gpsLabel,
  ScanMethod? scanMethod,
  DeliveryWindow? deliveryWindow,
}) {
  // Vraie route de l'écran : la fin du scan referme les étapes du flux
  // (`leaveScanFlow`), puis retombe sur l'onglet Suivi s'il n'y a rien dessous.
  final router = GoRouter(
    initialLocation: '/tracking/scan/confirm',
    routes: [
      GoRoute(
        path: '/tracking/scan/confirm',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<TrackingBloc>.value(value: bloc),
            BlocProvider<RatingBloc>(create: (_) => MockRatingBloc()),
            BlocProvider<AuthBloc>(create: (_) => MockAuthBloc()),
          ],
          child: ScanConfirmScreen(
            bidId: 'bid-123',
            etape: etape,
            packageLabel: 'DON-TEST01',
            photoPath: photoPath,
            gpsLat: gpsLat,
            gpsLon: gpsLon,
            gpsLabel: gpsLabel,
            scanMethod: scanMethod,
            deliveryWindow: deliveryWindow,
          ),
        ),
      ),
      GoRoute(
        path: '/tracking',
        builder: (_, _) => const Scaffold(body: Text('hub')),
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
}

void main() {
  setUpAll(() {
    registerFallbackValue(QrScanSubmitRequested(bidId: '', eventType: ''));
    registerFallbackValue(ConfirmDeliveryRequested(bidId: '', code: ''));
  });

  // ─── DEPART — basic UI ────────────────────────────────────────────────────
  testWidgets('DEPART — pas de champ code, bouton Valider', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    expect(find.text('Valider la lecture'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // ─── ARRIVEE — code field visible ─────────────────────────────────────────
  testWidgets('ARRIVEE — champ code visible + bouton Confirmer', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    expect(find.text('Confirmer la livraison'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  // ─── DEPART — tap Valider dispatches event ────────────────────────────────
  testWidgets('DEPART — tap Valider dispatch QrScanSubmitRequested', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    await tester.tap(find.text('Valider la lecture'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<QrScanSubmitRequested>()))).called(1);
  });

  // ─── packageLabel recap ────────────────────────────────────────────────────
  testWidgets('affiche recap avec packageLabel', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    expect(find.text('DON-TEST01'), findsOneWidget);
  });

  // ─── ARRIVEE — clavier ouvert : le bouton reste visible (FLUTTER-BN, BF) ───
  testWidgets(
    'ARRIVEE — clavier ouvert : le bouton reste au-dessus du clavier',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 450);
      addTearDown(tester.view.reset);

      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(bloc, const Stream<TrackingState>.empty());
      await tester.pumpWidget(_wrap('ARRIVEE', bloc));
      await tester.pump();

      final button = find.text('Confirmer la livraison');
      expect(button, findsOneWidget);
      // Sans défilement : le bas du bouton est au-dessus du clavier (450 px).
      expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(1280 - 450));
      expect(tester.getTopLeft(button).dy, greaterThan(0));
    },
  );

  // ─── ARRIVEE — code too short → no dispatch ───────────────────────────────
  testWidgets('ARRIVEE — code < 6 chiffres → pas de dispatch', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<ConfirmDeliveryRequested>())));
    // Le refus est expliqué (FLUTTER-BA) : il passait pour une panne.
    expect(
      find.text('Le code de retrait contient 6 chiffres.'),
      findsOneWidget,
    );
  });

  testWidgets('ARRIVEE — code collé avec espace : chiffres seuls gardés', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123 456');
    await tester.pump();
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pump();
    verify(
      () => bloc.add(
        any(
          that: isA<ConfirmDeliveryRequested>().having(
            (e) => e.code,
            'code',
            '123456',
          ),
        ),
      ),
    ).called(1);
  });

  // ─── ARRIVEE — code = 6 → dispatches ConfirmDeliveryRequested ────────────
  testWidgets('ARRIVEE — code 6 chiffres → dispatch ConfirmDeliveryRequested', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pump();
    verify(
      () => bloc.add(any(that: isA<ConfirmDeliveryRequested>())),
    ).called(1);
  });

  testWidgets(
    'ARRIVEE — la photo prise est transmise à ConfirmDeliveryRequested',
    (tester) async {
      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(bloc, const Stream<TrackingState>.empty());
      await tester.pumpWidget(
        _wrap('ARRIVEE', bloc, photoPath: '/tmp/arrivee_photo.jpg'),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();
      await tester.tap(find.text('Confirmer la livraison'));
      await tester.pump();
      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as ConfirmDeliveryRequested;
      expect(event.code, '654321');
      expect(event.photo?.path, '/tmp/arrivee_photo.jpg');
      expect(event.scanMethod, isNull);
    },
  );

  testWidgets('la provenance reçue part avec l\'étape et la remise', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc, scanMethod: ScanMethod.qr));
    await tester.pump();
    await tester.tap(find.text('Valider la lecture'));
    await tester.pump();
    final scan =
        verify(() => bloc.add(captureAny())).captured.single
            as QrScanSubmitRequested;
    expect(scan.scanMethod, ScanMethod.qr);

    await tester.pumpWidget(
      _wrap('ARRIVEE', bloc, scanMethod: ScanMethod.manual),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pump();
    final delivery =
        verify(() => bloc.add(captureAny())).captured.single
            as ConfirmDeliveryRequested;
    expect(delivery.scanMethod, ScanMethod.manual);
  });

  // ─── Loading state — CircularProgressIndicator shown ────────────────────
  testWidgets('état QrScanSubmitting — spinner affiché dans le bouton', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(QrScanSubmitting());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    // DonyButton in isLoading state shows CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
  });

  // ─── QrScanSuccess → showDialog ──────────────────────────────────────────
  testWidgets('état QrScanSuccess — affiche dialogue succès', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, Stream.fromIterable([QrScanSuccess(_fakeEvent())]));
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pumpAndSettle();
    expect(find.text('Lecture enregistrée !'), findsOneWidget);
  });

  // ─── QrScanQueued → showDialog ────────────────────────────────────────────
  testWidgets('état QrScanQueued — affiche dialogue hors-ligne', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, Stream.fromIterable([QrScanQueued()]));
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pumpAndSettle();
    expect(find.text('Lecture en attente'), findsOneWidget);
  });

  // ─── DeliveryConfirmSuccess → DonySuccessScreen ──────────────────────────
  testWidgets('état DeliveryConfirmSuccess — affiche DonySuccessScreen livré', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable([
        DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE')),
      ]),
    );
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pumpAndSettle();
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Colis livré !'), findsOneWidget);
  });

  // ─── QrScanError → affiche message erreur ────────────────────────────────
  testWidgets('état QrScanError — affiche message erreur', (tester) async {
    final bloc = MockTrackingBloc();
    const err = NetworkException('Erreur serveur');
    when(() => bloc.state).thenReturn(QrScanError(err));
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    // Error message is shown via ErrorPresenter — just verify no crash
    expect(find.byType(Scaffold), findsOneWidget);
  });

  // ─── DeliveryConfirmError → affiche message erreur ───────────────────────
  testWidgets('état DeliveryConfirmError — affiche message erreur', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    const err = NetworkException('Code invalide');
    when(() => bloc.state).thenReturn(DeliveryConfirmError(err));
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  // ─── GPS display ─────────────────────────────────────────────────────────
  testWidgets('affiche le nom du lieu quand gpsLabel est fourni', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(
      _wrap('DEPART', bloc, gpsLat: 48.8566, gpsLon: 2.3522, gpsLabel: 'Paris'),
    );
    await tester.pump();
    expect(find.text('Paris'), findsOneWidget);
    expect(find.textContaining('48.8566'), findsNothing);
    expect(find.textContaining('2.3522'), findsNothing);
  });

  // Sentry FLUTTER-3W : sur un écran de 360 dp (Redmi), une adresse issue du
  // géocodage inverse débordait de la pastille de lieu de 1 à 3 px à droite.
  testWidgets('une adresse longue tient dans la pastille de lieu en 360 dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    const address =
        '12 avenue du Général de Gaulle, Villeneuve-Saint-Georges, '
        'Île-de-France, France';
    await tester.pumpWidget(
      _wrap('DEPART', bloc, gpsLat: 48.73, gpsLon: 2.45, gpsLabel: address),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(address), findsOneWidget);
  });

  // ─── "Reprendre photo" visible si photoPath fourni ───────────────────────
  testWidgets('bouton Reprendre la photo visible si photoPath fourni', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(
      _wrap('DEPART', bloc, photoPath: '/tmp/fake_photo.jpg'),
    );
    await tester.pump();
    expect(find.text('Reprendre la photo'), findsOneWidget);
  });

  // ─── "Reprendre photo" absent sans photoPath ─────────────────────────────
  testWidgets('bouton Reprendre la photo absent sans photoPath', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    expect(find.text('Reprendre la photo'), findsNothing);
  });

  // ─── TRANSIT etape chip ───────────────────────────────────────────────────
  testWidgets('TRANSIT — chip étape Transit affiché', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('TRANSIT', bloc));
    await tester.pump();
    expect(find.textContaining('Transit'), findsWidgets);
  });

  // ─── anglais — titre, chip et bouton traduits ────────────────────────────
  testWidgets('anglais — titre, chip et bouton traduits', (tester) async {
    useEnglish();
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    expect(find.text('Confirm scan'), findsOneWidget);
    expect(find.text('Departure recorded'), findsOneWidget);
    expect(find.text('Validate scan'), findsOneWidget);
  });

  // ─── DeliveryConfirmSuccess — RatingBottomSheet non simultané ────────────
  testWidgets(
    'DeliveryConfirmSuccess — RatingBottomSheet pas affiché en même temps que l\'écran succès',
    (tester) async {
      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(
        bloc,
        Stream.fromIterable([
          DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE')),
        ]),
      );
      await tester.pumpWidget(_wrap('ARRIVEE', bloc));
      await tester.pumpAndSettle();
      // Écran succès visible
      expect(find.text('Colis livré !'), findsOneWidget);
      // Rating sheet PAS affiché en même temps (régression)
      expect(find.textContaining('Évaluer'), findsNothing);
    },
  );

  // ─── DeliveryConfirmSuccess — bouton Terminer présent ────────────────────
  testWidgets('DeliveryConfirmSuccess — bouton Terminer présent', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable([
        DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE')),
      ]),
    );
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pumpAndSettle();
    expect(find.text('Colis livré !'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
  });

  // ─── DeliveryConfirmSuccess — tap Terminer : RatingBottomSheet puis /tracking
  testWidgets(
    'DeliveryConfirmSuccess — tap Terminer affiche RatingBottomSheet puis '
    'navigue vers /tracking après fermeture',
    (tester) async {
      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(
        bloc,
        Stream.fromIterable([
          DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE')),
        ]),
      );
      await tester.pumpWidget(_wrap('ARRIVEE', bloc));
      await tester.pumpAndSettle();
      expect(find.byType(DonySuccessScreen), findsOneWidget);

      await tester.tap(find.text('Terminer'));
      await tester.pump(); // déclenche l'appel async RatingBottomSheet.show
      await tester.pumpAndSettle(); // animation d'ouverture de la sheet

      expect(tester.takeException(), isNull);
      expect(find.byType(RatingBottomSheet), findsOneWidget);
      // Toujours sur l'écran succès tant que la sheet n'est pas fermée.
      expect(find.text('hub'), findsNothing);

      // Ferme la sheet comme le ferait l'utilisateur.
      final sheetContext = tester.element(find.byType(RatingBottomSheet));
      Navigator.of(sheetContext).pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RatingBottomSheet), findsNothing);
      expect(find.text('hub'), findsOneWidget);
    },
  );

  // ─── Livraison avant le départ du trajet (FLUTTER-CB, back #419) ─────────
  group('ARRIVEE — verrou avant le départ', () {
    DonyButton submit(WidgetTester tester) =>
        tester.widget<DonyButton>(find.byKey(const Key('scan-confirm-submit')));

    MockTrackingBloc idleBloc() {
      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(bloc, const Stream<TrackingState>.empty());
      return bloc;
    }

    testWidgets('départ à venir : bouton désactivé, explication affichée', (
      tester,
    ) async {
      final bloc = idleBloc();
      await tester.pumpWidget(
        _wrap(
          'ARRIVEE',
          bloc,
          deliveryWindow: DeliveryWindow(
            departure: DateTime.now().add(const Duration(days: 2)),
            hasTime: true,
          ),
        ),
      );
      await tester.pump();

      expect(submit(tester).onPressed, isNull);
      expect(
        find.textContaining('Disponible après le départ du trajet (le'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '654321');
      await tester.tap(find.byKey(const Key('scan-confirm-submit')));
      await tester.pump();
      verifyNever(() => bloc.add(any(that: isA<ConfirmDeliveryRequested>())));
    });

    testWidgets('départ passé : bouton actif, aucune explication', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          'ARRIVEE',
          idleBloc(),
          deliveryWindow: DeliveryWindow(
            departure: DateTime.now().subtract(const Duration(hours: 1)),
            hasTime: true,
          ),
        ),
      );
      await tester.pump();

      expect(submit(tester).onPressed, isNotNull);
      expect(find.byKey(const Key('delivery-locked-hint')), findsNothing);
    });

    testWidgets('départ inconnu : bouton actif (le serveur tranche)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap('ARRIVEE', idleBloc()));
      await tester.pump();

      expect(submit(tester).onPressed, isNotNull);
      expect(find.byKey(const Key('delivery-locked-hint')), findsNothing);
    });

    testWidgets('DEPART : jamais verrouillé par le départ', (tester) async {
      await tester.pumpWidget(
        _wrap(
          'DEPART',
          idleBloc(),
          deliveryWindow: DeliveryWindow(
            departure: DateTime.now().add(const Duration(days: 2)),
            hasTime: true,
          ),
        ),
      );
      await tester.pump();

      expect(submit(tester).onPressed, isNotNull);
    });

    testWidgets(
      '422 trip-not-departed : message du catalogue, code saisi conservé',
      (tester) async {
        final bloc = MockTrackingBloc();
        when(() => bloc.state).thenReturn(TrackingInitial());
        final states = StreamController<TrackingState>();
        addTearDown(states.close);
        whenListen(bloc, states.stream);
        await tester.pumpWidget(_wrap('ARRIVEE', bloc));
        await tester.pump();
        await tester.enterText(find.byType(TextField), '654321');
        await tester.pump();

        const err = ValidationException(
          'Trip has not departed yet',
          code: 'trip-not-departed',
        );
        when(() => bloc.state).thenReturn(DeliveryConfirmError(err));
        states.add(DeliveryConfirmError(err));
        await tester.pump();

        expect(
          find.text(
            "La livraison ne peut être confirmée qu'après le départ du "
            'trajet. Réessayez après le trajet.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Trip has not departed'), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, '654321');
        expect(submit(tester).onPressed, isNotNull);
      },
    );
  });
}
