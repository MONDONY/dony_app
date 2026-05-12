import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class MyPackageRequestsScreen extends StatelessWidget {
  const MyPackageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Mes demandes',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: const MyPackageRequestsBody(showFab: true),
    );
  }
}

class MyPackageRequestsBody extends StatelessWidget {
  const MyPackageRequestsBody({super.key, this.showFab = false});
  final bool showFab;

  @override
  Widget build(BuildContext context) {
    bool hasParent;
    try {
      BlocProvider.of<PackageRequestBloc>(context, listen: false);
      hasParent = true;
    } catch (_) {
      hasParent = false;
    }
    if (hasParent) return _ListContent(showFab: showFab);
    return BlocProvider(
      create: (_) =>
          getIt<PackageRequestBloc>()..add(const FetchMyRequests()),
      child: _ListContent(showFab: showFab),
    );
  }
}

class _ListContent extends StatelessWidget {
  const _ListContent({required this.showFab});
  final bool showFab;

  @override
  Widget build(BuildContext context) {
    final list = BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, state) {
        if (state.status == PackageRequestListStatus.loading) {
          return Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary));
        }
        if (state.status == PackageRequestListStatus.error) {
          return _ErrorView(
            message: state.errorMessage ?? 'Erreur',
            onRetry: () => context
                .read<PackageRequestBloc>()
                .add(const FetchMyRequests()),
          );
        }
        if (state.requests.isEmpty) {
          return _EmptyView(
            onCreate: () async {
              await PackageRequestCreateWizard.show(context);
              if (context.mounted) {
                context
                    .read<PackageRequestBloc>()
                    .add(const RefreshMyRequests());
              }
            },
          );
        }
        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            context
                .read<PackageRequestBloc>()
                .add(const RefreshMyRequests());
          },
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
                DonySpacing.lg, DonySpacing.xl,
                DonySpacing.lg,
                MediaQuery.of(context).padding.bottom + 100),
            itemCount: state.requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.sm + 4),
            itemBuilder: (context, i) {
              final r = state.requests[i];
              return _RequestCard(request: r)
                  .animate()
                  .fadeIn(duration: 220.ms, delay: (60 * i).ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic);
            },
          ),
        );
      },
    );

    if (!showFab) return list;

    return Stack(
      children: [
        Positioned.fill(child: list),
        Positioned(
          right: DonySpacing.lg,
          bottom: DonySpacing.xl,
          child: FloatingActionButton.extended(
            heroTag: 'my-package-requests-fab',
            onPressed: () async {
              await PackageRequestCreateWizard.show(context);
            },
            backgroundColor: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Builder(
              builder: (context) => Text(
                'Nouvelle demande',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => PackageRequestDetailBottomSheet.show(context, request.id),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1 : badge status + temps
              Row(
                children: [
                  _StatusBadge(status: request.status),
                  const Spacer(),
                  Text(
                    _timeAgo(request.createdAt),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              // Row 2 : route
              Text(
                '${request.departureCity} → ${request.arrivalCity}',
                style: tt.titleLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              // Row 3 : détails
              Text(
                _buildDetails(request),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              Divider(height: 1, color: cs.outline),
              const SizedBox(height: DonySpacing.sm),
              // Row 4 : footer contextuel
              _CardFooter(request: request),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PackageRequestStatus status;

  ({Color bg, Color fg, String label}) get _config => switch (status) {
        PackageRequestStatus.open => (
            bg: DonyColors.success50,
            fg: DonyColors.success500,
            label: 'OUVERTE'
          ),
        PackageRequestStatus.negotiating => (
            bg: DonyColors.warning50,
            fg: DonyColors.warning500,
            label: 'NÉGOCIATION'
          ),
        PackageRequestStatus.accepted => (
            bg: DonyColors.success50,
            fg: DonyColors.success500,
            label: 'ACCEPTÉE'
          ),
        PackageRequestStatus.completed => (
            bg: DonyColors.success50,
            fg: DonyColors.success500,
            label: 'LIVRÉE'
          ),
        PackageRequestStatus.expired => (
            bg: DonyColors.neutral100,
            fg: DonyColors.neutral500,
            label: 'EXPIRÉE'
          ),
        PackageRequestStatus.cancelled => (
            bg: DonyColors.danger50,
            fg: DonyColors.danger500,
            label: 'ANNULÉE'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: cfg.fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            cfg.label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cfg.fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.request});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return switch (request.status) {
      PackageRequestStatus.open => Row(
          children: [
            Icon(Icons.access_time_rounded,
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'En attente d\'offres…',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1),
              ),
            ),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Modification à venir'),
                    behavior: SnackBarBehavior.floating),
              ),
              child: Text(
                'Modifier',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      PackageRequestStatus.negotiating => Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 14, color: DonyColors.warning500),
            const SizedBox(width: 6),
            Text(
              'Négociation en cours',
              style: tt.bodySmall?.copyWith(
                  color: DonyColors.warning500,
                  fontWeight: FontWeight.w600,
                  height: 1),
            ),
          ],
        ),
      PackageRequestStatus.accepted => Row(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 14, color: DonyColors.success500),
            const SizedBox(width: 6),
            Text(
              'Acceptée — compléter les détails',
              style: tt.bodySmall?.copyWith(
                  color: DonyColors.success500,
                  fontWeight: FontWeight.w600,
                  height: 1),
            ),
          ],
        ),
      _ => Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              _statusLabel(request.status),
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1),
            ),
          ],
        ),
    };
  }

  String _statusLabel(PackageRequestStatus s) => switch (s) {
        PackageRequestStatus.open => 'Ouverte',
        PackageRequestStatus.negotiating => 'Négociation',
        PackageRequestStatus.accepted => 'Acceptée',
        PackageRequestStatus.completed => 'Livrée',
        PackageRequestStatus.expired => 'Expirée',
        PackageRequestStatus.cancelled => 'Annulée',
      };
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.xl, vertical: DonySpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          // Icône boîte dans un carré arrondi
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: DonyColors.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text('📦', style: TextStyle(fontSize: 40)),
              ),
            )
                .animate()
                .scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 350.ms,
                    curve: Curves.elasticOut)
                .fadeIn(duration: 220.ms),
          ),
          const SizedBox(height: DonySpacing.xl),
          Text(
            'Tu n\'as encore rien envoyé',
            textAlign: TextAlign.center,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 280.ms),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Publie ta première demande et reçois des offres de voyageurs en quelques heures.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 280.ms),
          const SizedBox(height: DonySpacing.xxl),
          DonyButton(
            label: '+ Publier ma première demande',
            onPressed: onCreate,
          ).animate().fadeIn(delay: 200.ms, duration: 280.ms).slideY(
              begin: 0.15, curve: Curves.easeOutCubic),
          const Spacer(flex: 2),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl + 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: DonyColors.danger500),
            const SizedBox(height: DonySpacing.base),
            Text(message,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
    _shortCat(r.contentCategory.label),
    if (r.targetPriceEur != null)
      '≈${r.targetPriceEur!.toStringAsFixed(0)} €',
  ];
  return parts.join(' · ');
}

String _shortCat(String label) =>
    label.length > 5 ? '${label.substring(0, 3)}.' : label;
