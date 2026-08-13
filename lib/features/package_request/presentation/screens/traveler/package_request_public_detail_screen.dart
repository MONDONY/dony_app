import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/package_status_chip.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_methods_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PackageRequestPublicDetailScreen extends StatefulWidget {
  const PackageRequestPublicDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestPublicDetailScreen> createState() =>
      _PackageRequestPublicDetailScreenState();
}

class _PackageRequestPublicDetailScreenState
    extends State<PackageRequestPublicDetailScreen> {
  PackageRequest? _request;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.packageRequestDetailOpened,
      ),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await getIt<PackageRequestRepository>().getById(
        widget.requestId,
      );
      if (mounted) {
        setState(() => _request = r);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _report(String reason) async {
    try {
      await getIt<PackageRequestRepository>().report(
        widget.requestId,
        reason: reason,
      );
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.packageRequestReported,
          properties: {'reason': reason},
        ),
      );
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Demande signalée. Merci.',
          type: DonySnackbarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        DonySnackbar.show(
          context,
          message: 'Impossible de signaler pour le moment',
          type: DonySnackbarType.error,
        );
      }
    }
  }

  void _showReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      builder: (sheetCtx) {
        const reasons = <(String, String)>[
          ('PROHIBITED', 'Contenu interdit'),
          ('SCAM', 'Arnaque / fraude'),
          ('INAPPROPRIATE', 'Contenu inapproprié'),
          ('OTHER', 'Autre raison'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: DonySpacing.md),
              Text(
                'Signaler la demande',
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: DonySpacing.sm),
              for (final (code, label) in reasons)
                ListTile(
                  leading: const DonyIcon('flag', size: 18),
                  title: Text(label),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _report(code);
                  },
                ),
              const SizedBox(height: DonySpacing.sm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final announcement = extra?['announcement'] as AnnouncementModel?;
    final cs = Theme.of(context).colorScheme;
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : authState is AuthProfileUpdated
        ? authState.user.id
        : null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(
        title: 'Demande d\'envoi',
        actions: [
          const DonyFeedbackButton(),
          IconButton(
            tooltip: 'Signaler',
            icon: const DonyIcon('flag', size: 20),
            onPressed: _showReportSheet,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(fontSize: 14, color: kError),
                ),
              ),
            )
          : _request == null
          ? const SizedBox.shrink()
          : PackageRequestPublicDetailBody(
              request: _request!,
              announcement: announcement,
              currentUserId: currentUserId,
              onChanged: _load,
            ),
    );
  }
}

/// Extracted body widget — accepts a [PackageRequest] directly so it is
/// independently testable without DI or GoRouter setup.
class PackageRequestPublicDetailBody extends StatelessWidget {
  const PackageRequestPublicDetailBody({
    super.key,
    required this.request,
    this.announcement,
    this.currentUserId,
    this.onChanged,
  });

  final PackageRequest request;
  final AnnouncementModel? announcement;

  /// UID backend de l'utilisateur courant — sert à détecter le propriétaire
  /// de la demande (`currentUserId == request.senderId`). Null si non connecté.
  final String? currentUserId;

  /// Appelé après une action propriétaire (édition de la demande ou retour
  /// depuis l'écran « Offres reçues ») pour rafraîchir le détail.
  final VoidCallback? onChanged;

  String get _sizeLabel => switch (request.parcelSize.name.toUpperCase()) {
    'SMALL' => 'S',
    'MEDIUM' => 'M',
    'LARGE' => 'L',
    _ => request.parcelSize.name.toUpperCase(),
  };

  String get _parcelHint => switch (request.parcelSize.name.toUpperCase()) {
    'SMALL' => 'Sac',
    'MEDIUM' => 'Carton',
    'LARGE' => 'Valise',
    _ => 'Taille',
  };

  @override
  Widget build(BuildContext context) {
    final r = request;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final depFlag = cityFlag(r.departureCity);
    final arrFlag = cityFlag(r.arrivalCity);
    // Le modèle de détail n'expose pas de champ `urgent` (backend ne l'envoie
    // pas ici) — repli local sur le seuil d'urgence, comme documenté dans
    // dony_urgency.dart.
    final isUrgent = isUrgentDate(r.desiredDate);
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.lg,
            MediaQuery.of(context).padding.bottom + 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photos colis (carousel) ──────────────────────────────────
              if (r.photoUrls.isNotEmpty) ...[
                _PhotoCarousel(urls: r.photoUrls),
                const SizedBox(height: DonySpacing.base),
              ],

              // ── Identité demande + statut ────────────────────────────────
              Row(
                children: [
                  DonyIcon('package', size: 14, color: cs.warning),
                  const SizedBox(width: DonySpacing.xxs),
                  Flexible(
                    child: Text(
                      'DEMANDE D\'ENVOI',
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: cs.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  if (!r.negotiable) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DonyIcon(
                            'lock',
                            size: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: DonySpacing.xxs),
                          Text(
                            'PRIX FERME',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.xs),
                  ],
                  packageStatusChip(context, r.status),
                  if (isUrgent) ...[
                    const SizedBox(width: DonySpacing.xs),
                    const DonyUrgentBadge(),
                  ],
                ],
              ),
              const SizedBox(height: DonySpacing.sm),

              // ── Titre corridor ───────────────────────────────────────────
              Text(
                '${depFlag != null ? '$depFlag ' : ''}${r.departureCity} → '
                '${r.arrivalCity}${arrFlag != null ? ' $arrFlag' : ''}',
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.flight_rounded,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      'le ${r.desiredDate.day}/${r.desiredDate.month}/${r.desiredDate.year} '
                      '(±${r.dateToleranceDays}j)',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.base),

              // ── Poids / Taille (tuiles) ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: 'scale',
                      value:
                          '${r.weightKg.toStringAsFixed(r.weightKg % 1 == 0 ? 0 : 1)} kg',
                      label: 'Poids',
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: _StatTile(
                      icon: 'package',
                      value: _sizeLabel,
                      label: _parcelHint,
                    ),
                  ),
                ],
              ),

              // ── Catégories (chips) ───────────────────────────────────────
              if (r.categories.isNotEmpty) ...[
                const SizedBox(height: DonySpacing.md),
                Text(
                  'CATÉGORIES',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Wrap(
                  spacing: DonySpacing.sm,
                  runSpacing: DonySpacing.sm,
                  children: [
                    for (final cat in r.categories) _CategoryChip(label: cat),
                  ],
                ),
              ],

              // ── Description ──────────────────────────────────────────────
              if (r.description != null && r.description!.isNotEmpty) ...[
                const SizedBox(height: DonySpacing.md),
                _detailCard(context, 'Description', [
                  Text(
                    r.description!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.5,
                    ),
                  ),
                ]),
              ],

              if (r.targetPriceEur != null) ...[
                const SizedBox(height: DonySpacing.md),
                _detailCard(context, 'Budget', [
                  _kv(
                    context,
                    'banknote',
                    r.negotiable ? 'Budget' : 'Prix ferme',
                    PriceDisplay.money(r.targetPriceEur!, r.currency),
                  ),
                ]),
              ],
              if (r.acceptedPaymentMethods.isNotEmpty) ...[
                const SizedBox(height: DonySpacing.md),
                _PaymentMethodsCard(methods: r.acceptedPaymentMethods),
              ],
              if (r.pickupNeighborhood != null ||
                  r.deliveryNeighborhood != null) ...[
                const SizedBox(height: DonySpacing.md),
                _detailCard(context, 'Zones', [
                  if (r.pickupNeighborhood != null)
                    _kv(context, 'map-pin', 'Pickup', r.pickupNeighborhood!),
                  if (r.deliveryNeighborhood != null)
                    _kv(
                      context,
                      'map-pin',
                      'Livraison',
                      r.deliveryNeighborhood!,
                    ),
                ]),
              ],
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: currentUserId != null && currentUserId == r.senderId
              ? _OwnerCta(request: r, onChanged: onChanged)
              : r.viewerThreadId != null
              ? DonyButton(
                  // Le voyageur a déjà une offre en cours → on bascule vers sa
                  // négociation (négociable) / proposition de trajet (prix ferme).
                  label: r.negotiable
                      ? 'Voir ma négociation'
                      : 'Proposer mon trajet',
                  onPressed: () =>
                      context.push('/negotiations/${r.viewerThreadId}'),
                )
              : r.negotiable
              ? DonyButton(
                  label: 'Proposer mon trajet',
                  onPressed: () => MakeOfferBottomSheet.show(
                    context,
                    packageRequestId: r.id,
                    targetPriceEur: r.targetPriceEur,
                    weightKg: announcement?.availableKg ?? r.weightKg,
                    departureCity: r.departureCity,
                    arrivalCity: r.arrivalCity,
                    initialDate: announcement?.departureDate,
                    currency: r.currency,
                  ),
                )
              : _FirmPriceCta(request: r, announcement: announcement),
        ),
      ],
    );
  }

  static Widget _detailCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
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
            title,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          ...children,
        ],
      ),
    );
  }

  static Widget _kv(
    BuildContext context,
    String iconAsset,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon(iconAsset, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.md),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile statistique (Poids / Taille) — icône + grande valeur + libellé.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });
  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: DonySpacing.base,
        horizontal: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Center(child: DonyIcon(icon, size: 18, color: cs.primary)),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Chip catégorie (lecture seule) — emoji + libellé.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emojiForLabel(label), style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo carousel ───────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.urls});
  final List<String> urls;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: widget.urls[i],
                cacheKey: DonyImage.stableCacheKey(widget.urls[i]),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(DonyRadius.xl),
                ),
                child: Text(
                  '📷 ${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.urls.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(DonyRadius.full),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// CTA affiché au **propriétaire** de la demande : « Modifier » (visible
/// uniquement tant que la demande est éditable — OPEN/NEGOTIATING) +
/// « Offres reçues » (accès rapide aux négociations reçues). Quand la demande
/// n'est plus modifiable, seul « Offres reçues » reste.
class _OwnerCta extends StatelessWidget {
  const _OwnerCta({required this.request, this.onChanged});

  final PackageRequest request;
  final VoidCallback? onChanged;

  bool get _editable =>
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;

  Future<void> _openOffers(BuildContext context) async {
    await context.push('/package-requests/${request.id}');
    if (context.mounted) {
      onChanged?.call();
    }
  }

  Future<void> _edit(BuildContext context) async {
    await PackageRequestCreateWizard.show(context, initial: request);
    if (context.mounted) {
      onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = DonyButton(
      key: const Key('owner-offers'),
      label: 'Offres reçues',
      onPressed: () => _openOffers(context),
    );
    if (!_editable) {
      return offers;
    }
    return Row(
      children: [
        Expanded(
          child: DonyButton(
            key: const Key('owner-edit'),
            label: 'Modifier',
            variant: DonyButtonVariant.secondary,
            onPressed: () => _edit(context),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(child: offers),
      ],
    );
  }
}

/// CTA button for firm-price requests — tapping dispatches
/// [NegotiationStartRequested] with [proposedPriceEur = targetPriceEur].
class _FirmPriceCta extends StatelessWidget {
  const _FirmPriceCta({required this.request, this.announcement});

  final PackageRequest request;
  final AnnouncementModel? announcement;

  @override
  Widget build(BuildContext context) {
    final price = request.targetPriceEur;
    final label = price != null
        ? 'Prendre à ${PriceDisplay.money(price, request.currency)} · Prix ferme'
        : 'Prendre ce colis';

    return BlocProvider(
      create: (_) => getIt<NegotiationBloc>(),
      child: Builder(
        builder: (ctx) => BlocConsumer<NegotiationBloc, NegotiationState>(
          listener: (ctx, state) {
            if (state is NegotiationLoaded) {
              DonySnackbar.show(
                ctx,
                message: 'Offre confirmée',
                type: DonySnackbarType.success,
              );
            } else if (state is NegotiationError) {
              DonySnackbar.show(
                ctx,
                message: state.error.message,
                type: DonySnackbarType.error,
              );
            }
          },
          builder: (ctx, state) {
            final isLoading = state is NegotiationLoading;
            return DonyButton(
              key: const Key('take-firm-price'),
              label: isLoading ? 'Envoi…' : label,
              isLoading: isLoading,
              onPressed: isLoading || price == null
                  ? null
                  : () {
                      MakeOfferBottomSheet.show(
                        ctx,
                        packageRequestId: request.id,
                        targetPriceEur: price,
                        weightKg: announcement?.availableKg ?? request.weightKg,
                        departureCity: request.departureCity,
                        arrivalCity: request.arrivalCity,
                        initialDate: announcement?.departureDate,
                        isFirmPrice: true,
                        currency: request.currency,
                      );
                    },
            );
          },
        ),
      ),
    );
  }
}

/// Carte lecture-seule listant les moyens de paiement que l'expéditeur accepte.
class _PaymentMethodsCard extends StatelessWidget {
  const _PaymentMethodsCard({required this.methods});

  final Set<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      key: const Key('payment-methods-card'),
      width: double.infinity,
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
            'Mode de paiement souhaité',
            style: tt.bodyMedium!.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Accepté par l\'expéditeur',
            style: tt.bodyMedium!.copyWith(fontSize: 12, color: kTextHint),
          ),
          const SizedBox(height: DonySpacing.md),
          PaymentMethodsChips(methods: methods),
        ],
      ),
    );
  }
}
