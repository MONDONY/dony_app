import 'package:equatable/equatable.dart';

/// Formulaire rempli par l'IA.
///
/// [path] : segment de `POST /assistant/form-draft/{path}` ; [analyticsName] :
/// propriété `kind` des événements `ai_form_draft_*`.
enum AiFormKind {
  trip(path: 'trip', analyticsName: 'trip'),
  packageRequest(path: 'package-request', analyticsName: 'package_request');

  const AiFormKind({required this.path, required this.analyticsName});

  final String path;
  final String analyticsName;
}

enum AiChatRole { user, assistant }

/// Un message du dialogue, envoyé tel quel au serveur à chaque tour : le
/// serveur ne garde aucune session.
class AiChatMessage extends Equatable {
  const AiChatMessage({required this.role, required this.text});

  const AiChatMessage.user(this.text) : role = AiChatRole.user;

  const AiChatMessage.assistant(this.text) : role = AiChatRole.assistant;

  final AiChatRole role;
  final String text;

  Map<String, String> toJson() => {'role': role.name, 'text': text};

  @override
  List<Object?> get props => [role, text];
}

/// Vrai si [value] porte une information : ni `null`, ni texte blanc, ni liste
/// vide. Un booléen `false` compte : l'utilisateur a dit « pas d'espèces ».
bool isFilledDraftValue(Object? value) => switch (value) {
  null => false,
  final String text => text.trim().isNotEmpty,
  final List<Object?> list => list.isNotEmpty,
  _ => true,
};

/// Réponse 200 de `POST /assistant/form-draft/{kind}`.
class AiFormDraftReply extends Equatable {
  const AiFormDraftReply({
    required this.draft,
    required this.understood,
    required this.missing,
    required this.question,
    required this.quickReplies,
    required this.done,
    required this.degraded,
    required this.remainingToday,
  });

  /// Lecture tolérante : un champ absent ou d'un autre type vaut son défaut.
  /// Seul `remainingToday` non numérique lève une `TypeError`, que le dépôt
  /// convertit en [AiFormDraftNetworkException].
  factory AiFormDraftReply.fromJson(Map<String, dynamic> json) {
    final rawDraft = json['draft'];
    final question = json['question'];
    return AiFormDraftReply(
      draft: Map<String, Object?>.unmodifiable({
        if (rawDraft is Map)
          for (final entry in rawDraft.entries)
            if (entry.key is String) entry.key as String: entry.value,
      }),
      understood: _strings(json['understood']),
      missing: _strings(json['missing']),
      question: question is String && question.trim().isNotEmpty
          ? question.trim()
          : null,
      quickReplies: _strings(json['quickReplies'])
          .where((r) => r.trim().isNotEmpty && r.length <= maxQuickReplyLength)
          .take(maxQuickReplies)
          .toList(growable: false),
      done: json['done'] == true,
      degraded: json['degraded'] == true,
      remainingToday: (json['remainingToday'] as num?)?.toInt() ?? 0,
    );
  }

  static const int maxQuickReplies = 3;
  static const int maxQuickReplyLength = 40;

  /// Clés du schéma du formulaire (spec §3.5, §3.6), toutes nullables.
  final Map<String, Object?> draft;
  final List<String> understood;

  /// Calculé par le serveur à partir des champs requis.
  final List<String> missing;
  final String? question;
  final List<String> quickReplies;
  final bool done;
  final bool degraded;
  final int remainingToday;

  static List<String> _strings(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is String) item,
  ];

  @override
  List<Object?> get props => [
    draft,
    understood,
    missing,
    question,
    quickReplies,
    done,
    degraded,
    remainingToday,
  ];
}

/// Échecs d'un tour, typés pour que le BLoC choisisse l'état.
sealed class AiFormDraftException implements Exception {
  const AiFormDraftException();
}

/// Assistant ou formulaires IA éteints (404), compte non éligible (403).
final class AiFormDraftDisabledException extends AiFormDraftException {
  const AiFormDraftDisabledException();
}

/// Quota quotidien atteint (429 `assistant-form-draft-quota-exceeded`).
final class AiFormDraftQuotaExceededException extends AiFormDraftException {
  const AiFormDraftQuotaExceededException({this.retryAfter});

  final Duration? retryAfter;
}

/// Trop de tours pour un dialogue (422 `form-draft-too-many-turns`).
final class AiFormDraftTooManyTurnsException extends AiFormDraftException {
  const AiFormDraftTooManyTurnsException();
}

/// Toute autre panne : réseau, serveur, réponse illisible.
final class AiFormDraftNetworkException extends AiFormDraftException {
  const AiFormDraftNetworkException();
}

/// Contrôles faits par l'app avant de remplir le formulaire (spec §4.3).
enum AiDraftWarning {
  departureCityUnknown,
  arrivalCityUnknown,
  noPriceGrid,
  cardNotConfigured,
  cardUnavailableInCurrency,
  mobileMoneyUnavailable,
  planeOnly,
  budgetOutOfRange,
}

/// Brouillon contrôlé par l'app, prêt à remplir le formulaire. C'est aussi le
/// résultat de la feuille (`null` quand elle est fermée sans remplir).
class AiResolvedDraft extends Equatable {
  const AiResolvedDraft({required this.draft, this.warnings = const []});

  final Map<String, Object?> draft;
  final List<AiDraftWarning> warnings;

  /// Clés remplies par l'IA, pour la marque « IA » et le bandeau.
  Set<String> get filledFields => {
    for (final entry in draft.entries)
      if (isFilledDraftValue(entry.value)) entry.key,
  };

  @override
  List<Object?> get props => [draft, warnings];
}

/// Contrôles propres à un formulaire : villes, grille, carte, devise…
abstract interface class AiDraftResolver {
  Future<AiResolvedDraft> resolve(Map<String, Object?> draft);
}

/// Paramètres d'un dialogue, passés au BLoC par GetIt (`param1`).
class AiFormDraftSession extends Equatable {
  const AiFormDraftSession({
    required this.kind,
    required this.resolver,
    this.defaultCurrency,
  });

  final AiFormKind kind;
  final AiDraftResolver resolver;

  /// Devise du formulaire au moment d'ouvrir la feuille (code ISO).
  final String? defaultCurrency;

  @override
  List<Object?> get props => [kind, resolver, defaultCurrency];
}

/// `yyyy-MM-dd` du jour local de [d].
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Décalage UTC au format `+HH:MM` : un identifiant `ZoneOffset` valide pour
/// `ZoneId.of` côté serveur, l'app n'embarquant aucun fuseau IANA.
String utcOffsetId(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  final hours = (minutes ~/ 60).toString().padLeft(2, '0');
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$rest';
}

/// Jour d'une date ISO stricte `yyyy-MM-dd`, sinon `null`.
DateTime? parseIsoDate(Object? raw) {
  if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    return null;
  }
  final parsed = DateTime.tryParse(raw);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}
