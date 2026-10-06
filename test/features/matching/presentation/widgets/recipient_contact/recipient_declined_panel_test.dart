import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_replacement/recipient_replacement_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_declined_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

const _title = 'Destinataire à redésigner';
const _body = "Le destinataire a refusé le colis. L'expéditeur est prévenu.";
const _requestLabel = 'Demander un autre destinataire';
const _sentLabel = 'Demande envoyée';

/// Vue voyageur : le back masque nom et numéro quand le destinataire refuse.
BidModel _declined({
  String status = 'IN_TRANSIT',
  DateTime? requestedAt,
  String id = 'bid-1',
}) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  recipientDeclined: true,
  recipientReplacementRequestedAt: requestedAt,
  weightKg: 3,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

DioException _tooSoon(String? next) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    error: const RateLimitException(),
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 429,
      data: {
        'code': 'recipient-replacement-too-soon',
        'nextRequestAllowedAt': ?next,
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

/// Libellé attendu de la prochaine demande, même règle que l'encart.
String _nextLabel(DateTime next, DateTime now) {
  final local = next.toLocal();
  final time = DateFormat.Hm('fr').format(local);
  if (DateUtils.isSameDay(local, now.toLocal())) {
    return 'Nouvelle demande possible à $time';
  }
  final date = DateFormat.MMMd('fr').format(local);
  return 'Nouvelle demande possible le $date à $time';
}

void main() {
  late _MockBidRepository repository;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() => registerFallbackValue(_FakeBidEvent()));

  setUp(() {
    repository = _MockBidRepository();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerFactory<RecipientReplacementCubit>(
      () => RecipientReplacementCubit(repository, analytics),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool withBidBloc = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final body = Scaffold(body: SingleChildScrollView(child: child));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: withBidBloc
            ? BlocProvider<BidBloc>.value(value: bidBloc, child: body)
            : body,
      ),
    );
  }

  Future<void> askAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text(_requestLabel));
    await tester.pumpAndSettle();
    expect(find.text('Demander un autre destinataire ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recipient-replacement-confirm')));
    await tester.pumpAndSettle();
  }

  group('ColisDestinataireCard voyageur, destinataire en refus', () {
    testWidgets('ni nom, ni numéro : encart et bouton de demande', (
      tester,
    ) async {
      await pump(
        tester,
        ColisDestinataireCard(bid: _declined(), isSender: false),
      );

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_body), findsOneWidget);
      expect(find.text(_requestLabel), findsOneWidget);
      expect(find.text('Destinataire'), findsNothing);
      expect(find.text('Téléphone'), findsNothing);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('colis livré : explication sans bouton', (tester) async {
      await pump(
        tester,
        ColisDestinataireCard(
          bid: _declined(status: 'COMPLETED'),
          isSender: false,
        ),
      );

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_requestLabel), findsNothing);
      expect(find.text(_sentLabel), findsNothing);
    });

    testWidgets('vue expéditeur : lignes habituelles, pas d\'encart', (
      tester,
    ) async {
      await pump(tester, ColisDestinataireCard(bid: _declined()));

      expect(find.text(_title), findsNothing);
      expect(find.text('Destinataire'), findsOneWidget);
    });
  });

  group('demande de remplacement', () {
    testWidgets('« Annuler » dans la feuille : aucun appel', (tester) async {
      await pump(tester, RecipientDeclinedPanel(bid: _declined()));

      await tester.tap(find.text(_requestLabel));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("L'expéditeur recevra une notification"),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('recipient-replacement-cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => repository.requestRecipientReplacement(any()));
      expect(find.text(_requestLabel), findsOneWidget);
    });

    testWidgets(
      'confirmée : appel, snackbar, bouton « Demande envoyée » et heure de '
      'la prochaine demande, détail rechargé',
      (tester) async {
        final now = DateTime(2026, 10, 6, 9, 15);
        final requestedAt = now.toUtc();
        when(
          () => repository.requestRecipientReplacement('bid-1'),
        ).thenAnswer((_) async => _declined(requestedAt: requestedAt));

        await pump(
          tester,
          RecipientDeclinedPanel(bid: _declined(), clock: () => now),
        );
        await askAndConfirm(tester);

        verify(() => repository.requestRecipientReplacement('bid-1')).called(1);
        expect(find.text("Demande envoyée à l'expéditeur."), findsOneWidget);
        expect(find.text(_sentLabel), findsOneWidget);
        expect(find.text(_requestLabel), findsNothing);
        expect(find.text('Nouvelle demande possible à 21:15'), findsOneWidget);
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

        // Le bouton est inactif.
        await tester.tap(find.text(_sentLabel));
        await tester.pumpAndSettle();
        expect(find.text('Demander un autre destinataire ?'), findsNothing);
      },
    );

    testWidgets('sans BidBloc (feuille de l\'écran trajet) : pas d\'erreur', (
      tester,
    ) async {
      when(
        () => repository.requestRecipientReplacement('bid-1'),
      ).thenAnswer((_) async => _declined());

      await pump(
        tester,
        RecipientDeclinedPanel(bid: _declined()),
        withBidBloc: false,
      );
      await askAndConfirm(tester);

      // Réponse sans date : délai compté depuis maintenant.
      expect(find.text(_sentLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('demande déjà faite il y a moins de 12 h : bouton inactif', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 6, 18);
      final requestedAt = DateTime(2026, 10, 6, 10, 5);
      await pump(
        tester,
        RecipientDeclinedPanel(
          bid: _declined(requestedAt: requestedAt),
          clock: () => now,
        ),
      );

      expect(find.text(_sentLabel), findsOneWidget);
      expect(find.text(_requestLabel), findsNothing);
      expect(
        find.text(_nextLabel(requestedAt.add(const Duration(hours: 12)), now)),
        findsOneWidget,
      );
      expect(find.text('Nouvelle demande possible à 22:05'), findsOneWidget);
    });

    testWidgets('prochaine demande le lendemain : date et heure', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 6, 23);
      await pump(
        tester,
        RecipientDeclinedPanel(
          bid: _declined(requestedAt: DateTime(2026, 10, 6, 20)),
          clock: () => now,
        ),
      );

      expect(find.text(_sentLabel), findsOneWidget);
      expect(
        find.text(_nextLabel(DateTime(2026, 10, 7, 8), now)),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nouvelle demande possible le '),
        findsOneWidget,
      );
    });

    testWidgets('demande de plus de 12 h : nouvelle demande possible', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 6, 23);
      await pump(
        tester,
        RecipientDeclinedPanel(
          bid: _declined(requestedAt: DateTime(2026, 10, 6, 10)),
          clock: () => now,
        ),
      );

      expect(find.text(_requestLabel), findsOneWidget);
      expect(find.text(_sentLabel), findsNothing);
    });

    testWidgets('429 : snackbar et heure renvoyée par le serveur', (
      tester,
    ) async {
      final now = DateTime(2026, 10, 6, 9);
      final next = DateTime(2026, 10, 6, 14, 40).toUtc();
      when(
        () => repository.requestRecipientReplacement('bid-1'),
      ).thenThrow(_tooSoon(next.toIso8601String()));

      await pump(
        tester,
        RecipientDeclinedPanel(bid: _declined(), clock: () => now),
      );
      await askAndConfirm(tester);

      expect(
        find.textContaining("Vous avez déjà prévenu l'expéditeur."),
        findsOneWidget,
      );
      expect(find.text(_sentLabel), findsOneWidget);
      expect(find.text('Nouvelle demande possible à 14:40'), findsOneWidget);
    });

    testWidgets('429 sans date : « dans 12 h »', (tester) async {
      when(
        () => repository.requestRecipientReplacement('bid-1'),
      ).thenThrow(_tooSoon(null));

      await pump(tester, RecipientDeclinedPanel(bid: _declined()));
      await askAndConfirm(tester);

      expect(find.text(_sentLabel), findsOneWidget);
      expect(find.text('Nouvelle demande possible dans 12 h'), findsOneWidget);
    });

    testWidgets('409 : message clair et détail rechargé', (tester) async {
      when(
        () => repository.requestRecipientReplacement('bid-1'),
      ).thenThrow(const ConflictException('x', code: 'recipient-not-declined'));

      await pump(tester, RecipientDeclinedPanel(bid: _declined()));
      await askAndConfirm(tester);

      expect(
        find.textContaining('Le destinataire a déjà changé'),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('erreur réseau : message d\'erreur, bouton réutilisable', (
      tester,
    ) async {
      when(
        () => repository.requestRecipientReplacement('bid-1'),
      ).thenThrow(const OfflineException());

      await pump(tester, RecipientDeclinedPanel(bid: _declined()));
      await askAndConfirm(tester);

      expect(find.text(_requestLabel), findsOneWidget);
      expect(find.text(_sentLabel), findsNothing);
      verifyNever(() => bidBloc.add(any()));
    });

    testWidgets('showTitle: false : explication seule', (tester) async {
      await pump(
        tester,
        RecipientDeclinedPanel(bid: _declined(), showTitle: false),
      );

      expect(find.text(_title), findsNothing);
      expect(find.text(_body), findsOneWidget);
    });
  });

  group('contact du destinataire en refus', () {
    test('TravelerRecipientContactCard masquée', () {
      final declined = BidModel(
        id: 'bid-1',
        announcementId: 'ann-1',
        senderId: 'sender-1',
        status: 'IN_TRANSIT',
        // Défensif : même si un numéro arrivait, aucun canal.
        recipientPhone: '+221700000000',
        recipientDeclined: true,
        createdAt: DateTime(2026, 10),
        updatedAt: DateTime(2026, 10),
      );
      expect(TravelerRecipientContactCard.shouldShow(declined), isFalse);
    });

    testWidgets('RecipientContactActions : aucun bouton', (tester) async {
      await pump(
        tester,
        RecipientContactActions(
          bid: BidModel(
            id: 'bid-1',
            announcementId: 'ann-1',
            senderId: 'sender-1',
            status: 'IN_TRANSIT',
            recipientPhone: '+221700000000',
            recipientDeclined: true,
            createdAt: DateTime(2026, 10),
            updatedAt: DateTime(2026, 10),
          ),
        ),
      );

      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('SMS'), findsNothing);
      expect(find.text('Appeler'), findsNothing);
    });

    testWidgets(
      'feuille « Prévenir les destinataires » : ligne sans nom ni numéro ni '
      'canal, bouton de demande',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => NotifyRecipientsSheet.show(
                    context,
                    bids: [_declined(id: 'z', status: 'ARRIVED')],
                    source: NotifyRecipientsSource.manual,
                  ),
                  child: const Text('OUVRIR'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OUVRIR'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('notify-recipient-z')), findsOneWidget);
        // Titre une seule fois : la ligne le porte, l'encart ne le répète pas.
        expect(find.text(_title), findsOneWidget);
        expect(find.text('Arrivé'), findsOneWidget);
        expect(find.text(_body), findsOneWidget);
        expect(find.text(_requestLabel), findsOneWidget);
        expect(find.textContaining('Numéro indisponible'), findsNothing);
        expect(
          find.byKey(const Key('recipient-contact-whatsapp-z')),
          findsNothing,
        );
        expect(find.byKey(const Key('recipient-contact-call-z')), findsNothing);
      },
    );
  });
}
