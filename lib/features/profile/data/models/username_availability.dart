import 'package:equatable/equatable.dart';

/// Motif d'un identifiant refusé, tel que le serveur le renvoie.
enum UsernameReason {
  invalidFormat,
  reserved,
  looksLikePhone,
  taken,
  recentlyReleased,
  unchanged,

  /// Motif inconnu d'un back plus récent : traité comme un simple refus.
  unknown;

  static UsernameReason? fromApi(String? raw) {
    if (raw == null) return null;
    return switch (raw) {
      'INVALID_FORMAT' => invalidFormat,
      'RESERVED' => reserved,
      'LOOKS_LIKE_PHONE' => looksLikePhone,
      'TAKEN' => taken,
      'RECENTLY_RELEASED' => recentlyReleased,
      'UNCHANGED' => unchanged,
      _ => unknown,
    };
  }
}

/// Réponse de `GET /auth/me/username/availability`.
class UsernameAvailability extends Equatable {
  const UsernameAvailability({
    required this.available,
    this.reason,
    this.suggestions = const [],
  });

  factory UsernameAvailability.fromJson(Map<String, dynamic> json) {
    final available = json['available'] == true;
    final rawSuggestions = json['suggestions'];
    return UsernameAvailability(
      available: available,
      reason: available
          ? null
          : UsernameReason.fromApi(json['reason'] as String?) ??
                UsernameReason.unknown,
      suggestions: rawSuggestions is List
          ? rawSuggestions.whereType<String>().toList()
          : const [],
    );
  }

  final bool available;
  final UsernameReason? reason;

  /// 0 à 3 identifiants libres, seulement pour `TAKEN` et `RECENTLY_RELEASED`.
  final List<String> suggestions;

  @override
  List<Object?> get props => [available, reason, suggestions];
}
