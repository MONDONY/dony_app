import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/widgets/request_owner_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Corps commun à `PackageRequestDetailScreen` (plein écran) et
/// `PackageRequestDetailBottomSheet` (chemin principal, ouvert depuis la
/// liste). Les deux enveloppes ne diffèrent que par leur chrome (AppBar vs
/// handle de sheet) — le contenu métier vit ici pour ne pas être écrit deux fois.
class PackageRequestDetailBody extends StatelessWidget {
  const PackageRequestDetailBody({
    super.key,
    required this.request,
    required this.threads,
    required this.actionInFlight,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onCancel,
  });

  final PackageRequest request;
  final List<NegotiationThread> threads;
  final bool actionInFlight;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(request: request, threadsCount: threads.length),
            const SizedBox(height: DonySpacing.base),
            IgnorePointer(
              ignoring: actionInFlight,
              child: Opacity(
                opacity: actionInFlight ? 0.5 : 1,
                child: RequestOwnerActionGrid(
                  request: request,
                  hasOffers: threads.isNotEmpty,
                  onEdit: onEdit,
                  onPublish: onPublish,
                  onUnpublish: onUnpublish,
                  onCancel: onCancel,
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.xl),
            _OffersSection(threads: threads, request: request),
          ],
        )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.request, required this.threadsCount});
  final PackageRequest request;
  final int threadsCount;

  @override
  Widget build(BuildContext context) {
    final publishedAt = DateFormat('HH:mm').format(request.createdAt);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2540), Color(0xFF1A3A6B)],
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: [
          BoxShadow(
            color: DonyColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glow bleu top-right
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: DonyColors.primary.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route
                Text(
                  '${request.departureCity} → ${request.arrivalCity}',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                // Détails
                Text(
                  _buildDetails(request),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                // Bottom row : badge offres + heure publication
                Row(
                  children: [
                    if (threadsCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DonyColors.primary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(DonyRadius.full),
                          border: Border.all(
                            color: DonyColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$threadsCount OFFRE${threadsCount > 1 ? 'S' : ''}',
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(DonyRadius.full),
                        ),
                        child: Text(
                          'En attente d\'offres…',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'publié à $publishedAt',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offers section ────────────────────────────────────────────────────────────

class _OffersSection extends StatelessWidget {
  const _OffersSection({required this.threads, required this.request});
  final List<NegotiationThread> threads;
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    // For firm-price (non-negotiable) requests, show candidates selection UI.
    if (!request.negotiable) {
      return CandidatesSection(request: request, threads: threads);
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (threads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(DonySpacing.xl),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: DonyColors.primarySoft,
                borderRadius: BorderRadius.circular(DonyRadius.lg),
              ),
              child: const Center(child: DonyEmoji.parcel(size: 26)),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucune offre pour l\'instant',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Tu seras notifié dès qu\'un voyageur fait une offre.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section
        Row(
          children: [
            Text(
              'OFFRES REÇUES',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: DonyColors.primarySoft,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Text(
                '${threads.length}',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.base),
        ...threads.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm + 4),
            child: _OfferTile(
              thread: t,
              isPrimary: i == 0,
            ).animate().fadeIn(duration: 200.ms, delay: (60 * i).ms),
          );
        }),
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.thread, required this.isPrimary});
  final NegotiationThread thread;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = thread.travelerName ?? 'Voyageur';
    final rating = thread.travelerRating;
    final date = DateFormat('d MMM', 'fr').format(thread.travelerTravelDate);

    return InkWell(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      onTap: () => context.push('/negotiations/${thread.id}'),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: isPrimary ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: isPrimary
                ? cs.primary.withValues(alpha: 0.25)
                : cs.outline,
          ),
        ),
        child: Row(
          children: [
            DonyAvatar(
              name: name,
              imageUrl: thread.travelerPhotoUrl,
              size: DonyAvatarSize.md,
              verified: (thread.travelerTripsCount ?? 0) > 0,
            ),
            const SizedBox(width: DonySpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(width: 4),
                        const DonyIcon(
                          'star',
                          size: 13,
                          color: DonyColors.warning500,
                        ),
                        Text(
                          rating.toStringAsFixed(1),
                          style: tt.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              // L'expéditeur voit TOUJOURS le prix qu'il paie (net + commission
              // = gross), montant exact — jamais le net touché par le voyageur.
              PriceDisplay.eur(
                thread.grossPriceEur ??
                    PriceDisplay.grossFromNet(thread.currentPriceEur),
              ),
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: cs.primary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Candidates section (prix ferme — non-negotiable) ─────────────────────────

/// Public widget testable: shown for firm-price (negotiable=false) requests.
/// Displays OPEN-status threads as candidate cards with a "Choisir" CTA.
class CandidatesSection extends StatelessWidget {
  const CandidatesSection({
    required this.request,
    required this.threads,
    super.key,
  });

  final PackageRequest request;
  final List<NegotiationThread> threads;

  @override
  Widget build(BuildContext context) {
    if (!request.negotiable) {
      // Candidats encore en lice (le voyageur a pris le prix ferme → OPEN).
      final openThreads = threads
          .where((t) => t.status == NegotiationThreadStatus.open)
          .toList();
      // Offre déjà choisie : le thread est passé en AWAITING_TRIP / AWAITING_PAYMENT.
      // Tant qu'elle n'est pas payée, elle doit RESTER visible ici pour que
      // l'expéditeur la finalise — sinon l'offre disparaît de « Ma demande ».
      final chosen = threads
          .where(
            (t) =>
                t.status == NegotiationThreadStatus.awaitingTrip ||
                t.status == NegotiationThreadStatus.awaitingPayment,
          )
          .toList();

      // Une fois un voyageur choisi, on n'affiche que l'offre en cours à finaliser.
      final visible = chosen.isNotEmpty ? chosen : openThreads;
      final showingChosen = chosen.isNotEmpty;

      if (visible.isEmpty) return const SizedBox.shrink();

      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Text(
                showingChosen ? 'OFFRE ACCEPTÉE' : 'VOYAGEURS INTÉRESSÉS',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: DonyColors.primarySoft,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  '${visible.length}',
                  style: tt.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: DonyColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          // Candidate cards
          ...visible.asMap().entries.map((entry) {
            final i = entry.key;
            final thread = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm + 4),
              child: _CandidateCard(
                thread: thread,
                // OPEN → « Choisir » (sélection) ; offre déjà choisie → « Finaliser »
                // (le thread est en AWAITING_TRIP/PAYMENT, l'expéditeur doit payer).
                ctaLabel: showingChosen ? 'Finaliser' : 'Choisir',
                // Ouvrir la négociation : c'est là que vit le flux complet
                // d'acceptation + paiement (ThreadStateCtaBar → « Accepter —
                // Tu paies X € » → complete-details → paiement avec biométrie).
                // Un « accept » direct depuis ici ne pourrait pas finaliser.
                onChoose: () => context.push('/negotiations/${thread.id}'),
              ).animate().fadeIn(duration: 200.ms, delay: (60 * i).ms),
            );
          }),
          // Disclaimer note — uniquement à l'étape de choix (candidats OPEN).
          // Une fois un voyageur choisi, plus rien à « décliner ».
          if (!showingChosen) ...[
            const SizedBox(height: DonySpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: DonyColors.warning500.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(
                  color: DonyColors.warning500.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const DonyIcon(
                    'info',
                    size: 16,
                    color: DonyColors.warning500,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      'Les autres seront déclinés automatiquement.',
                      style: tt.bodySmall?.copyWith(
                        color: DonyColors.warning500,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // For negotiable requests, render nothing from this widget
    // (_OffersSection handles it via the standard path).
    return const SizedBox.shrink();
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.thread,
    required this.onChoose,
    this.ctaLabel = 'Choisir',
  });

  final NegotiationThread thread;
  final VoidCallback onChoose;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = thread.travelerName ?? 'Voyageur';
    final rating = thread.travelerRating;
    final date = DateFormat('d MMM', 'fr').format(thread.travelerTravelDate);

    final grossPrice =
        thread.grossPriceEur ??
        PriceDisplay.grossFromNet(thread.currentPriceEur);
    final priceLabel = 'Tu paies ${PriceDisplay.eur(grossPrice)}';

    // Toute la carte est tappable et ouvre la négociation (même cible que le
    // bouton « Choisir »), comme _OfferTile pour les demandes négociables.
    return InkWell(
      key: Key('candidate-card-${thread.id}'),
      borderRadius: BorderRadius.circular(DonyRadius.md),
      onTap: onChoose,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            DonyAvatar(
              name: name,
              imageUrl: thread.travelerPhotoUrl,
              size: DonyAvatarSize.md,
              verified: (thread.travelerTripsCount ?? 0) > 0,
            ),
            const SizedBox(width: DonySpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Traveler name + rating
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(width: 4),
                        const DonyIcon(
                          'star',
                          size: 13,
                          color: DonyColors.warning500,
                        ),
                        Text(
                          rating.toStringAsFixed(1),
                          style: tt.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Travel date
                  Text(
                    date,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  // Price label
                  Text(
                    priceLabel,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            // Choose CTA
            SizedBox(
              height: 44,
              child: ElevatedButton(
                key: Key('choose-traveler-${thread.id}'),
                onPressed: onChoose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DonyColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  textStyle: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _buildDetails(PackageRequest r) {
  final date = DateFormat('d MMM', 'fr').format(r.desiredDate);
  final parts = [
    '$date ±${r.dateToleranceDays}j',
    '${r.weightKg.toStringAsFixed(0)} kg',
    if (r.categories.isNotEmpty) r.categories.first,
    if (r.targetPriceEur != null) '≈${r.targetPriceEur!.toStringAsFixed(0)} €',
  ];
  return parts.join(' · ');
}
