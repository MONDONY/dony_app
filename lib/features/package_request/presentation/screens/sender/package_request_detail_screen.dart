import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      if (mounted) setState(() { _request = r; _threads = threads; });
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
              backgroundColor: DonyColors.danger500),
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
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: cs.primary,
          onPressed: () => context.pop(),
        ),
        title: Text('Ma demande',
            style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: false,
        actions: [
          IconButton(
            icon:
                Icon(Icons.more_horiz_rounded, color: cs.onSurface, size: 22),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: _loading
          ? Center(
              child:
                  CircularProgressIndicator(color: cs.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _request == null
                  ? const SizedBox.shrink()
                  : _DetailBody(
                      request: _request!,
                      threads: _threads,
                      cancelling: _cancelling,
                      onCancel: _cancel,
                      onComplete: () => context.push(
                          '/package-requests/${widget.requestId}/shipment'),
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
    required this.onComplete,
  });
  final PackageRequest request;
  final List<NegotiationThread> threads;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  bool get _canCancel =>
      request.status == PackageRequestStatus.open ||
      request.status == PackageRequestStatus.negotiating;
  bool get _showComplete =>
      request.status == PackageRequestStatus.accepted;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero card sombre
              _HeroCard(request: request, threadsCount: threads.length),
              const SizedBox(height: DonySpacing.xl),
              // Section offres
              _OffersSection(
                threads: threads,
                request: request,
              ),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(
              begin: 0.04, curve: Curves.easeOutCubic),
        ),
        // CTA fixe en bas
        if (_showComplete)
          _StickyBottom(
            child: DonyButton(
              label: 'Compléter les détails →',
              onPressed: onComplete,
            ),
          )
        else if (_canCancel)
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
    final publishedAt =
        DateFormat('HH:mm').format(request.createdAt);

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base + 4),
      decoration: BoxDecoration(
        color: DonyColors.ink700,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: [
          BoxShadow(
            color: DonyColors.ink900.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DonyColors.terra500,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
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
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    'En attente d\'offres…',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
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
              child: const Center(
                  child: Icon(Icons.inbox_outlined,
                      size: 26, color: DonyColors.primary)),
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
                  color: cs.onSurfaceVariant, height: 1.5),
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
            ).animate().fadeIn(
                duration: 200.ms,
                delay: (60 * i).ms),
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
    final travelerDisplayName =
        thread.travelerName ?? 'Voyageur';
    final rating = thread.travelerRating;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyAvatar(
                name: travelerDisplayName,
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
                          travelerDisplayName,
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: DonySpacing.xs),
                          Icon(Icons.star_rounded,
                              size: 14,
                              color: DonyColors.warning500),
                          Text(
                            rating.toStringAsFixed(1),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(thread.lastActivityAt),
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Prix
              Text(
                '${thread.currentPriceEur.toStringAsFixed(0)} €',
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          // CTA
          DonyButton(
            label: 'Voir la négo →',
            variant: isPrimary
                ? DonyButtonVariant.primary
                : DonyButtonVariant.ghost,
            onPressed: () =>
                context.push('/negotiations/${thread.id}'),
          ),
        ],
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
            Icon(Icons.error_outline_rounded,
                size: 48, color: DonyColors.danger500),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant),
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

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
  return 'il y a ${diff.inDays}j';
}

String _buildDetails(PackageRequest r) {
  final date = DateFormat('d MMM', 'fr').format(r.desiredDate);
  final parts = [
    '$date ±${r.dateToleranceDays}j',
    '${r.weightKg.toStringAsFixed(0)} kg',
    r.contentCategory.label,
    if (r.targetPriceEur != null)
      '≈${r.targetPriceEur!.toStringAsFixed(0)} €',
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
    return DonyBottomSheet.show(
      context,
      title: 'Ma demande',
      heightFraction: 0.92,
      stickyBottom: ValueListenableBuilder<_SheetBtnConfig?>(
        valueListenable: btnNotifier,
        builder: (_, config, __) {
          if (config == null) return const SizedBox.shrink();
          return DonyButton(
            label: config.label,
            variant: config.isDestructive
                ? DonyButtonVariant.destructive
                : DonyButtonVariant.primary,
            isLoading: config.isLoading,
            onPressed: config.onPressed,
          );
        },
      ),
      child: _SheetBody(
        requestId: requestId,
        onBtnConfig: (cfg) => WidgetsBinding.instance
            .addPostFrameCallback((_) => btnNotifier.value = cfg),
      ),
    ).whenComplete(btnNotifier.dispose);
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({
    required this.requestId,
    required this.onBtnConfig,
  });
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
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {}
      if (mounted) {
        setState(() { _request = r; _threads = threads; });
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
    final canCancel = r.status == PackageRequestStatus.open ||
        r.status == PackageRequestStatus.negotiating;
    final showComplete = r.status == PackageRequestStatus.accepted;

    if (showComplete) {
      widget.onBtnConfig(_SheetBtnConfig(
        label: 'Compléter les détails →',
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          context.push('/package-requests/${widget.requestId}/shipment');
        },
      ));
    } else if (canCancel) {
      widget.onBtnConfig(_SheetBtnConfig(
        label: cancelling ? 'Annulation…' : 'Annuler la demande',
        isDestructive: true,
        isLoading: cancelling,
        onPressed: _cancel,
      ));
    } else {
      widget.onBtnConfig(null);
    }
  }

  Future<void> _cancel() async {
    if (_request == null) return;
    setState(() => _cancelling = true);
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
        setState(() => _cancelling = false);
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(request: r, threadsCount: _threads.length),
          const SizedBox(height: DonySpacing.xl),
          _OffersSection(threads: _threads, request: r),
        ],
      ).animate().fadeIn(duration: 280.ms).slideY(
          begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}
