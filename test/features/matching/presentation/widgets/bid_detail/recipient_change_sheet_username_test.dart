import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _MockInvitationRepo extends Mock
    implements RecipientInvitationRepository {}

BidModel _bid() => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'IN_TRANSIT',
  recipientName: 'Fatou Sow',
  recipientPhone: '+221771234567',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockBidRepository bids;
  late _MockInvitationRepo invitations;
  late _MockAnalytics analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    bids = _MockBidRepository();
    invitations = _MockInvitationRepo();
    analytics = _MockAnalytics();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => invitations.parcelDesignationOffered).thenReturn(true);
    when(() => invitations.usernameChannelUnsupported).thenReturn(false);
    when(() => invitations.parcelDesignationUnavailable).thenReturn(false);
    when(() => invitations.lookupUsername(any())).thenAnswer(
      (_) async => const UsernameLookup(
        username: 'awa.diallo',
        initial: 'A',
        parcelDesignation: true,
      ),
    );
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<RecipientInvitationRepository>(invitations)
      ..registerFactory<RecipientChangeCubit>(
        () => RecipientChangeCubit(bids, analytics),
      )
      ..registerFactory<DesignateYadonyUserCubit>(
        () => DesignateYadonyUserCubit(invitations, analytics),
      );
  });

  tearDown(() async => getIt.reset());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openRecipientChangeSheet(context, _bid()),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> designate(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('recipient-change-yadony-user')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('designate-yadony-user-field')),
      'awa.diallo',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('designate-yadony-user-choose')));
    await tester.pumpAndSettle();
  }

  testWidgets('back sans désignation de colis : pas de choix', (tester) async {
    when(() => invitations.parcelDesignationOffered).thenReturn(false);
    await open(tester);
    expect(find.byKey(const Key('recipient-change-yadony-user')), findsNothing);
  });

  testWidgets('identifiant choisi : envoie recipientUsername seul', (
    tester,
  ) async {
    when(
      () => bids.changeRecipient(
        any(),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
        recipientUsername: any(named: 'recipientUsername'),
      ),
    ).thenAnswer((_) async => _bid());
    await open(tester);
    expect(find.text('Un utilisateur Yadony'), findsOneWidget);
    await designate(tester);

    expect(find.text('@awa.diallo'), findsOneWidget);
    expect(find.text('En attente de confirmation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    verify(
      () => bids.changeRecipient('bid-1', recipientUsername: 'awa.diallo'),
    ).called(1);
  });

  testWidgets('Changer revient aux champs nom et numéro', (tester) async {
    await open(tester);
    await designate(tester);
    await tester.tap(find.text('Changer'));
    await tester.pumpAndSettle();
    expect(find.text('Fatou Sow'), findsOneWidget);
    expect(find.text('+221771234567'), findsOneWidget);
  });
}
