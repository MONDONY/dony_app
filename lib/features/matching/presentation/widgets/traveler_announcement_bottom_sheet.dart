import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/utils/map_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

/// Rend la feuille et se termine à sa fermeture.
///
/// Le `Future` sert à la route `/traveler/:announcementId`, qui doit se refermer
/// derrière la feuille pour ne pas laisser une page vide dans la pile. Les
/// autres appelants l'ignorent sans conséquence.
Future<void> showTravelerAnnouncementSheet(
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
  // Sert à masquer le blocage sur son propre trajet. Lu ici, comme le reste :
  // la feuille s'affiche hors de l'arbre de providers.
  final lecteurId = authState.currentUserId;
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

  // `useRootNavigator: true` place la feuille hors de l'arbre de providers :
  // le cubit doit être capturé ici et réinjecté par `wrapper`, sinon le cœur
  // des favoris ne trouverait rien à lire.
  FavoriteIdsCubit? favoris;
  try {
    favoris = context.read<FavoriteIdsCubit>();
  } catch (_) {
    /* Absent de ce contexte (tests, points d'entrée isolés) : pas de cœur. */
  }

  return DonyBottomSheet.show<void>(
    context,
    title: 'Détail du trajet',
    wrapper: favoris == null
        ? null
        : (child) => BlocProvider<FavoriteIdsCubit>.value(
            value: favoris!,
            child: child,
          ),
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

        final tt = Theme.of(innerCtx).textTheme;
        final cs = Theme.of(innerCtx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: 'Faire une demande',
              iconAsset: 'send',
              onPressed: () => openCreateBid(negotiation: false),
            ),
            // Entrée de négociation reléguée en lien : un seul CTA dominant
            // (redesign « Corridor héro »). Réservée aux trajets ouverts aux
            // propositions : sur un prix ferme, il n'y aurait rien à proposer.
            if (announcement.negotiable)
              InkWell(
                key: const Key('negotiate-price-btn'),
                borderRadius: BorderRadius.circular(DonyRadius.sm),
                onTap: () => openCreateBid(negotiation: true),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Trajet négociable · ',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Proposer un prix',
                        style: tt.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
    child: _TravelerAnnouncementContent(
      announcement: announcement,
      avecFavori: favoris != null,
      lecteurId: lecteurId,
    ),
  );
}

class _TravelerAnnouncementContent extends StatelessWidget {
  const _TravelerAnnouncementContent({
    required this.announcement,
    this.avecFavori = false,
    this.lecteurId,
  });

  /// Identifiant du lecteur, pour ne pas lui proposer de se bloquer lui-même.
  final String? lecteurId;

  /// Le voyageur du trajet, sauf s'il s'agit du lecteur lui-même.
  TravelerProfile? get _voyageurBloquable {
    final voyageur = announcement.traveler;
    if (voyageur == null) return null;
    final estSien =
        lecteurId != null &&
        (lecteurId == announcement.travelerId || lecteurId == voyageur.id);
    return estSien ? null : voyageur;
  }

  /// Faux quand le point d'ouverture n'a pas de `FavoriteIdsCubit` : un
  /// `BlocBuilder` sans provider **lève**, il ne se contente pas de ne rien
  /// afficher.
  final bool avecFavori;

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final categories = announcement.acceptedContentTypes ?? [];
    final hasGrid =
        announcement.pricingMode == 'MIXED' &&
        announcement.priceGridItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (avecFavori)
          _HeroWithFavorite(announcement: announcement)
        else
          _HeroCorridorCard(announcement: announcement),
        const SizedBox(height: DonySpacing.md),
        _StatCardsRow(announcement: announcement, hasGrid: hasGrid),
        if (hasGrid) ...[
          const SizedBox(height: DonySpacing.md),
          _PriceGridCard(
            items: announcement.priceGridItems,
            currency: announcement.currency,
            convertedCurrency: announcement.convertedCurrency,
          ),
        ],
        const SizedBox(height: DonySpacing.md),
        _TravelerCard(announcement: announcement),
        if (announcement.pickupAddress != null ||
            announcement.deliveryAddress != null) ...[
          const SizedBox(height: DonySpacing.md),
          _LocationsCard(announcement: announcement),
        ],

        if (announcement.acceptedPaymentMethods.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Paiements acceptés',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.xs + 2,
            runSpacing: DonySpacing.xs,
            children: [
              for (final m in announcement.acceptedPaymentMethods)
                _PaymentChip(method: m),
            ],
          ),
          // Avertissement porté jusqu'ici par le seul écran « Détail annonce ».
          // Il ne relève pas de la présentation : un trajet payé de la main à
          // la main sort du séquestre, donc de toute garantie de remboursement.
          if (announcement.acceptedPaymentMethods.length == 1 &&
              announcement.acceptedPaymentMethods.contains(
                BidPaymentMethod.cash,
              )) ...[
            const SizedBox(height: DonySpacing.md),
            DonyStatusBanner(
              type: DonyStatusBannerType.warning,
              iconAsset: 'triangle-alert',
              messageSpan: TextSpan(
                children: [
                  TextSpan(
                    text: 'Trajet en espèces uniquement. ',
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        'Le paiement se fait en main propre au voyageur, '
                        'Yadony ne séquestre pas votre argent et ne peut pas '
                        'le rembourser automatiquement en cas de litige.',
                  ),
                ],
              ),
            ),
          ],
        ],

        if (announcement.arrivalInstructions != null &&
            announcement.arrivalInstructions!.trim().isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          _InstructionsCard(text: announcement.arrivalInstructions!.trim()),
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

        // Le blocage vivait sur l'écran « Détail annonce », supprimé au profit
        // de cette feuille. Sans ce report, un des points d'entrée du blocage
        // disparaîtrait. Masqué sur son propre trajet : on ne se bloque pas.
        if (_voyageurBloquable != null)
          Center(
            child: InkWell(
              key: const Key('block-traveler-link'),
              borderRadius: BorderRadius.circular(DonyRadius.sm),
              onTap: () => showBlockMenu(
                context,
                userId: _voyageurBloquable!.id,
                displayName: _voyageurBloquable!.resolvedName,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyIcon('ban', size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      'Bloquer ce voyageur',
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

/// Carte héro navy du corridor — même dégradé que la carte du détail
/// propriétaire ([AnnouncementDetailBody]) pour garder un seul langage visuel
/// entre les deux faces du trajet.
/// Carte héro surmontée du cœur des favoris.
///
/// Le cœur vivait dans la barre de titre de l'écran « Détail annonce ». Cet
/// écran disparaît au profit de cette feuille : sans ce report, une annonce
/// ouverte depuis une notification ne pourrait plus être mise en favori.
class _HeroWithFavorite extends StatelessWidget {
  const _HeroWithFavorite({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final hero = _HeroCorridorCard(announcement: announcement);

    // N'est monté que lorsque le cubit existe : le point d'entrée sans favoris
    // rend `_HeroCorridorCard` directement.
    return BlocBuilder<FavoriteIdsCubit, FavoriteIdsState>(
      builder: (context, state) {
        final estFavori = state.tripIds.contains(announcement.id);
        return Stack(
          children: [
            hero,
            Positioned(
              top: DonySpacing.xs,
              right: DonySpacing.xs,
              child: FavoriteHeartButton(
                isFavorite: estFavori,
                onToggle: () =>
                    unawaited(_basculerFavori(context, announcement.id)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _basculerFavori(BuildContext context, String id) async {
    final cubit = context.read<FavoriteIdsCubit>();
    try {
      await cubit.toggleTrip(id);
      if (!context.mounted) return;
      final desormaisFavori = cubit.isTripFav(id);
      DonySnackbar.show(
        context,
        message: desormaisFavori
            ? 'Trajet ajouté aux favoris'
            : 'Trajet retiré des favoris',
        type: desormaisFavori
            ? DonySnackbarType.success
            : DonySnackbarType.info,
      );
    } catch (_) {
      if (!context.mounted) return;
      DonySnackbar.show(
        context,
        message: 'Impossible de modifier les favoris',
        type: DonySnackbarType.error,
      );
    }
  }
}

class _HeroCorridorCard extends StatelessWidget {
  const _HeroCorridorCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dateStr = DateFormat(
      'EEE d MMM yyyy',
      'fr',
    ).format(announcement.departureDate);
    final kgLabel = announcement.isKgFree
        ? 'Kg libre'
        : '${announcement.availableKg.toStringAsFixed(0)} kg dispo';
    final transportLabel = announcement.transportMode?.label;
    final depTime = announcement.departureTime;
    final arrTime = announcement.arrivalTime;
    final hoursLabel = (depTime != null && arrTime != null)
        ? '$depTime → $arrTime'
        : null;

    final cityStyle = tt.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 21,
      color: Colors.white,
    );

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0C4A6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAJET',
            style: tt.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              Flexible(
                child: Text(
                  announcement.departureCity,
                  style: cityStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: DonySpacing.sm),
                child: DonyIcon(
                  'arrow-right',
                  size: 18,
                  color: DonyColors.blue300,
                ),
              ),
              Flexible(
                child: Text(
                  announcement.arrivalCity,
                  style: cityStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm + DonySpacing.xxs),
          Wrap(
            spacing: DonySpacing.xs + 2,
            runSpacing: DonySpacing.xs,
            children: [
              _HeroChip(label: dateStr),
              if (transportLabel != null) _HeroChip(label: transportLabel),
              if (hoursLabel != null) _HeroChip(label: hoursLabel),
              _HeroChip(label: kgLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm + DonySpacing.xxs,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(label, style: tt.labelMedium?.copyWith(color: Colors.white)),
    );
  }
}

/// Rangée des chiffres forts : prix (ou grille) à gauche, date limite de dépôt
/// à droite. Sans date limite, la carte prix prend toute la largeur.
class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({required this.announcement, required this.hasGrid});

  final AnnouncementModel announcement;
  final bool hasGrid;

  @override
  Widget build(BuildContext context) {
    final deadline = announcement.handoverDeadline?.toLocal();
    // IntrinsicHeight : égalise la hauteur des deux cartes sans stretch
    // non borné (la colonne parente est dans un scrollable).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: hasGrid
                ? _GridStatCard(
                    items: announcement.priceGridItems,
                    currency: announcement.currency,
                  )
                : _PriceStatCard(announcement: announcement),
          ),
          if (deadline != null) ...[
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _StatCard(
                value: DateFormat('EEE d MMM', 'fr').format(deadline),
                label: 'date limite de dépôt',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.valueColor,
    this.subtitle,
  });

  final String value;
  final String label;
  final Color? valueColor;

  /// Ligne discrète sous la valeur (équivalent « environ » multidevise).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              color: valueColor ?? cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _PriceStatCard extends StatelessWidget {
  const _PriceStatCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Garde sur hasKgPrice (valeur > 0), pas sur la seule nullité :
    // senderPricePerKg n'est en pratique jamais null (pricePerKgDisplay
    // toujours servi), 0 est la vraie valeur trompeuse en mode MIXED.
    if (!announcement.hasKgPrice) {
      return const _StatCard(value: '—', label: 'Prix indisponible');
    }
    return _StatCard(
      value: formatPriceIn(
        announcement.senderPricePerKg!,
        announcement.currency,
      ),
      // Repère « environ » du même montant (brut expéditeur) dans la devise du
      // lecteur, servi par le détail depuis le lot 5.
      subtitle:
          announcement.pricePerKgDisplayConverted != null &&
              announcement.convertedCurrency != null
          ? 'environ ${formatPriceIn(announcement.pricePerKgDisplayConverted!, announcement.convertedCurrency)}/kg'
          : null,
      label: 'par kilo',
      valueColor: cs.primary,
    );
  }
}

/// Carte compacte annonçant la grille tarifaire, avec le nombre d'articles et
/// le prix d'appel le plus bas — le détail vit dans [_PriceGridCard].
class _GridStatCard extends StatelessWidget {
  const _GridStatCard({required this.items, required this.currency});

  final List<AnnouncementGridItemModel> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final minPrice = items
        .map((i) => i.unitPriceDisplay)
        .reduce((a, b) => a < b ? a : b);
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.blue200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DonyIcon('layout-grid', size: 16, color: cs.primary),
              const SizedBox(width: DonySpacing.xs + 2),
              Flexible(
                child: Text(
                  'Grille tarifaire',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: cs.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xxs),
          Text(
            '${items.length} article${items.length > 1 ? 's' : ''} · '
            'dès ${formatPriceIn(minPrice, currency)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Liste « Tarif par article », plafonnée à [_collapsedCount] lignes : au-delà,
/// un pied « Voir tous les tarifs (N) » déplie le reste sur place pour que la
/// grille ne repousse pas le voyageur et le CTA hors du premier regard.
class _PriceGridCard extends StatefulWidget {
  const _PriceGridCard({
    required this.items,
    required this.currency,
    this.convertedCurrency,
  });

  /// Devise du lecteur pour les équivalents « environ » des items (lot 5).
  final String? convertedCurrency;

  final List<AnnouncementGridItemModel> items;
  final String currency;

  @override
  State<_PriceGridCard> createState() => _PriceGridCardState();
}

class _PriceGridCardState extends State<_PriceGridCard> {
  static const _collapsedCount = 4;

  /// Dépliage purement éphémère — ValueNotifier plutôt que setState pour ne
  /// reconstruire que la liste, pas la carte entière.
  final ValueNotifier<bool> _expanded = ValueNotifier(false);

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.md,
              DonySpacing.md,
              DonySpacing.md,
              DonySpacing.sm,
            ),
            child: Text(
              'Tarif par article',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _expanded,
            builder: (context, expanded, _) {
              final showAll =
                  expanded || widget.items.length <= _collapsedCount;
              final visible = showAll
                  ? widget.items
                  : widget.items.take(_collapsedCount).toList();
              return AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.md,
                          ),
                          color: cs.surfaceContainerHighest,
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.md,
                          vertical: DonySpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                visible[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: DonySpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatPriceIn(
                                    visible[i].unitPriceDisplay,
                                    widget.currency,
                                  ),
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                                // Équivalent « environ » (lot 5), serveur.
                                if (visible[i].convertedUnitPriceDisplay !=
                                        null &&
                                    widget.convertedCurrency != null)
                                  Text(
                                    'environ ${formatPriceIn(visible[i].convertedUnitPriceDisplay!, widget.convertedCurrency)}',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!showAll)
                      InkWell(
                        key: const Key('price-grid-expand'),
                        onTap: () => _expanded.value = true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            border: Border(top: BorderSide(color: cs.outline)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Voir tous les tarifs (${widget.items.length})',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: DonySpacing.xs),
                              DonyIcon(
                                'chevron-down',
                                size: 14,
                                color: cs.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Lieux de remise et de récupération du colis — mêmes libellés que la page
/// web publique du trajet, masqués individuellement quand l'annonce (legacy)
/// ne porte pas l'adresse.
class _LocationsCard extends StatelessWidget {
  const _LocationsCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pickup = announcement.pickupAddress;
    final delivery = announcement.deliveryAddress;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pickup != null && delivery != null)
            _RouteMiniMap(pickup: pickup, delivery: delivery),
          if (pickup != null)
            _LocationRow(
              key: const Key('location-pickup'),
              iconAsset: 'upload',
              iconColor: cs.primary,
              iconBackground: cs.primaryContainer,
              title: 'Remise du colis',
              address: pickup,
            ),
          if (pickup != null && delivery != null)
            Divider(height: 1, color: cs.surfaceContainerHighest),
          if (delivery != null)
            _LocationRow(
              key: const Key('location-delivery'),
              iconAsset: 'download',
              iconColor: DonyColors.accent,
              iconBackground: DonyColors.accentSoft,
              title: 'Récupération',
              address: delivery,
            ),
        ],
      ),
    );
  }
}

/// Une ligne d'adresse entièrement tappable : ouvre le point dans l'app de
/// carte native (Plans sur iOS, Google Maps sur Android). Le badge
/// « Itinéraire » signale l'affordance sans laisser croire à un lien web.
class _LocationRow extends StatelessWidget {
  const _LocationRow({
    super.key,
    required this.iconAsset,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.address,
  });

  final String iconAsset;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final AddressData address;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => unawaited(
        openInMaps(
          getIt<ExternalUrlLauncher>(),
          lat: address.lat,
          lng: address.lng,
          label: address.label,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.md),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(DonyRadius.sm),
              ),
              alignment: Alignment.center,
              child: DonyIcon(iconAsset, size: 14, color: iconColor),
            ),
            const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(address.label, style: tt.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonyIcon('map-pin', size: 13, color: cs.primary),
                const SizedBox(width: DonySpacing.xxs),
                Text(
                  'Itinéraire',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-carte non interactive de l'itinéraire (remise → récupération), en tête
/// de la card Lieux. Tap = ouvre la carte native centrée sur la remise. En
/// `liteMode` sur Android (bitmap léger) ; sur iOS, une carte figée (tous les
/// gestes désactivés). Un `GestureDetector` par-dessus capte le tap partout.
class _RouteMiniMap extends StatelessWidget {
  const _RouteMiniMap({required this.pickup, required this.delivery});

  final AddressData pickup;
  final AddressData delivery;

  @override
  Widget build(BuildContext context) {
    final swLat = pickup.lat < delivery.lat ? pickup.lat : delivery.lat;
    final swLng = pickup.lng < delivery.lng ? pickup.lng : delivery.lng;
    final neLat = pickup.lat > delivery.lat ? pickup.lat : delivery.lat;
    final neLng = pickup.lng > delivery.lng ? pickup.lng : delivery.lng;

    return SizedBox(
      height: 130,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (pickup.lat + delivery.lat) / 2,
                (pickup.lng + delivery.lng) / 2,
              ),
              zoom: 2,
            ),
            liteModeEnabled: true,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            // Carte figée : le tap est géré par le GestureDetector au-dessus.
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: LatLng(pickup.lat, pickup.lng),
              ),
              Marker(
                markerId: const MarkerId('delivery'),
                position: LatLng(delivery.lat, delivery.lng),
              ),
            },
            onMapCreated: (c) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                c.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(swLat, swLng),
                      northeast: LatLng(neLat, neLng),
                    ),
                    40,
                  ),
                );
              });
            },
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(
                openInMaps(
                  getIt<ExternalUrlLauncher>(),
                  lat: pickup.lat,
                  lng: pickup.lng,
                  label: pickup.label,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip d'un moyen de paiement accepté (espèces / carte).
class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.method});

  final BidPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isCash = method == BidPaymentMethod.cash;
    final label = isCash ? 'Espèces' : 'Carte';
    final icon = isCash ? 'banknote' : 'credit-card';
    final fg = isCash ? cs.success : cs.primary;
    final bg = isCash ? cs.successLight : cs.primaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm + DonySpacing.xxs,
        vertical: DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(icon, size: 13, color: fg),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encart « Instructions du voyageur » (consignes de retrait), ton neutre.
class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceWarm,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('info', size: 16, color: cs.warning),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions du voyageur',
                  style: tt.labelMedium?.copyWith(color: cs.warning),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(text, style: tt.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte voyageur compacte — tappable pour ouvrir le profil public complet.
class _TravelerCard extends StatelessWidget {
  const _TravelerCard({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final totalTrips = traveler?.totalTrips ?? 0;
    final isKycVerified = traveler?.kycVerified ?? false;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: InkWell(
        key: const Key('traveler-block'),
        borderRadius: BorderRadius.circular(DonyRadius.card),
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
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Row(
            children: [
              DonyAvatar(
                name: traveler?.resolvedName ?? 'Voyageur',
                imageUrl: traveler?.avatarUrl,
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
