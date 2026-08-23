import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ResidenceAddressState extends Equatable {
  const ResidenceAddressState();
  @override
  List<Object?> get props => const [];
}

class ResidenceAddressInitial extends ResidenceAddressState {
  const ResidenceAddressInitial();
}

class ResidenceAddressSaving extends ResidenceAddressState {
  const ResidenceAddressSaving();
}

class ResidenceAddressSuccess extends ResidenceAddressState {
  const ResidenceAddressSuccess();
}

class ResidenceAddressError extends ResidenceAddressState {
  const ResidenceAddressError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Étape « adresse » du parcours d'onboarding.
///
/// L'adresse n'est jamais reprise de la pièce d'identité : celle du document
/// peut être périmée, alors que Stripe Connect demande la résidence actuelle.
/// C'est pourquoi on la collecte nous-mêmes, une seule fois.
class ResidenceAddressCubit extends Cubit<ResidenceAddressState> {
  ResidenceAddressCubit(this._repository, this._analytics)
    : super(const ResidenceAddressInitial());

  final AuthRepository _repository;
  final AnalyticsService _analytics;

  Future<void> submit({
    required String street,
    String? line2,
    required String postalCode,
    required String city,
  }) async {
    if (state is ResidenceAddressSaving) return;
    emit(const ResidenceAddressSaving());
    try {
      await _repository.updateResidenceAddress(
        street: street,
        line2: line2,
        postalCode: postalCode,
        city: city,
      );
      // Aucune PII : ni rue, ni code postal, ni ville.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.residenceAddressSaved,
          properties: {'has_line2': line2 != null && line2.isNotEmpty},
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.onboardingStepCompleted,
          properties: {'step': 'address'},
        ),
      );
      emit(const ResidenceAddressSuccess());
    } catch (_) {
      emit(
        const ResidenceAddressError(
          'Impossible d\'enregistrer cette adresse. Réessayez.',
        ),
      );
    }
  }

  /// Passer l'étape ne doit jamais échouer : l'utilisateur n'a rien à
  /// enregistrer ici, et un problème réseau ne peut pas le retenir.
  ///
  /// Ne pose PAS `onboarding_seen_at` : à cette étape il reste l'identité et
  /// les paiements, et poser la date ici empêcherait le parcours de se
  /// réimposer au prochain lancement. Le champ n'est posé qu'à l'arrivée
  /// réelle sur l'accueil, quel que soit le point de sortie du parcours.
  Future<void> skip() async {
    if (state is ResidenceAddressSaving) return;
    emit(const ResidenceAddressSaving());
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.onboardingStepSkipped,
        properties: {'step': 'address'},
      ),
    );
    emit(const ResidenceAddressSuccess());
  }
}
