import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/sent_invitations_cubit.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/presentation/widgets/invite_recipient_sheet.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

/// Ouvre la feuille d'invitation puis, si elle est partie, annonce le même
/// message que le compte existe ou non.
///
/// Les invitations envoyées sont rechargées dès le succès de l'envoi, depuis
/// la feuille elle-même ([InviteRecipientSheet.show] `onSent`) : le
/// rechargement ne dépend plus du retour de la feuille ni du contexte de la
/// tuile qui l'a ouverte (FLUTTER-88, la section n'apparaissait qu'après un
/// rechargement manuel de l'écran).
Future<void> inviteYadonyRecipient(BuildContext context) async {
  final cubit = context.read<SentInvitationsCubit>();
  final sent = await InviteRecipientSheet.show(
    context,
    userCountry: _userCountry(),
    onSent: () {
      if (!cubit.isClosed) unawaited(cubit.load());
    },
  );
  if (!sent || !context.mounted) return;
  DonySnackbar.show(
    context,
    message: context.l10n.recipientInviteSent,
    type: DonySnackbarType.success,
  );
}

/// Ouvre la feuille de partage système avec [text]. Injectable en test.
typedef AppLinkSharer = Future<void> Function(String text, Rect? origin);

Future<void> _shareWithSystemSheet(String text, Rect? origin) async {
  await Share.share(text, sharePositionOrigin: origin);
}

/// Pays de résidence de l'utilisateur, pour mettre au format international
/// un numéro repris de ses contacts. `null` s'il n'est pas connu.
String? _userCountry() => getIt.isRegistered<BusinessPrefsBloc>()
    ? getIt<BusinessPrefsBloc>().state.country
    : null;

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
///
/// Une invitation vers un numéro sans compte reste listée comme les autres :
/// le serveur ne distingue jamais les deux cas, pour ne pas révéler si un
/// numéro a un compte Yadony. La ligne d'aide et le partage du lien de l'app
/// couvrent le cas où la personne n'a pas encore l'app (FLUTTER-89).
class SentInvitationsSection extends StatelessWidget {
  const SentInvitationsSection({super.key, this.share});

  /// Remplace la feuille de partage système dans les tests.
  final AppLinkSharer? share;

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
              const SizedBox(height: DonySpacing.xxs),
              Text(
                l.recipientSentInvitationsHelp,
                key: const Key('sent-invitations-help'),
                style: tt.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              for (final invitation in state.invitations)
                _SentInvitationRow(
                  invitation: invitation,
                  busy: state.busyId == invitation.id,
                  share: share ?? _shareWithSystemSheet,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SentInvitationRow extends StatelessWidget {
  const _SentInvitationRow({
    required this.invitation,
    required this.busy,
    required this.share,
  });

  final SentRecipientInvitation invitation;
  final bool busy;
  final AppLinkSharer share;

  /// Lien d'installation de Yadony, à envoyer à la personne invitée. Même
  /// message que le numéro ait un compte ou non : l'app n'en sait rien.
  Future<void> _shareAppLink(BuildContext buttonContext) async {
    final text = buttonContext.l10n.recipientSentInvitationShareMessage;
    final origin = sharePositionOriginFor(buttonContext);
    buttonContext.read<SentInvitationsCubit>().trackAppLinkShared();
    await share(text, origin);
  }

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
    final name = invitation.name;
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
                // Le nom, quand l'expéditeur l'a donné, se lit avant la cible
                // masquée, qui passe alors en dessous.
                if (name != null) ...[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    invitation.maskedTarget,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ] else
                  Text(
                    invitation.maskedTarget,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(height: 2),
                // Seules les invitations en attente restent listées : une
                // invitation acceptée rejoint le carnet (badge Yadony).
                DonyBadge(
                  label: l.recipientSentInvitationPending,
                  type: DonyBadgeType.warning,
                ),
                Builder(
                  builder: (buttonContext) => TextButton.icon(
                    key: Key('sent-invitation-share-${invitation.id}'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, kDonyMinTapTarget),
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: () => unawaited(_shareAppLink(buttonContext)),
                    icon: DonyIcon('share-2', size: 16, color: cs.primary),
                    label: Text(l.recipientSentInvitationShareAction),
                  ),
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
