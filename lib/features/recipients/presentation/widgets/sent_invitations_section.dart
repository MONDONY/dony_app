import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/sent_invitations_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/presentation/widgets/invite_recipient_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre la feuille d'invitation puis, si elle est partie, annonce le même
/// message que le compte existe ou non et recharge les invitations envoyées.
Future<void> inviteYadonyRecipient(BuildContext context) async {
  final cubit = context.read<SentInvitationsCubit>();
  final sent = await InviteRecipientSheet.show(context);
  if (!sent || !context.mounted) return;
  DonySnackbar.show(
    context,
    message: context.l10n.recipientInviteSent,
    type: DonySnackbarType.success,
  );
  await cubit.load();
}

/// Entrée « Ajouter un destinataire Yadony » du carnet. Masquée sur un back
/// antérieur au lot 4 (404 sur les invitations).
class InviteYadonyRecipientTile extends StatelessWidget {
  const InviteYadonyRecipientTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<SentInvitationsCubit, SentInvitationsState>(
      buildWhen: (p, c) => p.isUnsupported != c.isUnsupported,
      builder: (context, state) {
        if (state.isUnsupported) return const SizedBox.shrink();
        return DonyListTile(
          key: const Key('invite-yadony-recipient'),
          label: l.recipientInviteAction,
          subtitle: l.recipientInviteActionSubtitle,
          iconAsset: 'user-plus',
          showDivider: false,
          trailing: const DonyIcon('chevron-right', size: 18),
          onTap: () => inviteYadonyRecipient(context),
        );
      },
    );
  }
}

/// « Invitations envoyées » : cible masquée, statut et annulation. Invisible
/// tant qu'il n'y a rien à montrer, en échec comme sur un back ancien.
class SentInvitationsSection extends StatelessWidget {
  const SentInvitationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return BlocConsumer<SentInvitationsCubit, SentInvitationsState>(
      listenWhen: (p, c) =>
          c.actionError != null && !identical(p.actionError, c.actionError),
      listener: (context, state) =>
          unawaited(ErrorPresenter.show(context, state.actionError)),
      builder: (context, state) {
        if (state.status != SentInvitationsStatus.loaded ||
            state.invitations.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          key: const Key('sent-invitations-section'),
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.recipientSentInvitationsTitle,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: DonySpacing.sm),
              for (final invitation in state.invitations)
                _SentInvitationRow(
                  invitation: invitation,
                  busy: state.busyId == invitation.id,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SentInvitationRow extends StatelessWidget {
  const _SentInvitationRow({required this.invitation, required this.busy});

  final SentRecipientInvitation invitation;
  final bool busy;

  Future<void> _cancel(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<SentInvitationsCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.recipientSentInvitationCancelTitle,
      message: l.recipientSentInvitationCancelMessage,
      iconAsset: 'user-x',
      confirmLabel: l.recipientSentInvitationCancelAction,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed ?? false) await cubit.revoke(invitation.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final accepted = invitation.isAccepted;
    return Padding(
      key: Key('sent-invitation-${invitation.id}'),
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        children: [
          DonyIcon(
            invitation.isEmail ? 'mail' : 'phone',
            size: 18,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.maskedTarget,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                DonyBadge(
                  label: accepted
                      ? l.recipientSentInvitationAccepted
                      : l.recipientSentInvitationPending,
                  type: accepted
                      ? DonyBadgeType.success
                      : DonyBadgeType.warning,
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              key: Key('sent-invitation-cancel-${invitation.id}'),
              onPressed: () => _cancel(context),
              child: Text(l.commonCancel),
            ),
        ],
      ),
    );
  }
}
