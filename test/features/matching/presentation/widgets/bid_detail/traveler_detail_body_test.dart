import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockAmendmentRepo extends Mock implements BidAmendmentRepository {}

class _MockSupplementRepo extends Mock implements BidSupplementRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockCancelBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

BidModel _bid(
  String status, {
  String? trackingToken,
  String? recipientPhone,
  List<BidAmendment> amendments = const [],
  BidSupplement? supplement,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  bool voyageurConfirmed = false,
  DateTime? departureAt,
}) => BidModel(
  amendments: amendments,
  supplement: supplement,
  paymentMethod: paymentMethod,
  voyageurConfirmed: voyageurConfirmed,
  departureAt: departureAt,
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  trackingToken: trackingToken,
  totalAmountEur: 48,
  senderName: 'Mariama D.',
  recipientPhone: recipientPhone,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  final conv = _MockConvBloc();
  final cancel = _MockCancelBloc();
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  when(() => cancel.state).thenReturn(CancellationInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<ConversationOpenBloc>.value(value: conv),
            BlocProvider<CancellationBloc>.value(value: cancel),
          ],
          child: TravelerDetailBody(bid: bid),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

class _MockProcedureCubit extends MockCubit<DeliveryNoShowProcedureState>
    implements DeliveryNoShowProcedureCubit {}

void main() {
  // Carte « destinataire absent » (FLUTTER-E2) d'un colis ARRIVED : procédure
  // indisponible, l'écran garde l'ancien signalement.
  setUp(() {
    final cubit = _MockProcedureCubit();
    whenListen(
      cubit,
      const Stream<DeliveryNoShowProcedureState>.empty(),
      initialState: const DeliveryNoShowProcedureUnavailable(),
    );
    when(() => cubit.load(any())).thenAnswer((_) async {});
    if (getIt.isRegistered<DeliveryNoShowProcedureCubit>()) {
      getIt.unregister<DeliveryNoShowProcedureCubit>();
    }
    getIt.registerFactory<DeliveryNoShowProcedureCubit>(() => cubit);
  });
  tearDown(() {
    if (getIt.isRegistered<DeliveryNoShowProcedureCubit>()) {
      getIt.unregister<DeliveryNoShowProcedureCubit>();
    }
  });

  group('modification du colis', () {
    setUp(() {
      final analytics = _MockAnalytics();
      final repo = _MockAmendmentRepo();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt
        ..registerFactory<AmendmentActionCubit>(
          () => AmendmentActionCubit(repo, analytics),
        )
        ..registerFactory<AmendmentAcceptCubit>(
          () => AmendmentAcceptCubit(
            repo,
            analytics,
            AmendmentCommissionFlow(repo, analytics),
          ),
        );
    });
    tearDown(() {
      getIt
        ..unregister<AmendmentActionCubit>()
        ..unregister<AmendmentAcceptCubit>();
    });

    testWidgets('demande ouverte : carte sous le hero, avant le contact', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          amendments: const [
            BidAmendment(
              id: 'am-1',
              status: BidAmendmentStatus.proposed,
              rail: 'CASH',
              addedWeightKg: 3,
              grossAmount: 26.8,
              netAmount: 23.5,
              commissionAmount: 3.3,
            ),
          ],
        ),
      );

      expect(find.byType(AmendmentTravelerCard), findsOneWidget);
      final card = tester.getTopLeft(find.byType(AmendmentTravelerCard)).dy;
      expect(
        card,
        greaterThan(tester.getTopLeft(find.byType(TravelerHeroCard)).dy),
      );
      expect(
        card,
        lessThan(tester.getTopLeft(find.byType(ExpediteurContactCard)).dy),
      );
    });

    testWidgets('sans modification : aucune carte', (tester) async {
      await _pump(tester, _bid('ACCEPTED'));

      expect(find.byType(AmendmentTravelerCard), findsNothing);
    });
  });

  // Phrases d'aide sorties du footer : elles vivent dans des cartes
  // d'information du corps, juste sous le hero.
  group("cartes d'information (phrases sorties du footer)", () {
    setUp(() {
      final analytics = _MockAnalytics();
      final amendmentRepo = _MockAmendmentRepo();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt
        ..registerFactory<SupplementActionCubit>(
          () => SupplementActionCubit(_MockSupplementRepo(), analytics),
        )
        ..registerFactory<AmendmentActionCubit>(
          () => AmendmentActionCubit(amendmentRepo, analytics),
        )
        ..registerFactory<AmendmentAcceptCubit>(
          () => AmendmentAcceptCubit(
            amendmentRepo,
            analytics,
            AmendmentCommissionFlow(amendmentRepo, analytics),
          ),
        );
    });
    tearDown(() {
      getIt
        ..unregister<SupplementActionCubit>()
        ..unregister<AmendmentActionCubit>()
        ..unregister<AmendmentAcceptCubit>();
    });

    const awaiting = "En attente du paiement de l'expéditeur (mobile money).";
    const supplementBlocked =
        "Un supplément attend la réponse de l'expéditeur : le scan est bloqué.";
    const amendmentBlocked =
        'Une modification attend votre réponse : le scan est bloqué.';

    testWidgets(
      'AWAITING_PAYMENT mobile money : carte d\'attente sous le hero',
      (tester) async {
        await _pump(
          tester,
          _bid('AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.mobileMoney),
        );
        expect(find.text(awaiting), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(awaiting)).dy,
          greaterThan(tester.getTopLeft(find.byType(TravelerHeroCard)).dy),
        );
      },
    );

    testWidgets('AWAITING_PAYMENT hors mobile money : pas de carte', (
      tester,
    ) async {
      await _pump(tester, _bid('AWAITING_PAYMENT'));
      expect(find.text(awaiting), findsNothing);
    });

    testWidgets('autre statut : pas de carte d\'attente', (tester) async {
      await _pump(
        tester,
        _bid('ACCEPTED', paymentMethod: BidPaymentMethod.mobileMoney),
      );
      expect(find.text(awaiting), findsNothing);
    });

    testWidgets('supplément bloquant : phrase du scan bloqué', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          supplement: const BidSupplement(
            id: 'sup-1',
            status: BidSupplementStatus.proposed,
            grossAmount: 16.8,
            blocksHandover: true,
          ),
        ),
      );
      expect(find.text(supplementBlocked), findsOneWidget);
      expect(find.text(amendmentBlocked), findsNothing);
    });

    testWidgets('modification bloquante : phrase du scan bloqué', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          voyageurConfirmed: true,
          amendments: const [
            BidAmendment(
              id: 'am-1',
              status: BidAmendmentStatus.proposed,
              rail: 'CASH',
              grossAmount: 26.8,
              blocksHandover: true,
            ),
          ],
        ),
      );
      expect(find.text(amendmentBlocked), findsOneWidget);
      expect(find.text(supplementBlocked), findsNothing);
    });

    testWidgets('rien ne bloque : aucune phrase de scan bloqué', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED', voyageurConfirmed: true));
      expect(find.text(supplementBlocked), findsNothing);
      expect(find.text(amendmentBlocked), findsNothing);
    });

    testWidgets('présence non confirmée : pas de phrase de scan bloqué', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          amendments: const [
            BidAmendment(
              id: 'am-1',
              status: BidAmendmentStatus.proposed,
              rail: 'CASH',
              grossAmount: 26.8,
              blocksHandover: true,
            ),
          ],
        ),
      );
      expect(find.text(amendmentBlocked), findsNothing);
    });

    testWidgets('remise verrouillée avant le départ : carte avec la date et '
        'le code de retrait', (tester) async {
      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          departureAt: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      expect(
        find.textContaining('Disponible après le départ du trajet (le'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'demandez au destinataire son code de retrait à 6 chiffres',
        ),
        findsOneWidget,
      );
    });

    for (final status in ['IN_TRANSIT', 'ARRIVED']) {
      testWidgets('$status verrouillé : même carte', (tester) async {
        await _pump(
          tester,
          _bid(
            status,
            departureAt: DateTime.now().add(const Duration(days: 2)),
          ),
        );
        expect(
          find.textContaining('Disponible après le départ du trajet (le'),
          findsOneWidget,
        );
      });
    }

    testWidgets('départ passé : pas de carte de verrou', (tester) async {
      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          departureAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
      expect(find.textContaining('Disponible après le départ'), findsNothing);
      expect(find.textContaining('code de retrait à 6 chiffres'), findsNothing);
    });

    testWidgets('départ inconnu : pas de carte de verrou', (tester) async {
      await _pump(tester, _bid('HANDED_OVER'));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
    });

    // Le verrou tombe seul à l'heure du départ (même State, didUpdateWidget de
    // DeliveryDepartureGate) : la porte lit DateTime.now(), pas d'horloge à
    // avancer, on rejoue donc le même colis avec un départ désormais passé.
    testWidgets('le départ passe : la carte du verrou disparaît', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          departureAt: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      expect(
        find.textContaining('Disponible après le départ du trajet (le'),
        findsOneWidget,
      );
      final stateBefore = tester.state(find.byType(TravelerDetailBody));

      await _pump(
        tester,
        _bid(
          'HANDED_OVER',
          departureAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      expect(tester.state(find.byType(TravelerDetailBody)), same(stateBefore));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
      expect(find.textContaining('code de retrait à 6 chiffres'), findsNothing);
    });

    // La porte enveloppe TOUJOURS le corps (sans fenêtre elle ne verrouille
    // jamais) : le passage de ACCEPTED à HANDED_OVER garde la même porte et le
    // même State, sans remonter la racine du corps. (Les enfants i > 0 perdent
    // leur enveloppe d'animation d'entrée au rebuild suivant, comportement
    // existant : on ne compare donc pas leurs éléments.)
    testWidgets('ACCEPTED -> HANDED_OVER : même porte, même State', (
      tester,
    ) async {
      final departure = DateTime.now().subtract(const Duration(hours: 1));
      await _pump(tester, _bid('ACCEPTED', departureAt: departure));
      final gateBefore = tester.state(find.byType(DeliveryDepartureGate));
      final bodyBefore = tester.state(find.byType(TravelerDetailBody));

      await _pump(tester, _bid('HANDED_OVER', departureAt: departure));

      expect(
        tester.state(find.byType(DeliveryDepartureGate)),
        same(gateBefore),
      );
      expect(tester.state(find.byType(TravelerDetailBody)), same(bodyBefore));
      expect(find.textContaining('Disponible après le départ'), findsNothing);
    });

    testWidgets(
      'ACCEPTED sans verrou -> HANDED_OVER avant le départ : la carte '
      'apparaît dans la même porte',
      (tester) async {
        final departure = DateTime.now().add(const Duration(days: 2));
        await _pump(tester, _bid('ACCEPTED', departureAt: departure));
        final gateBefore = tester.state(find.byType(DeliveryDepartureGate));
        expect(find.textContaining('Disponible après le départ'), findsNothing);

        await _pump(tester, _bid('HANDED_OVER', departureAt: departure));

        expect(
          tester.state(find.byType(DeliveryDepartureGate)),
          same(gateBefore),
        );
        expect(
          find.textContaining('Disponible après le départ du trajet (le'),
          findsOneWidget,
        );
      },
    );

    testWidgets('statut sans remise (ACCEPTED) : pas de carte de verrou', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          'ACCEPTED',
          departureAt: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      expect(find.textContaining('Disponible après le départ'), findsNothing);
    });
  });

  testWidgets('ACCEPTED → hero + contact + gain présents', (tester) async {
    await _pump(tester, _bid('ACCEPTED'));
    expect(find.byType(TravelerHeroCard), findsOneWidget);
    expect(find.byType(ExpediteurContactCard), findsOneWidget);
    expect(find.byType(TravelerGainCard), findsOneWidget);
  });

  // Régression : ARRIVED absent de _activeStatuses faisait disparaître la carte
  // expéditeur et les actions de suivi dès le marquage d'arrivée.
  testWidgets('ARRIVED → carte contact toujours là, mais aucune action suivi', (
    tester,
  ) async {
    await _pump(tester, _bid('ARRIVED'));
    expect(find.byType(ExpediteurContactCard), findsOneWidget);
    // Le suivi appartient à l'expéditeur : le voyageur détient le colis mais
    // n'en est pas propriétaire, il n'a donc jamais accès aux actions de suivi,
    // y compris une fois arrivé à destination.
    expect(find.text('Suivi du colis'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);
  });

  testWidgets(
    'PENDING → profil de l\'expéditeur sans contact, téléphone du destinataire masqué',
    (tester) async {
      await _pump(tester, _bid('PENDING'));
      expect(find.byType(ExpediteurContactCard), findsOneWidget);
      expect(
        _contactIcon(ExpediteurContactCard, 'message-circle'),
        findsNothing,
      );
      expect(_contactIcon(ExpediteurContactCard, 'phone'), findsNothing);
      expect(find.text('Téléphone'), findsNothing);
      // Et on lui dit pourquoi (FLUTTER-4T).
      expect(
        find.text(
          "Vous pourrez contacter l'expéditeur une fois la demande acceptée.",
        ),
        findsOneWidget,
      );
      expect(find.byType(TravelerGainCard), findsOneWidget);
    },
  );

  group('contact du destinataire (lot 3B)', () {
    for (final status in ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      testWidgets('$status + téléphone → rangée WhatsApp / SMS / Appeler', (
        tester,
      ) async {
        await _pump(tester, _bid(status, recipientPhone: '+221700000000'));
        expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
        expect(find.text('Contacter le destinataire'), findsOneWidget);
        expect(
          find.byKey(const Key('recipient-contact-sms-b1')),
          findsOneWidget,
        );
      });
    }

    // FLUTTER-JT : le voyageur ne joint le destinataire qu'après le retrait.
    // Même si un ancien serveur sert encore le numéro à ACCEPTED, ni carte, ni
    // boutons, ni numéro : une ligne discrète annonce que le contact viendra.
    testWidgets('ACCEPTED + téléphone (ancien serveur) → ligne discrète seule', (
      tester,
    ) async {
      await _pump(tester, _bid('ACCEPTED', recipientPhone: '+221700000000'));
      expect(find.byType(TravelerRecipientContactCard), findsNothing);
      expect(find.text('Contacter le destinataire'), findsNothing);
      expect(find.byKey(const Key('recipient-contact-sms-b1')), findsNothing);
      expect(find.text('+221700000000'), findsNothing);
      expect(find.byType(TravelerRecipientContactPendingNote), findsOneWidget);
      expect(
        find.text(
          'Le contact du destinataire sera disponible après la récupération du colis.',
        ),
        findsOneWidget,
      );
      // Le contact de l'expéditeur, lui, reste ouvert dès l'acceptation.
      expect(
        _contactIcon(ExpediteurContactCard, 'message-circle'),
        findsOneWidget,
      );
    });

    testWidgets('HANDED_OVER → numéro affiché, plus de ligne discrète', (
      tester,
    ) async {
      await _pump(tester, _bid('HANDED_OVER', recipientPhone: '+221700000000'));
      expect(find.text('+221700000000'), findsWidgets);
      expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
      expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
    });

    testWidgets('demande pas encore acceptée → rangée masquée', (tester) async {
      await _pump(tester, _bid('PENDING', recipientPhone: '+221700000000'));
      expect(find.byType(TravelerRecipientContactCard), findsNothing);
    });

    testWidgets('sans téléphone du destinataire → rangée masquée', (
      tester,
    ) async {
      await _pump(tester, _bid('ARRIVED'));
      expect(find.byType(TravelerRecipientContactCard), findsNothing);
    });
  });

  testWidgets('trackingToken présent → pas de lien ni action suivi voyageur', (
    tester,
  ) async {
    await _pump(tester, _bid('ACCEPTED', trackingToken: 'public-token'));

    expect(find.text('Suivi du colis'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Plus de détails'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Plus de détails'));
    await tester.pumpAndSettle();

    expect(find.text('LIEN DE SUIVI'), findsNothing);
    expect(find.textContaining('public-token'), findsNothing);
  });
}

/// Bouton d'une carte de profil (appel ou message), repéré par son icône.
Finder _contactIcon(Type card, String icon) => find.descendant(
  of: find.byType(card),
  matching: find.byWidgetPredicate((w) => w is DonyIcon && w.name == icon),
);
