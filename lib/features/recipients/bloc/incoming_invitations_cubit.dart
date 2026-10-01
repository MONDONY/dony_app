import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Code ProblemDetail : accepter exige un numéro sur le compte.
const kInvitationPhoneRequiredCode = 'recipient-invitation-phone-required';

enum IncomingInvitationsStatus { loading, loaded, error }

/// Issue ponctuelle d'une action, que l'écran signale une fois.
enum IncomingInvitationOutcome { accepted, phoneRequired, failed }

class IncomingInvitationsState {
  const IncomingInvitationsState({
    this.status = IncomingInvitationsStatus.loading,
    this.invitations = const [],
    this.busyId,
    this.outcome,
    this.outcomeName,
    this.error,
  });

  final IncomingInvitationsStatus status;
  final List<IncomingRecipientInvitation> invitations;
  final String? busyId;
  final IncomingInvitationOutcome? outcome;

  /// Prénom de l'expéditeur concerné par [outcome].
  final String? outcomeName;
  final AppException? error;

  List<IncomingRecipientInvitation> get pending =>
      invitations.where((i) => i.isPending).toList();

  List<IncomingRecipientInvitation> get accepted =>
      invitations.where((i) => i.isAccepted).toList();

  IncomingInvitationsState copyWith({
    IncomingInvitationsStatus? status,
    List<IncomingRecipientInvitation>? invitations,
    String? busyId,
    IncomingInvitationOutcome? outcome,
    String? outcomeName,
    AppException? error,
  }) => IncomingInvitationsState(
    status: status ?? this.status,
    invitations: invitations ?? this.invitations,
    busyId: busyId,
    outcome: outcome,
    outcomeName: outcomeName,
    error: error,
  );
}

/// Demandes d'expéditeurs reçues : écran `/recipient-invitations` et bandeau
/// de l'onglet Suivi. Un échec de chargement (back antérieur au lot 4
/// compris) ne masque jamais une liste déjà affichée.
class IncomingInvitationsCubit extends Cubit<IncomingInvitationsState> {
  IncomingInvitationsCubit(this._repository, this._analytics)
    : super(const IncomingInvitationsState());

  final RecipientInvitationRepository _repository;
  final AnalyticsService _analytics;

  Future<void> load() async {
    try {
      final invitations = await _repository.getIncoming();
      if (isClosed) return;
      emit(
        IncomingInvitationsState(
          status: IncomingInvitationsStatus.loaded,
          invitations: invitations,
        ),
      );
    } catch (e) {
      if (isClosed || state.status == IncomingInvitationsStatus.loaded) return;
      emit(
        IncomingInvitationsState(
          status: IncomingInvitationsStatus.error,
          error: unwrapDioError(e),
        ),
      );
    }
  }

  Future<void> accept(String id) async {
    final invitation = _find(id);
    if (invitation == null || state.busyId != null) return;
    emit(state.copyWith(busyId: id));
    try {
      await _repository.accept(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          invitations: [
            for (final i in state.invitations)
              i.id == id ? i.copyWith(status: 'ACCEPTED') : i,
          ],
          outcome: IncomingInvitationOutcome.accepted,
          outcomeName: invitation.inviterFirstName,
        ),
      );
      _trackAnswer('accepted');
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      final phoneRequired =
          error is ConflictException &&
          error.code == kInvitationPhoneRequiredCode;
      emit(
        state.copyWith(
          outcome: phoneRequired
              ? IncomingInvitationOutcome.phoneRequired
              : IncomingInvitationOutcome.failed,
          error: error,
        ),
      );
    }
  }

  Future<void> decline(String id) async {
    if (_find(id) == null || state.busyId != null) return;
    emit(state.copyWith(busyId: id));
    try {
      await _repository.decline(id);
      if (isClosed) return;
      emit(state.copyWith(invitations: _without(id)));
      _trackAnswer('declined');
    } catch (e) {
      _fail(e);
    }
  }

  /// Retrait d'un expéditeur autorisé : ses prochains colis redemanderont
  /// une confirmation.
  Future<void> revoke(String id) async {
    if (_find(id) == null || state.busyId != null) return;
    emit(state.copyWith(busyId: id));
    try {
      await _repository.revoke(id);
      if (isClosed) return;
      emit(state.copyWith(invitations: _without(id)));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.recipientInvitationRevoked,
          properties: {'side': 'invitee'},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  IncomingRecipientInvitation? _find(String id) {
    for (final i in state.invitations) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<IncomingRecipientInvitation> _without(String id) =>
      state.invitations.where((i) => i.id != id).toList();

  void _fail(Object e) {
    if (isClosed) return;
    emit(
      state.copyWith(
        outcome: IncomingInvitationOutcome.failed,
        error: unwrapDioError(e),
      ),
    );
  }

  void _trackAnswer(String answer) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.recipientInvitationAnswered,
        properties: {'answer': answer},
      ),
    );
  }
}
