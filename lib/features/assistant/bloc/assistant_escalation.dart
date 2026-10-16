import 'package:dony/features/assistant/bloc/assistant_bloc.dart';

/// Plafonds du back pour un ticket support.
const int kEscalationSubjectMax = 200;
const int kEscalationMessageMax = 4000;

AssistantMessage _noMessage() =>
    const AssistantMessage(id: -1, author: AssistantAuthor.user, text: '');

/// Première question de l'utilisateur, coupée à 200 caractères. Vide quand la
/// conversation ne contient aucune question : l'appelant met un sujet par
/// défaut.
String buildEscalationSubject(List<AssistantMessage> messages) {
  final first = messages.firstWhere(
    (m) => m.author == AssistantAuthor.user,
    orElse: _noMessage,
  );
  final text = first.text.trim();
  return text.length > kEscalationSubjectMax
      ? text.substring(0, kEscalationSubjectMax)
      : text;
}

/// Dernière question, puis l'échange du plus récent au plus ancien, coupé à
/// 4 000 caractères (la dernière question est toujours conservée).
String buildEscalationMessage(
  List<AssistantMessage> messages, {
  required String youLabel,
  required String assistantLabel,
  required String header,
}) {
  final useful = messages
      .where((m) => !m.isError && m.text.trim().isNotEmpty)
      .toList();
  final last = useful.lastWhere(
    (m) => m.author == AssistantAuthor.user,
    orElse: _noMessage,
  );
  final head = last.text.trim();
  final buffer = StringBuffer(
    head.length > kEscalationMessageMax
        ? head.substring(0, kEscalationMessageMax)
        : head,
  );
  if (head.isEmpty) return '';
  final intro = '\n\n$header\n';
  if (buffer.length + intro.length >= kEscalationMessageMax) {
    return buffer.toString();
  }
  buffer.write(intro);
  for (final m in useful.reversed) {
    final who = m.author == AssistantAuthor.user ? youLabel : assistantLabel;
    final line = '$who : ${m.text.trim()}\n';
    if (buffer.length + line.length > kEscalationMessageMax) break;
    buffer.write(line);
  }
  return buffer.toString().trimRight();
}
