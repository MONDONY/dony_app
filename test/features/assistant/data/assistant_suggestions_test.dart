import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrat `suggestions` de `POST /assistant/ask` (FLUTTER-RD) : facultatif,
/// l'app tolère l'ancien back (clé absente, `null`, `kind` inconnu).
void main() {
  Map<String, dynamic> body([Object? suggestions, bool withKey = true]) => {
    'answer': 'Réponse.',
    'answered': true,
    'actions': const [],
    'sources': const [],
    'provider': 'claude',
    'remainingToday': 12,
    if (withKey) 'suggestions': suggestions,
  };

  test('présentes : 2 questions de suite puis 1 découverte', () {
    final answer = AssistantAnswer.fromJson(
      body([
        {'text': 'Comment payer ?', 'kind': 'FOLLOW_UP'},
        {'text': 'Et le remboursement ?', 'kind': 'FOLLOW_UP'},
        {'text': 'Découvrir les alertes de trajet', 'kind': 'DISCOVERY'},
      ]),
    );
    expect(answer.suggestions, const [
      AssistantSuggestion(
        text: 'Comment payer ?',
        kind: AssistantSuggestionKind.followUp,
      ),
      AssistantSuggestion(
        text: 'Et le remboursement ?',
        kind: AssistantSuggestionKind.followUp,
      ),
      AssistantSuggestion(
        text: 'Découvrir les alertes de trajet',
        kind: AssistantSuggestionKind.discovery,
      ),
    ]);
    expect(answer.suggestions.last.isDiscovery, isTrue);
    expect(answer.suggestions.first.isDiscovery, isFalse);
  });

  test('clé absente (ancien back) : aucune suggestion', () {
    final answer = AssistantAnswer.fromJson(body(null, false));
    expect(answer.suggestions, isEmpty);
    expect(answer.answer, 'Réponse.');
  });

  test('null : aucune suggestion, la réponse reste lue', () {
    expect(AssistantAnswer.fromJson(body()).suggestions, isEmpty);
  });

  test('pas une liste : aucune suggestion', () {
    expect(AssistantAnswer.fromJson(body('FOLLOW_UP')).suggestions, isEmpty);
    expect(AssistantAnswer.fromJson(body({'text': 'x'})).suggestions, isEmpty);
  });

  test('kind inconnu, absent ou mal typé : ignoré, sans crash', () {
    final answer = AssistantAnswer.fromJson(
      body([
        {'text': 'Inconnue', 'kind': 'PROMO'},
        {'text': 'Sans type'},
        {'text': 'Minuscule', 'kind': 'follow_up'},
        {'text': 'Valide', 'kind': 'FOLLOW_UP'},
      ]),
    );
    expect(answer.suggestions.map((s) => s.text), ['Valide']);
  });

  test('éléments mal formés écartés (texte absent, vide, non textuel)', () {
    final answer = AssistantAnswer.fromJson(
      body([
        'texte seul',
        42,
        null,
        {'kind': 'FOLLOW_UP'},
        {'text': '   ', 'kind': 'FOLLOW_UP'},
        {'text': 7, 'kind': 'DISCOVERY'},
        {'text': '  Garder  ', 'kind': 'DISCOVERY'},
      ]),
    );
    expect(answer.suggestions, const [
      AssistantSuggestion(
        text: 'Garder',
        kind: AssistantSuggestionKind.discovery,
      ),
    ]);
  });

  test('plus de 3 : au plus 2 de suite et 1 découverte, suite en premier', () {
    final answer = AssistantAnswer.fromJson(
      body([
        {'text': 'D1', 'kind': 'DISCOVERY'},
        {'text': 'F1', 'kind': 'FOLLOW_UP'},
        {'text': 'F2', 'kind': 'FOLLOW_UP'},
        {'text': 'F3', 'kind': 'FOLLOW_UP'},
        {'text': 'D2', 'kind': 'DISCOVERY'},
      ]),
    );
    expect(answer.suggestions.map((s) => s.text), ['F1', 'F2', 'D1']);
  });

  test('doublons (casse comprise) écartés', () {
    final answer = AssistantAnswer.fromJson(
      body([
        {'text': 'Même question', 'kind': 'FOLLOW_UP'},
        {'text': 'même QUESTION', 'kind': 'FOLLOW_UP'},
      ]),
    );
    expect(answer.suggestions, hasLength(1));
  });
}
