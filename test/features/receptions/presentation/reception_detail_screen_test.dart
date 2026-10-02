import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/receptions/bloc/reception_detail_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/presentation/screens/reception_detail_screen.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<ReceptionDetailState>
    implements ReceptionDetailCubit {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

const _id = 'b1';

const _pending = Reception(
  bidId: _id,
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
  senderFirstName: 'Awa',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  recipientName: 'Moussa Diop',
);

Reception _confirmed({
  String bidStatus = 'IN_TRANSIT',
  String? code = '482913',
  String? instructions = 'Sortie B, parking P2.',
  String? travelerId,
  String? senderId,
}) => Reception(
  bidId: _id,
  linkStatus: 'CONFIRMED',
  bidStatus: bidStatus,
  senderFirstName: 'Awa',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 10, 4),
  arrivalDate: DateTime(2026, 10, 5),
  trackingNumber: 'DON-AB12CD',
  travelerFirstName: 'Ibrahima',
  arrivalInstructions: instructions,
  weightKg: 4.5,
  confirmationCode: code,
  travelerId: travelerId,
  senderId: senderId,
);

void main() {
  late _MockCubit cubit;
  late _MockConversationOpenBloc conversationOpen;
  late List<Reception> timelineOpened;

  setUpAll(() {
    registerFallbackValue(const ConversationOpenRequested('x'));
  });

  setUp(() {
    DonySnackbar.clearDedup();
    cubit = _MockCubit();
    timelineOpened = [];
    when(() => cubit.load(any())).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.confirm()).thenAnswer((_) async {});
    when(() => cubit.decline()).thenAnswer((_) async {});
    if (getIt.isRegistered<ReceptionDetailCubit>()) {
      getIt.unregister<ReceptionDetailCubit>();
    }
    getIt.registerFactory<ReceptionDetailCubit>(() => cubit);
    // Bouton « Écrire au voyageur » (lot 3C) : bloc résolu par GetIt.
    conversationOpen = _MockConversationOpenBloc();
    when(
      () => conversationOpen.state,
    ).thenReturn(const ConversationOpenInitial());
    if (getIt.isRegistered<ConversationOpenBloc>()) {
      getIt.unregister<ConversationOpenBloc>();
    }
    getIt.registerFactory<ConversationOpenBloc>(() => conversationOpen);
  });

  tearDown(() {
    getIt.unregister<ReceptionDetailCubit>();
    getIt.unregister<ConversationOpenBloc>();
  });

  void stub(
    ReceptionDetailState state, {
    List<ReceptionDetailState> later = const [],
  }) {
    whenListen(cubit, Stream.fromIterable(later), initialState: state);
  }

  /// Écran poussé par-dessus une page « onglet Suivi », comme depuis la
  /// section ou une notification.
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    bool settle = true,
  }) async {
    final router = GoRouter(
      initialLocation: '/tracking',
      routes: [
        GoRoute(
          path: '/tracking',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/receptions/$_id'),
              child: const Text('onglet Suivi'),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/public',
          builder: (_, state) => Scaffold(
            body: Text('profil ${(state.extra! as ProfilePublicArgs).userId}'),
          ),
        ),
        GoRoute(
          path: '/conversations/:id',
          builder: (_, state) =>
              Scaffold(body: Text('chat ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/receptions/:bidId',
          builder: (_, state) => ReceptionDetailScreen(
            bidId: state.pathParameters['bidId']!,
            openTimeline: (_, reception) async => timelineOpened.add(reception),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('onglet Suivi'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('chargement : squelette, colis demandé au cubit', (tester) async {
    stub(const ReceptionDetailLoading());

    await pump(tester, settle: false);

    verify(() => cubit.load(_id)).called(1);
    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
    expect(find.byKey(const Key('reception-confirm')), findsNothing);
  });

  group('à confirmer', () {
    testWidgets('expéditeur, trajet, question et deux boutons', (tester) async {
      stub(const ReceptionDetailLoaded(_pending));

      await pump(tester);

      expect(find.text('Colis à recevoir'), findsOneWidget);
      expect(find.text('Awa vous envoie un colis'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RouteLabel && w.from == 'Paris' && w.to == 'Dakar',
        ),
        findsOneWidget,
      );
      expect(find.text('Destinataire indiqué : Moussa Diop'), findsOneWidget);
      expect(find.text('Ce colis est-il pour vous ?'), findsOneWidget);
      expect(find.text('Oui, c\'est pour moi'), findsOneWidget);
      expect(find.text('Ce n\'est pas pour moi'), findsOneWidget);
      // Aucun code ni détail tant que le lien n'est pas confirmé.
      expect(find.byKey(const Key('reception-code')), findsNothing);
      expect(find.byKey(const Key('reception-view-tracking')), findsNothing);
    });

    testWidgets('lien à confirmer : carte expéditeur vers son profil', (
      tester,
    ) async {
      stub(
        const ReceptionDetailLoaded(
          Reception(
            bidId: _id,
            linkStatus: 'PENDING',
            bidStatus: 'ACCEPTED',
            senderFirstName: 'Awa',
            senderId: 'send-1',
          ),
        ),
      );
      await pump(tester);

      expect(find.text('Expéditeur'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('reception-sender-card')),
      );
      await tester.tap(find.byKey(const Key('reception-sender-card')));
      await tester.pumpAndSettle();

      expect(find.text('profil send-1'), findsOneWidget);
    });

    testWidgets('expéditeur inconnu et date de départ', (tester) async {
      stub(
        ReceptionDetailLoaded(
          Reception(
            bidId: _id,
            linkStatus: 'PENDING',
            bidStatus: 'ACCEPTED',
            departureDate: DateTime(2026, 10, 4),
          ),
        ),
      );

      await pump(tester);

      expect(find.text('Un colis vous est envoyé'), findsOneWidget);
      expect(find.text('Départ le 4 octobre 2026'), findsOneWidget);
    });

    testWidgets('« Oui, c\'est pour moi » confirme', (tester) async {
      stub(const ReceptionDetailLoaded(_pending));
      await pump(tester);

      await tester.tap(find.byKey(const Key('reception-confirm')));
      await tester.pump();

      verify(() => cubit.confirm()).called(1);
    });

    testWidgets('refus : confirmation légère avant d\'envoyer', (tester) async {
      stub(const ReceptionDetailLoaded(_pending));
      await pump(tester);

      await tester.tap(find.byKey(const Key('reception-decline')));
      await tester.pumpAndSettle();
      expect(find.text('Ce colis n\'est pas pour vous ?'), findsOneWidget);

      // Annuler : rien ne part.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.decline());

      await tester.tap(find.byKey(const Key('reception-decline')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Ce n\'est pas pour moi'),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => cubit.decline()).called(1);
    });

    testWidgets('geste en cours : boutons bloqués', (tester) async {
      stub(
        const ReceptionDetailLoaded(
          _pending,
          action: ReceptionAction.confirming,
        ),
      );
      await pump(tester, settle: false);

      await tester.tap(find.byKey(const Key('reception-decline')));
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('refusé : retour à l\'onglet Suivi avec un message', (
      tester,
    ) async {
      final controller = StreamController<ReceptionDetailState>();
      addTearDown(controller.close);
      whenListen(
        cubit,
        controller.stream,
        initialState: const ReceptionDetailLoaded(_pending),
      );
      await pump(tester);

      controller.add(
        const ReceptionDetailLoaded(_pending, action: ReceptionAction.declined),
      );
      await tester.pumpAndSettle();

      expect(find.text('onglet Suivi'), findsOneWidget);
      expect(
        find.text('C\'est noté, ce colis a été retiré de votre liste.'),
        findsOneWidget,
      );
    });

    testWidgets('confirmé : message de succès', (tester) async {
      final controller = StreamController<ReceptionDetailState>();
      addTearDown(controller.close);
      whenListen(
        cubit,
        controller.stream,
        initialState: const ReceptionDetailLoaded(_pending),
      );
      await pump(tester);

      controller.add(
        ReceptionDetailLoaded(
          _confirmed(bidStatus: 'ACCEPTED', code: null),
          action: ReceptionAction.confirmed,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('C\'est noté, vous suivez ce colis.'), findsOneWidget);
      expect(find.byKey(const Key('reception-view-tracking')), findsOneWidget);
    });

    testWidgets('échec du geste : erreur affichée, écran conservé', (
      tester,
    ) async {
      final controller = StreamController<ReceptionDetailState>();
      addTearDown(controller.close);
      whenListen(
        cubit,
        controller.stream,
        initialState: const ReceptionDetailLoaded(_pending),
      );
      await pump(tester);

      controller.add(
        const ReceptionDetailLoaded(
          _pending,
          action: ReceptionAction.failed,
          actionError: OfflineException(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('reception-confirm')), findsOneWidget);
    });
  });

  group('confirmé', () {
    testWidgets('étape, code de retrait, détails et instructions', (
      tester,
    ) async {
      stub(ReceptionDetailLoaded(_confirmed()));

      await pump(tester);

      expect(find.text('En route'), findsOneWidget);
      expect(find.byKey(const Key('reception-code')), findsOneWidget);
      expect(find.text('482913'), findsOneWidget);
      expect(
        find.text(
          'Donnez ce code au voyageur à la remise du colis, pas avant.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('copy-code-button')), findsOneWidget);
      expect(find.text('Ibrahima'), findsOneWidget);
      expect(find.text('DON-AB12CD'), findsOneWidget);
      expect(find.text('4,5 kg'), findsOneWidget);
      expect(find.text('4 octobre 2026'), findsOneWidget);
      expect(find.text('Sortie B, parking P2.'), findsOneWidget);
      // Pas de boutons de confirmation sur un colis déjà confirmé.
      expect(find.byKey(const Key('reception-confirm')), findsNothing);
    });

    testWidgets('chiffres à chasse fixe', (tester) async {
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      final code = tester.widget<Text>(find.text('482913'));
      expect(
        code.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('code pas encore généré : explication d\'attente', (
      tester,
    ) async {
      stub(
        ReceptionDetailLoaded(
          _confirmed(bidStatus: 'ACCEPTED', code: null, instructions: null),
        ),
      );

      await pump(tester);

      expect(find.text('Le voyageur va récupérer le colis'), findsOneWidget);
      expect(find.byKey(const Key('reception-code')), findsNothing);
      expect(find.byKey(const Key('reception-code-pending')), findsOneWidget);
      expect(find.text('INSTRUCTIONS DE RETRAIT'), findsNothing);
    });

    testWidgets('arrivé : ville d\'arrivée dans l\'étape', (tester) async {
      stub(ReceptionDetailLoaded(_confirmed(bidStatus: 'ARRIVED')));
      await pump(tester);
      expect(find.text('Arrivé à Dakar'), findsOneWidget);
    });

    testWidgets('remis : ni code ni attente', (tester) async {
      stub(
        ReceptionDetailLoaded(_confirmed(bidStatus: 'COMPLETED', code: null)),
      );
      await pump(tester);
      expect(find.text('Remis'), findsOneWidget);
      expect(find.byKey(const Key('reception-code')), findsNothing);
      expect(find.byKey(const Key('reception-code-pending')), findsNothing);
    });

    // Sentry FLUTTER-6E : étapes libellées, remis = tout fait.
    testWidgets('étapes libellées : confié fait, voyage en cours', (
      tester,
    ) async {
      stub(ReceptionDetailLoaded(_confirmed(bidStatus: 'HANDED_OVER')));
      await pump(tester);

      expect(find.byKey(const Key('reception-steps')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Colis confié au voyageur, fait'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Voyage en cours, en cours'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Remis au destinataire, à venir'),
        findsOneWidget,
      );
    });

    testWidgets('remis : toutes les étapes faites', (tester) async {
      stub(
        ReceptionDetailLoaded(_confirmed(bidStatus: 'COMPLETED', code: null)),
      );
      await pump(tester);

      expect(
        find.bySemanticsLabel('Remis au destinataire, fait'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r', (en cours|à venir)$')),
        findsNothing,
      );
    });

    // Sentry FLUTTER-6G/6H : profil du voyageur depuis l'écran Réceptions.
    testWidgets('carte voyageur : ouvre son profil public', (tester) async {
      stub(ReceptionDetailLoaded(_confirmed(travelerId: 'trav-1')));
      await pump(tester);

      await tester.ensureVisible(
        find.byKey(const Key('reception-traveler-card')),
      );
      await tester.tap(find.byKey(const Key('reception-traveler-card')));
      await tester.pumpAndSettle();

      expect(find.text('profil trav-1'), findsOneWidget);
    });

    // Sentry FLUTTER-7P : le titre « Awa vous envoie un colis » ne menait
    // nulle part ; la carte expéditeur ouvre son profil.
    testWidgets('carte expéditeur : ouvre son profil public', (tester) async {
      stub(ReceptionDetailLoaded(_confirmed(senderId: 'send-1')));
      await pump(tester);

      await tester.ensureVisible(
        find.byKey(const Key('reception-sender-card')),
      );
      expect(find.bySemanticsLabel('Voir le profil de Awa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reception-sender-card')));
      await tester.pumpAndSettle();

      expect(find.text('profil send-1'), findsOneWidget);
    });

    testWidgets('sans id expéditeur (back antérieur) : pas de carte', (
      tester,
    ) async {
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      expect(find.byKey(const Key('reception-sender-card')), findsNothing);
    });

    testWidgets('sans id voyageur (back antérieur) : simple ligne', (
      tester,
    ) async {
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      expect(find.byKey(const Key('reception-traveler-card')), findsNothing);
      expect(find.text('Ibrahima'), findsOneWidget);
    });

    testWidgets('« Voir le suivi » ouvre la frise du colis', (tester) async {
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      await tester.tap(find.byKey(const Key('reception-view-tracking')));
      await tester.pump();

      expect(timelineOpened.single.bidId, _id);
    });

    testWidgets('anglais : étape, code et bouton traduits', (tester) async {
      stub(ReceptionDetailLoaded(_confirmed(bidStatus: 'ARRIVED')));
      await pump(tester, locale: AppL10n.en);

      expect(find.text('Incoming parcel'), findsOneWidget);
      expect(find.text('Arrived in Dakar'), findsOneWidget);
      expect(find.text('YOUR PICKUP CODE'), findsOneWidget);
      expect(find.text('View tracking'), findsOneWidget);
    });
  });

  group('erreurs', () {
    testWidgets('hors ligne : erreur avec Réessayer', (tester) async {
      stub(const ReceptionDetailError(OfflineException()));
      await pump(tester);

      expect(find.text('Impossible de charger ce colis'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      verify(() => cubit.retry()).called(1);
    });

    testWidgets('404 : colis plus disponible, retour au suivi', (tester) async {
      stub(const ReceptionDetailError(NotFoundException()));
      await pump(tester);

      expect(find.text('Ce colis n\'est plus disponible'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      await tester.tap(find.text('Retour au suivi'));
      await tester.pumpAndSettle();
      expect(find.text('onglet Suivi'), findsOneWidget);
    });
  });

  group('écrire au voyageur (lot 3C)', () {
    final buttonKey = find.byKey(const Key('reception-message-traveler'));

    for (final status in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      testWidgets('$status : bouton présent', (tester) async {
        stub(ReceptionDetailLoaded(_confirmed(bidStatus: status)));
        await pump(tester);
        expect(buttonKey, findsOneWidget);
        expect(find.text('Écrire au voyageur'), findsOneWidget);
      });
    }

    testWidgets('colis remis ou lien à confirmer : pas de bouton', (
      tester,
    ) async {
      stub(ReceptionDetailLoaded(_confirmed(bidStatus: 'COMPLETED')));
      await pump(tester);
      expect(buttonKey, findsNothing);
      expect(find.byKey(const Key('reception-view-tracking')), findsOneWidget);
    });

    testWidgets('lien à confirmer : pas de bouton', (tester) async {
      stub(const ReceptionDetailLoaded(_pending));
      await pump(tester);
      expect(buttonKey, findsNothing);
    });

    testWidgets('tap : ouvre la conversation côté destinataire', (
      tester,
    ) async {
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      await tester.tap(buttonKey);
      await tester.pump();

      final event =
          verify(() => conversationOpen.add(captureAny())).captured.single
              as RecipientConversationOpenRequested;
      expect(event.bidId, _id);
      expect(event.role, RecipientConversationRole.recipient);
    });

    testWidgets('conversation ouverte : poussée vers le chat', (tester) async {
      whenListen(
        conversationOpen,
        Stream<ConversationOpenState>.fromIterable(const [
          ConversationOpenLoading(),
          ConversationOpenSuccess(
            ConversationModel(
              id: 'conv-r',
              bidId: _id,
              firestoreConversationId: 'rconv_b1',
              otherParticipant: ParticipantModel(id: 'u', name: 'Ibrahima'),
              kind: ConversationModel.kindRecipientTraveler,
            ),
          ),
        ]),
        initialState: const ConversationOpenInitial(),
      );
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      expect(find.text('chat conv-r'), findsOneWidget);
    });

    testWidgets('refus du serveur : snackbar générique, écran conservé', (
      tester,
    ) async {
      whenListen(
        conversationOpen,
        Stream<ConversationOpenState>.fromIterable(const [
          ConversationOpenError(ForbiddenException('interdit')),
        ]),
        initialState: const ConversationOpenInitial(),
      );
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester);

      expect(
        find.text(
          'Impossible d\'ouvrir la conversation pour le moment. '
          'Réessayez plus tard.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('interdit'), findsNothing);
      expect(buttonKey, findsOneWidget);
    });

    testWidgets('ouverture en cours : bouton inactif', (tester) async {
      when(
        () => conversationOpen.state,
      ).thenReturn(const ConversationOpenLoading());
      stub(ReceptionDetailLoaded(_confirmed()));
      await pump(tester, settle: false);

      await tester.tap(buttonKey, warnIfMissed: false);
      await tester.pump();
      verifyNever(() => conversationOpen.add(any()));
    });
  });
}
