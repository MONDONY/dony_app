import 'package:dony/core/utils/contact_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/recording_url_launcher.dart';

void main() {
  group('whatsAppChatUri', () {
    test('numéro international : wa.me avec le texte encodé', () {
      final uri = whatsAppChatUri('+221 70 000 00 00', 'Bonjour & à bientôt');
      expect(uri!.host, 'wa.me');
      expect(uri.path, '/221700000000');
      expect(uri.queryParameters['text'], 'Bonjour & à bientôt');
    });

    test('numéro local ou trop court : null', () {
      expect(whatsAppChatUri('0612345678', 'x'), isNull);
      expect(whatsAppChatUri(null, 'x'), isNull);
    });
  });

  group('smsUri', () {
    const body = 'Bonjour Awa, retrait : gare & marché ?';
    final encoded = Uri.encodeComponent(body);

    test('Android : sms:<numéro>?body=<texte encodé>', () {
      final uri = smsUri(
        '+221 70-000 (00) 00',
        body,
        platform: TargetPlatform.android,
      );
      expect(uri.toString(), 'sms:+221700000000?body=$encoded');
    });

    test('iOS : sms:<numéro>&body=<texte encodé>', () {
      final uri = smsUri('+221700000000', body, platform: TargetPlatform.iOS);
      expect(uri.toString(), 'sms:+221700000000&body=$encoded');
    });

    test('numéro sans indicatif gardé tel quel, sans +', () {
      final uri = smsUri(
        '06 12 34 56 78',
        'x',
        platform: TargetPlatform.android,
      );
      expect(uri.toString(), 'sms:0612345678?body=x');
    });

    test('caractères spéciaux et retours à la ligne encodés', () {
      final uri = smsUri(
        '+33600000000',
        'a b\nc&d',
        platform: TargetPlatform.android,
      );
      expect(uri.toString(), 'sms:+33600000000?body=a%20b%0Ac%26d');
    });

    test('sans numéro exploitable : null', () {
      expect(smsUri(null, 'x'), isNull);
      expect(smsUri('12', 'x'), isNull);
      expect(smsUri('   ', 'x'), isNull);
    });
  });

  group('ContactLinkLauncher', () {
    test('ouvre en externalApplication, jamais en webview', () async {
      final fake = RecordingUrlLauncher();
      final opened = await ContactLinkLauncher(
        launcher: fake,
      ).open(Uri.parse('https://wa.me/221700000000?text=x'));
      expect(opened, isTrue);
      expect(fake.urls, ['https://wa.me/221700000000?text=x']);
      expect(fake.modes, [PreferredLaunchMode.externalApplication]);
    });

    test('lit le lanceur de la plateforme par défaut', () async {
      final fake = RecordingUrlLauncher(result: false);
      installUrlLauncher(fake, addTearDown);
      final opened = await ContactLinkLauncher().open(Uri.parse('sms:+221'));
      expect(opened, isFalse);
      expect(fake.modes, [PreferredLaunchMode.externalApplication]);
    });

    test('lanceur qui lève : false, aucune exception', () async {
      final opened = await ContactLinkLauncher(
        launcher: RecordingUrlLauncher(throws: true),
      ).open(Uri.parse('sms:+221'));
      expect(opened, isFalse);
    });
  });
}
