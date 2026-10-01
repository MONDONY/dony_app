import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/incoming_invitations_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran de l'ajout de numéro du profil, proposé quand accepter exige un
/// téléphone sur le compte (409 `recipient-invitation-phone-required`).
const kAddProfilePhoneRoute = '/profile/edit/phone';

/// Demandes d'expéditeurs reçues : accepter ou refuser une invitation
/// « destinataire Yadony », retirer un expéditeur déjà autorisé.
class RecipientInvitationsScreen extends StatelessWidget {
  const RecipientInvitationsScreen({super.key});

  Future<void> _onOutcome(
    BuildContext context,
    IncomingInvitationsState state,
  ) async {
    final l = context.l10n;
    final cubit = context.read<IncomingInvitationsCubit>();
    switch (state.outcome) {
      case IncomingInvitationOutcome.accepted:
        DonySnackbar.show(
          context,
          message: l.recipientInvitationAcceptedMessage(
            state.outcomeName ?? '',
          ),
          type: DonySnackbarType.success,
        );
      case IncomingInvitationOutcome.phoneRequired:
        final addPhone = await DonyDialog.show(
          context,
          title: l.recipientInvitationPhoneRequiredTitle,
          message: l.recipientInvitationPhoneRequiredMessage,
          iconAsset: 'phone',
          confirmLabel: l.recipientInvitationPhoneRequiredAction,
        );
        if ((addPhone ?? false) && context.mounted) {
          await context.push<void>(kAddProfilePhoneRoute);
          if (context.mounted) await cubit.load();
        }
      case IncomingInvitationOutcome.failed:
        unawaited(ErrorPresenter.show(context, state.error));
        // L'invitation a pu changer ailleurs (retirée par l'expéditeur).
        await cubit.load();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonyPageScaffold(
      title: l.recipientInvitationsTitle,
      scrollable: false,
      padding: EdgeInsets.zero,
      body: BlocConsumer<IncomingInvitationsCubit, IncomingInvitationsState>(
        listenWhen: (p, c) => c.outcome != null && p.outcome == null,
        listener: (context, state) => unawaited(_onOutcome(context, state)),
        builder: (context, state) {
          final cubit = context.read<IncomingInvitationsCubit>();
          if (state.status == IncomingInvitationsStatus.loading) {
            return const DonyEmptyState(
              type: DonyEmptyStateType.loading,
              title: '',
            );
          }
          if (state.status == IncomingInvitationsStatus.error) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.erreurLegere,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: l.commonLoadError,
              description: ErrorPresenter.resolve(state.error, l10n: l).message,
              actionLabel: l.commonRetry,
              onAction: cubit.load,
            );
          }
          final pending = state.pending;
          final accepted = state.accepted;
          if (pending.isEmpty && accepted.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: l.recipientInvitationsEmptyTitle,
              description: l.recipientInvitationsEmptyDescription,
            );
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionTitle(label: l.recipientInvitationsPendingSection),
                  for (final invitation in pending)
                    _PendingCard(
                      invitation: invitation,
                      busy: state.busyId == invitation.id,
                    ),
                  const SizedBox(height: DonySpacing.lg),
                ],
                if (accepted.isNotEmpty) ...[
                  _SectionTitle(label: l.recipientInvitationsAuthorizedSection),
                  for (final invitation in accepted)
                    _AuthorizedRow(
                      invitation: invitation,
                      busy: state.busyId == invitation.id,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Text(
        label,
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.invitation, required this.busy});

  final IncomingRecipientInvitation invitation;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final cubit = context.read<IncomingInvitationsCubit>();
    final name = invitation.inviterFirstName;
    return Container(
      key: Key('incoming-invitation-${invitation.id}'),
      margin: const EdgeInsets.only(bottom: DonySpacing.sm),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyAvatar(name: name, size: DonyAvatarSize.sm),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  l.recipientInvitationRequestTitle(name),
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.recipientInvitationConsent(name),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              Expanded(
                child: DonyButton(
                  key: Key('incoming-invitation-decline-${invitation.id}'),
                  label: l.recipientInvitationDecline,
                  variant: DonyButtonVariant.secondary,
                  onPressed: busy ? null : () => cubit.decline(invitation.id),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyButton(
                  key: Key('incoming-invitation-accept-${invitation.id}'),
                  label: l.recipientInvitationAccept,
                  isLoading: busy,
                  onPressed: busy ? null : () => cubit.accept(invitation.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthorizedRow extends StatelessWidget {
  const _AuthorizedRow({required this.invitation, required this.busy});

  final IncomingRecipientInvitation invitation;
  final bool busy;

  Future<void> _remove(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<IncomingInvitationsCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.recipientInvitationRemoveTitle(invitation.inviterFirstName),
      message: l.recipientInvitationRemoveMessage,
      iconAsset: 'user-x',
      confirmLabel: l.recipientInvitationRemove,
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed ?? false) await cubit.revoke(invitation.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      key: Key('authorized-sender-${invitation.id}'),
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        children: [
          DonyAvatar(
            name: invitation.inviterFirstName,
            size: DonyAvatarSize.sm,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.inviterFirstName,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  l.recipientInvitationAuthorizedSubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
            TextButton.icon(
              key: Key('authorized-sender-remove-${invitation.id}'),
              onPressed: () => _remove(context),
              icon: DonyIcon('user-x', size: 16, color: cs.error),
              label: Text(
                l.recipientInvitationRemove,
                style: TextStyle(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }
}
