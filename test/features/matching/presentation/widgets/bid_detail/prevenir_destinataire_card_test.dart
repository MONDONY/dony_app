import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

BidModel _bid({
  String status = 'ACCEPTED',
  String? recipientName = 'Fatou',
  String? recipientPhone = '+221 70 000 00 00',
  String? trackingToken = 'tok-abc123',
  String? confirmationCode,
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
}) => BidModel(
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
        PrevenirDestinataireCard.withCode(
          _bid(status: 'HANDED_OVER', confirmationCode: '1'),
        ),
        isTrue,
      );
      expect(
        PrevenirDestinataireCard.withCode(_bid(confirmationCode: '1')),
        isFalse,
      );
      expect(
        PrevenirDestinataireCard.withCode(_bid(status: 'IN_TRANSIT')),
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
  });
}
