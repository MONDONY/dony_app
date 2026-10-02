import 'package:dony/features/messaging/data/chat_message_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final v = ChatMessageValidator();
  final now = DateTime(2026, 6, 20, 12);

  String? blockReason(ChatValidation r) =>
      r is ChatValidationBlocked ? r.reason : null;

  group('base', () {
    test('texte normal → ok (trim)', () {
      final r = v.validate('  Bonjour Kadi  ', now: now);
      expect(r, isA<ChatValidationOk>());
      expect((r as ChatValidationOk).text, 'Bonjour Kadi');
    });
    test('vide → blocked empty', () {
      final r = v.validate('   ', now: now);
      expect(blockReason(r), 'empty');
    });
    test('500 caractères → ok ; 501 → length', () {
      expect(v.validate('a' * 500, now: now), isA<ChatValidationOk>());
      expect(blockReason(v.validate('a' * 501, now: now)), 'length');
    });
  });

  group('anti-contournement', () {
    for (final p in [
      '0612345678',
      '06 12 34 56 78',
      '06.12.34.56.78',
      '+33 6 12 34 56 78',
      'appelle moi au 0789456123',
    ]) {
      test('téléphone bloqué: "$p"', () {
        expect(blockReason(v.validate(p, now: now)), 'contact');
      });
    }
    test('email → contact', () {
      expect(
        blockReason(v.validate('ecris a kadi@gmail.com', now: now)),
        'contact',
      );
    });
    for (final a in [
      'ajoute moi sur whatsapp',
      'voici t.me/kadi',
      'on parle sur telegram',
      'mon snap',
    ]) {
      test('app externe bloquée: "$a"', () {
        expect(blockReason(v.validate(a, now: now)), 'contact');
      });
    }
    test('date 22/06/2026 → ok (pas un téléphone)', () {
      expect(
        v.validate('rendez-vous le 22/06/2026 à la gare', now: now),
        isA<ChatValidationOk>(),
      );
    });
    test('petits nombres → ok', () {
      expect(
        v.validate('14h le 22 juin, quai 9', now: now),
        isA<ChatValidationOk>(),
      );
    });
  });

  group('faux positifs (FLUTTER-80/81/84/85) : mots courants autorisés', () {
    for (final t in [
      'ok un instant svp',
      "j'ai eu un bug que j'ai signalé je ne sais pas si tu l'as vu",
      'je vais signaler le problème',
      'pas de signal ici, je te réponds ce soir',
      "il faut installer l'appli",
      'Instantly done',
      'une instance du bug',
      "l'hôtel est tellement loin",
      'tel quel, merci',
      'je fais un snapshot',
      'primo, le colis pèse 3 kg',
      'mon code de retrait est 821921',
      '821921',
      'D\'accord.Merci beaucoup',
      'Salut.Comment ça va ?',
      'la tribune et la ribambelle',
      'le mailing est parti',
      'rendez-vous le 22-06-2026',
      'prix 1 500 000 FCFA',
      'rdv @ 14h',
    ]) {
      test('autorisé: "$t"', () {
        expect(v.validate(t, now: now), isA<ChatValidationOk>());
      });
    }
  });

  group('vrais cas : bloqués avec le terme repéré', () {
    String? termOf(String t) {
      final r = v.validate(t, now: now);
      expect(r, isA<ChatValidationBlocked>(), reason: t);
      expect((r as ChatValidationBlocked).reason, 'contact', reason: t);
      return r.term;
    }

    for (final (input, term) in [
      ('06 12 34 56 78', '06 12 34 56 78'),
      ('+33612345678', '+33612345678'),
      ('appelle le 06-12-34-56-78', '06-12-34-56-78'),
      ("mon insta c'est @abc", 'insta'),
      ('mon Insta', 'Insta'),
      ('va voir instagram.com/kadi', 'instagram'),
      ('wa.me/33612345678', 'wa.me'),
      ('écris sur wa.me/kadi', 'wa.me'),
      ('écris à x@gmail.com', 'x@gmail.com'),
      ('ajoute moi sur WhatsApp', 'WhatsApp'),
      ('mon watsap', 'watsap'),
      ('on parle sur telegram', 'telegram'),
      ('mon snap', 'snap'),
      ('écris-moi sur signal', 'signal'),
      ('via imo', 'imo'),
      ('mon fb', 'fb'),
      ('suis-moi @kadi_221', '@kadi_221'),
      ('voici t.me/kadi', 't.me'),
    ]) {
      test('bloqué: "$input" → « $term »', () {
        expect(termOf(input), term);
      });
    }

    test('analytics : la raison reste « contact »', () {
      final r = v.validate('mon insta', now: now) as ChatValidationBlocked;
      expect(r.reason, 'contact');
    });
  });

  group('contenu interdit', () {
    test('IBAN → banking', () {
      expect(
        blockReason(
          v.validate('mon iban FR7630006000011234567890189', now: now),
        ),
        'banking',
      );
    });
    test('IBAN espacé → banking', () {
      expect(
        blockReason(
          v.validate('IBAN FR76 3000 6000 0112 3456 7890 189', now: now),
        ),
        'banking',
      );
    });
    for (final u in [
      'https://arnaque.io',
      'yadony.com',
      'www.exemple.fr',
      'va sur monsite.com',
    ]) {
      test('URL bloquée: "$u"', () {
        expect(blockReason(v.validate(u, now: now)), 'url');
      });
    }
    test('insulte → profanity', () {
      expect(
        blockReason(v.validate('espèce de connard', now: now)),
        'profanity',
      );
    });
  });

  group('anti-spam', () {
    test('doublon < 30 s → duplicate', () {
      final recent = [
        SentRecord(now.subtract(const Duration(seconds: 10)), 'salut'),
      ];
      expect(
        blockReason(v.validate('salut', recent: recent, now: now)),
        'duplicate',
      );
    });
    test('même texte > 30 s → ok', () {
      final recent = [
        SentRecord(now.subtract(const Duration(seconds: 40)), 'salut'),
      ];
      expect(
        v.validate('salut', recent: recent, now: now),
        isA<ChatValidationOk>(),
      );
    });
    test('5 envois / 15 s → rate ; 4 → ok', () {
      List<SentRecord> sends(int n) => List.generate(
        n,
        (i) => SentRecord(now.subtract(Duration(seconds: i + 1)), 'm$i'),
      );
      expect(
        blockReason(v.validate('nouveau', recent: sends(5), now: now)),
        'rate',
      );
      expect(
        v.validate('nouveau', recent: sends(4), now: now),
        isA<ChatValidationOk>(),
      );
    });
    test('envois hors fenêtre 15 s → pas de rate', () {
      final old = List.generate(
        6,
        (i) => SentRecord(now.subtract(Duration(seconds: 20 + i)), 'm$i'),
      );
      expect(v.validate('ok', recent: old, now: now), isA<ChatValidationOk>());
    });
  });
}
