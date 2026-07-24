import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// Carte profil expéditeur (vue voyageur) — bouton 📞 conditionnel + 💬 chat.
///
/// Le bouton téléphone est affiché uniquement si :
///   - `bid.senderPhone` est non-null et non-vide,
///   - ET le statut n'est pas COMPLETED ni DELIVERED.
///
/// Requiert un [ConversationOpenBloc] dans le contexte.
class ExpediteurContactCard extends StatelessWidget {
  final BidModel bid;

  const ExpediteurContactCard({super.key, required this.bid});

  bool get _showPhoneButton {
    final phone = bid.senderPhone;
    if (phone == null || phone.isEmpty) {
      return false;
    }
    final s = bid.status;
    return s != 'COMPLETED' && s != 'DELIVERED';
  }

  Future<void> _call(BuildContext context) async {
    unawaited(getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.senderCallInitiated,
      properties: {'status': bid.status},
    ));
    final uri = Uri(scheme: 'tel', path: bid.senderPhone);
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && context.mounted) {
      DonySnackbar.show(
        context,
        message: 'Impossible d\'ouvrir le composeur',
        type: DonySnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = bid.resolvedSenderName;
    final canOpenProfile = bid.senderId.isNotEmpty;

    return InkWell(
      onTap: canOpenProfile
          ? () => context.push(
                '/profile/public',
                extra: ProfilePublicArgs(
                  userId: bid.senderId,
                  showSubscribe: false,
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXPÉDITEUR',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            Row(
              children: [
                DonyAvatar(
                  name: name,
                  imageUrl: bid.senderAvatarUrl,
                  verified: bid.senderKycVerified,
                  pro: bid.senderIsProAccount,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badges — Wrap : un nom long + deux badges (KYC +
                      // Kilo Pro) ne tiennent pas sur une ligne dans la colonne
                      // étroite ; le Wrap fait passer les chips à la ligne au
                      // lieu d'un RenderFlex overflow. Le nom (maxLines 1 +
                      // ellipsis) est borné par la largeur du Wrap.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: DonySpacing.xs,
                        runSpacing: DonySpacing.xs,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (bid.senderKycVerified)
                            MiniChip(
                              label: 'Identité',
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          if (bid.senderKiloPro)
                            const MiniChip(
                              label: 'Kilo Pro',
                              color: DonyColors.amberDark,
                              bg: DonyColors.amberLight,
                            ),
                        ],
                      ),
                      // Nombre d'envois
                      if (bid.senderTotalShipments != null)
                        Text(
                          '· ${bid.senderTotalShipments} envoi${bid.senderTotalShipments! > 1 ? 's' : ''}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Bouton 📞 — conditionnel
                if (_showPhoneButton) ...[
                  _IconActionButton(
                    iconAsset: 'phone',
                    onTap: () => _call(context),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                ],
                // Bouton 💬 chat
                BlocBuilder<ConversationOpenBloc, ConversationOpenState>(
                  builder: (context, openState) {
                    final isOpening = openState is ConversationOpenLoading;
                    return _IconActionButton(
                      iconAsset: 'message-circle',
                      isLoading: isOpening,
                      onTap: isOpening
                          ? null
                          : () => context.read<ConversationOpenBloc>().add(
                                ConversationOpenRequested(bid.id),
                              ),
                    );
                  },
                ),
                if (canOpenProfile) ...[
                  const SizedBox(width: DonySpacing.xs),
                  DonyIcon(
                    'chevron-right',
                    color: cs.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton icône circulaire 44×44 ─────────────────────────────────────────────

class _IconActionButton extends StatelessWidget {
  final String iconAsset;
  final VoidCallback? onTap;
  final bool isLoading;

  const _IconActionButton({
    required this.iconAsset,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: cs.primary),
        ),
        child: isLoading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  color: cs.primary,
                  strokeWidth: 2,
                ),
              )
            : DonyIcon(iconAsset, color: cs.primary, size: 18),
      ),
    );
  }
}
