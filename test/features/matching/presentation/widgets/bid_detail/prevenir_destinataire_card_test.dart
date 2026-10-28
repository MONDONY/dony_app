import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'ACCEPTED',
  String? recipientName = 'Fatou',
  String? recipientPhone = '+221 70 000 00 00',
  String? trackingToken = 'tok-abc123',
  String? confirmationCode,
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
  String? recipientAppStatus,
  bool pickupCodeRenewalNeeded = false,
}) => BidModel(
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  trackingToken: trackingToken,
  confirmationCode: confirmationCode,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  recipientAppStatus: recipientAppStatus,
);

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));

  setUpAll(() => registerFallbackValue(Uri()));

  group('whatsAppChatUri', () {
    test('numéro international : chiffres seuls et texte encodé', () {
      final uri = whatsAppChatUri('+221 70 000 00 00', 'Bonjour & suivi');
      expect(uri, isNotNull);
      expect(uri!.host, 'wa.me');
      expect(uri.path, '/221700000000');
      expect(uri.queryParameters['text'], 'Bonjour & suivi');
    });

    test('préfixe 00 retiré', () {
      expect(whatsAppChatUri('00221700000000', 'x')!.path, '/221700000000');
    });

    test('numéro sans indicatif, trop court ou absent : null', () {
      expect(whatsAppChatUri('0612345678', 'x'), isNull);
      expect(whatsAppChatUri('+2217', 'x'), isNull);
      expect(whatsAppChatUri(null, 'x'), isNull);
    });
  });

  group('recipientNotifyMessage', () {
    test('lien de suivi, trajet, invitation', () {
      final text = recipientNotifyMessage(fr, _bid(), withCode: false);
      expect(text, startsWith('Bonjour Fatou, je vous envoie un colis'));
      expect(text, contains('(Paris → Dakar)'));
      expect(text, contains('/tok-abc123'));
      expect(text, contains('https://yadony.com'));
    });

    test('avec le code de retrait', () {
      final text = recipientNotifyMessage(
        fr,
        _bid(status: 'IN_TRANSIT', confirmationCode: '482913'),
        withCode: true,
      );
      expect(text, contains('482913'));
      expect(text, contains('/tok-abc123'));
    });

    test('sans nom ni ville', () {
      final text = recipientNotifyMessage(
        fr,
        _bid(recipientName: '  ', departureCity: null),
        withCode: false,
      );
      expect(text, startsWith('Bonjour, je vous envoie un colis avec Yadony.'));
    });
  });

  group('règles d\'affichage', () {
    test('shouldShow : lien de suivi requis, colis pas encore remis', () {
      expect(PrevenirDestinataireCard.shouldShow(_bid()), isTrue);
      expect(
        PrevenirDestinataireCard.shouldShow(_bid(status: 'ARRIVED')),
        isTrue,
      );
      expect(
        PrevenirDestinataireCard.shouldShow(_bid(trackingToken: null)),
        isFalse,
      );
      expect(
        PrevenirDestinataireCard.shouldShow(_bid(status: 'COMPLETED')),
        isFalse,
      );
      expect(
        PrevenirDestinataireCard.shouldShow(_bid(status: 'PENDING')),
        isFalse,
      );
    });

    test('withCode : seulement une fois le colis confié', () {
      expect(
        PrevenirDestinataire.withCode(
          _bid(status: 'HANDED_OVER', confirmationCode: '1'),
        ),
        isTrue,
      );
      expect(
        PrevenirDestinataire.withCode(_bid(confirmationCode: '1')),
        isFalse,
      );
      expect(
        PrevenirDestinataire.withCode(_bid(status: 'IN_TRANSIT')),
        isFalse,
      );
    });
  });

  group('PrevenirDestinataireCard.shouldShow — refus (FLUTTER-E8)', () {
    test('refus sans lien de suivi mais modifiable : visible', () {
      expect(
        PrevenirDestinataireCard.shouldShow(
          _bid(trackingToken: null, recipientAppStatus: 'DECLINED'),
        ),
        isTrue,
      );
    });

    test('refus sur un colis livré : masqué', () {
      expect(
        PrevenirDestinataireCard.shouldShow(
          _bid(status: 'COMPLETED', recipientAppStatus: 'DECLINED'),
        ),
        isFalse,
      );
    });

    test('sans refus ni lien : masqué', () {
      expect(
        PrevenirDestinataireCard.shouldShow(_bid(trackingToken: null)),
        isFalse,
      );
    });
  });

  group('PrevenirDestinataireCard', () {
    late _MockLauncher launcher;
    late List<String> shared;

    setUp(() {
      launcher = _MockLauncher();
      shared = [];
    });

    Future<void> pump(WidgetTester tester, BidModel bid) => tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: SingleChildScrollView(
            child: PrevenirDestinataireCard(
              bid: bid,
              launcher: launcher,
              shareFallback: (text, _) async => shared.add(text),
            ),
          ),
        ),
      ),
    );

    testWidgets('demande acceptée : ouvre WhatsApp avec le lien', (
      tester,
    ) async {
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      await pump(tester, _bid());

      expect(find.text('Prévenir Fatou'), findsOneWidget);
      await tester.tap(find.text('Prévenir sur WhatsApp'));
      await tester.pumpAndSettle();

      final uri =
          verify(() => launcher.open(captureAny())).captured.single as Uri;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/221700000000');
      expect(uri.queryParameters['text'], contains('/tok-abc123'));
      expect(shared, isEmpty);
    });

    testWidgets('code prêt : bouton et message portent le code', (
      tester,
    ) async {
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      await pump(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '482913'),
      );

      await tester.tap(find.text('Envoyer le code sur WhatsApp'));
      await tester.pumpAndSettle();

      final uri =
          verify(() => launcher.open(captureAny())).captured.single as Uri;
      expect(uri.queryParameters['text'], contains('482913'));
    });

    // FLUTTER-G1 : code bloqué → le message ne part qu'avec le lien, on le dit.
    testWidgets(
      'code bloqué : message avec le lien et invitation à régénérer',
      (tester) async {
        when(() => launcher.open(any())).thenAnswer((_) async => true);
        await pump(tester, _bid(status: 'IN_TRANSIT'));

        expect(
          find.byKey(const Key('recipient-notify-code-blocked')),
          findsOneWidget,
        );
        expect(find.text('Prévenir sur WhatsApp'), findsOneWidget);
      },
    );

    // FLUTTER-G2 : code expiré → jamais dans le message, explication dédiée.
    testWidgets('code expiré : lien seul et « a expiré »', (tester) async {
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      await pump(
        tester,
        _bid(
          status: 'IN_TRANSIT',
          confirmationCode: '482913',
          pickupCodeRenewalNeeded: true,
        ),
      );

      expect(
        find.text(
          "Le code de retrait a expiré : générez-en un nouveau pour l'ajouter au message.",
        ),
        findsOneWidget,
      );
      expect(find.text('Prévenir sur WhatsApp'), findsOneWidget);
      await tester.tap(find.text('Prévenir sur WhatsApp'));
      await tester.pumpAndSettle();
      final uri =
          verify(() => launcher.open(captureAny())).captured.single as Uri;
      expect(uri.queryParameters['text'], isNot(contains('482913')));
    });

    testWidgets('code effacé : texte « bloqué » inchangé', (tester) async {
      await pump(tester, _bid(status: 'IN_TRANSIT'));
      expect(
        find.text(
          "Générez d'abord un nouveau code de retrait pour l'ajouter au message.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('code présent : aucune invitation à régénérer', (tester) async {
      await pump(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '482913'),
      );
      expect(
        find.byKey(const Key('recipient-notify-code-blocked')),
        findsNothing,
      );
    });

    testWidgets('WhatsApp ne s\'ouvre pas : repli sur le partage', (
      tester,
    ) async {
      when(() => launcher.open(any())).thenAnswer((_) async => false);
      await pump(tester, _bid());

      await tester.tap(find.text('Prévenir sur WhatsApp'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single, contains('/tok-abc123'));
    });

    testWidgets('numéro sans indicatif : partage direct, sans WhatsApp', (
      tester,
    ) async {
      await pump(
        tester,
        _bid(recipientPhone: '0612345678', recipientName: null),
      );

      expect(find.text('Prévenir le destinataire'), findsOneWidget);
      await tester.tap(find.text('Prévenir sur WhatsApp'));
      await tester.pumpAndSettle();

      verifyNever(() => launcher.open(any()));
      expect(shared, hasLength(1));
    });

    testWidgets('destinataire dans Yadony : pastille en tête, WhatsApp reste', (
      tester,
    ) async {
      await pump(tester, _bid(recipientAppStatus: 'CONFIRMED'));

      expect(find.byKey(const Key('recipient-app-confirmed')), findsOneWidget);
      expect(find.text('Fatou suit le colis dans Yadony'), findsOneWidget);
      expect(find.byKey(const Key('recipient-app-declined')), findsNothing);
      expect(find.text('Prévenir sur WhatsApp'), findsOneWidget);
    });

    testWidgets('destinataire sans nom : pastille générique', (tester) async {
      await pump(
        tester,
        _bid(recipientName: null, recipientAppStatus: 'CONFIRMED'),
      );

      expect(
        find.text('Le destinataire suit le colis dans Yadony'),
        findsOneWidget,
      );
    });

    testWidgets(
      'destinataire en refus : bandeau neutre, « Prévenir » neutralisé, '
      'action « Désigner un autre destinataire » (FLUTTER-E8)',
      (tester) async {
        await pump(
          tester,
          _bid(status: 'IN_TRANSIT', recipientAppStatus: 'DECLINED'),
        );

        expect(
          find.byKey(const Key('recipient-declined-sender')),
          findsOneWidget,
        );
        expect(find.text('Destinataire à remplacer'), findsOneWidget);
        expect(find.byKey(const Key('recipient-app-declined')), findsOneWidget);
        expect(find.text('Ce destinataire a refusé le colis.'), findsOneWidget);
        expect(find.byKey(const Key('recipient-app-confirmed')), findsNothing);
        // Le code ne repart pas vers le numéro qui a refusé.
        expect(find.text('Prévenir sur WhatsApp'), findsNothing);
        expect(find.text('Envoyer le code sur WhatsApp'), findsNothing);
        expect(find.text('Prévenir Fatou'), findsNothing);
        expect(
          find.byKey(const Key('recipient-declined-change')),
          findsOneWidget,
        );
        expect(find.text('Désigner un autre destinataire'), findsOneWidget);
        // Pas de demande du voyageur : pas de mention.
        expect(
          find.byKey(const Key('recipient-replacement-requested')),
          findsNothing,
        );
        verifyNever(() => launcher.open(any()));
      },
    );

    testWidgets('refus + demande du voyageur : mention dans le bandeau', (
      tester,
    ) async {
      await pump(
        tester,
        BidModel(
          id: 'bid-001',
          announcementId: 'ann-001',
          senderId: 'sender-001',
          status: 'ARRIVED',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          recipientName: 'Fatou',
          recipientPhone: '+221 70 000 00 00',
          trackingToken: 'tok-abc123',
          recipientAppStatus: 'DECLINED',
          recipientReplacementRequestedAt: DateTime.utc(2026, 10, 6, 8),
        ),
      );

      expect(
        find.byKey(const Key('recipient-replacement-requested')),
        findsOneWidget,
      );
      expect(
        find.text('Le voyageur vous demande d\'en désigner un autre.'),
        findsOneWidget,
      );
    });

    testWidgets('lien en attente ou absent : encart inchangé', (tester) async {
      for (final status in [null, 'PENDING']) {
        await pump(tester, _bid(recipientAppStatus: status));

        expect(find.byKey(const Key('recipient-app-confirmed')), findsNothing);
        expect(find.byKey(const Key('recipient-app-declined')), findsNothing);
      }
    });
  });

  group('PrevenirDestinataire — règles', () {
    test('canNotify : lien de suivi et colis pas encore remis', () {
      expect(PrevenirDestinataire.canNotify(_bid()), isTrue);
      expect(PrevenirDestinataire.canNotify(_bid(status: 'ARRIVED')), isTrue);
      expect(
        PrevenirDestinataire.canNotify(_bid(status: 'COMPLETED')),
        isFalse,
      );
      expect(PrevenirDestinataire.canNotify(_bid(status: 'PENDING')), isFalse);
    });

    test('canNotify is false without tracking token', () {
      expect(
        PrevenirDestinataire.canNotify(_bid(trackingToken: null)),
        isFalse,
      );
    });

    test('canNotify is false when recipient declined and change allowed', () {
      final declined = _bid(
        status: 'IN_TRANSIT',
        recipientAppStatus: 'DECLINED',
      );
      expect(PrevenirDestinataire.isDeclinedActionable(declined), isTrue);
      expect(PrevenirDestinataire.canNotify(declined), isFalse);
    });

    test('canNotify is false when recipient declined even if change not '
        'allowed', () {
      for (final status in [
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'ARRIVED',
      ]) {
        expect(
          PrevenirDestinataire.canNotify(
            _bid(status: status, recipientAppStatus: 'DECLINED'),
          ),
          isFalse,
          reason: status,
        );
      }
      expect(
        PrevenirDestinataire.canNotify(
          _bid(status: 'COMPLETED', recipientAppStatus: 'DECLINED'),
        ),
        isFalse,
      );
    });

    test(
      'showsDeclined true for declined IN_TRANSIT, with or without token',
      () {
        expect(
          PrevenirDestinataire.showsDeclined(
            _bid(status: 'IN_TRANSIT', recipientAppStatus: 'DECLINED'),
          ),
          isTrue,
        );
        expect(
          PrevenirDestinataire.showsDeclined(
            _bid(
              status: 'IN_TRANSIT',
              trackingToken: null,
              recipientAppStatus: 'DECLINED',
            ),
          ),
          isTrue,
        );
      },
    );

    test('showsDeclined false for a declined delivered parcel', () {
      expect(
        PrevenirDestinataire.showsDeclined(
          _bid(status: 'COMPLETED', recipientAppStatus: 'DECLINED'),
        ),
        isFalse,
      );
    });

    test('showsDeclined false when recipient not declined', () {
      expect(PrevenirDestinataire.showsDeclined(_bid()), isFalse);
      expect(
        PrevenirDestinataire.showsDeclined(
          _bid(recipientAppStatus: 'CONFIRMED'),
        ),
        isFalse,
      );
    });

    test('shouldShow garde le résultat d\'avant, quel que soit le bid', () {
      // Règle d'origine : carte visible si canNotify (ancienne définition) ou
      // refus modifiable.
      bool before(BidModel b) {
        final inWindow = const {
          'ACCEPTED',
          'HANDED_OVER',
          'IN_TRANSIT',
          'ARRIVED',
        }.contains(b.status);
        final declinedActionable =
            b.recipientAppStatus == 'DECLINED' && inWindow;
        return (b.trackingToken != null && inWindow && !declinedActionable) ||
            declinedActionable;
      }

      for (final status in [
        'PENDING',
        'ACCEPTED',
        'HANDED_OVER',
        'IN_TRANSIT',
        'ARRIVED',
        'COMPLETED',
        'CANCELLED',
      ]) {
        for (final token in [null, 'tok']) {
          for (final app in [null, 'PENDING', 'CONFIRMED', 'DECLINED']) {
            final b = _bid(
              status: status,
              trackingToken: token,
              recipientAppStatus: app,
            );
            expect(
              PrevenirDestinataireCard.shouldShow(b),
              before(b),
              reason: '$status / $token / $app',
            );
          }
        }
      }
    });

    test('isDeclinedActionable : faux sans refus ou sur un colis livré', () {
      expect(PrevenirDestinataire.isDeclinedActionable(_bid()), isFalse);
      expect(
        PrevenirDestinataire.isDeclinedActionable(
          _bid(status: 'COMPLETED', recipientAppStatus: 'DECLINED'),
        ),
        isFalse,
      );
    });

    test('withCode is false when pickup code expired', () {
      expect(
        PrevenirDestinataire.withCode(
          _bid(
            status: 'IN_TRANSIT',
            confirmationCode: '482913',
            pickupCodeRenewalNeeded: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('PrevenirDestinataire.notify', () {
    late _MockLauncher launcher;
    late _MockAnalytics analytics;
    late List<String> shared;

    setUp(() {
      launcher = _MockLauncher();
      analytics = _MockAnalytics();
      shared = [];
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<AnalyticsService>(analytics);
      addTearDown(() => getIt.unregister<AnalyticsService>());
    });

    Future<void> pumpTrigger(WidgetTester tester, BidModel bid) =>
        tester.pumpWidget(
          localizedApp(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => PrevenirDestinataire.notify(
                    context,
                    bid,
                    launcher: launcher,
                    shareFallback: (text, _) async => shared.add(text),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );

    testWidgets('notify opens WhatsApp then falls back to share', (
      tester,
    ) async {
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      await pumpTrigger(tester, _bid());
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      final uri =
          verify(() => launcher.open(captureAny())).captured.single as Uri;
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], contains('/tok-abc123'));
      expect(shared, isEmpty);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientNotified,
          properties: {
            'with_code': false,
            'channel': 'whatsapp',
            'status': 'ACCEPTED',
          },
        ),
      ).called(1);

      // WhatsApp refuse de s'ouvrir : repli sur le partage.
      when(() => launcher.open(any())).thenAnswer((_) async => false);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single, contains('/tok-abc123'));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientNotified,
          properties: {
            'with_code': false,
            'channel': 'share',
            'status': 'ACCEPTED',
          },
        ),
      ).called(1);
    });

    testWidgets('code prêt : le message porte le code, with_code vrai', (
      tester,
    ) async {
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      await pumpTrigger(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '482913'),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      final uri =
          verify(() => launcher.open(captureAny())).captured.single as Uri;
      expect(uri.queryParameters['text'], contains('482913'));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.recipientNotified,
          properties: {
            'with_code': true,
            'channel': 'whatsapp',
            'status': 'IN_TRANSIT',
          },
        ),
      ).called(1);
    });

    testWidgets('numéro sans indicatif : partage direct, sans WhatsApp', (
      tester,
    ) async {
      await pumpTrigger(tester, _bid(recipientPhone: '0612345678'));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      verifyNever(() => launcher.open(any()));
      expect(shared, hasLength(1));
    });
  });

  group('PrevenirDestinataireBody', () {
    Future<void> pumpBody(WidgetTester tester, BidModel bid) =>
        tester.pumpWidget(
          localizedApp(
            Scaffold(
              body: SingleChildScrollView(
                child: PrevenirDestinataireBody(bid: bid),
              ),
            ),
          ),
        );

    testWidgets('sans cadre ni bouton : le contenu seul', (tester) async {
      await pumpBody(tester, _bid());

      expect(find.byType(DetailCard), findsNothing);
      expect(find.byType(DonyButton), findsNothing);
      expect(find.textContaining('Fatou'), findsWidgets);
    });

    testWidgets('body shows code blocked note when needsNewPickupCode', (
      tester,
    ) async {
      await pumpBody(tester, _bid(status: 'IN_TRANSIT'));

      expect(
        find.byKey(const Key('recipient-notify-code-blocked')),
        findsOneWidget,
      );
      expect(
        find.text(
          "Générez d'abord un nouveau code de retrait pour l'ajouter au message.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('code expiré : explication dédiée', (tester) async {
      await pumpBody(
        tester,
        _bid(
          status: 'IN_TRANSIT',
          confirmationCode: '482913',
          pickupCodeRenewalNeeded: true,
        ),
      );

      expect(
        find.text(
          "Le code de retrait a expiré : générez-en un nouveau pour l'ajouter au message.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('code présent : aucune note de code', (tester) async {
      await pumpBody(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '482913'),
      );

      expect(
        find.byKey(const Key('recipient-notify-code-blocked')),
        findsNothing,
      );
    });

    testWidgets('destinataire dans Yadony : pastille en tête', (tester) async {
      await pumpBody(tester, _bid(recipientAppStatus: 'CONFIRMED'));

      expect(find.byKey(const Key('recipient-app-confirmed')), findsOneWidget);
      expect(find.text('Fatou suit le colis dans Yadony'), findsOneWidget);
    });

    testWidgets('destinataire sans nom : pastille générique', (tester) async {
      await pumpBody(
        tester,
        _bid(recipientName: null, recipientAppStatus: 'CONFIRMED'),
      );

      expect(
        find.text('Le destinataire suit le colis dans Yadony'),
        findsOneWidget,
      );
    });
  });

  group('RecipientDeclinedCard', () {
    testWidgets('rendu public : bandeau, mention du voyageur, action', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: SingleChildScrollView(
              child: RecipientDeclinedCard(
                bid: BidModel(
                  id: 'bid-001',
                  announcementId: 'ann-001',
                  senderId: 'sender-001',
                  status: 'ARRIVED',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                  recipientAppStatus: 'DECLINED',
                  recipientReplacementRequestedAt: DateTime.utc(2026, 10, 6, 8),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('recipient-declined-sender')),
        findsOneWidget,
      );
      expect(find.text('Ce destinataire a refusé le colis.'), findsOneWidget);
      expect(
        find.byKey(const Key('recipient-replacement-requested')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recipient-declined-change')),
        findsOneWidget,
      );
    });
  });
}
