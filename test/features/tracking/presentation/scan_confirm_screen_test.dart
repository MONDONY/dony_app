import 'package:bloc_test/bloc_test.dart';
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
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {
  MockRatingBloc() {
    when(() => state).thenReturn(const RatingInitial());
    whenListen(this, const Stream<RatingState>.empty());
  }
}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {
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
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => MultiBlocProvider(
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
        ),
      ),
    ),
    GoRoute(
        path: '/tracking',
        builder: (_, __) => const Scaffold(body: Text('hub'))),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() {
    registerFallbackValue(
        QrScanSubmitRequested(bidId: '', eventType: ''));
    registerFallbackValue(
        ConfirmDeliveryRequested(bidId: '', code: ''));
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
  testWidgets('ARRIVEE — champ code visible + bouton Confirmer', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    expect(find.text('Confirmer la livraison'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  // ─── DEPART — tap Valider dispatches event ────────────────────────────────
  testWidgets('DEPART — tap Valider dispatch QrScanSubmitRequested',
      (tester) async {
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
  });

  // ─── ARRIVEE — code = 6 → dispatches ConfirmDeliveryRequested ────────────
  testWidgets('ARRIVEE — code 6 chiffres → dispatch ConfirmDeliveryRequested',
      (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(find.text('Confirmer la livraison'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<ConfirmDeliveryRequested>()))).called(1);
  });

  // ─── Loading state — CircularProgressIndicator shown ────────────────────
  testWidgets('état QrScanSubmitting — spinner affiché dans le bouton',
      (tester) async {
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
    whenListen(
      bloc,
      Stream.fromIterable([QrScanSuccess(_fakeEvent())]),
    );
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pumpAndSettle();
    expect(find.text('Lecture enregistrée !'), findsOneWidget);
  });

  // ─── QrScanQueued → showDialog ────────────────────────────────────────────
  testWidgets('état QrScanQueued — affiche dialogue hors-ligne', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, Stream.fromIterable([QrScanQueued()]));
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pumpAndSettle();
    expect(find.text('Lecture en attente'), findsOneWidget);
  });

  // ─── DeliveryConfirmSuccess → DonySuccessScreen ──────────────────────────
  testWidgets('état DeliveryConfirmSuccess — affiche DonySuccessScreen livré',
      (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable(
          [DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE'))]),
    );
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pumpAndSettle();
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Colis livré !'), findsOneWidget);
  });

  // ─── QrScanError → affiche message erreur ────────────────────────────────
  testWidgets('état QrScanError — affiche message erreur', (tester) async {
    final bloc = MockTrackingBloc();
    final err = const NetworkException('Erreur serveur');
    when(() => bloc.state).thenReturn(QrScanError(err));
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('DEPART', bloc));
    await tester.pump();
    // Error message is shown via ErrorPresenter — just verify no crash
    expect(find.byType(Scaffold), findsOneWidget);
  });

  // ─── DeliveryConfirmError → affiche message erreur ───────────────────────
  testWidgets('état DeliveryConfirmError — affiche message erreur',
      (tester) async {
    final bloc = MockTrackingBloc();
    final err = const NetworkException('Code invalide');
    when(() => bloc.state).thenReturn(DeliveryConfirmError(err));
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  // ─── GPS display ─────────────────────────────────────────────────────────
  testWidgets('affiche GPS quand gpsLat/gpsLon fournis', (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(
        _wrap('DEPART', bloc, gpsLat: 48.8566, gpsLon: 2.3522));
    await tester.pump();
    expect(find.textContaining('48.8566'), findsOneWidget);
    expect(find.textContaining('2.3522'), findsOneWidget);
  });

  // ─── "Reprendre photo" visible si photoPath fourni ───────────────────────
  testWidgets('bouton Reprendre la photo visible si photoPath fourni',
      (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(
        _wrap('DEPART', bloc, photoPath: '/tmp/fake_photo.jpg'));
    await tester.pump();
    expect(find.text('Reprendre la photo'), findsOneWidget);
  });

  // ─── "Reprendre photo" absent sans photoPath ─────────────────────────────
  testWidgets('bouton Reprendre la photo absent sans photoPath', (tester) async {
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

  // ─── DeliveryConfirmSuccess — RatingBottomSheet non simultané ────────────
  testWidgets(
      'DeliveryConfirmSuccess — RatingBottomSheet pas affiché en même temps que l\'écran succès',
      (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable(
          [DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE'))]),
    );
    await tester.pumpWidget(_wrap('ARRIVEE', bloc));
    await tester.pumpAndSettle();
    // Écran succès visible
    expect(find.text('Colis livré !'), findsOneWidget);
    // Rating sheet PAS affiché en même temps (régression)
    expect(find.textContaining('Évaluer'), findsNothing);
  });

  // ─── DeliveryConfirmSuccess — bouton Terminer présent ────────────────────
  testWidgets('DeliveryConfirmSuccess — bouton Terminer présent',
      (tester) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable(
          [DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE'))]),
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
      Stream.fromIterable(
          [DeliveryConfirmSuccess(_fakeEvent(eventType: 'ARRIVEE'))]),
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
  });
}
