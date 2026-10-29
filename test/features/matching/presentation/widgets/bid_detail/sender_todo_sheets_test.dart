// Bottom sheets des tuiles « À traiter » de la fiche colis (vue expéditeur) :
// contenu sans cadre, boutons dans le pied, BLoCs de l'écran reposés,
// fermeture une fois la demande traitée, mesure d'ouverture et libellés à
// taille nominale en français et en anglais, à 360 dp et grand texte.
import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAmendmentRepository extends Mock implements BidAmendmentRepository {}

BidAmendment _amendment({
  String id = 'am-1',
  BidAmendmentStatus status = BidAmendmentStatus.proposed,
  String rail = BidAmendment.railCash,
}) => BidAmendment(
  id: id,
  status: status,
  rail: rail,
  addedWeightKg: 3,
  grossAmount: 26.8,
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 40)),
  blocksHandover: status.isOpen,
);

TripRescheduleInfo _reschedule({bool pending = true}) => TripRescheduleInfo(
  id: 'r1',
  reason: 'FLIGHT_CANCELLED',
  previousDepartureDate: DateTime(2026, 10, 9),
  newDepartureDate: DateTime(2026, 10, 13),
  decisionPending: pending,
  decisionDeadline: DateTime.utc(2026, 10, 12, 16),
);

BidModel _bid({
  String status = 'IN_TRANSIT',
  String? recipientAppStatus = 'DECLINED',
  DateTime? replacementRequestedAt,
  TripRescheduleInfo? reschedule,
  List<BidAmendment> amendments = const [],
}) => BidModel(
  amendments: amendments,
  travelerName: 'Moussa',
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  weightKg: 3,
  recipientName: 'Awa',
  recipientPhone: '+221700000000',
  trackingToken: 'tok-abc123',
  recipientAppStatus: recipientAppStatus,
  recipientReplacementRequestedAt: replacementRequestedAt,
  reschedule: reschedule,
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
);

/// Vraies polices de l'app : la police de repli des tests donne un cadratin
/// par glyphe et fausserait la mesure des libellés.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  late MockAnalyticsBackend backend;
  late _MockBidBloc bidBloc;
  late _MockCancellationBloc cancellationBloc;
  late StreamController<BidState> bidStates;
  late StreamController<CancellationState> cancellationStates;
  late _MockAmendmentRepository amendmentRepository;

  setUpAll(() async {
    registerFallbackValue(BidDetailRequested('fallback'));
    registerFallbackValue(RescheduleDecisionRequested('x', keep: true));
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await _loadAppFonts();
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    bidStates = StreamController<BidState>.broadcast();
    addTearDown(bidStates.close);
    bidBloc = _MockBidBloc();
    whenListen(bidBloc, bidStates.stream, initialState: BidInitial());

    cancellationStates = StreamController<CancellationState>.broadcast();
    addTearDown(cancellationStates.close);
    cancellationBloc = _MockCancellationBloc();
    whenListen(
      cancellationBloc,
      cancellationStates.stream,
      initialState: CancellationInitial(),
    );

    await getIt.reset();
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerFactory<RecipientChangeCubit>(
      () => RecipientChangeCubit(_MockBidRepository(), analytics),
    );
    amendmentRepository = _MockAmendmentRepository();
    getIt.registerFactory<AmendmentActionCubit>(
      () => AmendmentActionCubit(amendmentRepository, analytics),
    );
    DonySnackbar.clearDedup();
  });

  tearDown(() async => getIt.reset());

  /// Ouvre la feuille depuis un `Builder` posé sous les fournisseurs de
  /// l'écran, comme le fait le corps de la fiche.
  Future<void> openTodo(
    WidgetTester tester,
    BidModel bid,
    SenderTodoTile tile, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size? size,
    bool withBlocs = true,
    SenderTodoSource source = SenderTodoSource.tile,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final opener = Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              openSenderTodoSheet(context, bid, tile, source: source),
          child: const Text('open-todo'),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: withBlocs
            ? MultiBlocProvider(
                providers: [
                  BlocProvider<BidBloc>.value(value: bidBloc),
                  BlocProvider<CancellationBloc>.value(value: cancellationBloc),
                ],
                child: opener,
              )
            : opener,
      ),
    );
    await tester.tap(find.text('open-todo'));
    await tester.pumpAndSettle();
  }

  Finder footer() => find.byKey(const Key('donyBottomSheetFooter'));
  Finder footerButtons() =>
      find.descendant(of: footer(), matching: find.byType(DonyButton));

  group('destinataire à remplacer', () {
    testWidgets('titre, contenu sans cadre, bouton dans le pied', (
      tester,
    ) async {
      await openTodo(tester, _bid(), SenderTodoTile.recipient);

      expect(tester.takeException(), isNull);
      expect(find.text('Destinataire à remplacer'), findsOneWidget);
      expect(find.byType(RecipientDeclinedBody), findsOneWidget);
      expect(find.byType(DetailCard), findsNothing);
      expect(find.text('Ce destinataire a refusé le colis.'), findsOneWidget);
      expect(
        find.descendant(
          of: footer(),
          matching: find.byKey(const Key('recipient-declined-change')),
        ),
        findsOneWidget,
      );
      // Aucun bouton dans le contenu défilant.
      expect(find.byType(DonyButton), findsOneWidget);
    });

    testWidgets('le bouton ferme la feuille et ouvre le changement de '
        'destinataire avec le BidBloc de l\'écran', (tester) async {
      await openTodo(tester, _bid(), SenderTodoTile.recipient);

      await tester.tap(footerButtons());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Destinataire à remplacer'), findsNothing);
      expect(find.text('Modifier le destinataire'), findsOneWidget);
    });

    testWidgets('suit le colis rechargé : mention de la demande du voyageur', (
      tester,
    ) async {
      await openTodo(tester, _bid(), SenderTodoTile.recipient);
      expect(
        find.byKey(const Key('recipient-replacement-requested')),
        findsNothing,
      );

      bidStates.add(
        BidDetailLoaded(
          _bid(replacementRequestedAt: DateTime.utc(2026, 10, 6, 8)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Destinataire à remplacer'), findsOneWidget);
      expect(
        find.byKey(const Key('recipient-replacement-requested')),
        findsOneWidget,
      );
    });

    testWidgets('se ferme quand le colis rechargé n\'a plus de refus', (
      tester,
    ) async {
      await openTodo(tester, _bid(), SenderTodoTile.recipient);

      bidStates.add(BidDetailLoaded(_bid(recipientAppStatus: null)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Destinataire à remplacer'), findsNothing);
    });

    testWidgets('le colis rechargé d\'un autre envoi ne ferme rien', (
      tester,
    ) async {
      await openTodo(tester, _bid(), SenderTodoTile.recipient);

      bidStates.add(
        BidDetailLoaded(
          BidModel(
            id: 'bid-other',
            announcementId: 'ann-001',
            senderId: 'sender-001',
            status: 'COMPLETED',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Destinataire à remplacer'), findsOneWidget);
    });

    testWidgets('sans BLoC à l\'écran : contenu de l\'ouverture', (
      tester,
    ) async {
      await openTodo(
        tester,
        _bid(),
        SenderTodoTile.recipient,
        withBlocs: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RecipientDeclinedBody), findsOneWidget);
      expect(footerButtons(), findsOneWidget);
    });
  });

  group('trajet reporté', () {
    BidModel pending() =>
        _bid(recipientAppStatus: null, reschedule: _reschedule());

    testWidgets('titre, carte sans cadre, deux boutons empilés dans le pied', (
      tester,
    ) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);

      expect(tester.takeException(), isNull);
      expect(find.text('Trajet reporté'), findsOneWidget);
      final card = tester.widget<TripRescheduleCard>(
        find.byType(TripRescheduleCard),
      );
      expect(card.framed, isFalse);
      expect(
        find.descendant(
          of: find.byType(TripRescheduleCard),
          matching: find.byType(DonyCard),
        ),
        findsNothing,
      );
      expect(find.textContaining('Répondez avant'), findsOneWidget);
      expect(footerButtons(), findsNWidgets(2));
      expect(find.byType(DonyButton), findsNWidgets(2));
      final keep = find.byKey(const Key('reschedule-keep'));
      final withdraw = find.byKey(const Key('reschedule-withdraw'));
      expect(find.descendant(of: footer(), matching: keep), findsOneWidget);
      expect(find.descendant(of: footer(), matching: withdraw), findsOneWidget);
      // Empilés : principal en haut, même largeur.
      expect(
        tester.getTopLeft(keep).dy,
        lessThan(tester.getTopLeft(withdraw).dy),
      );
      expect(tester.getSize(keep).width, tester.getSize(withdraw).width);
    });

    testWidgets('le pied lit le CancellationBloc de l\'écran', (tester) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);

      final inFooter = tester.element(find.byKey(const Key('reschedule-keep')));
      expect(inFooter.read<CancellationBloc>(), same(cancellationBloc));
      expect(inFooter.read<BidBloc>(), same(bidBloc));
    });

    testWidgets('« Garder mon colis » envoie la décision puis la feuille se '
        'ferme au succès', (tester) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);

      await tester.tap(find.byKey(const Key('reschedule-keep')));
      await tester.pump();
      final event =
          verify(() => cancellationBloc.add(captureAny())).captured.single
              as RescheduleDecisionRequested;
      expect(event.bidId, 'bid-001');
      expect(event.keep, isTrue);
      expect(find.text('Trajet reporté'), findsOneWidget);

      cancellationStates.add(RescheduleKept());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Trajet reporté'), findsNothing);
    });

    testWidgets('« Annuler sans frais » confirme, envoie, puis se ferme', (
      tester,
    ) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);

      await tester.tap(find.byKey(const Key('reschedule-withdraw')));
      await tester.pumpAndSettle();
      expect(find.text('Annuler votre envoi ?'), findsOneWidget);
      verifyNever(() => cancellationBloc.add(any()));

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Annuler sans frais'),
        ),
      );
      await tester.pumpAndSettle();
      final event =
          verify(() => cancellationBloc.add(captureAny())).captured.single
              as RescheduleDecisionRequested;
      expect(event.keep, isFalse);
      // La feuille est restée sous la confirmation.
      expect(find.text('Trajet reporté'), findsOneWidget);

      cancellationStates.add(RescheduleWithdrawn());
      await tester.pumpAndSettle();

      expect(find.text('Trajet reporté'), findsNothing);
    });

    testWidgets('pendant l\'envoi : principal en chargement, second inactif', (
      tester,
    ) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);

      cancellationStates.add(CancellationLoading());
      await tester.pump();
      await tester.pump();

      final keep = tester.widget<DonyButton>(
        find.byKey(const Key('reschedule-keep')),
      );
      final withdraw = tester.widget<DonyButton>(
        find.byKey(const Key('reschedule-withdraw')),
      );
      expect(keep.isLoading, isTrue);
      expect(keep.onPressed, isNull);
      expect(withdraw.onPressed, isNull);
    });

    testWidgets('se ferme quand le colis rechargé n\'attend plus de réponse', (
      tester,
    ) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);

      bidStates.add(
        BidDetailLoaded(
          _bid(
            recipientAppStatus: null,
            reschedule: _reschedule(pending: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trajet reporté'), findsNothing);
    });

    testWidgets('la confirmation ouverte n\'est pas refermée par un '
        'rechargement', (tester) async {
      await openTodo(tester, pending(), SenderTodoTile.reschedule);
      await tester.tap(find.byKey(const Key('reschedule-withdraw')));
      await tester.pumpAndSettle();

      bidStates.add(
        BidDetailLoaded(
          _bid(
            recipientAppStatus: null,
            reschedule: _reschedule(pending: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Annuler votre envoi ?'), findsOneWidget);
    });
  });

  group('modification du colis', () {
    BidModel withAmendment(BidAmendment a) =>
        _bid(status: 'ACCEPTED', recipientAppStatus: null, amendments: [a]);

    Finder cancelButton() => find.byKey(const Key('amendment-cancel-btn'));
    Finder payButton() => find.descendant(
      of: footer(),
      matching: find.byKey(const Key('amendment-pay-btn')),
    );

    for (final status in [
      BidAmendmentStatus.proposed,
      BidAmendmentStatus.authorizationPending,
    ]) {
      testWidgets('${status.name} : titre, contenu sans cadre, « Annuler ma '
          'demande » seul dans le pied', (tester) async {
        await openTodo(
          tester,
          // L'autorisation en attente n'existe que pour la carte.
          withAmendment(
            _amendment(
              status: status,
              rail: status == BidAmendmentStatus.authorizationPending
                  ? BidAmendment.railStripe
                  : BidAmendment.railCash,
            ),
          ),
          SenderTodoTile.amendment,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Modification du colis'), findsOneWidget);
        expect(find.text('MODIFICATION DU COLIS'), findsNothing);
        expect(find.byType(DetailCard), findsNothing);
        final card = tester.widget<AmendmentSenderCard>(
          find.byType(AmendmentSenderCard),
        );
        expect(card.framed, isFalse);
        expect(find.text('En attente de Moussa'), findsOneWidget);
        expect(
          find.descendant(of: footer(), matching: cancelButton()),
          findsOneWidget,
        );
        expect(find.byType(DonyButton), findsOneWidget);
      });
    }

    testWidgets('commission du voyageur en attente : aucun bouton', (
      tester,
    ) async {
      await openTodo(
        tester,
        withAmendment(_amendment(status: BidAmendmentStatus.commissionPending)),
        SenderTodoTile.amendment,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Modification du colis'), findsOneWidget);
      expect(find.byType(DonyButton), findsNothing);
    });

    testWidgets('acceptée, mobile money : « Payer » seul dans le pied', (
      tester,
    ) async {
      await openTodo(
        tester,
        withAmendment(
          _amendment(
            status: BidAmendmentStatus.paymentPending,
            rail: BidAmendment.railPawapay,
          ),
        ),
        SenderTodoTile.amendment,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Modification acceptée par Moussa'), findsOneWidget);
      expect(payButton(), findsOneWidget);
      expect(find.byType(DonyButton), findsOneWidget);
      expect(cancelButton(), findsNothing);
    });

    testWidgets('le pied lit le cubit d\'action du wrapper et le BidBloc', (
      tester,
    ) async {
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
      );

      final inFooter = tester.element(cancelButton());
      expect(inFooter.read<AmendmentActionCubit>(), isNotNull);
      expect(inFooter.read<BidBloc>(), same(bidBloc));
    });

    testWidgets('« Annuler ma demande » confirme, annule, puis la feuille se '
        'ferme, confirme et relit le colis', (tester) async {
      when(() => amendmentRepository.cancel('bid-001', 'am-1')).thenAnswer(
        (_) async => _amendment(status: BidAmendmentStatus.cancelled),
      );
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
      );

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      expect(find.text('Annuler votre demande ?'), findsOneWidget);
      verifyNever(() => amendmentRepository.cancel(any(), any()));

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Annuler ma demande'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(() => amendmentRepository.cancel('bid-001', 'am-1')).called(1);
      expect(find.text('Modification du colis'), findsNothing);
      expect(find.text('Demande annulée'), findsOneWidget);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidAmendmentCancelled, any()),
      ).called(1);
    });

    testWidgets('pendant l\'annulation : bouton en chargement', (tester) async {
      final pending = Completer<BidAmendment>();
      when(
        () => amendmentRepository.cancel(any(), any()),
      ).thenAnswer((_) => pending.future);
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
      );

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Annuler ma demande'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final button = tester.widget<DonyButton>(cancelButton());
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
      expect(find.text('Modification du colis'), findsOneWidget);

      pending.complete(_amendment(status: BidAmendmentStatus.cancelled));
      await tester.pumpAndSettle();
      expect(find.text('Modification du colis'), findsNothing);
    });

    testWidgets('annulation refusée : la feuille reste, l\'erreur s\'affiche '
        'et le colis est relu', (tester) async {
      when(() => amendmentRepository.cancel(any(), any())).thenThrow(
        const ConflictException(
          'déjà traitée',
          code: 'amendment-not-cancellable',
        ),
      );
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
      );

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(FilledButton, 'Annuler ma demande'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Modification du colis'), findsOneWidget);
      expect(find.text('Demande annulée'), findsNothing);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidAmendmentActionFailed, {
          'action': 'cancel',
          'error_code': 'amendment-not-cancellable',
        }),
      ).called(1);
    });

    testWidgets('suit le colis rechargé : proposée puis acceptée en mobile '
        'money, le pied passe d\'« Annuler » à « Payer »', (tester) async {
      await openTodo(
        tester,
        withAmendment(_amendment(rail: BidAmendment.railPawapay)),
        SenderTodoTile.amendment,
      );
      expect(cancelButton(), findsOneWidget);

      bidStates.add(
        BidDetailLoaded(
          withAmendment(
            _amendment(
              status: BidAmendmentStatus.paymentPending,
              rail: BidAmendment.railPawapay,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modification du colis'), findsOneWidget);
      expect(cancelButton(), findsNothing);
      expect(payButton(), findsOneWidget);
    });

    testWidgets('se ferme quand le colis rechargé n\'a plus de demande '
        'ouverte', (tester) async {
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
      );

      bidStates.add(
        BidDetailLoaded(
          withAmendment(_amendment(status: BidAmendmentStatus.declined)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Modification du colis'), findsNothing);
    });

    testWidgets('l\'ouverture de la feuille ne réémet pas bid_amendment_viewed '
        '(mesuré à l\'affichage de la tuile)', (tester) async {
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
      );
      Navigator.of(tester.element(cancelButton())).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-todo'));
      await tester.pumpAndSettle();

      verifyNever(
        () => backend.capture(AnalyticsEvents.bidAmendmentViewed, any()),
      );
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'amendment',
          'role': 'sender',
          'source': 'tile',
        }),
      ).called(2);
    });

    testWidgets('ouverte par un lien : source link', (tester) async {
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
        source: SenderTodoSource.link,
      );

      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'amendment',
          'role': 'sender',
          'source': 'link',
        }),
      ).called(1);
    });

    testWidgets('sans BLoC à l\'écran : contenu et bouton de l\'ouverture', (
      tester,
    ) async {
      await openTodo(
        tester,
        withAmendment(_amendment()),
        SenderTodoTile.amendment,
        withBlocs: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AmendmentSenderCard), findsOneWidget);
      expect(cancelButton(), findsOneWidget);
    });

    // « Payer » pousse un écran : la feuille se ferme d'abord, l'écran
    // d'attente s'ouvre avec le contexte de l'écran, puis le colis est relu
    // au retour.
    testWidgets('« Payer » ferme la feuille, ouvre l\'écran d\'attente puis '
        'relit le colis au retour', (tester) async {
      final bid = withAmendment(
        _amendment(
          status: BidAmendmentStatus.paymentPending,
          rail: BidAmendment.railPawapay,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<BidBloc>.value(
              value: bidBloc,
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => openSenderTodoSheet(
                      context,
                      bid,
                      SenderTodoTile.amendment,
                    ),
                    child: const Text('open-todo'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/bids/:bidId/amendments/:id/mobile-money/awaiting',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(true),
                child: const Text('awaiting-screen'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.tap(find.text('open-todo'));
      await tester.pumpAndSettle();

      await tester.tap(payButton());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Modification du colis'), findsNothing);
      expect(find.text('awaiting-screen'), findsOneWidget);
      verify(
        () => backend.capture(AnalyticsEvents.bidAmendmentPaymentStarted, {
          'method': 'mobile_money',
        }),
      ).called(1);
      verifyNever(() => bidBloc.add(any()));

      await tester.tap(find.text('awaiting-screen'));
      await tester.pumpAndSettle();

      expect(find.text('open-todo'), findsOneWidget);
      final event =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidDetailRequested;
      expect(event.bidId, 'bid-001');
    });
  });

  group('mesure', () {
    for (final (tile, bid) in [
      (SenderTodoTile.recipient, _bid()),
      (
        SenderTodoTile.reschedule,
        _bid(recipientAppStatus: null, reschedule: _reschedule()),
      ),
    ]) {
      testWidgets('bid_detail_tile_opened avec la tuile, le rôle et la source '
          '(${tile.name})', (tester) async {
        await openTodo(tester, bid, tile);

        verify(
          () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': tile.name,
            'role': 'sender',
            'source': 'tile',
          }),
        ).called(1);
      });
    }
  });

  group('boutons à taille nominale', () {
    double labelScale(WidgetTester tester, Finder button, String label) {
      final fitted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: button, matching: find.text(label));
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      for (final (name, bid, tile, labels) in [
        (
          'recipient',
          _bid(),
          SenderTodoTile.recipient,
          {
            const Key('recipient-declined-change'):
                l.recipientDeclinedSenderButton,
          },
        ),
        (
          'reschedule',
          _bid(recipientAppStatus: null, reschedule: _reschedule()),
          SenderTodoTile.reschedule,
          {
            const Key('reschedule-keep'): l.bidRescheduleKeep,
            const Key('reschedule-withdraw'): l.bidRescheduleWithdraw,
          },
        ),
        (
          'amendment-cancel',
          _bid(
            status: 'ACCEPTED',
            recipientAppStatus: null,
            amendments: [_amendment()],
          ),
          SenderTodoTile.amendment,
          {const Key('amendment-cancel-btn'): l.amendmentCancelButton},
        ),
        (
          'amendment-pay',
          _bid(
            status: 'ACCEPTED',
            recipientAppStatus: null,
            amendments: [
              _amendment(
                status: BidAmendmentStatus.paymentPending,
                rail: BidAmendment.railPawapay,
              ),
            ],
          ),
          SenderTodoTile.amendment,
          {
            const Key('amendment-pay-btn'): l.amendmentPay(
              formatSupplementAmount(26.8, 'EUR'),
            ),
          },
        ),
      ]) {
        testWidgets('${locale.languageCode} à 360 dp, TextScaler 1.3 ($name)', (
          tester,
        ) async {
          await openTodo(
            tester,
            bid,
            tile,
            locale: locale,
            textScale: 1.3,
            size: const Size(360, 800),
          );

          expect(tester.takeException(), isNull);
          for (final MapEntry(key: key, value: label) in labels.entries) {
            final button = find.byKey(key);
            expect(tester.getSize(button).height, 52, reason: label);
            expect(labelScale(tester, button, label), closeTo(1, 0.001));
          }
        });
      }
    }
  });
}
