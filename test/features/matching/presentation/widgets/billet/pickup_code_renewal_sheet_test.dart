import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/presentation/widgets/billet/pickup_code_renewal_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

void main() {
  setUpAll(() => registerFallbackValue(TrackingRefreshCodeRequested('x')));

  late _MockTrackingBloc tracking;
  late _MockBidBloc bids;
  late StreamController<TrackingState> states;

  setUp(() {
    tracking = _MockTrackingBloc();
    bids = _MockBidBloc();
    states = StreamController<TrackingState>.broadcast();
    when(() => bids.state).thenReturn(BidInitial());
    whenListen(tracking, states.stream, initialState: TrackingInitial());
  });

  tearDown(() => states.close());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TrackingBloc>.value(value: tracking),
            BlocProvider<BidBloc>.value(value: bids),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showPickupCodeRenewalSheet(context, bidId: 'bid-1'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('titre, explication et bouton épinglé', (tester) async {
    await openSheet(tester);
    expect(find.text('Le voyageur demande un nouveau code'), findsOneWidget);
    expect(
      find.textContaining("Le code de retrait n'est plus valide"),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pickup-code-renewal-generate')),
      findsOneWidget,
    );
  });

  testWidgets('l\'appui régénère le code, marqué « après blocage »', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('pickup-code-renewal-generate')));
    await tester.pump();

    final captured =
        verify(() => tracking.add(captureAny())).captured.single
            as TrackingRefreshCodeRequested;
    expect(captured.bidId, 'bid-1');
    expect(captured.afterBlock, isTrue);
  });

  testWidgets('nouveau code reçu : la feuille se ferme', (tester) async {
    await openSheet(tester);
    states.add(TrackingConfirmCodeLoaded('123456'));
    await tester.pumpAndSettle();
    expect(find.text('Le voyageur demande un nouveau code'), findsNothing);
  });

  testWidgets('erreur : la feuille se ferme (le talon la présente)', (
    tester,
  ) async {
    await openSheet(tester);
    states.add(TrackingRefreshCodeError(const NetworkException('x')));
    await tester.pumpAndSettle();
    expect(find.text('Le voyageur demande un nouveau code'), findsNothing);
  });
}
