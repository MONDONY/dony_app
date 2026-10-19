import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidSupplement _cash(
  BidSupplementStatus status, {
  String? commissionStatus,
  bool forSender = false,
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  rail: 'CASH',
  netAmount: forSender ? null : 15,
  commissionAmount: forSender ? null : 2,
  grossAmount: 17,
  reasonCode: 'EXTRA_WEIGHT',
  commissionStatus: forSender ? null : commissionStatus,
  expiresAt: DateTime(2026, 10, 19, 14, 30),
  blocksHandover: status.isOpen,
);

BidModel _bid(BidSupplement? supplement) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  paymentMethod: BidPaymentMethod.cash,
  supplement: supplement,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Texte affiché, espaces insécables du format monétaire lues comme des
/// espaces simples.
Finder _txt(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll(RegExp('[  ]'), ' ') ==
          text,
);

void main() {
  late _MockRepository repository;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;
  late bool failAuth;
  late bool authorizeResult;
  late int authorizations;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    DonySnackbar.clearDedup();
    repository = _MockRepository();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    failAuth = false;
    authorizeResult = true;
    authorizations = 0;
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt
      ..registerFactory<SupplementActionCubit>(
        () => SupplementActionCubit(repository, analytics),
      )
      ..registerFactory<SupplementCommissionCubit>(
        () => SupplementCommissionCubit(
          SupplementCommissionFlow(
            repository,
            analytics,
            nextAction: (_) async {
              if (failAuth) throw StateError('canceled');
            },
          ),
          analytics,
        ),
      );
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SupplementTravelerCard traveler(BidSupplement s) => SupplementTravelerCard(
    bid: _bid(s),
    authorize: (_) async {
      authorizations++;
      return authorizeResult;
    },
  );

  group('shouldShow (voyageur, espèces)', () {
    test('annulée : toujours montrée en espèces, jamais sinon', () {
      expect(
        SupplementTravelerCard.shouldShow(
          _bid(_cash(BidSupplementStatus.cancelled)),
        ),
        isTrue,
      );
      expect(
        SupplementTravelerCard.shouldShow(
          _bid(
            const BidSupplement(
              id: 's',
              status: BidSupplementStatus.cancelled,
              rail: 'STRIPE',
              grossAmount: 1,
            ),
          ),
        ),
        isFalse,
      );
    });

    test('retirée : montrée seulement si la commission a été prélevée', () {
      expect(
        SupplementTravelerCard.shouldShow(
          _bid(_cash(BidSupplementStatus.withdrawn)),
        ),
        isFalse,
      );
      for (final status in [
        SupplementCommissionStatus.charged,
        SupplementCommissionStatus.refunded,
        SupplementCommissionStatus.refundFailed,
      ]) {
        expect(
          SupplementTravelerCard.shouldShow(
            _bid(
              _cash(BidSupplementStatus.withdrawn, commissionStatus: status),
            ),
          ),
          isTrue,
          reason: status,
        );
      }
    });

    test(
      'l\'expéditeur ne voit jamais une demande en attente de commission',
      () {
        expect(
          SupplementSenderCard.shouldShow(
            _bid(_cash(BidSupplementStatus.commissionPending, forSender: true)),
          ),
          isFalse,
        );
      },
    );
  });

  group('voyageur', () {
    testWidgets('commission à valider : aide et « Valider le paiement »', (
      tester,
    ) async {
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async => _cash(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
        ),
      );
      await pump(
        tester,
        traveler(_cash(BidSupplementStatus.commissionPending)),
      );

      expect(find.text('Commission à valider'), findsOneWidget);
      expect(
        find.textContaining('Validez le paiement de la commission'),
        findsOneWidget,
      );
      expect(find.text('Retirer la demande'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('supplement-commission-confirm-btn')),
      );
      await tester.pumpAndSettle();

      expect(authorizations, 1);
      verify(() => repository.confirmCommission('bid-1', 'sup-1')).called(1);
      expect(
        find.text('Commission payée : demande envoyée à l\'expéditeur'),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('vérification refusée : rien n\'est confirmé', (tester) async {
      authorizeResult = false;
      await pump(
        tester,
        traveler(_cash(BidSupplementStatus.commissionPending)),
      );

      await tester.tap(
        find.byKey(const Key('supplement-commission-confirm-btn')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paiement non confirmé, réessayez'), findsOneWidget);
      verifyNever(() => repository.confirmCommission(any(), any()));
    });

    testWidgets('3DS abandonnée : message, pas de relecture', (tester) async {
      failAuth = true;
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async => const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.commissionPending,
          rail: 'CASH',
          grossAmount: 17,
          commissionClientSecret: 'pi_secret',
        ),
      );
      await pump(
        tester,
        traveler(_cash(BidSupplementStatus.commissionPending)),
      );

      await tester.tap(
        find.byKey(const Key('supplement-commission-confirm-btn')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Validation bancaire interrompue : rien n\'a été prélevé. Réessayez.',
        ),
        findsOneWidget,
      );
      verifyNever(() => bidBloc.add(any()));
    });

    testWidgets('carte refusée : erreur et relecture', (tester) async {
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenThrow(
        const ValidationException(
          'd',
          code: 'supplement-commission-card-declined',
        ),
      );
      await pump(
        tester,
        traveler(_cash(BidSupplementStatus.commissionPending)),
      );

      await tester.tap(
        find.byKey(const Key('supplement-commission-confirm-btn')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carte refusée'), findsWidgets);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('Stripe traite encore : message neutre et relecture', (
      tester,
    ) async {
      when(
        () => repository.confirmCommission('bid-1', 'sup-1'),
      ).thenAnswer((_) async => _cash(BidSupplementStatus.commissionPending));
      await pump(
        tester,
        traveler(_cash(BidSupplementStatus.commissionPending)),
      );

      await tester.tap(
        find.byKey(const Key('supplement-commission-confirm-btn')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Demande enregistrée : paiement de la commission en cours de '
          'validation',
        ),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('en attente, commission prélevée : aide et récap espèces', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _cash(
            BidSupplementStatus.proposed,
            commissionStatus: SupplementCommissionStatus.charged,
          ),
        ),
      );

      expect(find.text('En attente de l\'expéditeur'), findsOneWidget);
      expect(
        find.text(
          'Commission prélevée. Elle vous est rendue si la demande n\'aboutit '
          'pas.',
        ),
        findsOneWidget,
      );
      expect(find.text('Remis en espèces par l\'expéditeur'), findsOneWidget);
      expect(
        find.byKey(const Key('supplement-commission-confirm-btn')),
        findsNothing,
      );
    });

    testWidgets('accepté : complément remis en main propre', (tester) async {
      await pump(
        tester,
        traveler(
          _cash(
            BidSupplementStatus.paid,
            commissionStatus: SupplementCommissionStatus.charged,
          ),
        ),
      );

      expect(
        _txt('Supplément accepté : l\'expéditeur vous remet 17 € en espèces'),
        findsOneWidget,
      );
      expect(
        find.text('Recevez le complément en main propre à la remise du colis.'),
        findsOneWidget,
      );
    });

    testWidgets('refusé : commission rendue', (tester) async {
      await pump(
        tester,
        traveler(
          _cash(
            BidSupplementStatus.declined,
            commissionStatus: SupplementCommissionStatus.refunded,
          ),
        ),
      );

      expect(find.text('L\'expéditeur a refusé le supplément'), findsOneWidget);
      expect(
        find.text('La commission du supplément vous a été rendue.'),
        findsOneWidget,
      );
    });

    testWidgets('expiré : commission en cours de remboursement', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _cash(
            BidSupplementStatus.expired,
            commissionStatus: SupplementCommissionStatus.charged,
          ),
        ),
      );

      expect(
        find.text('La commission du supplément vous sera rendue sous peu.'),
        findsOneWidget,
      );
    });

    testWidgets('annulée sans prélèvement (3DS jamais validée)', (
      tester,
    ) async {
      await pump(tester, traveler(_cash(BidSupplementStatus.cancelled)));

      expect(find.text('Demande de supplément annulée'), findsOneWidget);
      expect(
        find.text('Rien n\'a été prélevé sur votre solde ni sur votre carte.'),
        findsOneWidget,
      );
    });

    testWidgets('retirée après prélèvement : commission rendue', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _cash(
            BidSupplementStatus.withdrawn,
            commissionStatus: SupplementCommissionStatus.refunded,
          ),
        ),
      );

      expect(find.text('Demande retirée'), findsOneWidget);
      expect(
        find.text('La commission du supplément vous a été rendue.'),
        findsOneWidget,
      );
    });

    testWidgets('colis non livré après acceptation : rendre le complément', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _cash(
            BidSupplementStatus.refunded,
            commissionStatus: SupplementCommissionStatus.refunded,
          ),
        ),
      );

      expect(
        find.text(
          'Colis non livré : rendez le complément en espèces à l\'expéditeur',
        ),
        findsOneWidget,
      );
    });
  });

  group('expéditeur', () {
    testWidgets('en attente : aide « Accepter » des espèces, brut seul', (
      tester,
    ) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_cash(BidSupplementStatus.proposed, forSender: true)),
        ),
      );

      expect(find.text('Le voyageur demande un supplément'), findsOneWidget);
      expect(
        find.textContaining('remettez le complément en espèces au voyageur'),
        findsOneWidget,
      );
      expect(_txt('15 €'), findsNothing);
    });

    testWidgets('accepté : à remettre en espèces', (tester) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_cash(BidSupplementStatus.paid, forSender: true)),
        ),
      );

      expect(
        _txt('Supplément accepté : 17 € à remettre en espèces'),
        findsOneWidget,
      );
    });

    testWidgets('colis non livré après acceptation : complément rendu', (
      tester,
    ) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_cash(BidSupplementStatus.refunded, forSender: true)),
        ),
      );

      expect(
        find.text(
          'Colis non livré : le voyageur vous rend le complément en espèces',
        ),
        findsOneWidget,
      );
    });
  });
}
