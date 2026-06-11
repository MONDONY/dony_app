import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_profile_sheet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// Carte profil voyageur (vue expéditeur) — bouton 📞 conditionnel + 💬 chat.
///
/// Le bouton téléphone est affiché uniquement si :
///   - `bid.travelerPhone` est non-null et non-vide,
///   - ET le statut n'est pas COMPLETED ni DELIVERED.
///
/// Requiert un [ConversationOpenBloc] dans le contexte.
class VoyageurContactCard extends StatelessWidget {
  final BidModel bid;

  const VoyageurContactCard({super.key, required this.bid});

  TravelerProfile _buildTravelerProfile() => TravelerProfile(
        id: bid.travelerId ?? '',
        displayName: bid.travelerName,
        phoneNumber: bid.travelerPhone,
        averageRating: bid.travelerAverageRating,
        totalTrips: bid.travelerTotalTrips,
        kycVerified: bid.travelerKycVerified,
        isProAccount: bid.travelerIsProAccount,
        kiloPro: bid.travelerKiloPro,
      );

  bool get _showPhoneButton {
    final phone = bid.travelerPhone;
    if (phone == null || phone.isEmpty) {
      return false;
    }
    final s = bid.status;
    return s != 'COMPLETED' && s != 'DELIVERED';
  }

  Future<void> _call(BuildContext context) async {
    unawaited(getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.travelerCallInitiated,
      properties: {'status': bid.status},
    ));
    final uri = Uri(scheme: 'tel', path: bid.travelerPhone);
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
    final name = bid.travelerName ?? 'Voyageur';
    final canOpenProfile = bid.travelerId != null;

    final ratingLabel = bid.travelerAverageRating != null
        ? '★ ${bid.travelerAverageRating!.toStringAsFixed(1)}'
        : '★ —';
    final tripsLabel = bid.travelerTotalTrips != null
        ? '· ${bid.travelerTotalTrips} trajet${bid.travelerTotalTrips! > 1 ? 's' : ''}'
        : '';

    return InkWell(
      onTap: canOpenProfile
          ? () => showTravelerProfileSheet(context, _buildTravelerProfile())
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
              'VOYAGEUR',
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
                  verified: bid.travelerKycVerified,
                  pro: bid.travelerIsProAccount,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (bid.travelerKycVerified) ...[
                            const SizedBox(width: DonySpacing.xs),
                            MiniChip(
                              label: 'KYC',
                              color: cs.primary,
                              bg: cs.primaryContainer,
                            ),
                          ],
                          if (bid.travelerKiloPro) ...[
                            const SizedBox(width: DonySpacing.xs),
                            const MiniChip(
                              label: 'Kilo Pro',
                              color: DonyColors.amberDark,
                              bg: DonyColors.amberLight,
                            ),
                          ],
                        ],
                      ),
                      // Note + trajets
                      Text(
                        '$ratingLabel $tripsLabel'.trim(),
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
                    icon: Icons.phone_rounded,
                    onTap: () => _call(context),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                ],
                // Bouton 💬 chat
                BlocBuilder<ConversationOpenBloc, ConversationOpenState>(
                  builder: (context, openState) {
                    final isOpening = openState is ConversationOpenLoading;
                    return _IconActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
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
                  Icon(
                    Icons.chevron_right_rounded,
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
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _IconActionButton({
    required this.icon,
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
            : Icon(icon, color: cs.primary, size: 18),
      ),
    );
  }
}
