import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Moyen par lequel l'expéditeur retrouve son destinataire.
enum InvitationChannel { phone, email }

enum InviteRecipientStatus { editing, submitting, sent, failed }

class InviteRecipientState {
  const InviteRecipientState({
    this.channel = InvitationChannel.phone,
    this.input = '',
    this.status = InviteRecipientStatus.editing,
    this.error,
    this.touched = false,
    this.name = '',
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

  /// Valeur envoyée au serveur : numéro E.164 ou email en minuscules.
  String get target => channel == InvitationChannel.phone
      ? normalizeRecipientPhone(input)
      : input.trim().toLowerCase();

  /// Nom au-delà de ce que le serveur accepte : l'envoi est bloqué.
  bool get nameTooLong => name.trim().length > nameMaxLength;

  /// Numéro ou e-mail au bon format.
  bool get targetIsValid => channel == InvitationChannel.phone
      ? kRecipientPhoneE164.hasMatch(target)
      : kRecipientEmail.hasMatch(target);

  bool get isValid => targetIsValid && !nameTooLong;

  /// Saisie commencée mais invalide : le champ affiche son erreur.
  bool get showsError => touched && input.trim().isNotEmpty && !targetIsValid;

  bool get isQuotaExceeded => error is RateLimitException;

  InviteRecipientState copyWith({
    InvitationChannel? channel,
    String? input,
    InviteRecipientStatus? status,
    AppException? error,
    bool? touched,
    String? name,
  }) => InviteRecipientState(
    channel: channel ?? this.channel,
    input: input ?? this.input,
    status: status ?? this.status,
    error: error,
    touched: touched ?? this.touched,
    name: name ?? this.name,
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
    // Le nom vaut pour les deux moyens : il survit au changement d'onglet.
    emit(InviteRecipientState(channel: channel, name: state.name));
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
      ),
    );
  }

  void inputChanged(String value) {
    if (state.status == InviteRecipientStatus.submitting) return;
    emit(state.copyWith(input: value, status: InviteRecipientStatus.editing));
  }

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
      if (channel == InvitationChannel.phone) {
        await _repository.sendToPhone(state.target, name: name);
      } else {
        await _repository.sendToEmail(state.target, name: name);
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
      emit(
        state.copyWith(
          status: InviteRecipientStatus.failed,
          error: unwrapDioError(e),
        ),
      );
    }
  }
}
