import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/screens/reception_confirm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinput/pinput.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ConfirmDeliveryRequested(bidId: 'fallback', code: '000000'),
    );
  });

  late _MockTrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<TrackingState>.empty());
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<TrackingBloc>.value(
          value: bloc,
          child: const ReceptionConfirmScreen(bidId: 'bid-1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900)); // anim mascotte
  }

  group('ReceptionConfirmScreen', () {
    testWidgets('affiche le bouton de confirmation', (tester) async {
      await pump(tester);
      expect(
        find.widgetWithText(DonyButton, 'Confirmer la livraison'),
        findsOneWidget,
      );
    });

    testWidgets('moins de 6 chiffres → aucune confirmation dispatchée', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(Pinput), '4721');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(DonyButton, 'Confirmer la livraison'),
      );
      await tester.pump();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'code à 6 chiffres + confirmation → dispatche ConfirmDeliveryRequested',
      (tester) async {
        await pump(tester);
        await tester.enterText(find.byType(Pinput), '472913');
        await tester.pump();
        await tester.tap(
          find.widgetWithText(DonyButton, 'Confirmer la livraison'),
        );
        await tester.pump();

        final events = verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<ConfirmDeliveryRequested>().toList();
        expect(events, isNotEmpty);
        expect(events.first.bidId, 'bid-1');
        expect(events.first.code, '472913');
      },
    );
  });
}
