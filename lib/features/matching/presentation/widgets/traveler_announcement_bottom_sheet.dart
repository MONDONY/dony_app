import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
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
  // currentUser couvre AuthAuthenticated ET AuthProfileUpdated (émis après
  // upload avatar / édition profil) — sinon le KYC repasserait à false.
  final isKycVerified = authState.currentUser?.isKycVerified ?? false;
  // Un expéditeur non vérifié peut quand même écrire à un voyageur qui a
  // désactivé « profils vérifiés uniquement » : sans cette exception, le réglage
  // du voyageur resterait sans effet, le client barrant la route avant l'appel.
  // Le serveur reste l'autorité (403 contact-kyc-required s'il s'est ravisé).
  final canSendRequest =
      isKycVerified || (announcement.traveler?.acceptsUnverified ?? false);
  // Capture la référence au BidBloc du parent (carousel / liste) pour pouvoir
  // déclencher un refresh après la fermeture de CreateBidBottomSheet, même
  // quand useRootNavigator: true sort du BlocProvider tree.
  final BidBloc? parentBidBloc = context.mounted
      ? context.read<BidBloc>()
      : null;

  // Détecte un colis existant du viewer sur ce trajet — même si l'appelant n'a
  // pas passé existingBid (certains points d'entrée — carte, accueil — ne le
  // font pas). On lit le BidBloc du parent maintenant (avant le sheet : avec
  // useRootNavigator le sheet sort du BlocProvider tree). Le bid négocié
  // matérialisé (statut ACCEPTED) y figure → on grise « Faire une demande ».
  BidModel? resolvedBid = existingBid;
  if (resolvedBid == null && context.mounted) {
    try {
      resolvedBid = context
          .read<BidBloc>()
          .state
          .activeBidsByAnnouncement()[announcement.id];
    } catch (_) {
      /* BidBloc indisponible dans ce contexte — on ignore */
    }
  }
  final resolvedStatus = resolvedBid?.status ?? existingBidStatus;

  // « A déjà un colis sur ce trajet » couvre tout colis en cours, demande
  // jusqu'à livraison (EN ROUTE / LIVRÉ inclus) — pas seulement en attente/accepté.
  final hasActiveBid =
      resolvedStatus != null &&
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
                    DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Flexible(
                      child: Text(
                        'Vous avez déjà un colis sur ce trajet',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DonyButton(
                key: const Key('see-my-parcel-btn'),
                label: 'Voir mon colis',
                iconAsset: 'package',
                onPressed: resolvedBid == null
                    ? null
                    : () {
                        Navigator.of(innerCtx, rootNavigator: true).pop();
                        if (context.mounted) {
                          context.push(
                            '/bids/${resolvedBid!.id}',
                            extra: resolvedBid,
                          );
                        }
                      },
              ),
            ],
          );
        }
        Future<void> openCreateBid({required bool negotiation}) async {
          final navigator = Navigator.of(innerCtx, rootNavigator: true);
          final rootCtx = navigator.context;
          navigator.pop();
          if (authState.currentUser == null) {
            await AuthRequiredSheet.show(
              rootCtx,
              reason: AuthRequiredReason.offer,
            );
            return;
          }
          if (canSendRequest) {
            await CreateBidBottomSheet.show(
              rootCtx,
              announcement: announcement,
              negotiation: negotiation,
            );
            // Refresh silencieux du BidBloc parent pour que la liste
            // affiche immédiatement le chip "Demande en attente".
            parentBidBloc?.add(
              const BidMyListAutoRefreshRequested(force: true),
            );
          } else {
            await KycStatusBottomSheet.show(rootCtx);
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: 'Faire une demande',
              iconAsset: 'send',
              onPressed: () => openCreateBid(negotiation: false),
            ),
            // Second CTA réservé aux trajets ouverts aux propositions : sur un
            // prix ferme, il n'aurait rien à proposer.
            if (announcement.negotiable) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('negotiate-price-btn'),
                label: 'Proposer un prix',
                iconAsset: 'handshake',
                variant: DonyButtonVariant.secondary,
                onPressed: () => openCreateBid(negotiation: true),
              ),
            ],
          ],
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
    final dateStr = DateFormat(
      'EEEE d MMMM yyyy',
      'fr',
    ).format(announcement.departureDate);
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
              : () => context.push(
                  '/profile/public',
                  extra: ProfilePublicArgs(
                    userId: traveler.id,
                    showSubscribe: true,
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
            child: Row(
              children: [
                DonyAvatar(
                  name: traveler?.resolvedName ?? 'Voyageur',
                  imageUrl: traveler?.avatarUrl,
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
                          DonyIcon('star', size: 14, color: cs.warning),
                          const SizedBox(width: DonySpacing.xxs),
                          Text(
                            rating != null
                                ? '${rating.toStringAsFixed(1)}/5'
                                : 'Nouveau',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            '· $totalTrips trajet${totalTrips > 1 ? 's' : ''}',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
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
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 1.5,
                    color: cs.primary.withValues(alpha: 0.3),
                  ),
                  const DonyEmoji.planeTakeoff(),
                  Container(
                    width: 28,
                    height: 1.5,
                    color: cs.primary.withValues(alpha: 0.3),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: DonyColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
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
        _InfoRow(iconAsset: 'calendar', label: dateStr),
        const SizedBox(height: DonySpacing.sm),
        _InfoRow(
          iconAsset: 'package',
          label: announcement.isKgFree
              ? 'Kg libre'
              : '${announcement.availableKg.toStringAsFixed(0)} kg disponibles',
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoRow(
          iconAsset: 'euro',
          // Garde sur hasKgPrice (valeur > 0), pas sur la seule nullité :
          // senderPricePerKg n'est en pratique jamais null (pricePerKgDisplay
          // toujours servi), 0 est la vraie valeur trompeuse en mode MIXED.
          label: announcement.pricingMode == 'MIXED'
              ? 'Grille tarifaire'
              : !announcement.hasKgPrice
              ? 'Prix indisponible'
              : '${formatPriceIn(announcement.senderPricePerKg!, announcement.currency)}/kg',
          labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
        ),

        if (announcement.handoverDeadline != null) ...[
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(
            iconAsset: 'calendar',
            label:
                'Dépôt des colis '
                '${_handoverDeadlineLabel(announcement.handoverDeadline!.toLocal())}',
          ),
        ],

        if (announcement.pricingMode == 'MIXED' &&
            announcement.priceGridItems.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Tarif par article',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
            child: Column(
              children: announcement.priceGridItems
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          Text(
                            formatPriceIn(
                              item.unitPriceDisplay,
                              announcement.currency,
                            ),
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],

        if (categories.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Types de colis acceptés',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: categories.map((c) => _CategoryChip(label: c)).toList(),
          ),
        ],

        if (announcement.description != null &&
            announcement.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Message du voyageur',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(announcement.description!, style: tt.bodyMedium),
        ],

        const SizedBox(height: DonySpacing.lg),
        Center(
          child: InkWell(
            key: const Key('report-announcement-link'),
            borderRadius: BorderRadius.circular(DonyRadius.sm),
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.push(
                '/settings/report-incident',
                extra: {
                  'targetType': IncidentTargetType.announcement,
                  'targetId': announcement.id,
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm,
                vertical: DonySpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon('flag', size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    'Signaler ce trajet',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

/// Formate la plage de remise. Même jour → « date heure → heure » ;
/// jours différents → « date heure → date heure » (la date de fin est affichée
/// quand elle diffère, car la fenêtre peut s'étaler sur plusieurs jours).
String _handoverDeadlineLabel(DateTime deadline) {
  return 'jusqu\'au ${DateFormat('EEE d MMM', 'fr').format(deadline)}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.iconAsset,
    required this.label,
    this.labelStyle,
  });
  final String iconAsset;
  final String label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 16, color: cs.onSurfaceVariant),
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
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
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
          DonyIcon('badge-check', size: 11, color: cs.success),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'Identité',
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
