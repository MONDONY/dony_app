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

enum _StatusFilter { all, open, accepted }

class MyPackageRequestsScreen extends StatelessWidget {
  const MyPackageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DonyAppBar(title: 'Mes demandes'),
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

// ── List content ──────────────────────────────────────────────────────────────

class _ListContent extends StatefulWidget {
  const _ListContent({required this.showFab});
  final bool showFab;

  @override
  State<_ListContent> createState() => _ListContentState();
}

class _ListContentState extends State<_ListContent> {
  _StatusFilter _filter = _StatusFilter.all;

  List<PackageRequest> _applyFilter(List<PackageRequest> all) {
    return switch (_filter) {
      _StatusFilter.all => all,
      _StatusFilter.open => all
          .where((r) =>
              r.status == PackageRequestStatus.open ||
              r.status == PackageRequestStatus.negotiating)
          .toList(),
      _StatusFilter.accepted => all
          .where((r) =>
              r.status == PackageRequestStatus.accepted ||
              r.status == PackageRequestStatus.completed)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final body = BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, state) {
        if (state.status == PackageRequestListStatus.loading) {
          return Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary),
          );
        }
        if (state.status == PackageRequestListStatus.error) {
          return _ErrorView(
            message: state.errorMessage ?? 'Erreur',
            onRetry: () =>
                context.read<PackageRequestBloc>().add(const FetchMyRequests()),
          );
        }
        if (state.requests.isEmpty) {
          return DonyEmptyState(
            title: 'Tu n\'as encore rien envoyé',
            description:
                'Publie ta première demande et reçois des offres de voyageurs en quelques heures.',
            mascotte: DonyMascotteType.assis,
            actionLabel: '+ Publier ma première demande',
            onAction: () async {
              await PackageRequestCreateWizard.show(context);
              if (context.mounted) {
                context
                    .read<PackageRequestBloc>()
                    .add(const RefreshMyRequests());
              }
            },
          );
        }

        final openCount = state.requests
            .where((r) =>
                r.status == PackageRequestStatus.open ||
                r.status == PackageRequestStatus.negotiating)
            .length;
        final acceptedCount = state.requests
            .where((r) =>
                r.status == PackageRequestStatus.accepted ||
                r.status == PackageRequestStatus.completed)
            .length;
        final filtered = _applyFilter(state.requests);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterRow(
              current: _filter,
              total: state.requests.length,
              openCount: openCount,
              acceptedCount: acceptedCount,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _FilterEmptyState(filter: _filter)
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: () async {
                        context
                            .read<PackageRequestBloc>()
                            .add(const RefreshMyRequests());
                      },
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          DonySpacing.base,
                          DonySpacing.lg,
                          MediaQuery.of(context).padding.bottom + 100,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: DonySpacing.sm),
                        itemBuilder: (context, i) {
                          return _RequestCard(request: filtered[i])
                              .animate()
                              .fadeIn(duration: 200.ms, delay: (50 * i).ms)
                              .slideY(begin: 0.03, curve: Curves.easeOutCubic);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );

    if (!widget.showFab) return body;

    return Stack(
      children: [
        Positioned.fill(child: body),
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
            label: Text(
              'Nouvelle demande',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.current,
    required this.total,
    required this.openCount,
    required this.acceptedCount,
    required this.onChanged,
  });

  final _StatusFilter current;
  final int total, openCount, acceptedCount;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          DonySpacing.base, DonySpacing.sm, DonySpacing.base, DonySpacing.sm + 2),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: DonyColors.neutral200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'Toutes ($total)',
              active: current == _StatusFilter.all,
              onTap: () => onChanged(_StatusFilter.all),
            ),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Expanded(
            child: _FilterChip(
              label: 'Ouvertes ($openCount)',
              active: current == _StatusFilter.open,
              onTap: () => onChanged(_StatusFilter.open),
            ),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Expanded(
            child: _FilterChip(
              label: 'Acceptées ($acceptedCount)',
              active: current == _StatusFilter.accepted,
              onTap: () => onChanged(_StatusFilter.accepted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs + 2),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(
            color: active ? cs.primary : DonyColors.neutral200,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : DonyColors.textMuted,
                ),
          ),
        ),
      ),
    );
  }
}

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.filter});
  final _StatusFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = filter == _StatusFilter.open
        ? 'Aucune demande ouverte'
        : 'Aucune demande acceptée';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl + 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: DonyColors.neutral300),
            const SizedBox(height: DonySpacing.base),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DonyColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request Card — Proposition B "Corridor Bold" ──────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final PackageRequest request;

  Color _accentColor(ColorScheme cs) => switch (request.status) {
        PackageRequestStatus.open => cs.primary,
        PackageRequestStatus.negotiating => DonyColors.warning500,
        PackageRequestStatus.accepted => DonyColors.success500,
        _ => DonyColors.neutral300,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = _accentColor(cs);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => PackageRequestDetailBottomSheet.show(context, request.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: DonyColors.neutral200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Accent circle top-right
              Positioned(
                top: -24,
                right: -24,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1 : route + temps
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${request.departureCity} → ${request.arrivalCity}',
                            style: tt.titleLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DonyColors.textPrimary,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _timeAgo(request.createdAt),
                            style: tt.bodySmall?.copyWith(
                              color: DonyColors.textSubtle,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    // Row 2 : méta
                    Text(
                      _buildDetails(request),
                      style: tt.bodySmall?.copyWith(
                        color: DonyColors.textMuted,
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.base),
                    // Row 3 : badge statut + action
                    Row(
                      children: [
                        _StatusBadge(status: request.status),
                        const Spacer(),
                        _CardAction(request: request),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.request});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return switch (request.status) {
      PackageRequestStatus.open ||
      PackageRequestStatus.negotiating =>
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modification à venir'),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          child: Text(
            'Modifier →',
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      PackageRequestStatus.accepted => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 13, color: DonyColors.success500),
            const SizedBox(width: 4),
            Text(
              'Compléter →',
              style: tt.labelSmall?.copyWith(
                color: DonyColors.success500,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
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
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
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
            decoration: BoxDecoration(color: cfg.fg, shape: BoxShape.circle),
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

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    if (r.targetPriceEur != null) '≈${r.targetPriceEur!.toStringAsFixed(0)} €',
  ];
  return parts.join(' · ');
}

String _shortCat(String label) =>
    label.length > 5 ? '${label.substring(0, 3)}.' : label;
