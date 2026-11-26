import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ce que montre la feuille « Dernière étape : vérifiez votre identité ».
class PublishKycGateState extends Equatable {
  const PublishKycGateState({
    this.shown = false,
    this.kycStatus = 'NOT_STARTED',
    this.draftSaved = false,
  });

  /// La feuille a été montrée pour ce formulaire.
  final bool shown;

  /// Statut d'identité du profil au moment du clic (`NOT_STARTED`,
  /// `PENDING`, `REJECTED`…).
  final String kycStatus;

  /// La saisie a été gardée en brouillon local avant d'ouvrir la feuille.
  final bool draftSaved;

  /// Vérification envoyée, en attente de la décision.
  bool get pending => kycStatus == 'PENDING';

  @override
  List<Object?> get props => [shown, kycStatus, draftSaved];
}

/// Vérification d'identité demandée au moment de publier.
///
/// L'utilisateur non vérifié remplit son formulaire sans être arrêté. Au clic
/// sur « Publier », sa saisie est d'abord gardée en brouillon local (pour ne
/// rien perdre pendant la vérification, qui quitte le formulaire), puis la
/// feuille de vérification s'ouvre. Une fois vérifié, il retrouve sa saisie
/// et publie : c'est `publish_kyc_gate_resumed`.
class PublishKycGateCubit extends Cubit<PublishKycGateState> {
  PublishKycGateCubit({
    required this.role,
    required AnalyticsService analytics,
    bool resumedFromGate = false,
  }) : _analytics = analytics,
       _engaged = resumedFromGate,
       super(const PublishKycGateState());

  final PublishCommitmentRole role;
  final AnalyticsService _analytics;

  /// La publication de ce formulaire a été arrêtée par la vérification
  /// (feuille montrée ici, ou saisie reprise d'un brouillon gardé par elle).
  bool _engaged;

  bool _resumedLogged = false;

  String get _role => role.wire.toLowerCase();

  /// Garde la saisie ([saveDraft], `null` quand le formulaire n'a pas de
  /// brouillon local : modification d'un trajet publié) puis prépare la
  /// feuille. Un échec d'écriture n'empêche pas de vérifier son identité.
  Future<void> open({
    required String kycStatus,
    Future<bool> Function()? saveDraft,
  }) async {
    var saved = false;
    if (saveDraft != null) {
      try {
        saved = await saveDraft();
      } on Object {
        saved = false;
      }
    }
    _engaged = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.publishKycGateShown,
        properties: {'role': _role, 'kyc_status': kycStatus.toLowerCase()},
      ),
    );
    if (isClosed) return;
    emit(
      PublishKycGateState(shown: true, kycStatus: kycStatus, draftSaved: saved),
    );
  }

  /// « Vérifier mon identité » (ou « Voir ma vérification ») touché.
  void verifyTapped() => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.publishKycGateVerifyTapped,
      properties: {'role': _role},
    ),
  );

  /// Publication réussie (jamais un brouillon serveur) : mesurée une fois,
  /// seulement si la vérification l'avait arrêtée.
  void publicationSucceeded() {
    if (!_engaged || _resumedLogged) return;
    _resumedLogged = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.publishKycGateResumed,
        properties: {'role': _role},
      ),
    );
  }
}
