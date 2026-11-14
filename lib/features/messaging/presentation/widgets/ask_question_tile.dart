import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/messaging/bloc/ask_question/ask_question_cubit.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tuile « Poser une question » de la feuille d'un trajet : ouvre une
/// conversation avec le voyageur avant toute réservation.
///
/// L'état (appui, chargement, tuile retirée) vit dans [AskQuestionCubit]. La
/// sortie de la feuille (chat, connexion, vérification d'identité) est
/// confiée à l'appelant ([onOpenChat], [onFollowUp]) : c'est lui qui connaît
/// le mécanisme de navigation de la feuille.
class AskQuestionTile extends StatelessWidget {
  /// Quota annoncé tant que le serveur ne l'a pas donné.
  static const int defaultLimit = 10;

  const AskQuestionTile({
    super.key,
    required this.announcement,
    required this.viewerId,
    required this.onOpenChat,
    required this.onFollowUp,
    this.viewerKycStatus,
    this.cubit,
  });

  final AnnouncementModel announcement;
  final String? viewerId;

  /// Statut KYC connu du lecteur (`null` : inconnu, le serveur tranche).
  final String? viewerKycStatus;

  /// Ferme la feuille puis ouvre la conversation.
  final void Function(ConversationModel conversation) onOpenChat;

  /// Ferme la feuille puis exécute [run] avec le contexte du navigateur racine.
  final void Function(Future<void> Function(BuildContext rootContext) run)
  onFollowUp;

  /// Cubit fourni par un test ; sinon une instance neuve de l'injection.
  @visibleForTesting
  final AskQuestionCubit? cubit;

  /// Un trajet n'accepte des questions que s'il est ouvert, et pas le sien.
  static bool isAvailable(AnnouncementModel a, String? viewerId) =>
      a.status == 'ACTIVE' && (viewerId == null || viewerId != a.travelerId);

  @override
  Widget build(BuildContext context) {
    if (!isAvailable(announcement, viewerId)) {
      return const SizedBox.shrink();
    }
    return BlocProvider<AskQuestionCubit>(
      create: (_) => cubit ?? getIt<AskQuestionCubit>(),
      child: BlocConsumer<AskQuestionCubit, AskQuestionState>(
        listener: _onOutcome,
        builder: (context, state) {
          if (state.hidden) return const SizedBox.shrink();
          return _AskQuestionTileBody(
            announcement: announcement,
            loading: state.loading,
            onTap: () => unawaited(
              context.read<AskQuestionCubit>().ask(
                announcement.id,
                knownKycStatus: viewerKycStatus,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onOutcome(BuildContext context, AskQuestionState state) {
    switch (state) {
      case AskQuestionChatReady(:final conversation):
        onOpenChat(conversation);
      case AskQuestionAuthRequired():
        onFollowUp(
          (root) =>
              AuthRequiredSheet.show(root, reason: AuthRequiredReason.offer),
        );
      case AskQuestionKycRequired(:final kycStatus):
        onFollowUp(
          (root) => KycRequiredBottomSheet.show(root, kycStatus: kycStatus),
        );
      case AskQuestionUnavailable():
        DonySnackbar.show(
          context,
          message: context.l10n.inquiryAskUnavailable,
          type: DonySnackbarType.warning,
        );
      case AskQuestionFailed(:final error):
        unawaited(ErrorPresenter.show(context, error));
      case AskQuestionIdle() || AskQuestionLoading() || AskQuestionHidden():
        break;
    }
  }
}

class _AskQuestionTileBody extends StatelessWidget {
  const _AskQuestionTileBody({
    required this.announcement,
    required this.loading,
    required this.onTap,
  });

  final AnnouncementModel announcement;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final traveler = announcement.traveler;
    final fullName = traveler?.travelerName(l) ?? l.tripTravelerFallbackName;
    final firstName = fullName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.md),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: InkWell(
          key: const Key('ask-question-tile'),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          onTap: loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: cs.primary),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : DonyIcon(
                          'message-circle',
                          size: 20,
                          color: cs.onPrimary,
                        ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.inquiryAskTileTitle,
                        style: tt.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l.inquiryAskTileSubtitle(firstName),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    l.inquiryAskTileBadge(AskQuestionTile.defaultLimit),
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
