import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

Future<void> _pump(
  WidgetTester tester,
  _MockTrackingBloc t,
  _MockBidBloc b, {
  String initialCode = '4729',
  int refreshCount = 0,
  DateTime? refreshWindowStart,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<TrackingBloc>.value(value: t),
            BlocProvider<BidBloc>.value(value: b),
          ],
          child: TalonRetraitCodeView(
            bidId: 'bid-1',
            initialCode: initialCode,
            refreshCount: refreshCount,
            refreshWindowStart: refreshWindowStart,
          ),
        ),
      ),
    ),
  );
  // Flush flutter_animate timers without failing on pending timers.
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('affiche le code de retrait initial', (tester) async {
    final t = _MockTrackingBloc();
    final b = _MockBidBloc();
    when(() => t.state).thenReturn(TrackingInitial());
    when(() => b.state).thenReturn(BidInitial());
    await _pump(tester, t, b);
    // Digit-box restyle: each digit is a separate Text widget
    for (final d in '4729'.split('')) {
      expect(find.text(d), findsWidgets);
    }
    expect(find.text('Copier le code'), findsOneWidget);
    expect(find.textContaining('Régénérer'), findsOneWidget);
  });

  // Fix #6: overflow regression test on a narrow 360dp device with 6-digit code
  testWidgets(
    'pas de RenderFlex overflow sur écran 360dp avec code 6 chiffres',
    (tester) async {
      // Simulate a 360×800 logical-pixel screen (pixel ratio 1.0)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final t = _MockTrackingBloc();
      final b = _MockBidBloc();
      when(() => t.state).thenReturn(TrackingInitial());
      when(() => b.state).thenReturn(BidInitial());

      await _pump(tester, t, b, initialCode: '472913');
      await tester.pump(const Duration(milliseconds: 400));

      // No RenderFlex overflow (or any other exception) must be thrown
      expect(tester.takeException(), isNull);

      // All 6 digit boxes must be rendered
      for (final d in '472913'.split('')) {
        expect(find.text(d), findsWidgets);
      }
    },
  );

  testWidgets(
    'TrackingRefreshCodeLoading → indicateur de chargement et texte "Régénération…"',
    (tester) async {
      final t = _MockTrackingBloc();
      final b = _MockBidBloc();
      when(() => t.state).thenReturn(TrackingRefreshCodeLoading());
      when(
        () => t.stream,
      ).thenAnswer((_) => Stream.value(TrackingRefreshCodeLoading()));
      when(() => b.state).thenReturn(BidInitial());
      when(() => b.stream).thenAnswer((_) => Stream<BidState>.empty());
      await _pump(tester, t, b);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Régénération…'), findsOneWidget);
    },
  );

  testWidgets('TrackingConfirmCodeLoaded → affiche le nouveau code', (
    tester,
  ) async {
    final t = _MockTrackingBloc();
    final b = _MockBidBloc();
    // Start with a new code loaded
    when(() => t.state).thenReturn(TrackingConfirmCodeLoaded('9999'));
    when(
      () => t.stream,
    ).thenAnswer((_) => Stream.value(TrackingConfirmCodeLoaded('9999')));
    when(() => b.state).thenReturn(BidInitial());
    when(() => b.stream).thenAnswer((_) => Stream<BidState>.empty());
    await _pump(tester, t, b, initialCode: '1111');
    // The displayed code should be the new one from state, not initialCode
    for (final d in '9999'.split('')) {
      expect(find.text(d), findsWidgets);
    }
  });

  testWidgets(
    'rate-limit actif (refreshCount=5, windowStart récent) → affiche countdown et message bloqué',
    (tester) async {
      final t = _MockTrackingBloc();
      final b = _MockBidBloc();
      when(() => t.state).thenReturn(TrackingInitial());
      when(() => b.state).thenReturn(BidInitial());
      // refreshCount = 5 (max) with a recent window start = rate limited
      final recentWindow = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await _pump(
        tester,
        t,
        b,
        refreshCount: 5,
        refreshWindowStart: recentWindow,
      );
      // Should show the lock icon (rate limited) and the limit message
      expect(find.textContaining('Limite de 5 régénérations'), findsOneWidget);
      // The regenerate button label should not say "Régénérer le code"
      expect(find.text('Régénérer le code'), findsNothing);
      // Should show a countdown like "Disponible dans"
      expect(find.textContaining('Disponible dans'), findsOneWidget);
    },
  );

  testWidgets(
    'rate-limit inactif (refreshCount=5, windowStart expiré) → bouton actif',
    (tester) async {
      final t = _MockTrackingBloc();
      final b = _MockBidBloc();
      when(() => t.state).thenReturn(TrackingInitial());
      when(() => b.state).thenReturn(BidInitial());
      // windowStart 25h ago → window expired, not rate limited
      final expiredWindow = DateTime.now().toUtc().subtract(
        const Duration(hours: 25),
      );
      await _pump(
        tester,
        t,
        b,
        refreshCount: 5,
        refreshWindowStart: expiredWindow,
      );
      // Button should be available again
      expect(find.text('Régénérer le code'), findsOneWidget);
      expect(find.textContaining('Limite de 5 régénérations'), findsNothing);
    },
  );
}
