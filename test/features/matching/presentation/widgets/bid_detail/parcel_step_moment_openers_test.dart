// Boutons d'un modal d'étape du colis : chaque ouvreur de la fiche ouvre la
// bonne fenêtre (QR, « Prévenir » en mode code, suivi, frise du voyageur).
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_step_moment.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/video_modal/data/models/parcel_step.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptance
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

void main() {
  const sender = 'sender-1';
  const traveler = 'traveler-1';

  BidModel bid({
    TravelerTrackingModel? tracking,
    String status = 'HANDED_OVER',
  }) => BidModel(
    id: 'bid-1',
    announcementId: 'ann-1',
    senderId: sender,
    travelerId: traveler,
    status: status,
    createdAt: DateTime(2026, 11),
    updatedAt: DateTime(2026, 11),
    confirmationCode: '482913',
    trackingToken: 'tok',
    recipientName: 'Awa',
    recipientPhone: '+221700000000',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    weightKg: 3,
    travelerTracking: tracking,
  );

  late _MockBidBloc bidBloc;
  late _MockTrackingBloc trackingBloc;

  void resetGetIt() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<TravelerTrackingCardCubit>()) {
      getIt.unregister<TravelerTrackingCardCubit>();
    }
    if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
  }

  setUpAll(() async {
    registerFallbackValue(BidDetailRequested('fallback'));
    await initializeDateFormatting('fr');
  });

  setUp(() async {
    final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
    await analytics.onConfigured();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => bidBloc.stream,
    ).thenAnswer((_) => const Stream<BidState>.empty());
    trackingBloc = _MockTrackingBloc();
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(
      () => trackingBloc.stream,
    ).thenAnswer((_) => const Stream<TrackingState>.empty());
    resetGetIt();
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerFactory<TravelerTrackingCardCubit>(
      () => TravelerTrackingCardCubit(analytics: analytics),
    );
    getIt.registerFactory<TrackingBloc>(() => trackingBloc);
  });

  tearDown(resetGetIt);

  /// Pose un bouton qui appelle l'ouvreur [pick] du moment, sous les BLoCs de
  /// la fiche, puis le touche.
  Future<void> run(
    WidgetTester tester,
    BidModel b,
    String viewer,
    ParcelActionOpener? Function(ParcelActionOpeners) pick,
  ) async {
    final openers = bidParcelStepMoment(b, viewerId: viewer)!.parcel!.openers;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<BidAcceptanceBloc>.value(value: _MockAcceptance()),
            BlocProvider<TrackingBloc>.value(value: trackingBloc),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => pick(openers)!(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    // Le QR affiche un indicateur de chargement sans fin : un seul pump long.
    await tester.pump(const Duration(seconds: 1));
  }

  TravelerTrackingModel tracking() => TravelerTrackingModel(
    status: TravelerTrackingStatus.enRoute,
    lastUpdatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    progressPct: 40,
    nearestCity: 'Marseille',
  );

  testWidgets('expéditeur : « Prévenir » ouvre la fenêtre en mode code', (
    tester,
  ) async {
    await run(tester, bid(), sender, (o) => o.sendCode);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('donyBottomSheetFooter')), findsOneWidget);
  });

  testWidgets('expéditeur : le suivi ouvre la tuile Suivi quand elle existe', (
    tester,
  ) async {
    await run(tester, bid(tracking: tracking()), sender, (o) => o.tracking);
    expect(tester.takeException(), isNull);
    expect(find.text('Suivi'), findsWidgets);
  });

  testWidgets('expéditeur : sans tuile Suivi, la frise du colis', (
    tester,
  ) async {
    await run(tester, bid(), sender, (o) => o.tracking);
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('expéditeur : le QR du colis s\'ouvre', (tester) async {
    await run(tester, bid(status: 'ACCEPTED'), sender, (o) => o.qr);
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('voyageur : le suivi ouvre la frise du colis', (tester) async {
    await run(tester, bid(), traveler, (o) => o.tracking);
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
