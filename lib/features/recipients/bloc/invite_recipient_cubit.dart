import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/features/profile/bloc/username/username_cubit.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Moyen par lequel l'expéditeur retrouve son destinataire.
enum InvitationChannel { phone, email, username }

/// Résultat de la recherche d'un identifiant Yadony.
enum UsernameLookupStatus {
  idle,
  searching,
  found,
  notFound,

  /// `422 recipient-invitation-self` : c'est l'identifiant de l'expéditeur.
  self,

  /// `429 recipient-lookup-quota` (30 par heure, partagé avec l'envoi).
  quota,

  /// Route absente (back pas encore déployé) : l'onglet disparaît.
  unsupported,

  /// Autre échec (réseau, serveur) : l'utilisateur peut réessayer.
  failed,
}

enum InviteRecipientStatus { editing, submitting, sent, failed }

class InviteRecipientState {
  const InviteRecipientState({
    this.channel = InvitationChannel.phone,
    this.input = '',
    this.status = InviteRecipientStatus.editing,
    this.error,
    this.touched = false,
    this.name = '',
    this.lookup = UsernameLookupStatus.idle,
    this.foundInitial = '',
    this.foundTarget = '',
    this.usernameUnsupported = false,
  });

  /// Longueur maximale du nom accepté par `POST /recipient-invitations`.
  static const nameMaxLength = 100;

  final InvitationChannel channel;

  /// Nom facultatif de la personne invitée, saisi ou repris du contact.
  final String name;

  /// Nom envoyé au serveur, `null` s'il est vide.
  String? get trimmedName {
    final n = name.trim();
    return n.isEmpty ? null : n;
  }

  /// Saisie brute du champ actif.
  final String input;
  final InviteRecipientStatus status;

  /// Échec du dernier envoi (`RateLimitException` pour le quota).
  final AppException? error;

  /// Le champ a perdu le focus une fois : son erreur peut s'afficher. Pas
  /// avant, pour ne pas reprocher un numéro en cours de frappe.
  final bool touched;

  /// Recherche de l'identifiant (canal [InvitationChannel.username]).
  final UsernameLookupStatus lookup;

  /// Initiale du prénom du compte trouvé.
  final String foundInitial;

  /// Identifiant pour lequel [lookup] est `found`.
  final String foundTarget;

  /// Le back ne connaît pas encore la recherche : l'onglet est retiré.
  final bool usernameUnsupported;

  /// Valeur envoyée au serveur : numéro E.164, e-mail ou identifiant en
  /// minuscules (sans `@` initial).
  String get target {
    switch (channel) {
      case InvitationChannel.phone:
        return normalizeRecipientPhone(input);
      case InvitationChannel.email:
        return input.trim().toLowerCase();
      case InvitationChannel.username:
        final v = input.trim().toLowerCase();
        return v.startsWith('@') ? v.substring(1) : v;
    }
  }

  /// Nom au-delà de ce que le serveur accepte : l'envoi est bloqué.
  bool get nameTooLong => name.trim().length > nameMaxLength;

  /// Numéro ou e-mail au bon format.
  bool get targetIsValid {
    switch (channel) {
      case InvitationChannel.phone:
        return kRecipientPhoneE164.hasMatch(target);
      case InvitationChannel.email:
        return kRecipientEmail.hasMatch(target);
      case InvitationChannel.username:
        return lookup == UsernameLookupStatus.found && foundTarget == target;
    }
  }

  /// Format local d'identifiant valide (3 à 20 caractères `a-z 0-9 . _`).
  bool get usernameFormatValid => UsernameCubit.isValidFormat(target);

  bool get isValid => targetIsValid && !nameTooLong;

  /// Saisie commencée mais invalide : le champ affiche son erreur.
  bool get showsError {
    if (!touched || input.trim().isEmpty) return false;
    if (channel == InvitationChannel.username) return !usernameFormatValid;
    return !targetIsValid;
  }

  bool get isQuotaExceeded => error is RateLimitException;

  InviteRecipientState copyWith({
    InvitationChannel? channel,
    String? input,
    InviteRecipientStatus? status,
    AppException? error,
    bool? touched,
    String? name,
    UsernameLookupStatus? lookup,
    String? foundInitial,
    String? foundTarget,
    bool? usernameUnsupported,
  }) => InviteRecipientState(
    channel: channel ?? this.channel,
    input: input ?? this.input,
    status: status ?? this.status,
    error: error,
    touched: touched ?? this.touched,
    name: name ?? this.name,
    lookup: lookup ?? this.lookup,
    foundInitial: foundInitial ?? this.foundInitial,
    foundTarget: foundTarget ?? this.foundTarget,
    usernameUnsupported: usernameUnsupported ?? this.usernameUnsupported,
  );
}

/// Feuille « Ajouter un destinataire Yadony ».
///
/// La réponse du serveur est la même que le compte existe ou non : la feuille
/// n'en déduit rien et annonce toujours « Invitation envoyée ».
class InviteRecipientCubit extends Cubit<InviteRecipientState> {
  InviteRecipientCubit(this._repository, this._analytics)
    : super(const InviteRecipientState());

  final RecipientInvitationRepository _repository;
  final AnalyticsService _analytics;

  void selectChannel(InvitationChannel channel) {
    if (channel == state.channel) return;
    if (channel == InvitationChannel.username && state.usernameUnsupported) {
      return;
    }
    _generation++;
    // Le nom vaut pour tous les moyens : il survit au changement d'onglet.
    emit(
      InviteRecipientState(
        channel: channel,
        name: state.name,
        usernameUnsupported: state.usernameUnsupported,
      ),
    );
  }

  void nameChanged(String value) {
    if (state.status == InviteRecipientStatus.submitting) return;
    emit(state.copyWith(name: value, status: InviteRecipientStatus.editing));
  }

  /// Contact choisi dans le carnet du téléphone : bascule sur le numéro, le
  /// met au format international avec le pays de l'utilisateur
  /// ([countryCode], un contact s'écrit souvent au format national `07…`) et
  /// reprend son nom. Un contact sans numéro ne garde que le nom.
  void contactPicked(PickedContact contact, {String? countryCode}) {
    if (state.status == InviteRecipientStatus.submitting) return;
    // Une recherche d'identifiant en vol ne doit pas écrire sur l'onglet
    // Numéro.
    _generation++;
    final phone = contact.phone;
    final fullName = contact.fullName?.trim() ?? '';
    final name = fullName.length > InviteRecipientState.nameMaxLength
        ? fullName.substring(0, InviteRecipientState.nameMaxLength)
        : fullName;
    final keptName = name.isEmpty ? state.name : name;
    if (phone == null || phone.isEmpty) {
      emit(state.copyWith(name: keptName));
      return;
    }
    emit(
      InviteRecipientState(
        input: internationalizeRecipientPhone(phone, countryCode),
        name: keptName,
        touched: true,
        usernameUnsupported: state.usernameUnsupported,
      ),
    );
  }

  void inputChanged(String value) {
    if (state.status == InviteRecipientStatus.submitting) return;
    // Toute modification de l'identifiant invalide l'aperçu et annule la
    // recherche en vol : le serveur n'est jamais interrogé à la frappe.
    if (state.channel == InvitationChannel.username) _generation++;
    emit(
      state.copyWith(
        input: value,
        status: InviteRecipientStatus.editing,
        lookup: state.channel == InvitationChannel.username
            ? UsernameLookupStatus.idle
            : null,
        foundInitial: '',
        foundTarget: '',
      ),
    );
  }

  /// Perte de focus du champ identifiant ou validation du clavier : lance la
  /// recherche, seulement si le format local est valide (le seau serveur est
  /// de 30 par heure, partagé avec l'envoi). Le serveur reste l'autorité.
  Future<void> usernameCommitted() async {
    // Feuille fermée (glissement) : ni requête, ni émission.
    if (isClosed) return;
    final s = state;
    if (s.channel != InvitationChannel.username ||
        s.status == InviteRecipientStatus.submitting ||
        !s.usernameFormatValid) {
      return;
    }
    // Déjà cherché (ou en cours) pour cette saisie ; seul un échec technique
    // se retente.
    if (s.lookup != UsernameLookupStatus.idle &&
        s.lookup != UsernameLookupStatus.failed) {
      return;
    }
    final target = s.target;
    final generation = ++_generation;
    emit(s.copyWith(lookup: UsernameLookupStatus.searching, touched: true));
    try {
      final result = await _repository.lookupUsername(target);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          lookup: UsernameLookupStatus.found,
          foundInitial: result.initial,
          foundTarget: target,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final status = _lookupStatusFor(unwrapDioError(e));
      emit(
        state.copyWith(
          lookup: status,
          usernameUnsupported: status == UsernameLookupStatus.unsupported
              ? true
              : null,
        ),
      );
    }
  }

  /// Verdict du serveur sur un identifiant, d'après le type du problème.
  static UsernameLookupStatus _lookupStatusFor(AppException error) {
    if (error is RateLimitException) return UsernameLookupStatus.quota;
    if (error is NotFoundException) {
      // Un 404 sans `user-not-found` est une route absente (ancien back).
      return (usernameProblemSlug(error)?.endsWith('user-not-found') ?? false)
          ? UsernameLookupStatus.notFound
          : UsernameLookupStatus.unsupported;
    }
    if (usernameProblemSlug(error)?.endsWith('recipient-invitation-self') ??
        false) {
      return UsernameLookupStatus.self;
    }
    return UsernameLookupStatus.failed;
  }

  var _generation = 0;

  /// Perte de focus du champ : l'erreur de format devient visible.
  void fieldBlurred() {
    if (!state.touched) emit(state.copyWith(touched: true));
  }

  Future<void> submit() async {
    if (!state.isValid || state.status == InviteRecipientStatus.submitting) {
      return;
    }
    emit(state.copyWith(status: InviteRecipientStatus.submitting));
    final channel = state.channel;
    final name = state.trimmedName;
    try {
      switch (channel) {
        case InvitationChannel.phone:
          await _repository.sendToPhone(state.target, name: name);
        case InvitationChannel.email:
          await _repository.sendToEmail(state.target, name: name);
        case InvitationChannel.username:
          await _repository.sendToUsername(state.target, name: name);
      }
      if (isClosed) return;
      emit(state.copyWith(status: InviteRecipientStatus.sent));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.recipientInvitationSent,
          properties: {'channel': channel.name},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      // Le compte a disparu ou la recherche est épuisée entre l'aperçu et
      // l'envoi : la feuille revient à l'état de recherche correspondant.
      if (channel == InvitationChannel.username) {
        final lookupFailure = _sendFailureAsLookup(error);
        if (lookupFailure != null) {
          emit(
            state.copyWith(
              status: InviteRecipientStatus.editing,
              lookup: lookupFailure,
              usernameUnsupported:
                  lookupFailure == UsernameLookupStatus.unsupported
                  ? true
                  : null,
            ),
          );
          return;
        }
      }
      emit(state.copyWith(status: InviteRecipientStatus.failed, error: error));
    }
  }

  static UsernameLookupStatus? _sendFailureAsLookup(AppException error) {
    if (error is RateLimitException) {
      // `recipient-invitation-quota` reste le quota quotidien d'envoi.
      return (error.apiCode?.endsWith('recipient-lookup-quota') ?? false)
          ? UsernameLookupStatus.quota
          : null;
    }
    final status = _lookupStatusFor(error);
    return status == UsernameLookupStatus.failed ? null : status;
  }
}
