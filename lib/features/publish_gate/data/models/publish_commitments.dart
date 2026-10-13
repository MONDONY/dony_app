import 'package:equatable/equatable.dart';

/// Rôle dont l'utilisateur accepte les engagements avant de publier.
enum PublishCommitmentRole {
  /// Publier un trajet.
  traveler('TRAVELER'),

  /// Publier une demande d'envoi.
  sender('SENDER');

  const PublishCommitmentRole(this.wire);

  final String wire;
}

/// Acceptation des engagements d'un rôle (`GET /auth/me/publish-commitments`).
class PublishCommitmentStatus extends Equatable {
  const PublishCommitmentStatus({required this.required, this.acceptedVersion});

  /// Vrai tant que la version en vigueur n'est pas acceptée : l'écran des
  /// engagements s'affiche avant le formulaire.
  final bool required;
  final String? acceptedVersion;

  factory PublishCommitmentStatus.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const PublishCommitmentStatus(required: true);
    }
    return PublishCommitmentStatus(
      required: json['required'] as bool? ?? true,
      acceptedVersion: json['acceptedVersion'] as String?,
    );
  }

  @override
  List<Object?> get props => [required, acceptedVersion];
}

/// Engagements de publication de l'utilisateur courant.
class PublishCommitments extends Equatable {
  const PublishCommitments({
    required this.currentVersion,
    required this.traveler,
    required this.sender,
  });

  /// Version en vigueur du texte, renvoyée telle quelle à l'acceptation.
  final String currentVersion;
  final PublishCommitmentStatus traveler;
  final PublishCommitmentStatus sender;

  PublishCommitmentStatus of(PublishCommitmentRole role) => switch (role) {
    PublishCommitmentRole.traveler => traveler,
    PublishCommitmentRole.sender => sender,
  };

  factory PublishCommitments.fromJson(Map<String, dynamic> json) =>
      PublishCommitments(
        currentVersion: json['currentVersion'] as String,
        traveler: PublishCommitmentStatus.fromJson(json['traveler']),
        sender: PublishCommitmentStatus.fromJson(json['sender']),
      );

  @override
  List<Object?> get props => [currentVersion, traveler, sender];
}
