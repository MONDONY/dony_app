import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequestListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockTripListBloc
    extends MockBloc<BidNegotiationListEvent, BidNegotiationListState>
    implements BidNegotiationListBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _kSettle = Duration(milliseconds: 600);

NegotiationThread _thread({
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  String? travelerName = 'Mamadou Diallo',
  DateTime? lastActivityAt,
}) => NegotiationThread(
  id: 't-1',
  packageRequestId: 'pr-1',
  travelerId: 'tr-1',
  travelerTravelDate: DateTime(2026, 6, 15),
  travelerAvailableKg: 10,
  status: status,
  currentPriceEur: 45,
  roundsCount: 2,
  lastActivityAt: lastActivityAt ?? DateTime(2026, 5, 10),
  createdAt: DateTime(2026, 5, 10),
  messages: const [],
  travelerName: travelerName,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  weightKg: 5,
);

BidNegotiationSummary _summary({
  String bidId = 'bid-1',
  String status = 'NEGOTIATING',
  String? counterparty = 'Awa Diop',
  DateTime? updatedAt,
}) => BidNegotiationSummary(
  bidId: bidId,
  announcementId: 'ann-1',
  status: status,
  round: 2,
  proposedGrossEur: 42,
  counterpartyName: counterparty,
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  updatedAt: updatedAt ?? DateTime(2026, 5, 20),
);

void main() {
  late _MockRequestListBloc requestBloc;
  late _MockTripListBloc tripBloc;
  late _MockAuthBloc authBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const NegotiationListFetchRequested());
    registerFallbackValue(const BidNegotiationListFetchRequested());
  });

  setUp(() {
    requestBloc = _MockRequestListBloc();
    tripBloc = _MockTripListBloc();
    authBloc = _MockAuthBloc();

    when(() => requestBloc.state).thenReturn(NegotiationListState());
    when(
      () => requestBloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationListState>.empty());
    when(() => tripBloc.state).thenReturn(const BidNegotiationListState());
    when(
      () => tripBloc.stream,
    ).thenAnswer((_) => const Stream<BidNegotiationListState>.empty());
    when(() => authBloc.state).thenReturn(
      const AuthAuthenticated(
        UserModel(
          id: 'sender-1',
          roles: ['SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        ),
      ),
    );
    when(
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());

    if (!getIt.isRegistered<NegotiationFilterCubit>()) {
      getIt.registerFactory<NegotiationFilterCubit>(
        () => NegotiationFilterCubit(),
      );
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationFilterCubit>()) {
      await getIt.unregister<NegotiationFilterCubit>();
    }
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<NegotiationListBloc>.value(value: requestBloc),
        BlocProvider<BidNegotiationListBloc>.value(value: tripBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: const Scaffold(body: MyNegotiationsBody()),
    ),
  );

  void loadBoth({
    List<NegotiationThread> threads = const [],
    List<BidNegotiationSummary> summaries = const [],
  }) {
    when(() => requestBloc.state).thenReturn(
      NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: threads,
      ),
    );
    when(() => tripBloc.state).thenReturn(
      BidNegotiationListState(
        status: BidNegotiationListStatus.loaded,
        summaries: summaries,
      ),
    );
  }

  Future<void> pumpBody(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pump(_kSettle);
  }

  testWidgets('les deux sources apparaissent dans la meme liste', (
    tester,
  ) async {
    loadBoth(threads: [_thread()], summaries: [_summary()]);
    await pumpBody(tester);

    expect(find.text('Mamadou Diallo'), findsOneWidget);
    expect(find.text('Awa Diop'), findsOneWidget);
  });

  testWidgets('chaque carte porte son marqueur de source', (tester) async {
    loadBoth(threads: [_thread()], summaries: [_summary()]);
    await pumpBody(tester);

    expect(find.text('Demande'), findsOneWidget);
    expect(find.text('Trajet'), findsOneWidget);
  });

  testWidgets('les compteurs des chips comptent les deux sources', (
    tester,
  ) async {
    loadBoth(
      threads: [
        _thread(),
        _thread(status: NegotiationThreadStatus.rejected),
      ],
      summaries: [
        _summary(),
        _summary(bidId: 'bid-2', status: 'REJECTED'),
      ],
    );
    await pumpBody(tester);

    expect(find.text('Toutes (4)'), findsOneWidget);
    expect(find.text('En cours (2)'), findsOneWidget);
    expect(find.text('Terminées (2)'), findsOneWidget);
  });

  testWidgets('l etat vide ne s affiche que si les deux sources sont vides', (
    tester,
  ) async {
    loadBoth(summaries: [_summary()]);
    await pumpBody(tester);

    expect(find.text('Aucune négociation'), findsNothing);
    expect(find.text('Awa Diop'), findsOneWidget);
  });

  testWidgets('la liste reste triee par activite la plus recente', (
    tester,
  ) async {
    loadBoth(
      threads: [_thread(lastActivityAt: DateTime(2026, 5, 10))],
      summaries: [_summary(updatedAt: DateTime(2026, 5, 25))],
    );
    await pumpBody(tester);

    final tripY = tester.getTopLeft(find.text('Awa Diop')).dy;
    final requestY = tester.getTopLeft(find.text('Mamadou Diallo')).dy;
    expect(tripY, lessThan(requestY));
  });
}
