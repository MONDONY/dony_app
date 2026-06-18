import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PackageRequestDetailScreen extends StatefulWidget {
  const PackageRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestDetailScreen> createState() =>
      _PackageRequestDetailScreenState();
}

class _PackageRequestDetailScreenState
    extends State<PackageRequestDetailScreen> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted)
        setState(() {
          _request = r;
          _threads = threads;
        });
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await getIt<PackageRequestRepository>().cancel(widget.requestId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: DonyColors.danger500,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: 'Ma demande',
        actions: [
          IconButton(
            icon: DonyIcon('ellipsis', color: cs.onSurface, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : _request == null
          ? const SizedBox.shrink()
          : BlocProvider<NegotiationBloc>(
              create: (_) => getIt<NegotiationBloc>(),
              child: BlocListener<NegotiationBloc, NegotiationState>(
                listenWhen: (prev, curr) =>
                    curr is NegotiationLoaded && prev is! NegotiationLoaded,
                listener: (_, __) => _load(),
                child: _DetailBody(
                  request: _request!,
                  threads: _threads,
                  cancelling: _cancelling,
                  onCancel: _cancel,
                ),
              ),
            ),
    );
  }
}

// ── Detail body ───────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.request,
    required this.threads,
    required this.cancelling,
    required this.onCancel,
  });
  final PackageRequest request;
  final List<NegotiationThread> threads;
  final bool cancelling;
  final VoidCallback onCancel;

  bool get _canCancel =>
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.xl,
            DonySpacing.lg,
            MediaQuery.of(context).padding.bottom + 120,
          ),
          child:
              Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero card sombre
                      _HeroCard(request: request, threadsCount: threads.length),
                      const SizedBox(height: DonySpacing.xl),
                      // Section offres
                      _OffersSection(threads: threads, request: request),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 280.ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
        // CTA fixe en bas — seulement « Annuler » tant que la demande cherche
        // un voyageur. Une fois payée, elle vit dans l'onglet Envois.
        if (_canCancel)
          _StickyBottom(
            child: DonyButton(
              label: cancelling ? 'Annulation…' : 'Annuler la demande',
              variant: DonyButtonVariant.destructive,
              isLoading: cancelling,
              onPressed: onCancel,
            ),
          ),
      ],
    );
  }
}

class _StickyBottom extends StatelessWidget {
  const _StickyBottom({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: DonySpacing.lg,
      right: DonySpacing.lg,
      bottom: MediaQuery.of(context).padding.bottom + DonySpacing.xl,
      child: child,
    );
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
                : DonyColors.neutral200,
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
                      Text(
                        name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
                      color: DonyColors.textMuted,
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
          border: Border.all(color: DonyColors.neutral200),
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
                      color: DonyColors.textMuted,
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

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DonyIcon(
              'circle-alert',
              size: 48,
              color: DonyColors.danger500,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
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

// ── Bottom sheet detail ───────────────────────────────────────────────────────

class _SheetBtnConfig {
  const _SheetBtnConfig({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isLoading;
}

abstract final class PackageRequestDetailBottomSheet {
  static Future<void> show(BuildContext context, String requestId) {
    final btnNotifier = ValueNotifier<_SheetBtnConfig?>(null);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetFrame(
        btnNotifier: btnNotifier,
        child: _SheetBody(
          requestId: requestId,
          onBtnConfig: (cfg) => WidgetsBinding.instance.addPostFrameCallback(
            (_) => btnNotifier.value = cfg,
          ),
        ),
      ),
    ).whenComplete(btnNotifier.dispose);
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.btnNotifier, required this.child});
  final ValueNotifier<_SheetBtnConfig?> btnNotifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: DonyColors.sand100,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral300,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.sm,
              DonySpacing.base,
              0,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Ma demande', style: tt.headlineSmall)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const DonyIcon('x', size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: DonySpacing.base, color: DonyColors.neutral200),
          // Contenu scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                0,
                DonySpacing.lg,
                DonySpacing.xl + bottomInset,
              ),
              child: child,
            ),
          ),
          // Bouton sticky
          ValueListenableBuilder<_SheetBtnConfig?>(
            valueListenable: btnNotifier,
            builder: (_, config, __) {
              if (config == null) return SizedBox(height: bottomInset);
              return Container(
                decoration: BoxDecoration(
                  color: DonyColors.sand100,
                  border: const Border(
                    top: BorderSide(color: DonyColors.neutral200),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.md,
                  DonySpacing.lg,
                  bottomInset + DonySpacing.base,
                ),
                child: DonyButton(
                  label: config.label,
                  variant: config.isDestructive
                      ? DonyButtonVariant.destructive
                      : DonyButtonVariant.primary,
                  isLoading: config.isLoading,
                  onPressed: config.onPressed,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.requestId, required this.onBtnConfig});
  final String requestId;
  final void Function(_SheetBtnConfig?) onBtnConfig;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _request = r;
          _threads = threads;
        });
        _syncBtn(r, false);
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncBtn(PackageRequest r, bool cancelling) {
    final canCancel =
        r.status == PackageRequestStatus.open ||
        r.status == PackageRequestStatus.negotiating;

    if (canCancel) {
      widget.onBtnConfig(
        _SheetBtnConfig(
          label: cancelling ? 'Annulation…' : 'Annuler la demande',
          isDestructive: true,
          isLoading: cancelling,
          onPressed: _cancel,
        ),
      );
    } else {
      widget.onBtnConfig(null);
    }
  }

  Future<void> _cancel() async {
    if (_request == null) return;
    _syncBtn(_request!, true);
    try {
      await getIt<PackageRequestRepository>().cancel(widget.requestId);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: DonyColors.danger500,
          ),
        );
        _syncBtn(_request!, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final r = _request;
    if (r == null) return const SizedBox.shrink();

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(request: r, threadsCount: _threads.length),
            const SizedBox(height: DonySpacing.lg),
            _OffersSection(threads: _threads, request: r),
          ],
        )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}
