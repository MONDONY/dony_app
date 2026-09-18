import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/currency/converted_price.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
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

  /// L'écran a déjà été quitté au profit de l'écran propriétaire (« Ma
  /// demande ») — ne jamais rediriger deux fois (le chargement de la demande
  /// et le listener Auth peuvent tous deux aboutir au même verdict).
  bool _leftForOwnerView = false;

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
    // Rechargement silencieux quand une demande est déjà affichée (retour de
    // la sheet d'offre, de la négociation ou d'une action propriétaire) : on
    // garde le contenu à l'écran plutôt que de repasser par le spinner, et un
    // échec réseau ne remplace pas une fiche déjà lisible.
    final silent = _request != null;
    setState(() {
      _loading = !silent;
      _error = null;
    });
    try {
      final r = await getIt<PackageRequestRepository>().getById(
        widget.requestId,
      );
      if (mounted) {
        setState(() => _request = r);
        _evaluateViewer(context);
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Verdict d'appartenance : `true`/`false` quand l'état d'auth est tranché,
  /// `null` tant qu'il ne l'est pas. Au démarrage à froid via le lien partagé
  /// (`yadony://demande/{id}`), l'AuthBloc peut encore être en cours de
  /// résolution : classer alors le propriétaire en visiteur le laisserait à
  /// tort sur la vue visiteur, donc on attend un état définitif (authentifié
  /// ou session invité). Même schéma que `TripOwnerDetailScreen`.
  bool? _ownershipVerdict(AuthState authState, PackageRequest r) {
    final currentUserId = authState.currentUserId;
    if (currentUserId != null) {
      return r.senderId == currentUserId;
    }
    if (authState is AuthGuestSessionReady) {
      return false;
    }
    return null;
  }

  /// Le lien partagé (`yadony://demande/{id}`) fait atterrir tout le monde
  /// ici, y compris l'expéditeur propriétaire de la demande s'il clique son
  /// propre lien. Il ne doit pas se retrouver à pouvoir faire une offre sur
  /// sa propre demande : on le renvoie vers son écran « Ma demande ». Tout
  /// autre visiteur (y compris un invité, verdict `false`) reste ici.
  void _evaluateViewer(BuildContext context) {
    if (_leftForOwnerView) {
      return;
    }
    final r = _request;
    if (r == null) {
      return;
    }
    AuthState authState;
    try {
      authState = context.read<AuthBloc>().state;
    } catch (_) {
      return;
    }
    final verdict = _ownershipVerdict(authState, r);
    if (verdict != true) {
      return;
    }
    _leftForOwnerView = true;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    }
    router.push('/package-requests/${r.id}');
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
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated =
        authState is AuthAuthenticated || authState is AuthProfileUpdated;
    if (!isAuthenticated) {
      unawaited(
        AuthRequiredSheet.show(context, reason: AuthRequiredReason.report),
      );
      return;
    }

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
    final currentUserId = context.read<AuthBloc>().state.currentUserId;
    return BlocListener<AuthBloc, AuthState>(
      // L'auth peut se résoudre APRÈS le chargement de la demande (démarrage à
      // froid via lien partagé) : on réévalue le verdict d'appartenance à
      // chaque changement d'état d'auth, pas seulement une fois la demande
      // chargée.
      listener: (context, _) => _evaluateViewer(context),
      child: Scaffold(
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
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 14,
                      color: kError,
                    ),
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

  /// Appelé pour rafraîchir le détail après toute action susceptible d'avoir
  /// changé son état : édition ou retour de « Offres reçues » côté
  /// propriétaire, fermeture de la sheet d'offre ou retour de la négociation
  /// côté voyageur (le CTA dépend de [PackageRequest.viewerThreadId]).
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

  /// Prix réellement payé par l'expéditeur. `targetPriceEur` seul est un
  /// NET (PR #219) : jamais afficher les deux montants côte à côte, ça
  /// révélerait le taux de commission par soustraction. Repli sur le net
  /// uniquement si le serveur ne sert pas encore le brut.
  double? get _displayPrice => request.grossPriceEur ?? request.targetPriceEur;

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
    final isGuest = currentUserId == null;
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

              if (_displayPrice != null) ...[
                const SizedBox(height: DonySpacing.md),
                _detailCard(context, 'Budget', [
                  _kv(
                    context,
                    'banknote',
                    r.negotiable ? 'Budget' : 'Prix ferme',
                    PriceDisplay.money(_displayPrice!, r.currency),
                  ),
                  // Repère « environ » dans la devise du lecteur (serveur, lot 5).
                  Padding(
                    padding: const EdgeInsets.only(top: DonySpacing.xxs),
                    child: ConvertedPriceLabel(
                      originalCurrency: r.currency,
                      convertedPricePerKg: r.convertedDisplayPrice,
                      convertedCurrency: r.convertedCurrency,
                      suffix: '',
                    ),
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
          child: isGuest
              ? _GuestLockedCta(
                  label: r.negotiable
                      ? 'Proposer mon trajet'
                      : _displayPrice != null
                      ? 'Prendre à ${PriceDisplay.money(_displayPrice!, r.currency)} · Prix ferme'
                      : 'Prendre ce colis',
                )
              : currentUserId == r.senderId
              ? _OwnerCta(request: r, onChanged: onChanged)
              : r.viewerThreadId != null
              ? DonyButton(
                  // Le voyageur a déjà une offre en cours → on bascule vers sa
                  // négociation (négociable) / proposition de trajet (prix ferme).
                  label: r.negotiable
                      ? 'Voir ma négociation'
                      : 'Voir ma proposition',
                  onPressed: () => _openThread(context, r.viewerThreadId!),
                )
              : r.negotiable
              ? DonyButton(
                  label: 'Proposer mon trajet',
                  onPressed: () => _makeOffer(context),
                )
              : _FirmPriceCta(
                  request: r,
                  announcement: announcement,
                  onChanged: onChanged,
                ),
        ),
      ],
    );
  }

  /// Le thread peut être annulé depuis la négociation : au retour on recharge
  /// pour que le CTA redevienne « Proposer mon trajet ».
  Future<void> _openThread(BuildContext context, String threadId) async {
    await context.push('/negotiations/$threadId');
    if (context.mounted) {
      onChanged?.call();
    }
  }

  /// Une offre envoyée crée un thread côté serveur : le détail doit se
  /// recharger dès la fermeture de la sheet, sinon il garde
  /// `viewerThreadId == null` et propose à nouveau un trajet au retour de la
  /// négociation poussée par-dessus.
  Future<void> _makeOffer(BuildContext context) async {
    final r = request;
    await MakeOfferBottomSheet.show(
      context,
      packageRequestId: r.id,
      targetPriceEur: r.targetPriceEur,
      weightKg: announcement?.availableKg ?? r.weightKg,
      departureCity: r.departureCity,
      arrivalCity: r.arrivalCity,
      desiredDate: r.desiredDate,
      dateToleranceDays: r.dateToleranceDays,
      transportMode: r.transportMode,
      initialDate: announcement?.departureDate,
      currency: r.currency,
    );
    if (context.mounted) {
      onChanged?.call();
    }
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

class _GuestLockedCta extends StatelessWidget {
  const _GuestLockedCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DonyButton(
      key: const Key('guest-auth-required'),
      label: label,
      onPressed: () =>
          AuthRequiredSheet.show(context, reason: AuthRequiredReason.offer),
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
  const _FirmPriceCta({
    required this.request,
    this.announcement,
    this.onChanged,
  });

  final PackageRequest request;
  final AnnouncementModel? announcement;

  /// Rappelé à la fermeture de la sheet, cf. [PackageRequestPublicDetailBody.onChanged].
  final VoidCallback? onChanged;

  Future<void> _take(BuildContext context, double price) async {
    await MakeOfferBottomSheet.show(
      context,
      packageRequestId: request.id,
      targetPriceEur: price,
      weightKg: announcement?.availableKg ?? request.weightKg,
      departureCity: request.departureCity,
      arrivalCity: request.arrivalCity,
      desiredDate: request.desiredDate,
      dateToleranceDays: request.dateToleranceDays,
      transportMode: request.transportMode,
      initialDate: announcement?.departureDate,
      isFirmPrice: true,
      currency: request.currency,
    );
    if (context.mounted) {
      onChanged?.call();
    }
  }

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
                  : () => _take(ctx, price),
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
