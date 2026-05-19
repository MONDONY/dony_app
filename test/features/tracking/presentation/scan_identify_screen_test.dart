import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/screens/scan_identify_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';

class MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

GoRouter _router(String? etape, {bool focusNumber = false}) => GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<TrackingBloc>(
          create: (_) => MockTrackingBloc()
            ..stub(TrackingInitial()),
          child: ScanIdentifyScreen(etape: etape, focusNumber: focusNumber),
        ),
      ),
      GoRoute(
          path: '/tracking/scan/photo',
          builder: (_, __) => const Scaffold(body: Text('photo'))),
      GoRoute(
          path: '/tracking/scan/qr-picker',
          builder: (_, __) => const Scaffold(body: Text('picker'))),
    ]);

extension _MockBlocX on MockTrackingBloc {
  void stub(TrackingState s) {
    when(() => state).thenReturn(s);
    whenListen(this, Stream.value(s));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(TrackingSearchRequested(''));
  });

  testWidgets('affiche badge étape quand etape=DEPART', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    expect(find.text('Départ'), findsOneWidget);
  });

  testWidgets('pas de badge étape quand etape=null', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router(null)));
    await tester.pump();
    expect(find.text('Départ'), findsNothing);
    expect(find.text('Transit'), findsNothing);
  });

  testWidgets('bouton Identifier désactivé au départ', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    final btn = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Identifier →'),
      matching: find.byType(ElevatedButton),
    ));
    expect(btn.onPressed, isNull);
  });

  testWidgets('saisir un numéro active le bouton Identifier', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router('DEPART')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'DON-ABC123');
    await tester.pump();
    final btn = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Identifier →'),
      matching: find.byType(ElevatedButton),
    ));
    expect(btn.onPressed, isNotNull);
  });
}
