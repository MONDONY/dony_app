import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bornes alignées sur le back (`TravelerStatusRequest`) : le serveur reste
/// juge, ces contrôles évitent seulement un aller-retour pour une faute de
/// frappe évidente.
const int kBusinessNameMinLength = 2;
const int kRegistrationNumberMinLength = 4;
const int kRegistrationNumberMaxLength = 40;
final RegExp kRegistrationNumberPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9 ./-]*$',
);
final RegExp kCountryPattern = RegExp(r'^[A-Z]{2}$');

/// État de la feuille « Comment voyagez-vous ? » : étape 1 (le choix) puis
/// étape 2 (la confirmation d'un particulier ou les trois champs d'un
/// professionnel).
sealed class TravelerStatusState extends Equatable {
  const TravelerStatusState();

  /// Le formulaire tel qu'il est, quel que soit l'état.
  TravelerStatusEditing get form;

  @override
  List<Object?> get props => [form];
}

/// Rien n'est choisi : aucune présélection, « Continuer » est grisé.
class TravelerStatusInitial extends TravelerStatusState {
  const TravelerStatusInitial();

  @override
  TravelerStatusEditing get form => const TravelerStatusEditing();
}

/// Le voyageur remplit la feuille.
class TravelerStatusEditing extends TravelerStatusState {
  const TravelerStatusEditing({
    this.choice,
    this.detailsStep = false,
    this.confirmed = false,
    this.businessName = '',
    this.registrationNumber = '',
    this.country,
  });

  final TravelerStatus? choice;

  /// Vrai à l'étape 2 (confirmation ou champs du professionnel).
  final bool detailsStep;

  /// Case « Je confirme voyager à titre personnel » (particulier).
  final bool confirmed;
  final String businessName;
  final String registrationNumber;

  /// Code ISO2 en majuscules, ou `null` tant qu'aucun pays n'est choisi.
  final String? country;

  @override
  TravelerStatusEditing get form => this;

  /// « Continuer » : un statut est choisi.
  bool get canContinue => choice != null;

  /// « Enregistrer » : particulier = case cochée ; professionnel = raison
  /// sociale, numéro conforme et pays.
  bool get canSubmit => switch (choice) {
    TravelerStatus.individual => confirmed,
    TravelerStatus.professional =>
      businessName.trim().length >= kBusinessNameMinLength &&
          isRegistrationNumberValid &&
          country != null &&
          kCountryPattern.hasMatch(country!),
    null => false,
  };

  bool get isRegistrationNumberValid {
    final number = registrationNumber.trim();
    return number.length >= kRegistrationNumberMinLength &&
        number.length <= kRegistrationNumberMaxLength &&
        kRegistrationNumberPattern.hasMatch(number);
  }

  TravelerStatusEditing copyWith({
    TravelerStatus? choice,
    bool? detailsStep,
    bool? confirmed,
    String? businessName,
    String? registrationNumber,
    String? country,
    bool clearCountry = false,
  }) => TravelerStatusEditing(
    choice: choice ?? this.choice,
    detailsStep: detailsStep ?? this.detailsStep,
    confirmed: confirmed ?? this.confirmed,
    businessName: businessName ?? this.businessName,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    country: clearCountry ? null : (country ?? this.country),
  );

  @override
  List<Object?> get props => [
    choice,
    detailsStep,
    confirmed,
    businessName,
    registrationNumber,
    country,
  ];
}

class TravelerStatusSubmitting extends TravelerStatusState {
  const TravelerStatusSubmitting(this.form);

  @override
  final TravelerStatusEditing form;
}

class TravelerStatusSuccess extends TravelerStatusState {
  const TravelerStatusSuccess(this.form, this.declaration);

  @override
  final TravelerStatusEditing form;
  final TravelerStatusDeclaration declaration;

  @override
  List<Object?> get props => [form, declaration.status, declaration.declaredAt];
}

/// Le back a refusé ou le réseau a coupé : la feuille reste ouverte, avec ce
/// qui a été saisi, pour corriger et renvoyer.
class TravelerStatusFailure extends TravelerStatusState {
  const TravelerStatusFailure(this.form, this.error);

  @override
  final TravelerStatusEditing form;
  final AppException error;

  /// Code métier du back (`traveler-status-invalid`…), `unknown` sinon.
  String get code => error.code ?? 'unknown';

  @override
  List<Object?> get props => [form, error];
}

/// Déclaration du statut légal du voyageur (`PUT /traveler-status/me`).
class TravelerStatusCubit extends Cubit<TravelerStatusState> {
  TravelerStatusCubit(this._repository, this._analytics)
    : super(const TravelerStatusInitial());

  final TravelerStatusRepository _repository;
  final AnalyticsService _analytics;

  void _edit(TravelerStatusEditing form) {
    if (state is TravelerStatusSubmitting || state is TravelerStatusSuccess) {
      return;
    }
    emit(form);
  }

  /// Choisit un statut. Changer de statut efface ce qui était saisi pour
  /// l'autre : la case d'un particulier ne vaut rien pour un professionnel.
  void choose(TravelerStatus status) {
    final form = state.form;
    if (form.choice == status) {
      _edit(form);
      return;
    }
    _edit(TravelerStatusEditing(choice: status, detailsStep: form.detailsStep));
  }

  /// « Continuer » : passe à l'étape 2. Sans choix, ne fait rien.
  void continueToDetails() {
    final form = state.form;
    if (!form.canContinue) return;
    _edit(form.copyWith(detailsStep: true));
  }

  /// « Retour » : revient au choix, en gardant le statut et la saisie.
  void back() => _edit(state.form.copyWith(detailsStep: false));

  void setConfirmed(bool value) => _edit(state.form.copyWith(confirmed: value));

  /// Met à jour la saisie du professionnel. Un argument absent garde la valeur
  /// courante ; [country] vide efface le pays.
  void updateBusiness({
    String? name,
    String? registrationNumber,
    String? country,
  }) {
    final form = state.form;
    _edit(
      country != null && country.isEmpty
          ? form.copyWith(
              businessName: name,
              registrationNumber: registrationNumber,
              clearCountry: true,
            )
          : form.copyWith(
              businessName: name,
              registrationNumber: registrationNumber,
              country: country,
            ),
    );
  }

  Future<void> submit() async {
    final form = state.form;
    if (state is TravelerStatusSubmitting ||
        state is TravelerStatusSuccess ||
        !form.canSubmit) {
      return;
    }
    final status = form.choice!;
    emit(TravelerStatusSubmitting(form));
    try {
      final declaration = switch (status) {
        TravelerStatus.individual => await _repository.declare(
          status: status,
          personalUseConfirmed: true,
        ),
        TravelerStatus.professional => await _repository.declare(
          status: status,
          businessName: form.businessName.trim(),
          registrationNumber: form.registrationNumber.trim(),
          country: form.country,
        ),
      };
      if (isClosed) return;
      emit(TravelerStatusSuccess(form, declaration));
      // Jamais la raison sociale ni le numéro : seulement le statut.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.travelerStatusDeclared,
          properties: {'status': status.wire},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(TravelerStatusFailure(form, unwrapDioError(e)));
    }
  }
}
