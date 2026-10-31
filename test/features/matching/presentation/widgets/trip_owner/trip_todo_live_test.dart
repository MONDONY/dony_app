// Dernières données connues des tuiles « À traiter » du trajet
// (`TripTodoLive`), partagées par la section de l'écran et les sheets : un
// rechargement (colis, compte Stripe) ne fait ni clignoter ni retomber la
// tuile « demandes » sur `pendingBidCount`.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/stripe_account_test_doubles.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

const _ready = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

AnnouncementModel _trip({
  String id = 'trip-1',
  String status = 'ACTIVE',
  int pendingBidCount = 0,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
}) {
  final now = DateTime(2026, 10, 30);
  return AnnouncementModel(
    id: id,
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: now.add(const Duration(days: 3)),
    availableKg: 20,
    totalKg: 20,
    status: status,
    createdAt: now,
    updatedAt: now,
    pendingBidCount: pendingBidCount,
    acceptedPaymentMethods: methods,
  );
}

/// Colis payé en espèces : une demande PENDING par carte n'est pas encore
/// payée par l'expéditeur, donc pas à traiter.
BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  paymentMethod: BidPaymentMethod.cash,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockAnnouncementBloc annBloc;
  late StreamController<AnnouncementState> annStates;
  late _MockBidBloc bidBloc;
  late StreamController<BidState> bidStates;
  late MockStripeAccountBloc stripeBloc;
  late StreamController<StripeAccountState> stripeStates;
  late _MockDepart departCubit;
  late StreamController<TripDepartState> departStates;
  late List<TripTodoLiveData> seen;

  setUp(() {
    annStates = StreamController<AnnouncementState>.broadcast();
    bidStates = StreamController<BidState>.broadcast();
    stripeStates = StreamController<StripeAccountState>.broadcast();
    departStates = StreamController<TripDepartState>.broadcast();
    addTearDown(annStates.close);
    addTearDown(bidStates.close);
    addTearDown(stripeStates.close);
    addTearDown(departStates.close);
    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    stripeBloc = MockStripeAccountBloc();
    departCubit = _MockDepart();
    seen = [];
  });

  /// Monte [TripTodoLive] comme le fera la section « À traiter » de l'écran.
  Future<void> pump(
    WidgetTester tester, {
    AnnouncementModel? trip,
    BidState? bidState,
    StripeAccountState stripe = const StripeAccountInitial(),
    TripDepartState depart = const TripDepartState(),
    bool withBlocs = true,
    List<BidModel>? initialBids,
  }) async {
    final t = trip ?? _trip();
    whenListen(
      annBloc,
      annStates.stream,
      initialState: AnnouncementDetailLoaded(t),
    );
    whenListen(
      bidBloc,
      bidStates.stream,
      initialState: bidState ?? BidListLoaded([_bid('b1', 'PENDING')]),
    );
    whenListen(stripeBloc, stripeStates.stream, initialState: stripe);
    whenListen(departCubit, departStates.stream, initialState: depart);

    final live = Builder(
      builder: (context) => TripTodoLive(
        trip: t,
        blocs: TripTodoBlocs.of(context),
        initialBids: initialBids,
        builder: (context, data) {
          seen.add(data);
          return Text(
            data.todo().map((item) => item.kind.name).join(','),
            textDirection: TextDirection.ltr,
          );
        },
      ),
    );
    await tester.pumpWidget(
      withBlocs
          ? MultiBlocProvider(
              providers: [
                BlocProvider<AnnouncementBloc>.value(value: annBloc),
                BlocProvider<BidBloc>.value(value: bidBloc),
                BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
                BlocProvider<TripDepartCubit>.value(value: departCubit),
              ],
              child: live,
            )
          : live,
    );
  }

  TripTodoLiveData last() => seen.last;

  int pending(TripTodoLiveData data) =>
      tripPendingRequestCount(data.trip, data.bids);

  testWidgets('TripTodoBlocs.of : blocs fournis au-dessus du contexte', (
    tester,
  ) async {
    late TripTodoBlocs blocs;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<TripDepartCubit>.value(value: departCubit),
        ],
        child: Builder(
          builder: (context) {
            blocs = TripTodoBlocs.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(blocs.bids, same(bidBloc));
    expect(blocs.depart, same(departCubit));
    expect(blocs.announcement, isNull);
    expect(blocs.stripe, isNull);
  });

  testWidgets('données de départ : trajet, colis, statut Stripe, départ', (
    tester,
  ) async {
    await pump(tester, stripe: _ready);

    expect(last().trip.id, 'trip-1');
    expect(last().bids?.single.id, 'b1');
    expect(pending(last()), 1);
    expect(last().cardReady, isTrue);
    expect(last().departed, isFalse);
    expect(find.text('requests'), findsOneWidget);
  });

  testWidgets('colis en rechargement : l\'action demandes ne clignote pas', (
    tester,
  ) async {
    // Le détail ne sert pas pendingBidCount : un repli donnerait 0.
    await pump(tester);
    final builds = seen.length;

    bidStates.add(BidLoading());
    await tester.pumpAndSettle();
    bidStates.add(BidError(const NetworkException('x')));
    await tester.pumpAndSettle();

    expect(seen.length, builds, reason: 'aucune reconstruction');
    expect(find.text('requests'), findsOneWidget);

    bidStates.add(BidListLoaded([_bid('b1', 'ACCEPTED')]));
    await tester.pumpAndSettle();
    expect(pending(last()), 0);
    expect(find.text('requests'), findsNothing);
  });

  testWidgets('monté pendant un rechargement : colis de l\'appelant repris', (
    tester,
  ) async {
    await pump(
      tester,
      bidState: BidLoading(),
      initialBids: [_bid('b1', 'PENDING'), _bid('b2', 'PENDING')],
    );

    expect(pending(last()), 2);
    expect(find.text('requests'), findsOneWidget);

    bidStates.add(BidListLoaded(const []));
    await tester.pumpAndSettle();
    expect(pending(last()), 0);
  });

  testWidgets('monté pendant un rechargement, sans colis connus : repli sur '
      'pendingBidCount', (tester) async {
    await pump(tester, trip: _trip(pendingBidCount: 3), bidState: BidLoading());

    expect(last().bids, isNull);
    expect(pending(last()), 3);
  });

  testWidgets('compte Stripe relu : chargement et erreur gardent le dernier '
      'statut', (tester) async {
    await pump(
      tester,
      trip: _trip(methods: const {BidPaymentMethod.cash}),
      stripe: _ready,
    );
    expect(last().cardReady, isTrue);

    stripeStates.add(const StripeAccountLoading());
    await tester.pumpAndSettle();
    stripeStates.add(const StripeAccountLoadError());
    await tester.pumpAndSettle();
    expect(last().cardReady, isTrue);
    expect(find.text('requests,addCard'), findsOneWidget);
  });

  testWidgets('trajet relu suivi, autre trajet ou chargement ignorés', (
    tester,
  ) async {
    await pump(tester);

    annStates.add(AnnouncementDetailLoaded(_trip(id: 'trip-2')));
    await tester.pumpAndSettle();
    annStates.add(AnnouncementLoading());
    await tester.pumpAndSettle();
    expect(last().trip.status, 'ACTIVE');

    annStates.add(AnnouncementUpdated(_trip(status: 'COMPLETED')));
    await tester.pumpAndSettle();
    expect(last().trip.status, 'COMPLETED');
    expect(last().todo(), isEmpty);
  });

  testWidgets('départ confirmé suivi', (tester) async {
    await pump(tester);
    departStates.add(const TripDepartState(departed: true));
    await tester.pumpAndSettle();
    expect(last().departed, isTrue);
  });

  testWidgets('sans blocs : valeurs de départ', (tester) async {
    await pump(tester, trip: _trip(pendingBidCount: 2), withBlocs: false);

    expect(last().bids, isNull);
    expect(pending(last()), 2);
    expect(last().stripe, isA<StripeAccountInitial>());
    expect(last().departed, isFalse);
    // Aucune demande déduite de pendingBidCount : il compte aussi les cartes
    // pas encore payées et les expéditeurs bloqués.
    expect(last().todo(), isEmpty);
  });

  testWidgets('todo : demandes traitées depuis l\'écran retirées', (
    tester,
  ) async {
    await pump(
      tester,
      bidState: BidListLoaded([_bid('b1', 'PENDING'), _bid('b2', 'PENDING')]),
    );
    final item = last().todo().single;
    expect(item.kind, TripTodoKind.requests);
    expect(item.count, 2);
    expect(last().todo(answered: {'b1'}).single.bidIds, ['b2']);
    expect(last().todo(answered: {'b1', 'b2'}), isEmpty);
  });
}
