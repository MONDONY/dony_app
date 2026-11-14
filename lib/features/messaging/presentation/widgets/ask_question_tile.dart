import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Tuile « Poser une question » de la feuille d'un trajet : ouvre une
/// conversation avec le voyageur avant toute réservation.
///
/// La sortie de la feuille (chat, connexion, vérification d'identité) est
/// confiée à l'appelant ([onOpenChat], [onFollowUp]) : c'est lui qui connaît
/// le mécanisme de navigation de la feuille.
class AskQuestionTile extends StatefulWidget {
  /// Quota annoncé tant que le serveur ne l'a pas donné.
  static const int defaultLimit = 10;

  const AskQuestionTile({
    super.key,
    required this.announcement,
    required this.viewerId,
    required this.onOpenChat,
    required this.onFollowUp,
    this.viewerKycStatus,
    this.conversationRepository,
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

  final ConversationRepository? conversationRepository;

  /// Un trajet n'accepte des questions que s'il est ouvert, et pas le sien.
  static bool isAvailable(AnnouncementModel a, String? viewerId) =>
      a.status == 'ACTIVE' && (viewerId == null || viewerId != a.travelerId);

  @override
  State<AskQuestionTile> createState() => _AskQuestionTileState();
}

enum _TileState { idle, loading, gone }

class _AskQuestionTileState extends State<AskQuestionTile> {
  final ValueNotifier<_TileState> _state = ValueNotifier(_TileState.idle);

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  ConversationRepository get _repo =>
      widget.conversationRepository ?? getIt<ConversationRepository>();

  void _showKyc(String status) => widget.onFollowUp(
    (root) => KycRequiredBottomSheet.show(root, kycStatus: status),
  );

  Future<void> _onTap() async {
    if (_state.value != _TileState.idle) return;
    if (!getIt<FirebaseSessionProbe>().hasRealSession) {
      widget.onFollowUp(
        (root) =>
            AuthRequiredSheet.show(root, reason: AuthRequiredReason.offer),
      );
      return;
    }
    final known = widget.viewerKycStatus;
    if (known != null && known != 'VERIFIED') {
      _showKyc(known);
      return;
    }
    _state.value = _TileState.loading;
    try {
      final conversation = await _repo.openInquiry(widget.announcement.id);
      if (!mounted) return;
      _state.value = _TileState.idle;
      widget.onOpenChat(conversation);
    } on InquiryKycRequiredException {
      if (!mounted) return;
      _state.value = _TileState.idle;
      _showKyc('NOT_STARTED');
    } on InquiryUnavailableException {
      if (!mounted) return;
      _state.value = _TileState.gone;
      DonySnackbar.show(
        context,
        message: context.l10n.inquiryAskUnavailable,
        type: DonySnackbarType.warning,
      );
    } catch (e) {
      if (!mounted) return;
      _state.value = _TileState.idle;
      await ErrorPresenter.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AskQuestionTile.isAvailable(widget.announcement, widget.viewerId)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final traveler = widget.announcement.traveler;
    final fullName = traveler?.travelerName(l) ?? l.tripTravelerFallbackName;
    final firstName = fullName.split(' ').first;
    return ValueListenableBuilder<_TileState>(
      valueListenable: _state,
      builder: (context, state, _) {
        if (state == _TileState.gone) return const SizedBox.shrink();
        final loading = state == _TileState.loading;
        return Padding(
          padding: const EdgeInsets.only(top: DonySpacing.md),
          child: Material(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: InkWell(
              key: const Key('ask-question-tile'),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              onTap: loading ? null : _onTap,
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
      },
    );
  }
}
