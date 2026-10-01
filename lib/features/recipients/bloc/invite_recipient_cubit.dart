import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
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
  });

  final InvitationChannel channel;

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

  bool get isValid => channel == InvitationChannel.phone
      ? kRecipientPhoneE164.hasMatch(target)
      : kRecipientEmail.hasMatch(target);

  /// Saisie commencée mais invalide : le champ affiche son erreur.
  bool get showsError => touched && input.trim().isNotEmpty && !isValid;

  bool get isQuotaExceeded => error is RateLimitException;

  InviteRecipientState copyWith({
    InvitationChannel? channel,
    String? input,
    InviteRecipientStatus? status,
    AppException? error,
    bool? touched,
  }) => InviteRecipientState(
    channel: channel ?? this.channel,
    input: input ?? this.input,
    status: status ?? this.status,
    error: error,
    touched: touched ?? this.touched,
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
    emit(InviteRecipientState(channel: channel));
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
    try {
      if (channel == InvitationChannel.phone) {
        await _repository.sendToPhone(state.target);
      } else {
        await _repository.sendToEmail(state.target);
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
