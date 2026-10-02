import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SentInvitationsStatus { loading, loaded, unsupported, error }

class SentInvitationsState {
  const SentInvitationsState({
    this.status = SentInvitationsStatus.loading,
    this.invitations = const [],
    this.busyId,
    this.actionError,
  });

  final SentInvitationsStatus status;
  final List<SentRecipientInvitation> invitations;

  /// Invitation en cours d'annulation.
  final String? busyId;

  /// Échec de la dernière annulation, à signaler une fois.
  final AppException? actionError;

  /// Back antérieur au lot 4 (404) : l'invitation n'existe pas encore,
  /// l'action et la section restent masquées.
  bool get isUnsupported => status == SentInvitationsStatus.unsupported;

  SentInvitationsState copyWith({
    SentInvitationsStatus? status,
    List<SentRecipientInvitation>? invitations,
    String? busyId,
    AppException? actionError,
  }) => SentInvitationsState(
    status: status ?? this.status,
    invitations: invitations ?? this.invitations,
    busyId: busyId,
    actionError: actionError,
  );
}

/// « Invitations envoyées » du carnet de destinataires.
class SentInvitationsCubit extends Cubit<SentInvitationsState> {
  SentInvitationsCubit(this._repository, this._analytics)
    : super(const SentInvitationsState());

  final RecipientInvitationRepository _repository;
  final AnalyticsService _analytics;

  /// Premier chargement comme rafraîchissement silencieux : un échec garde
  /// la liste déjà affichée.
  Future<void> load() async {
    try {
      // Une invitation acceptée a fait son œuvre : la personne figure déjà
      // dans le carnet, avec le badge Yadony. La garder ici la montrait deux
      // fois (Sentry FLUTTER-7V).
      final invitations = (await _repository.getSent())
          .where((i) => !i.isAccepted)
          .toList();
      if (isClosed) return;
      emit(
        SentInvitationsState(
          status: SentInvitationsStatus.loaded,
          invitations: invitations,
        ),
      );
    } catch (e) {
      if (isClosed || state.status == SentInvitationsStatus.loaded) return;
      final error = unwrapDioError(e);
      emit(
        SentInvitationsState(
          status: error is NotFoundException
              ? SentInvitationsStatus.unsupported
              : SentInvitationsStatus.error,
        ),
      );
    }
  }

  Future<void> revoke(String id) async {
    if (state.busyId != null) return;
    emit(state.copyWith(busyId: id));
    try {
      await _repository.revoke(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          invitations: state.invitations.where((i) => i.id != id).toList(),
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.recipientInvitationRevoked,
          properties: {'side': 'inviter'},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(actionError: unwrapDioError(e)));
    }
  }
}
