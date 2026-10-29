// Bottom sheets des tuiles « À traiter » de la fiche colis (vue expéditeur) :
// contenu sans cadre, boutons dans le pied, BLoCs de l'écran reposés,
// fermeture une fois la demande traitée, mesure d'ouverture et libellés à
// taille nominale en français et en anglais, à 360 dp et grand texte.
import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

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
}) => BidModel(
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
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final opener = Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => openSenderTodoSheet(context, bid, tile),
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
