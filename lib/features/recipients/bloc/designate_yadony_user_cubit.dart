import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/username/username_cubit.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Résultat de la recherche d'un identifiant pour désigner un destinataire
/// de colis.
enum DesignateLookup {
  idle,
  searching,
  found,
  notFound,
  self,
  quota,

  /// Route de recherche absente (back ancien) : le choix disparaît.
  unsupported,

  /// Le compte existe mais le back ne sait pas désigner un destinataire de
  /// colis par identifiant (`parcelDesignation` absent ou faux) : aucune
  /// sélection, sinon l'identifiant serait ignoré en silence.
  unavailable,
  failed,

  /// Le compte trouvé est déjà le destinataire désigné de ce colis : le back
  /// ne ferait rien, « Choisir » reste grisé.
  sameAsCurrent,
}

/// Identifiant choisi comme destinataire d'un colis.
class DesignatedUser {
  const DesignatedUser(this.username);

  /// Identifiant en minuscules, sans `@`.
  final String username;
}

class DesignateYadonyUserState {
  const DesignateYadonyUserState({
    this.input = '',
    this.lookup = DesignateLookup.idle,
    this.foundInitial = '',
    this.foundTarget = '',
    this.touched = false,
  });

  final String input;
  final DesignateLookup lookup;
  final String foundInitial;
  final String foundTarget;
  final bool touched;

  /// Identifiant normalisé : minuscules, sans `@` initial.
  String get target {
    final v = input.trim().toLowerCase();
    return v.startsWith('@') ? v.substring(1) : v;
  }

  bool get usernameFormatValid => UsernameCubit.isValidFormat(target);

  /// « Choisir » n'est actif que pour un compte trouvé, pour cette saisie.
  bool get canChoose =>
      lookup == DesignateLookup.found && foundTarget == target;

  bool get showsFormatError =>
      touched &&
      input.trim().isNotEmpty &&
      lookup == DesignateLookup.idle &&
      !usernameFormatValid;

  DesignateYadonyUserState copyWith({
    String? input,
    DesignateLookup? lookup,
    String? foundInitial,
    String? foundTarget,
    bool? touched,
  }) => DesignateYadonyUserState(
    input: input ?? this.input,
    lookup: lookup ?? this.lookup,
    foundInitial: foundInitial ?? this.foundInitial,
    foundTarget: foundTarget ?? this.foundTarget,
    touched: touched ?? this.touched,
  );
}

/// Feuille « Un utilisateur Yadony » : recherche d'un identifiant pour le
/// désigner destinataire d'un colis. Même recherche que l'invitation de
/// l'étape 1 (une requête à la validation, jamais à la frappe).
class DesignateYadonyUserCubit extends Cubit<DesignateYadonyUserState> {
  DesignateYadonyUserCubit(this._repository, this._analytics)
    : super(const DesignateYadonyUserState());

  final RecipientInvitationRepository _repository;
  final AnalyticsService _analytics;
  var _generation = 0;

  /// Identifiant déjà désigné sur le colis qu'on modifie, sinon `null`.
  String? excludeUsername;

  void inputChanged(String value) {
    _generation++;
    emit(
      state.copyWith(
        input: value,
        lookup: DesignateLookup.idle,
        foundInitial: '',
        foundTarget: '',
      ),
    );
  }

  void fieldBlurred() {
    if (!state.touched) emit(state.copyWith(touched: true));
  }

  /// Validation du clavier ou perte de focus : cherche si le format local est
  /// valide et si cette saisie n'a pas déjà été cherchée.
  Future<void> committed() async {
    if (isClosed) return;
    final s = state;
    if (!s.usernameFormatValid) return;
    if (s.lookup != DesignateLookup.idle &&
        s.lookup != DesignateLookup.failed) {
      return;
    }
    final target = s.target;
    final generation = ++_generation;
    emit(s.copyWith(lookup: DesignateLookup.searching, touched: true));
    try {
      final result = await _repository.lookupUsername(target);
      if (isClosed || generation != _generation) return;
      if (!result.parcelDesignation) {
        _repository.parcelDesignationUnavailable = true;
        emit(state.copyWith(lookup: DesignateLookup.unavailable));
        _logFailure('parcel-designation-unavailable');
        return;
      }
      if (excludeUsername != null &&
          excludeUsername!.trim().toLowerCase() == target) {
        emit(state.copyWith(lookup: DesignateLookup.sameAsCurrent));
        return;
      }
      emit(
        state.copyWith(
          lookup: DesignateLookup.found,
          foundInitial: result.initial,
          foundTarget: target,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final error = unwrapDioError(e);
      final status = switch (InviteRecipientCubit.lookupStatusFor(error)) {
        UsernameLookupStatus.notFound => DesignateLookup.notFound,
        UsernameLookupStatus.self => DesignateLookup.self,
        UsernameLookupStatus.quota => DesignateLookup.quota,
        UsernameLookupStatus.unsupported => DesignateLookup.unsupported,
        _ => DesignateLookup.failed,
      };
      if (status == DesignateLookup.unsupported) {
        _repository.usernameChannelUnsupported = true;
      }
      emit(state.copyWith(lookup: status));
      _logFailure(usernameProblemSlug(error) ?? error.code ?? 'unknown');
    }
  }

  /// « Choisir » : rend l'identifiant trouvé, `null` sans compte trouvé.
  DesignatedUser? choose() {
    if (!state.canChoose) return null;
    unawaited(
      _analytics.logEvent(AnalyticsEvents.recipientDesignatedByUsername),
    );
    return DesignatedUser(state.foundTarget);
  }

  void _logFailure(String errorCode) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.recipientDesignationByUsernameFailed,
        properties: {'error_code': errorCode},
      ),
    );
  }
}
