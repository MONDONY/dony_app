import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class PersonalInfoState extends Equatable {
  const PersonalInfoState();
  @override
  List<Object?> get props => const [];
}

class PersonalInfoInitial extends PersonalInfoState {
  const PersonalInfoInitial();
}

class PersonalInfoSaving extends PersonalInfoState {
  const PersonalInfoSaving();
}

class PersonalInfoSuccess extends PersonalInfoState {
  const PersonalInfoSuccess();
}

class PersonalInfoError extends PersonalInfoState {
  const PersonalInfoError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Étape « Vos informations » du parcours d'onboarding : le nom légal, et
/// rien d'autre.
///
/// Yadony ne recueille du voyageur que ce dont l'application a besoin pour le
/// nommer. Tout le reste de l'état civil — date de naissance, adresse de
/// résidence — est demandé par Stripe Connect dans son propre formulaire, qui
/// fait autorité pour ces champs et les revalide de toute façon. Les
/// collecter en amont ne faisait que doubler la saisie, et exposait au passage
/// des incohérences de format que Stripe refusait ensuite.
///
/// Le téléphone est absent pour la même raison : Stripe le redemande, c'est
/// son propre canal d'authentification.
class PersonalInfoCubit extends Cubit<PersonalInfoState> {
  PersonalInfoCubit(this._repository, this._analytics)
    : super(const PersonalInfoInitial());

  final AuthRepository _repository;
  final AnalyticsService _analytics;

  Future<void> submit({
    required String firstName,
    required String lastName,
  }) async {
    if (state is PersonalInfoSaving) return;
    emit(const PersonalInfoSaving());
    try {
      await _repository.updateProfile(firstName: firstName, lastName: lastName);
      // Aucune PII : ni prénom, ni nom.
      unawaited(
        _analytics.logEvent(AnalyticsEvents.onboardingIdentityDeclared),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.onboardingStepCompleted,
          properties: {'step': 'personal_info'},
        ),
      );
      emit(const PersonalInfoSuccess());
    } catch (_) {
      emit(
        const PersonalInfoError(
          'Impossible d\'enregistrer ces informations. Réessayez.',
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
    if (state is PersonalInfoSaving) return;
    emit(const PersonalInfoSaving());
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.onboardingStepSkipped,
        properties: {'step': 'personal_info'},
      ),
    );
    emit(const PersonalInfoSuccess());
  }
}
