import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
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
);

void main() {
  late _MockCubit cubit;
  late List<Reception> timelineOpened;

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
  });

  tearDown(() => getIt.unregister<ReceptionDetailCubit>());

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
}
