import 'package:dony/features/messaging/presentation/chat_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('chatPreviewLabel', () {
    test('marqueur photo → traduit dans les deux langues', () {
      expect(chatPreviewLabel(fr, kChatPreviewPhoto), '📷 Photo');
      expect(chatPreviewLabel(en, kChatPreviewPhoto), '📷 Photo');
    });

    test('marqueur localisation → traduit dans les deux langues', () {
      expect(
        chatPreviewLabel(fr, kChatPreviewLocation),
        '📍 Localisation partagée',
      );
      expect(chatPreviewLabel(en, kChatPreviewLocation), '📍 Shared location');
    });

    test('texte libre → rendu tel quel, quelle que soit la langue', () {
      expect(
        chatPreviewLabel(fr, 'Bonjour, colis reçu !'),
        'Bonjour, colis reçu !',
      );
      expect(
        chatPreviewLabel(en, 'Bonjour, colis reçu !'),
        'Bonjour, colis reçu !',
      );
    });
  });

  group('chatBlockedMessage', () {
    test('empty → chaîne vide (envoi ignoré en silence)', () {
      expect(chatBlockedMessage(fr, 'empty'), '');
      expect(chatBlockedMessage(en, 'empty'), '');
    });

    test('code inconnu → chaîne vide, comme empty', () {
      expect(chatBlockedMessage(fr, 'unknown-code'), '');
      expect(chatBlockedMessage(en, 'unknown-code'), '');
    });

    test('length → message avec la borne de ChatMessageRules.maxLength', () {
      expect(
        chatBlockedMessage(fr, 'length'),
        'Message trop long (500 caractères max).',
      );
      expect(
        chatBlockedMessage(en, 'length'),
        'Message too long (500 characters max).',
      );
    });

    test('duplicate → même message que l\'ancien texte fixe en fr', () {
      expect(
        chatBlockedMessage(fr, 'duplicate'),
        'Tu viens d\'envoyer ce message.',
      );
      expect(
        chatBlockedMessage(en, 'duplicate'),
        'You just sent this message.',
      );
    });

    test('rate → même message que l\'ancien texte fixe en fr', () {
      expect(
        chatBlockedMessage(fr, 'rate'),
        'Tu envoies trop de messages, patiente un instant.',
      );
      expect(
        chatBlockedMessage(en, 'rate'),
        'You\'re sending too many messages. Wait a moment.',
      );
    });

    test(
      'contact → même message que l\'ancien ChatMessageRules.contactMsg',
      () {
        expect(
          chatBlockedMessage(fr, 'contact'),
          'Pour ta sécurité, garde les échanges et le paiement sur Yadony. '
          'Le partage de coordonnées est interdit.',
        );
        expect(
          chatBlockedMessage(en, 'contact'),
          'For your safety, keep conversations and payment on Yadony. '
          'Sharing contact details isn\'t allowed.',
        );
      },
    );

    test('banking → même message que l\'ancien texte fixe en fr', () {
      expect(
        chatBlockedMessage(fr, 'banking'),
        'Le partage de coordonnées bancaires est interdit.',
      );
      expect(
        chatBlockedMessage(en, 'banking'),
        'Sharing bank details isn\'t allowed.',
      );
    });

    test('url → même message que l\'ancien texte fixe en fr', () {
      expect(
        chatBlockedMessage(fr, 'url'),
        'Les liens externes ne sont pas autorisés dans la messagerie.',
      );
      expect(
        chatBlockedMessage(en, 'url'),
        'External links aren\'t allowed in messages.',
      );
    });

    test('profanity → même message que l\'ancien texte fixe en fr', () {
      expect(
        chatBlockedMessage(fr, 'profanity'),
        'Reste courtois : ce message contient des termes interdits.',
      );
      expect(
        chatBlockedMessage(en, 'profanity'),
        'Keep it polite: this message contains banned words.',
      );
    });
  });
}
