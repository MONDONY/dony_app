import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void showTravelerAnnouncementSheet(
  BuildContext context, {
  required AnnouncementModel announcement,
  String? existingBidStatus,
  BidModel? existingBid,
}) {
  // Captured before DonyBottomSheet.show() — context may be invalid inside
  // onPressed since useRootNavigator: true places the sheet outside BlocProvider.
  final authState = context.read<AuthBloc>().state;
  final isKycVerified =
      authState is AuthAuthenticated && authState.user.isKycVerified;
  // Capture la référence au BidBloc du parent (carousel / liste) pour pouvoir
  // déclencher un refresh après la fermeture de CreateBidBottomSheet, même
  // quand useRootNavigator: true sort du BlocProvider tree.
  final BidBloc? parentBidBloc =
      context.mounted ? context.read<BidBloc>() : null;

  // Détecte un colis existant du viewer sur ce trajet — même si l'appelant n'a
  // pas passé existingBid (certains points d'entrée — carte, accueil — ne le
  // font pas). On lit le BidBloc du parent maintenant (avant le sheet : avec
  // useRootNavigator le sheet sort du BlocProvider tree). Le bid négocié
  // matérialisé (statut ACCEPTED) y figure → on grise « Faire une demande ».
  BidModel? resolvedBid = existingBid;
  if (resolvedBid == null && context.mounted) {
    try {
      resolvedBid =
          context.read<BidBloc>().state.activeBidsByAnnouncement()[announcement.id];
    } catch (_) {/* BidBloc indisponible dans ce contexte — on ignore */}
  }
  final resolvedStatus = resolvedBid?.status ?? existingBidStatus;

  // « A déjà un colis sur ce trajet » couvre tout colis en cours, demande
  // jusqu'à livraison (EN ROUTE / LIVRÉ inclus) — pas seulement en attente/accepté.
  final hasActiveBid = resolvedStatus != null &&
      MyActiveBidsLookup.ongoingBidStatuses.contains(resolvedStatus);

  DonyBottomSheet.show<void>(
    context,
    title: 'Détail du trajet',
    stickyBottom: Builder(
      builder: (innerCtx) {
        // Le viewer a déjà un colis sur ce trajet : on n'autorise pas une
        // nouvelle demande (le back la refuserait). On l'oriente vers son colis.
        if (hasActiveBid) {
          final tt = Theme.of(innerCtx).textTheme;
          final cs = Theme.of(innerCtx).colorScheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Flexible(
                      child: Text(
                        'Vous avez déjà un colis sur ce trajet',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              DonyButton(
                key: const Key('see-my-parcel-btn'),
                label: 'Voir mon colis',
                icon: Icons.inventory_2_rounded,
                onPressed: resolvedBid == null
                    ? null
                    : () {
                        Navigator.of(innerCtx, rootNavigator: true).pop();
                        if (context.mounted) {
                          context.push('/bids/${resolvedBid!.id}',
                              extra: resolvedBid);
                        }
                      },
              ),
            ],
          );
        }
        return DonyButton(
          label: 'Faire une demande',
          icon: Icons.send_rounded,
          onPressed: () async {
            final navigator = Navigator.of(innerCtx, rootNavigator: true);
            final rootCtx = navigator.context;
            navigator.pop();
            if (isKycVerified) {
              await CreateBidBottomSheet.show(rootCtx,
                  announcement: announcement);
              // Refresh silencieux du BidBloc parent pour que la liste
              // affiche immédiatement le chip "Demande en attente".
              parentBidBloc
                  ?.add(const BidMyListAutoRefreshRequested(force: true));
            } else {
              await KycStatusBottomSheet.show(rootCtx);
            }
          },
        );
      },
    ),
    child: _TravelerAnnouncementContent(announcement: announcement),
  );
}

class _TravelerAnnouncementContent extends StatelessWidget {
  const _TravelerAnnouncementContent({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr').format(announcement.departureDate);
    final categories = announcement.acceptedContentTypes ?? [];

    final totalTrips = traveler?.totalTrips ?? 0;
    final isKycVerified = traveler?.kycVerified ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voyageur — tappable pour ouvrir le profil complet (avec avis)
        InkWell(
          key: const Key('traveler-block'),
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          onTap: traveler == null
              ? null
              : () => showTravelerProfileSheet(context, traveler),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
            child: Row(
              children: [
                DonyAvatar(
                  name: traveler?.resolvedName ?? 'Voyageur',
                  size: DonyAvatarSize.lg,
                  verified: isKycVerified,
                  pro: traveler?.isProAccount ?? false,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              traveler?.resolvedName ?? 'Voyageur',
                              style: tt.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isKycVerified) ...[
                            const SizedBox(width: DonySpacing.xs),
                            const _KycVerifiedBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: cs.warning),
                          const SizedBox(width: DonySpacing.xxs),
                          Text(
                            rating != null ? '${rating.toStringAsFixed(1)}/5' : 'Nouveau',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            '· $totalTrips trajet${totalTrips > 1 ? 's' : ''}',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: DonySpacing.lg),
        Container(height: 1, color: cs.outline),
        const SizedBox(height: DonySpacing.lg),

        // Route
        Row(
          children: [
            Expanded(
              child: Text(
                announcement.departureCity,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                  Container(width: 28, height: 1.5, color: cs.primary.withValues(alpha: 0.3)),
                  Icon(Icons.flight_takeoff_rounded, size: 16, color: cs.primary),
                  Container(width: 28, height: 1.5, color: cs.primary.withValues(alpha: 0.3)),
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: DonyColors.accent, shape: BoxShape.circle)),
                ],
              ),
            ),
            Expanded(
              child: Text(
                announcement.arrivalCity,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),

        const SizedBox(height: DonySpacing.lg),

        // Détails
        _InfoRow(icon: Icons.calendar_today_outlined, label: dateStr),
        const SizedBox(height: DonySpacing.sm),
        _InfoRow(
          icon: Icons.inventory_2_outlined,
          label: '${announcement.availableKg.toStringAsFixed(0)} kg disponibles',
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoRow(
          icon: Icons.euro_rounded,
          label: announcement.pricingMode == 'MIXED'
              ? 'Grille tarifaire'
              : '${formatKgPrice(announcement.senderPricePerKg)} €/kg',
          labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
        ),

        if (announcement.pricingMode == 'MIXED' && announcement.priceGridItems.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text('Tarif par article', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: DonySpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
            child: Column(
              children: announcement.priceGridItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base, vertical: DonySpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: tt.bodyMedium),
                    Text(
                      '${item.unitPriceDisplay % 1 == 0 ? item.unitPriceDisplay.toStringAsFixed(0) : item.unitPriceDisplay.toStringAsFixed(2)} €',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],

        if (categories.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text('Types de colis acceptés', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: categories.map((c) => _CategoryChip(label: c)).toList(),
          ),
        ],

        if (announcement.description != null && announcement.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text('Message du voyageur', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: DonySpacing.sm),
          Text(announcement.description!, style: tt.bodyMedium),
        ],

        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.labelStyle});
  final IconData icon;
  final String label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            label,
            style: (tt.bodyMedium ?? const TextStyle()).merge(labelStyle),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: cs.outline),
      ),
      child: Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

class _KycVerifiedBadge extends StatelessWidget {
  const _KycVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('traveler-kyc-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 11,
            color: cs.success,
          ),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'KYC',
            style: tt.labelSmall?.copyWith(
              color: cs.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
