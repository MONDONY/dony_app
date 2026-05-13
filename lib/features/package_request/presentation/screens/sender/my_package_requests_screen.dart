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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _Tab { enCours, aVenir, passes }

List<PackageRequest> _filteredRequests(
    _Tab tab, List<PackageRequest> all) =>
    switch (tab) {
      _Tab.enCours => all
          .where((r) =>
              r.status == PackageRequestStatus.negotiating ||
              r.status == PackageRequestStatus.accepted)
          .toList(),
      _Tab.aVenir =>
          all.where((r) => r.status == PackageRequestStatus.open).toList(),
      _Tab.passes => all
          .where((r) =>
              r.status == PackageRequestStatus.completed ||
              r.status == PackageRequestStatus.expired ||
              r.status == PackageRequestStatus.cancelled)
          .toList(),
    };

({int enCours, int aVenir, int passes}) _tabCounts(
        List<PackageRequest> all) =>
    (
      enCours: all
          .where((r) =>
              r.status == PackageRequestStatus.negotiating ||
              r.status == PackageRequestStatus.accepted)
          .length,
      aVenir:
          all.where((r) => r.status == PackageRequestStatus.open).length,
      passes: all
          .where((r) =>
              r.status == PackageRequestStatus.completed ||
              r.status == PackageRequestStatus.expired ||
              r.status == PackageRequestStatus.cancelled)
          .length,
    );

// 0=Publié actif, 1=Accepté, 2=En route, 4=toutes done, -1=terminal grisé
int _activeStep(PackageRequestStatus status) => switch (status) {
      PackageRequestStatus.open => 0,
      PackageRequestStatus.negotiating => 1,
      PackageRequestStatus.accepted => 2,
      PackageRequestStatus.completed => 4,
      _ => -1,
    };

String _ctaLabel(PackageRequestStatus status) => switch (status) {
      PackageRequestStatus.open => 'Modifier →',
      PackageRequestStatus.negotiating ||
      PackageRequestStatus.accepted =>
        'Voir →',
      _ => 'Détail →',
    };

String _shortId(String id) =>
    '#${(id.length >= 8 ? id.substring(0, 8) : id).toUpperCase()}';

class MyPackageRequestsScreen extends StatelessWidget {
  const MyPackageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF2F1EF),
      body: MyPackageRequestsBody(showFab: true),
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
  _Tab _tab = _Tab.enCours;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, state) {
        final counts = state.status == PackageRequestListStatus.loaded
            ? _tabCounts(state.requests)
            : (enCours: 0, aVenir: 0, passes: 0);

        final header = _DarkHeader(
          activeTab: _tab,
          counts: counts,
          onTabChanged: (t) => setState(() => _tab = t),
        );

        Widget body;
        if (state.status == PackageRequestListStatus.loading) {
          body = Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary),
          );
        } else if (state.status == PackageRequestListStatus.error) {
          body = _ErrorView(
            message: state.errorMessage ?? 'Erreur',
            onRetry: () =>
                context.read<PackageRequestBloc>().add(const FetchMyRequests()),
          );
        } else {
          final filtered = _filteredRequests(_tab, state.requests);
          body = filtered.isEmpty
              ? _buildTabEmptyState(context)
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
                );
        }

        final content = Column(
          children: [
            header,
            Expanded(child: body),
          ],
        );

        if (!widget.showFab) return content;

        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              right: DonySpacing.lg,
              bottom: DonySpacing.xl,
              child: FloatingActionButton.extended(
                heroTag: 'my-package-requests-fab',
                onPressed: () async {
                  await PackageRequestCreateWizard.show(context);
                  if (context.mounted) {
                    context
                        .read<PackageRequestBloc>()
                        .add(const RefreshMyRequests());
                  }
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'Nouvelle demande',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabEmptyState(BuildContext context) {
    return switch (_tab) {
      _Tab.enCours => DonyEmptyState(
          title: 'Aucun envoi en cours',
          description:
              'Tes envois en négociation ou acceptés apparaîtront ici.',
          mascotte: DonyMascotteType.assis,
          actionLabel: '+ Publier une demande',
          onAction: () async {
            await PackageRequestCreateWizard.show(context);
            if (context.mounted) {
              context
                  .read<PackageRequestBloc>()
                  .add(const RefreshMyRequests());
            }
          },
        ),
      _Tab.aVenir => const DonyEmptyState(
          title: 'Aucune demande ouverte',
          description:
              'Tes demandes en attente de voyageur apparaîtront ici.',
          mascotte: DonyMascotteType.assis,
        ),
      _Tab.passes => const DonyEmptyState(
          title: 'Aucun historique',
          description:
              'Tes envois complétés, expirés et annulés apparaîtront ici.',
          mascotte: DonyMascotteType.assis,
        ),
    };
  }
}

// ── Request Card — Proposition B "Corridor Bold" ──────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final statusColor = switch (request.status) {
      PackageRequestStatus.open => cs.primary,
      PackageRequestStatus.negotiating => cs.warning,
      PackageRequestStatus.accepted ||
      PackageRequestStatus.completed =>
        cs.success,
      _ => cs.onSurfaceVariant,
    };

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
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : dot + badge statut + ref ID
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  _StatusBadge(status: request.status),
                  const Spacer(),
                  Text(
                    _shortId(request.id),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xs),
              // Ligne 2 : route
              Text(
                '${request.departureCity} → ${request.arrivalCity}',
                style: tt.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: DonySpacing.sm + 2),
              // Ligne 3 : stepper
              _ProgressStepper(status: request.status),
              const SizedBox(height: DonySpacing.sm + 2),
              // Ligne 4 : méta chips
              Text(
                _buildDetails(request),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              // Ligne 5 : date + CTA
              Row(
                children: [
                  Text(
                    '📅 ${DateFormat('d MMM yyyy', 'fr').format(request.desiredDate)}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  _CardAction(request: request),
                ],
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
    final label = _ctaLabel(request.status);
    final isDisabled = request.status == PackageRequestStatus.expired ||
        request.status == PackageRequestStatus.cancelled;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              if (request.status == PackageRequestStatus.open) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Modification à venir'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                PackageRequestDetailBottomSheet.show(context, request.id);
              }
            },
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDisabled ? cs.onSurfaceVariant : cs.primary,
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

// ── Dark Header ───────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  const _DarkHeader({
    required this.activeTab,
    required this.counts,
    required this.onTabChanged,
  });

  final _Tab activeTab;
  final ({int enCours, int aVenir, int passes}) counts;
  final ValueChanged<_Tab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    bool canGoBack;
    try {
      canGoBack = context.canPop();
    } catch (_) {
      canGoBack = false;
    }

    final activeCount = switch (activeTab) {
      _Tab.enCours => counts.enCours,
      _Tab.aVenir => counts.aVenir,
      _Tab.passes => counts.passes,
    };

    return Container(
      color: const Color(0xFF0A2540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          // Ligne titre
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.xs, DonySpacing.sm, DonySpacing.base, DonySpacing.xs),
            child: Row(
              children: [
                if (canGoBack)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () => context.pop(),
                  )
                else
                  const SizedBox(width: DonySpacing.base),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Mes envois',
                    style: tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (activeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xxs + 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Ligne tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.base, 0, DonySpacing.base, DonySpacing.sm),
            child: Row(
              children: [
                _DarkTab(
                  label: 'En cours',
                  active: activeTab == _Tab.enCours,
                  onTap: () => onTabChanged(_Tab.enCours),
                ),
                const SizedBox(width: DonySpacing.xs),
                _DarkTab(
                  label: 'À venir',
                  active: activeTab == _Tab.aVenir,
                  onTap: () => onTabChanged(_Tab.aVenir),
                ),
                const SizedBox(width: DonySpacing.xs),
                _DarkTab(
                  label: 'Passés',
                  active: activeTab == _Tab.passes,
                  onTap: () => onTabChanged(_Tab.passes),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTab extends StatelessWidget {
  const _DarkTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md, vertical: DonySpacing.xs + 2),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          border: active
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Progress Stepper ─────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.status});
  final PackageRequestStatus status;

  static const _labels = ['Publié', 'Accepté', 'En route', 'Livré'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _activeStep(status);

    Color dotColor(int i) {
      if (active == 4) return cs.primary; // completed: toutes done (bleu)
      if (active == -1) return cs.outlineVariant; // terminal: toutes grises
      if (i < active) return cs.primary; // étape passée: bleu
      if (i == active) return cs.success; // étape active: vert
      return cs.outlineVariant; // étape future: gris
    }

    Color connectorColor(int i) {
      if (active == 4) return cs.primary;
      if (active == -1) return cs.outlineVariant;
      return i < active ? cs.primary : cs.outlineVariant;
    }

    bool isActive(int i) => active >= 0 && active < 4 && i == active;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 4; i++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isActive(i) ? 11 : 9,
                height: isActive(i) ? 11 : 9,
                decoration: BoxDecoration(
                  color: dotColor(i),
                  shape: BoxShape.circle,
                  boxShadow: isActive(i)
                      ? [
                          BoxShadow(
                            color: dotColor(i).withValues(alpha: 0.3),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight:
                      isActive(i) ? FontWeight.w800 : FontWeight.w600,
                  color: isActive(i) ? dotColor(i) : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (i < 3)
            Expanded(
              child: Padding(
                // aligner le connecteur sur le centre vertical du dot
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  height: 2,
                  color: connectorColor(i),
                ),
              ),
            ),
        ],
      ],
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
  ];
  return parts.join(' · ');
}

String _shortCat(String label) =>
    label.length > 5 ? '${label.substring(0, 3)}.' : label;
