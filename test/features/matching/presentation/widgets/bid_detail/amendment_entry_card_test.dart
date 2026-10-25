import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_request_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_entry_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidModel _bid({bool allowed = true}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  travelerName: 'Moussa',
  status: 'ACCEPTED',
  amendmentAllowed: allowed,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockRepository repository;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    repository = _MockRepository();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options('bid-1')).thenAnswer(
      (_) async => const AmendmentOptions(
        currency: 'EUR',
        availableKg: 6,
        pricePerKgDisplay: 5.13,
        paymentMethods: [BidPaymentMethod.cash],
        minAmount: 1,
        maxAmount: 300,
      ),
    );
    getIt.registerFactory<AmendmentRequestCubit>(
      () => AmendmentRequestCubit(repository, analytics),
    );
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(body: AmendmentEntryCard(bid: bid)),
        ),
      ),
    );
  }

  test('entryCard_hiddenWhenNotAllowed', () {
    expect(AmendmentEntryCard.shouldShow(_bid(allowed: false)), isFalse);
    expect(AmendmentEntryCard.shouldShow(_bid()), isTrue);
  });

  testWidgets('entryCard_showsTitleBodyAndButton', (tester) async {
    await pump(tester, _bid());

    expect(find.text('MODIFIER MON COLIS'), findsOneWidget);
    expect(
      find.text(
        'Ajoutez des kilos ou des articles : Moussa a 48 h pour accepter.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DonyButton, 'Ajouter des kilos ou des articles'),
      findsOneWidget,
    );
  });

  testWidgets('entryCard_tapOpensSheet_closingWithoutRequestDoesNotReload', (
    tester,
  ) async {
    await pump(tester, _bid());
    await tester.tap(
      find.widgetWithText(DonyButton, 'Ajouter des kilos ou des articles'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modifier mon colis'), findsOneWidget);
    verifyNever(() => bidBloc.add(any()));
  });

  testWidgets('entryCard_requestSent_reloadsBid', (tester) async {
    when(
      () => repository.quote(
        'bid-1',
        addedKg: any(named: 'addedKg'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async => 22.4);
    when(
      () => repository.create(
        'bid-1',
        addedKg: 0.5,
        items: const {},
        method: BidPaymentMethod.cash,
      ),
    ).thenAnswer(
      (_) async => const AmendmentCheckout(
        amendment: BidAmendment(
          id: 'am-1',
          status: BidAmendmentStatus.proposed,
          rail: 'CASH',
          grossAmount: 22.4,
        ),
      ),
    );
    await pump(tester, _bid());
    await tester.tap(
      find.widgetWithText(DonyButton, 'Ajouter des kilos ou des articles'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Plus').first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DonyButton, 'Envoyer la demande à Moussa'),
    );
    await tester.pumpAndSettle();

    verify(
      () => bidBloc.add(
        any(
          that: isA<BidDetailRequested>().having(
            (e) => e.bidId,
            'bidId',
            'bid-1',
          ),
        ),
      ),
    ).called(1);
  });
}
