import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/plane_icon_expectations.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

final _today = DateTime.now();

TripDelayInfo _delay({
  String reason = 'PORT_CONGESTION',
  String? message = 'Attente au port de Tanger Med',
}) => TripDelayInfo(
  reason: reason,
  arrivalDate: _today.add(const Duration(days: 30)),
  arrivalDateMax: _today.add(const Duration(days: 37)),
  message: message,
  announcedAt: _today.subtract(const Duration(days: 1)),
);

BidModel _bid({
  String status = 'IN_TRANSIT',
  TransportMode? mode = TransportMode.boat,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  PayoutTrigger payoutTrigger = PayoutTrigger.delivery,
  TripDelayInfo? delay,
  String departureCity = 'Le Havre',
  String arrivalCity = 'Abidjan',
}) => BidModel(
  id: 'bid-boat',
  announcementId: 'trip-boat',
  senderId: 'sender-1',
  status: status,
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
  travelerId: 'traveler-1',
  travelerName: 'Awa',
  recipientName: 'Aïcha',
  recipientPhone: '+2250700000000',
  weightKg: 30,
  paymentMethod: paymentMethod,
  payoutTrigger: payoutTrigger,
  totalAmountEur: 60,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  transportMode: mode,
  departureDate: _today.subtract(const Duration(days: 8)),
  arrivalDate: _today.add(const Duration(days: 25)),
  arrivalDateMax: mode == TransportMode.boat
      ? _today.add(const Duration(days: 32))
      : null,
  latestTripDelay: delay,
  handoverAddress: const AddressData(label: 'Quai 4', lat: 49.48, lng: 0.1),
);

Widget _host(BidModel bid) {
  final tracking = _MockTrackingBloc();
  when(() => tracking.state).thenReturn(TrackingInitial());
  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());
  final cancellation = _MockCancellationBloc();
  whenListen<CancellationState>(
    cancellation,
    const Stream<CancellationState>.empty(),
    initialState: CancellationInitial(),
  );
  final conversation = _MockConversationOpenBloc();
  whenListen<ConversationOpenState>(
    conversation,
    const Stream<ConversationOpenState>.empty(),
    initialState: const ConversationOpenInitial(),
  );
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<TrackingBloc>.value(value: tracking),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<CancellationBloc>.value(value: cancellation),
          BlocProvider<ConversationOpenBloc>.value(value: conversation),
        ],
        child: SenderDetailBody(bid: bid),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  BidModel bid, {
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(bid));
  // Passes de 400 ms : le stagger de flutter_animate laisse des Timers.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// La carte Paiement lit l'étape de dépôt par son propre TrackingBloc.
void _registerDepositEvents(List<TrackingEventModel> events) {
  final bloc = _MockTrackingBloc();
  whenListen<TrackingState>(
    bloc,
    Stream.value(TrackingEventsLoaded(events)),
    initialState: TrackingInitial(),
  );
  getIt.registerFactory<TrackingBloc>(() => bloc);
}

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakeTrackingEvent());
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  tearDown(() async => getIt.reset());

  group('delayCard_shown : retard annoncé, carte de report réutilisée', () {
    testWidgets('bateau : motif, nouvelle arrivée estimée, message', (
      tester,
    ) async {
      await _pump(tester, _bid(delay: _delay()));

      expect(find.byType(TripDelayCard), findsOneWidget);
      expect(find.text('Retard annoncé'), findsOneWidget);
      expect(
        find.textContaining('Nouvelle arrivée estimée : du '),
        findsOneWidget,
      );
      expect(find.text('Motif : Congestion au port'), findsOneWidget);
      expect(
        find.text('Message du voyageur : Attente au port de Tanger Med'),
        findsOneWidget,
      );
      // Sous le billet, avant le voyageur (maquette FicheMer).
      expect(
        tester.getTopLeft(find.byType(TripDelayCard)).dy,
        lessThan(tester.getTopLeft(find.byType(VoyageurContactCard)).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('route, arrêt prolongé : jamais « escale »', (tester) async {
      await _pump(
        tester,
        _bid(
          mode: TransportMode.car,
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          delay: _delay(reason: 'EXTENDED_STOPOVER', message: null),
        ),
      );
      expect(find.text('Motif : Arrêt prolongé'), findsOneWidget);
      expect(find.textContaining('scale'), findsNothing);
      expect(find.byKey(const Key('trip-delay-message')), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('sans retard : pas de carte', (tester) async {
      await _pump(tester, _bid());
      expect(find.byType(TripDelayCard), findsNothing);
    });

    testWidgets('en anglais', (tester) async {
      useEnglish();
      await _pump(tester, _bid(delay: _delay()));
      expect(find.text('Delay announced'), findsOneWidget);
      expect(find.textContaining('New estimated arrival: '), findsOneWidget);
      expect(find.text('Reason: Port congestion'), findsOneWidget);
    });
  });

  group('depositPaidTile : versé au transporteur au dépôt du colis', () {
    testWidgets('déposé : montant versé, avec la date du dépôt', (
      tester,
    ) async {
      _registerDepositEvents([
        TrackingEventModel(
          id: 'evt-depart',
          bidId: 'bid-boat',
          eventType: 'DEPART',
          scannedAt: DateTime(2026, 11, 26, 14, 10),
          createdAt: DateTime(2026, 11, 26, 14, 10),
        ),
      ]);
      await _pump(tester, _bid(payoutTrigger: PayoutTrigger.deposit));

      expect(find.byKey(const Key('paiement-deposit-paid')), findsOneWidget);
      expect(
        find.textContaining(
          'versé au transporteur au dépôt du colis, le 26 nov.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('libéré à la livraison'), findsNothing);
    });

    testWidgets('dépôt pas encore lu : la phrase sans date', (tester) async {
      await _pump(
        tester,
        _bid(
          payoutTrigger: PayoutTrigger.deposit,
          paymentMethod: BidPaymentMethod.mobileMoney,
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('paiement-deposit-paid')),
          matching: find.byType(Text),
        ),
      );
      expect(text.data, endsWith('versé au transporteur au dépôt du colis'));
    });

    testWidgets('pas encore déposé : payé, versé au dépôt', (tester) async {
      await _pump(
        tester,
        _bid(status: 'ACCEPTED', payoutTrigger: PayoutTrigger.deposit),
      );
      expect(find.byKey(const Key('paiement-deposit-pending')), findsOneWidget);
      expect(
        find.textContaining('payé, versé au transporteur au dépôt du colis'),
        findsOneWidget,
      );
    });

    testWidgets('payoutTrigger absent (back sans la PR B) : séquestre '
        'inchangé', (tester) async {
      await _pump(tester, _bid());
      expect(find.byKey(const Key('paiement-deposit-paid')), findsNothing);
      expect(find.textContaining('libéré à la livraison'), findsOneWidget);
    });

    testWidgets('espèces : rien ne passe par Yadony, texte habituel', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          payoutTrigger: PayoutTrigger.deposit,
          paymentMethod: BidPaymentMethod.cash,
        ),
      );
      expect(find.byKey(const Key('paiement-deposit-paid')), findsNothing);
      expect(find.byKey(const Key('paiement-deposit-pending')), findsNothing);
    });

    testWidgets('annulé : remboursé, jamais « versé »', (tester) async {
      await _pump(
        tester,
        _bid(status: 'CANCELLED', payoutTrigger: PayoutTrigger.deposit),
      );
      expect(find.byKey(const Key('paiement-deposit-paid')), findsNothing);
      expect(find.textContaining('versé au transporteur'), findsNothing);
    });

    testWidgets('en anglais', (tester) async {
      useEnglish();
      await _pump(tester, _bid(payoutTrigger: PayoutTrigger.deposit));
      expect(
        find.textContaining('paid to the carrier at parcel drop-off'),
        findsOneWidget,
      );
    });
  });

  group('fiche bateau : arrivée estimée', () {
    testWidgets('billet : « Arrivée estimée » en fourchette', (tester) async {
      await _pump(tester, _bid());
      expect(
        tester.widget<Text>(find.byKey(const Key('billet-arrival-label'))).data,
        'Arrivée estimée',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('billet-arrival-value'))).data,
        contains(' au '),
      );
    });

    testWidgets('tuile Suivi : arrivée estimée en fourchette à l\'arrivée', (
      tester,
    ) async {
      await _pump(tester, _bid());
      final suivi = find.widgetWithText(DonyActionTile, 'Suivi');
      expect(suivi, findsOneWidget);
      expect(
        find.descendant(
          of: suivi,
          matching: find.textContaining('Arrivée estimée du '),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: suivi, matching: find.textContaining('à Abidjan')),
        findsOneWidget,
      );
    });

    testWidgets('résumé d\'état en anglais', (tester) async {
      useEnglish();
      String? line;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              line = SenderHeroCard.statusLine(context, _bid());
              return const SizedBox();
            },
          ),
        ),
      );
      expect(line, startsWith('Estimated arrival '));
      expect(line, contains(' in Abidjan.'));
    });

    testWidgets('route : arrivée datée, libellé habituel', (tester) async {
      await _pump(
        tester,
        _bid(
          mode: TransportMode.car,
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('billet-arrival-label'))).data,
        'Arrivée',
      );
    });
  });

  group('aucun avion sur la fiche', () {
    for (final mode in [TransportMode.boat, TransportMode.car]) {
      for (final width in [360.0, 800.0]) {
        testWidgets('${mode.name} à ${width.toInt()} dp, FR et EN', (
          tester,
        ) async {
          final bid = _bid(
            mode: mode,
            delay: _delay(),
            payoutTrigger: mode == TransportMode.boat
                ? PayoutTrigger.deposit
                : PayoutTrigger.delivery,
          );
          await _pump(tester, bid, width: width);
          expect(tester.takeException(), isNull);
          expectNoPlaneIcon(tester);
          expect(findDonyIcon(mode.iconAsset), findsWidgets);

          useEnglish();
          await _pump(tester, bid, width: width);
          expect(tester.takeException(), isNull);
          expectNoPlaneIcon(tester);
        });
      }
    }
  });
}
