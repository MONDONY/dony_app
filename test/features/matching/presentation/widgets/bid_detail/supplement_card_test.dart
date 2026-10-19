import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/parcel_refusal/parcel_refusal_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidSupplement _supplement(
  BidSupplementStatus status, {
  bool forSender = false,
  String? photoUrl,
  String reasonCode = 'GRID_ITEM',
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  rail: 'STRIPE',
  netAmount: forSender ? null : 15,
  commissionAmount: forSender ? null : 2,
  grossAmount: 17,
  reasonCode: reasonCode,
  reasonText: 'Un iPhone dans le colis',
  gridItemLabel: 'Téléphone',
  photoUrl: photoUrl,
  expiresAt: DateTime(2026, 10, 19, 14, 30),
  blocksHandover: status.isOpen,
);

BidModel _bid(BidSupplement? supplement, {String status = 'ACCEPTED'}) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'ann-1',
      senderId: 'sender-1',
      status: status,
      supplement: supplement,
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );

/// Texte affiché, espaces insécables du format monétaire lues comme des
/// espaces simples.
Finder _txt(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll(
            RegExp('[\\u00A0\\u202F]'),
            ' ',
          ) ==
          text,
);

void main() {
  late _MockRepository repository;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    DonySnackbar.clearDedup();
    repository = _MockRepository();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<SupplementActionCubit>(
      () => SupplementActionCubit(repository, analytics),
    );
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    bool settle = true,
  }) async {
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
    if (settle) await tester.pumpAndSettle();
  }

  group('shouldShow', () {
    test('voyageur : rien pour un supplément retiré, annulé ou inconnu', () {
      expect(SupplementTravelerCard.shouldShow(_bid(null)), isFalse);
      for (final s in [
        BidSupplementStatus.withdrawn,
        BidSupplementStatus.cancelled,
        BidSupplementStatus.unknown,
      ]) {
        expect(
          SupplementTravelerCard.shouldShow(_bid(_supplement(s))),
          isFalse,
        );
      }
      expect(
        SupplementTravelerCard.shouldShow(
          _bid(_supplement(BidSupplementStatus.commissionPending)),
        ),
        isTrue,
      );
    });

    test('expéditeur : rien tant que la commission espèces est prélevée', () {
      expect(SupplementSenderCard.shouldShow(_bid(null)), isFalse);
      expect(
        SupplementSenderCard.shouldShow(
          _bid(_supplement(BidSupplementStatus.commissionPending)),
        ),
        isFalse,
      );
      expect(
        SupplementSenderCard.shouldShow(
          _bid(_supplement(BidSupplementStatus.withdrawn)),
        ),
        isFalse,
      );
      expect(
        SupplementSenderCard.shouldShow(
          _bid(_supplement(BidSupplementStatus.proposed)),
        ),
        isTrue,
      );
    });
  });

  group('encart expéditeur', () {
    testWidgets('en attente : brut seulement, motif, échéance, refuser', (
      tester,
    ) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed, forSender: true)),
        ),
      );

      expect(find.text('Le voyageur demande un supplément'), findsOneWidget);
      expect(_txt('17 € de plus'), findsOneWidget);
      expect(find.text('Article : Téléphone'), findsOneWidget);
      expect(find.text('Un iPhone dans le colis'), findsOneWidget);
      expect(find.text('Réponse attendue avant 14:30'), findsOneWidget);
      // Jamais le net du voyageur ni la commission.
      expect(find.text('Pour vous'), findsNothing);
      expect(find.text('Commission Yadony'), findsNothing);
      expect(_txt('15 €'), findsNothing);
      expect(find.byKey(const Key('supplement-decline-btn')), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementViewed,
          properties: {'role': 'sender', 'status': 'proposed'},
        ),
      ).called(1);
    });

    testWidgets('photo du voyageur affichée', (tester) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(
            _supplement(
              BidSupplementStatus.proposed,
              forSender: true,
              photoUrl: 'https://r2.test/tracking/bid-1/x.jpg?sig=1',
            ),
          ),
        ),
        settle: false,
      );
      await tester.pump();

      expect(find.byType(DonyImage), findsOneWidget);
      expect(
        find.bySemanticsLabel('Photo du colis prise par le voyageur'),
        findsOneWidget,
      );
    });

    testWidgets('refuser : confirmation, appel, snackbar et rechargement', (
      tester,
    ) async {
      when(
        () => repository.decline(any(), any()),
      ).thenAnswer((_) async => _supplement(BidSupplementStatus.declined));
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed, forSender: true)),
        ),
      );

      await tester.tap(find.byKey(const Key('supplement-decline-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Refuser le supplément ?'), findsOneWidget);
      await tester.tap(find.text('Refuser le supplément').last);
      await tester.pumpAndSettle();

      verify(() => repository.decline('bid-1', 'sup-1')).called(1);
      expect(find.text('Supplément refusé'), findsOneWidget);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('refuser puis annuler : rien n\'est envoyé', (tester) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed, forSender: true)),
        ),
      );

      await tester.tap(find.byKey(const Key('supplement-decline-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.decline(any(), any()));
    });

    testWidgets('refus en échec : erreur affichée et colis relu', (
      tester,
    ) async {
      when(
        () => repository.decline(any(), any()),
      ).thenThrow(const ConflictException('x', code: 'supplement-not-pending'));
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed, forSender: true)),
        ),
      );

      await tester.tap(find.byKey(const Key('supplement-decline-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refuser le supplément').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Cette demande de supplément n\'attend plus de réponse.'),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('états clos : payé, refusé, expiré, remboursé', (tester) async {
      final cases = {
        BidSupplementStatus.paymentPending: 'Paiement du supplément en cours',
        BidSupplementStatus.paid: 'Supplément payé : 17 €',
        BidSupplementStatus.paidOut: 'Supplément payé : 17 €',
        BidSupplementStatus.declined: 'Vous avez refusé le supplément',
        BidSupplementStatus.expired: 'La demande de supplément a expiré',
        BidSupplementStatus.refunded: 'Le supplément vous a été remboursé',
        BidSupplementStatus.refundPending:
            'Remboursement du supplément en cours',
      };
      for (final entry in cases.entries) {
        await pump(
          tester,
          SupplementSenderCard(
            key: ValueKey(entry.key),
            bid: _bid(_supplement(entry.key, forSender: true)),
          ),
        );
        expect(_txt(entry.value), findsOneWidget, reason: entry.key.name);
        expect(
          find.byKey(const Key('supplement-decline-btn')),
          entry.key == BidSupplementStatus.paymentPending
              ? findsOneWidget
              : findsNothing,
          reason: entry.key.name,
        );
      }
    });
  });

  group('encart expéditeur : où payer', () {
    testWidgets('carte : renvoi vers le bouton du bas', (tester) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed, forSender: true)),
        ),
      );
      expect(
        find.text('Payez avec le bouton en bas de l\'écran, ou refusez ici.'),
        findsOneWidget,
      );
    });

    testWidgets('mobile money : renvoi vers le bouton du bas (PR A3)', (
      tester,
    ) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(
            const BidSupplement(
              id: 'sup-1',
              status: BidSupplementStatus.proposed,
              rail: 'PAWAPAY',
              grossAmount: 17,
            ),
          ),
        ),
      );
      expect(
        find.text('Payez avec le bouton en bas de l\'écran, ou refusez ici.'),
        findsOneWidget,
      );
    });

    testWidgets('mobile money, paiement lancé : « en attente », bouton du '
        'bas toujours proposé', (tester) async {
      await pump(
        tester,
        SupplementSenderCard(
          bid: _bid(
            const BidSupplement(
              id: 'sup-1',
              status: BidSupplementStatus.paymentPending,
              rail: 'PAWAPAY',
              grossAmount: 17,
            ),
          ),
        ),
      );
      expect(
        find.text('Paiement mobile money du supplément en attente'),
        findsOneWidget,
      );
      expect(find.text('Paiement du supplément en cours'), findsNothing);
      expect(
        find.text('Payez avec le bouton en bas de l\'écran, ou refusez ici.'),
        findsOneWidget,
      );
    });
  });

  group('encart voyageur', () {
    testWidgets('en attente : net, commission, total, blocage, retrait', (
      tester,
    ) async {
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed)),
        ),
      );

      expect(find.text('En attente de l\'expéditeur'), findsOneWidget);
      expect(find.text('Réponse attendue avant 14:30'), findsOneWidget);
      expect(find.text('Pour vous'), findsOneWidget);
      expect(_txt('15 €'), findsOneWidget);
      expect(_txt('2 €'), findsOneWidget);
      expect(_txt('17 €'), findsOneWidget);
      expect(
        find.text('Le scan de remise est bloqué en attendant sa réponse.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('supplement-withdraw-btn')), findsOneWidget);
    });

    testWidgets('retirer : confirmation, appel et rechargement', (
      tester,
    ) async {
      when(
        () => repository.withdraw(any(), any()),
      ).thenAnswer((_) async => _supplement(BidSupplementStatus.withdrawn));
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed)),
        ),
      );

      await tester.tap(find.byKey(const Key('supplement-withdraw-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Retirer la demande ?'), findsOneWidget);
      await tester.tap(find.text('Retirer la demande').last);
      await tester.pumpAndSettle();

      verify(() => repository.withdraw('bid-1', 'sup-1')).called(1);
      expect(find.text('Demande retirée'), findsOneWidget);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('paiement en cours : pas de retrait', (tester) async {
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(_supplement(BidSupplementStatus.paymentPending)),
        ),
      );
      expect(find.text('L\'expéditeur est en train de payer'), findsOneWidget);
      expect(find.byKey(const Key('supplement-withdraw-btn')), findsNothing);
    });

    testWidgets('mobile money, paiement en cours : même texte, icône '
        'téléphone', (tester) async {
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(
            const BidSupplement(
              id: 'sup-1',
              status: BidSupplementStatus.paymentPending,
              rail: 'PAWAPAY',
              netAmount: 1000,
              commissionAmount: 100,
              grossAmount: 1100,
              currency: 'XOF',
            ),
          ),
        ),
      );
      expect(find.text('L\'expéditeur est en train de payer'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'smartphone'),
        findsOneWidget,
      );
    });

    testWidgets('refusé : choix restant et lien vers le refus du colis', (
      tester,
    ) async {
      getIt.registerFactory<ParcelRefusalCubit>(
        () => ParcelRefusalCubit(
          _MockBidRepository(),
          _MockMediaService(),
          analytics,
        ),
      );
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(_supplement(BidSupplementStatus.declined)),
        ),
      );

      expect(find.text('L\'expéditeur a refusé le supplément'), findsOneWidget);
      expect(
        find.text(
          'Transportez le colis au prix prévu, ou refusez-le sans pénalité.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('supplement-refuse-parcel-btn')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(DonyButton, 'Refuser le colis'),
        findsOneWidget,
      );
    });

    testWidgets('expiré après le départ : pas de lien vers le refus', (
      tester,
    ) async {
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(
            _supplement(BidSupplementStatus.expired),
            status: 'IN_TRANSIT',
          ),
        ),
      );
      expect(
        find.text('L\'expéditeur n\'a pas répondu à temps'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('supplement-refuse-parcel-btn')),
        findsNothing,
      );
    });

    testWidgets('payé, versé, remboursé', (tester) async {
      final cases = {
        BidSupplementStatus.paid: 'Supplément payé : +15 € pour vous',
        BidSupplementStatus.payoutPending: 'Supplément payé : +15 € pour vous',
        BidSupplementStatus.paidOut: 'Supplément versé : +15 €',
        BidSupplementStatus.refunded: 'Supplément remboursé à l\'expéditeur',
        BidSupplementStatus.refundPending:
            'Remboursement de l\'expéditeur en cours',
      };
      for (final entry in cases.entries) {
        await pump(
          tester,
          SupplementTravelerCard(
            key: ValueKey(entry.key),
            bid: _bid(_supplement(entry.key)),
          ),
        );
        expect(_txt(entry.value), findsOneWidget, reason: entry.key.name);
      }
    });

    testWidgets('motif poids : libellé du motif', (tester) async {
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(
            _supplement(
              BidSupplementStatus.proposed,
              reasonCode: 'EXTRA_WEIGHT',
            ),
          ),
        ),
      );
      expect(find.text('Poids supérieur à la déclaration'), findsOneWidget);
    });

    testWidgets('anglais : textes traduits', (tester) async {
      useEnglish();
      await pump(
        tester,
        SupplementTravelerCard(
          bid: _bid(_supplement(BidSupplementStatus.proposed)),
        ),
      );
      expect(find.text('Waiting for the sender'), findsOneWidget);
      expect(find.text('Extra charge'), findsOneWidget);
    });
  });
}
