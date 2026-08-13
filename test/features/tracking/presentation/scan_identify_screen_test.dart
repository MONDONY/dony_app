import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/presentation/screens/scan_identify_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

GoRouter _router(String? etape, {bool focusNumber = false}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (ctx, _) => BlocProvider<TrackingBloc>(
        create: (_) => MockTrackingBloc()..stub(TrackingInitial()),
        child: ScanIdentifyScreen(etape: etape, focusNumber: focusNumber),
      ),
    ),
    GoRoute(
      path: '/tracking/scan/photo',
      builder: (_, _) => const Scaffold(body: Text('photo')),
    ),
    GoRoute(
      path: '/tracking/scan/qr-picker',
      builder: (_, _) => const Scaffold(body: Text('picker')),
    ),
  ],
);

GoRouter _routerWithBloc(MockTrackingBloc bloc, {String? etape}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: ScanIdentifyScreen(etape: etape),
      ),
    ),
    GoRoute(
      path: '/tracking/scan/photo',
      builder: (_, _) => const Scaffold(body: Text('photo')),
    ),
    GoRoute(
      path: '/tracking/scan/qr-picker',
      builder: (_, _) => const Scaffold(body: Text('picker')),
    ),
  ],
);

extension _MockBlocX on MockTrackingBloc {
  void stub(TrackingState s) {
    when(() => state).thenReturn(s);
    whenListen(this, Stream.value(s));
  }
}

TrackingSearchModel _fakeResult() => const TrackingSearchModel(
  trackingNumber: 'DON-ABC123',
  bidId: 'bid-xyz',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  currentStep: 'DEPART',
  stepLabel: 'Départ confirmé',
  paymentStatus: 'CAPTURED',
);

void main() {
  setUpAll(() {
    registerFallbackValue(TrackingSearchRequested(''));
  });

  // ─── Badge étape ──────────────────────────────────────────────────────────
  testWidgets('affiche badge étape quand etape=DEPART', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('DEPART')),
    );
    await tester.pump();
    expect(find.text('Départ'), findsOneWidget);
  });

  testWidgets('pas de badge étape quand etape=null', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(null)));
    await tester.pump();
    expect(find.text('Départ'), findsNothing);
    expect(find.text('Transit'), findsNothing);
  });

  testWidgets('affiche badge Transit quand etape=TRANSIT', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('TRANSIT')),
    );
    await tester.pump();
    expect(find.text('Transit'), findsOneWidget);
  });

  testWidgets('affiche badge Arrivée quand etape=ARRIVEE', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('ARRIVEE')),
    );
    await tester.pump();
    expect(find.text('Arrivée'), findsOneWidget);
  });

  // ─── Bouton Identifier ────────────────────────────────────────────────────
  testWidgets('bouton Identifier désactivé au départ', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('DEPART')),
    );
    await tester.pump();
    final btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Identifier →'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('saisir un numéro active le bouton Identifier', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('DEPART')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'DON-ABC123');
    await tester.pump();
    final btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Identifier →'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNotNull);
  });

  // ─── Dispatch TrackingSearchRequested ─────────────────────────────────────
  testWidgets('tap Identifier dispatch TrackingSearchRequested', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    bloc.stub(TrackingInitial());
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _routerWithBloc(bloc, etape: 'DEPART')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'DON-ABC123');
    await tester.pump();
    await tester.tap(find.text('Identifier →'));
    await tester.pump();
    verify(() => bloc.add(any(that: isA<TrackingSearchRequested>()))).called(1);
  });

  // ─── TrackingSearchError affiche message ─────────────────────────────────
  testWidgets('TrackingSearchError — affiche message introuvable', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    const err = NetworkException('Not found');
    when(() => bloc.state).thenReturn(TrackingSearchError(err));
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _routerWithBloc(bloc, etape: 'DEPART')),
    );
    await tester.pump();
    expect(find.textContaining('introuvable'), findsOneWidget);
  });

  // ─── TrackingSearchLoading — CircularProgressIndicator ───────────────────
  testWidgets('TrackingSearchLoading — affiche spinner dans bouton', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingSearchLoading());
    whenListen(bloc, const Stream<TrackingState>.empty());
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _routerWithBloc(bloc, etape: 'DEPART')),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ─── TrackingSearchLoaded (avec etape prédéfinie) → navigue vers photo ───
  testWidgets(
    'TrackingSearchLoaded avec etape=DEPART → navigue vers /tracking/scan/photo',
    (tester) async {
      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(
        bloc,
        Stream.fromIterable([TrackingSearchLoaded(_fakeResult())]),
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: _routerWithBloc(bloc, etape: 'DEPART'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('photo'), findsOneWidget);
    },
  );

  // ─── Scanner QR button present ────────────────────────────────────────────
  testWidgets('bouton Ouvrir le scanner QR présent', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('DEPART')),
    );
    await tester.pump();
    expect(find.text('Ouvrir le lecteur QR'), findsOneWidget);
  });

  // ─── Divider OU visible ───────────────────────────────────────────────────
  testWidgets('divider OU visible', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(null)));
    await tester.pump();
    expect(find.text('OU'), findsOneWidget);
  });

  // ─── Champ TextField hint DON-XXXXXX ─────────────────────────────────────
  testWidgets('champ TextField affiche hint DON-XXXXXX', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(null)));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  // ─── TrackingSearchLoaded sans étape → affiche picker sheet ──────────────
  testWidgets(
    'TrackingSearchLoaded sans etape → ouvre sheet "Quelle étape ?"',
    (tester) async {
      final bloc = MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(
        bloc,
        Stream.fromIterable([TrackingSearchLoaded(_fakeResult())]),
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: _routerWithBloc(bloc)),
      );
      await tester.pumpAndSettle();
      // The bottom sheet shows the etape picker
      expect(find.text('Quelle étape ?'), findsOneWidget);
    },
  );

  // ─── _EtapePickerSheet — liste toutes les étapes ─────────────────────────
  testWidgets('_EtapePickerSheet affiche Départ, Transit, Arrivée', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable([TrackingSearchLoaded(_fakeResult())]),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _routerWithBloc(bloc)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
  });

  // ─── _EtapePickerSheet — tap étape → navigue vers photo ──────────────────
  testWidgets('_EtapePickerSheet — tap Transit → navigue vers photo', (
    tester,
  ) async {
    final bloc = MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(
      bloc,
      Stream.fromIterable([TrackingSearchLoaded(_fakeResult())]),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _routerWithBloc(bloc)),
    );
    await tester.pumpAndSettle();
    // Tap Transit in the picker sheet
    await tester.tap(find.text('Transit'));
    await tester.pumpAndSettle();
    expect(find.text('photo'), findsOneWidget);
  });

  // ─── focusNumber=true — champ TextField autofocus ────────────────────────
  testWidgets('focusNumber=true — écran se construit sans erreur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router(null, focusNumber: true)),
    );
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  // ─── Titre écran ─────────────────────────────────────────────────────────
  testWidgets('titre Identifier le colis affiché', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _router('DEPART')),
    );
    await tester.pump();
    expect(find.text('Identifier le colis'), findsOneWidget);
  });
}
