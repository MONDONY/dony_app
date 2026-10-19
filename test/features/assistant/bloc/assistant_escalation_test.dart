import 'package:dony/features/assistant/bloc/assistant_bloc.dart';
import 'package:dony/features/assistant/bloc/assistant_escalation.dart';
import 'package:flutter_test/flutter_test.dart';

AssistantMessage u(int id, String t) =>
    AssistantMessage(id: id, author: AssistantAuthor.user, text: t);
AssistantMessage a(int id, String t) =>
    AssistantMessage(id: id, author: AssistantAuthor.assistant, text: t);

void main() {
  test('sujet = première question, coupé à 200', () {
    expect(
      buildEscalationSubject([u(1, 'x' * 300), u(3, 'autre')]).length,
      kEscalationSubjectMax,
    );
    expect(kEscalationSubjectMax, 200);
    expect(
      buildEscalationSubject([a(0, 'bonjour'), u(1, 'Ma question')]),
      'Ma question',
    );
  });

  test('transcript en texte brut, jamais les balises du texte riche', () {
    const rich = AssistantMessage(
      id: 2,
      author: AssistantAuthor.assistant,
      text: 'Allez dans Moi.\n• Touchez Profil',
      richText: 'Allez dans **Moi**.\n- Touchez **Profil**',
    );
    final msg = buildEscalationMessage(
      [u(1, 'Où ?'), rich],
      youLabel: 'Vous',
      assistantLabel: 'Assistant',
      header: 'Échange :',
    );
    expect(msg, contains('Assistant : Allez dans Moi.'));
    expect(msg, isNot(contains('**')));
    expect(rich.displayText, startsWith('Allez dans **Moi**'));
  });

  test('sujet vide quand aucune question n’a été posée', () {
    expect(buildEscalationSubject(const []), '');
    expect(buildEscalationSubject([a(0, 'bonjour')]), '');
  });

  test(
    'message = dernière question puis échange du plus récent au plus ancien',
    () {
      final msg = buildEscalationMessage(
        [u(1, 'Q1'), a(2, 'R1'), u(3, 'Q2'), a(4, 'R2')],
        youLabel: 'Vous',
        assistantLabel: 'Assistant',
        header: 'Échange avec l’assistant :',
      );
      expect(msg, startsWith('Q2\n\nÉchange avec l’assistant :\n'));
      expect(msg.indexOf('Assistant : R2'), lessThan(msg.indexOf('Vous : Q1')));
    },
  );

  test('tronqué à 4000 en gardant la dernière question', () {
    final messages = [
      for (var i = 0; i < 40; i++)
        i.isEven ? u(i, 'q$i ${'x' * 300}') : a(i, 'r$i ${'y' * 300}'),
    ];
    final msg = buildEscalationMessage(
      messages,
      youLabel: 'Vous',
      assistantLabel: 'Assistant',
      header: 'Échange :',
    );
    expect(msg.length, lessThanOrEqualTo(kEscalationMessageMax));
    expect(kEscalationMessageMax, 4000);
    expect(msg, startsWith('q38'));
  });

  test('une dernière question de plus de 4000 caractères est coupée', () {
    final msg = buildEscalationMessage(
      [u(1, 'z' * 5000), a(2, 'R')],
      youLabel: 'Vous',
      assistantLabel: 'Assistant',
      header: 'H',
    );
    expect(msg.length, kEscalationMessageMax);
    expect(msg, isNot(contains('Assistant : R')));
  });

  test('ignore les messages d’erreur', () {
    const err = AssistantMessage(
      id: 9,
      author: AssistantAuthor.assistant,
      text: '',
      isError: true,
    );
    expect(
      buildEscalationMessage(
        [u(1, 'Q'), err],
        youLabel: 'V',
        assistantLabel: 'A',
        header: 'H',
      ),
      isNot(contains('A : ')),
    );
  });

  test('sans question, le message est vide', () {
    expect(
      buildEscalationMessage(
        const [],
        youLabel: 'V',
        assistantLabel: 'A',
        header: 'H',
      ),
      '',
    );
  });

  bool noLoneSurrogate(String s) {
    final units = s.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final high = units[i] >= 0xD800 && units[i] <= 0xDBFF;
      final low = units[i] >= 0xDC00 && units[i] <= 0xDFFF;
      if (high &&
          (i + 1 >= units.length ||
              !(units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF))) {
        return false;
      }
      if (low &&
          (i == 0 || !(units[i - 1] >= 0xD800 && units[i - 1] <= 0xDBFF))) {
        return false;
      }
    }
    return true;
  }

  test('le sujet ne coupe jamais un emoji en deux', () {
    final subject = buildEscalationSubject([u(1, '${'a' * 199}😀')]);
    expect(subject.length, 199);
    expect(noLoneSurrogate(subject), isTrue);
    // Un emoji qui tient entièrement est conservé.
    final fits = buildEscalationSubject([u(1, '${'a' * 198}😀')]);
    expect(fits.length, 200);
    expect(noLoneSurrogate(fits), isTrue);
  });

  test('le message ne coupe jamais un emoji en deux', () {
    final msg = buildEscalationMessage(
      [u(1, '${'a' * 3999}😀')],
      youLabel: 'V',
      assistantLabel: 'A',
      header: 'H',
    );
    expect(msg.length, 3999);
    expect(noLoneSurrogate(msg), isTrue);
  });
}
