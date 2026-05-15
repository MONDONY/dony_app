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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<TrackingBloc>.value(value: t),
            BlocProvider<BidBloc>.value(value: b),
          ],
          child: TalonRetraitCodeView(
            bidId: 'bid-1',
            initialCode: initialCode,
            refreshCount: 0,
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
}
