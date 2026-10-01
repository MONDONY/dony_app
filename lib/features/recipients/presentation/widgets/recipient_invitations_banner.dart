import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/incoming_invitations_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route de l'écran des demandes d'expéditeurs.
const kRecipientInvitationsRoute = '/recipient-invitations';

/// Bandeau « N demande(s) d'expéditeurs », en tête de « Colis à recevoir »
/// dans l'onglet Suivi. Visible seulement quand une invitation attend une
/// réponse ; muet en échec et sur un back antérieur au lot 4.
class RecipientInvitationsBanner extends StatelessWidget {
  const RecipientInvitationsBanner({super.key});

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<IncomingInvitationsCubit>();
    await context.push<void>(kRecipientInvitationsRoute);
    // Accepté ou refusé depuis l'écran : le bandeau suit.
    if (context.mounted) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return BlocBuilder<IncomingInvitationsCubit, IncomingInvitationsState>(
      builder: (context, state) {
        final count = state.pending.length;
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.lg),
          child: DonyPressable(
            key: const Key('recipient-invitations-banner'),
            onTap: () => _open(context),
            child: Container(
              padding: const EdgeInsets.all(DonySpacing.base),
              decoration: BoxDecoration(
                color: cs.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.warning),
              ),
              child: Row(
                children: [
                  DonyIcon('user-plus', size: 22, color: cs.onSurface),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.recipientInvitationsBanner(count),
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.recipientInvitationsBannerSubtitle,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  DonyIcon('chevron-right', size: 18, color: cs.onSurface),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
