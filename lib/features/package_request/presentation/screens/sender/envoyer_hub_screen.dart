import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/package_request/presentation/screens/sender/my_package_requests_screen.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class EnvoyerHubScreen extends StatelessWidget {
  const EnvoyerHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<PackageRequestBloc>()..add(const FetchMyRequests()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<BidBloc>()..add(const BidMyListAutoRefreshRequested()),
        ),
        BlocProvider(
          create: (_) => getIt<NegotiationListBloc>()
            ..add(const NegotiationListFetchRequested()),
        ),
      ],
      child: const _EnvoyerHubView(),
    );
  }
}

// ── Hub view (dashboard ↔ section switcher) ───────────────────────────────────

class _EnvoyerHubView extends StatefulWidget {
  const _EnvoyerHubView();

  @override
  State<_EnvoyerHubView> createState() => _EnvoyerHubViewState();
}

class _EnvoyerHubViewState extends State<_EnvoyerHubView> {
  // null = dashboard, 0 = demandes, 1 = envois, 2 = négos
  int? _activeSection;

  static const _titles = ['Mes demandes', 'Mes envois', 'Négociations'];

  @override
  Widget build(BuildContext context) {
    if (_activeSection != null) {
      return _buildSectionView();
    }
    return _buildDashboard();
  }

  // ── Section (full-list) view ─────────────────────────────────────────────────

  Widget _buildSectionView() {
    final cs = Theme.of(context).colorScheme;
    final bodies = [
      const MyPackageRequestsBody(),
      const ShipmentListBody(),
      const MyNegotiationsBody(),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SectionHeader(
              title: _titles[_activeSection!],
              onBack: () => setState(() => _activeSection = null),
            ),
            Divider(height: 1, color: cs.outline),
            Expanded(child: bodies[_activeSection!]),
          ],
        ),
      ),
    );
  }

  // ── Dashboard view ───────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F6),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DashboardHeader(
              onNew: () async {
                await PackageRequestCreateWizard.show(context);
                if (mounted) {
                  context
                      .read<PackageRequestBloc>()
                      .add(const RefreshMyRequests());
                }
              },
              onDemandes: () => setState(() => _activeSection = 0),
              onEnvois: () => setState(() => _activeSection = 1),
              onNegos: () => setState(() => _activeSection = 2),
            ),
            Expanded(
              child: _DashboardScrollBody(
                onDemandes: () => setState(() => _activeSection = 0),
                onEnvois: () => setState(() => _activeSection = 1),
                onNegos: () => setState(() => _activeSection = 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header (back button) ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DonySpacing.xs, DonySpacing.sm, DonySpacing.lg, DonySpacing.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
              ),
              child: Icon(Icons.chevron_left_rounded, size: 20, color: cs.primary),
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard header ──────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.onNew,
    required this.onDemandes,
    required this.onEnvois,
    required this.onNegos,
  });

  final VoidCallback onNew;
  final VoidCallback onDemandes;
  final VoidCallback onEnvois;
  final VoidCallback onNegos;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, reqState) {
        return BlocBuilder<NegotiationListBloc, NegotiationListState>(
          buildWhen: (a, b) => a.activeCount != b.activeCount,
          builder: (context, negoState) {
            return BlocBuilder<BidBloc, BidState>(
              builder: (context, bidState) {
                final demandesCount = reqState.requests
                    .where((r) =>
                        r.status == PackageRequestStatus.open ||
                        r.status == PackageRequestStatus.negotiating ||
                        r.status == PackageRequestStatus.accepted)
                    .length;
                final envoisCount = bidState is BidListLoaded
                    ? bidState.bids
                        .where((b) =>
                            b.status == 'ACCEPTED' ||
                            b.status == 'PENDING' ||
                            b.status == 'AWAITING_PAYMENT')
                        .length
                    : 0;
                final negosCount = negoState.activeCount;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg, DonySpacing.base, DonySpacing.lg, DonySpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Titre + bouton Nouveau ──────────────────────────
                      Row(
                        children: [
                          Text(
                            'Envoyer',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: kTextPrimary,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onNew,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.md, vertical: 9),
                              decoration: BoxDecoration(
                                color: DonyColors.primary,
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.full),
                                boxShadow: [
                                  BoxShadow(
                                    color: DonyColors.primary
                                        .withValues(alpha: 0.30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      color: Colors.white, size: 15),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Nouveau',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DonySpacing.md),
                      // ── Pills de comptage ───────────────────────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CountPill(
                              dot: DonyColors.primary,
                              label: 'Demandes',
                              count: demandesCount,
                              onTap: onDemandes,
                            ),
                            const SizedBox(width: DonySpacing.sm),
                            _CountPill(
                              dot: DonyColors.success500,
                              label: 'Envois',
                              count: envoisCount,
                              onTap: onEnvois,
                            ),
                            const SizedBox(width: DonySpacing.sm),
                            _CountPill(
                              dot: DonyColors.warning500,
                              label: 'Négos',
                              count: negosCount,
                              isAlert: negosCount > 0,
                              onTap: onNegos,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.dot,
    required this.label,
    required this.count,
    required this.onTap,
    this.isAlert = false,
  });

  final Color dot;
  final String label;
  final int count;
  final VoidCallback onTap;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isAlert
        ? DonyColors.warning500.withValues(alpha: 0.12)
        : cs.surface;
    final border = isAlert
        ? DonyColors.warning500.withValues(alpha: 0.35)
        : cs.outlineVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md, vertical: DonySpacing.xs + 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              '$label $count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isAlert ? DonyColors.warning500 : kTextPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard scroll body ─────────────────────────────────────────────────────

class _DashboardScrollBody extends StatelessWidget {
  const _DashboardScrollBody({
    required this.onDemandes,
    required this.onEnvois,
    required this.onNegos,
  });

  final VoidCallback onDemandes, onEnvois, onNegos;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xs,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + 100,
      ),
      child: Column(
        children: [
          _DemandesCard(onViewAll: onDemandes)
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: 0.05, curve: Curves.easeOutCubic),
          const SizedBox(height: DonySpacing.sm + 2),
          _EnvoisCard(onViewAll: onEnvois)
              .animate()
              .fadeIn(delay: 60.ms, duration: 240.ms)
              .slideY(begin: 0.05, curve: Curves.easeOutCubic),
          const SizedBox(height: DonySpacing.sm + 2),
          _NegosCard(onViewAll: onNegos)
              .animate()
              .fadeIn(delay: 120.ms, duration: 240.ms)
              .slideY(begin: 0.05, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

// ── Demandes card ─────────────────────────────────────────────────────────────

class _DemandesCard extends StatelessWidget {
  const _DemandesCard({required this.onViewAll});
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<PackageRequestBloc, PackageRequestState>(
      builder: (context, state) {
        final activeRequests = state.requests
            .where((r) =>
                r.status == PackageRequestStatus.open ||
                r.status == PackageRequestStatus.negotiating ||
                r.status == PackageRequestStatus.accepted)
            .toList();
        final preview = activeRequests.take(2).toList();
        final isLoading = state.status == PackageRequestListStatus.loading;

        return _ActivityHubCard(
          bandGradient: LinearGradient(
            colors: [cs.primaryContainer, const Color(0xFFE0EAFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          bandIconBg: cs.primary.withValues(alpha: 0.12),
          bandIcon: Icons.send_rounded,
          bandIconColor: cs.primary,
          bandTitle: 'Demandes',
          bandTitleColor: const Color(0xFF0747C6),
          bandCount: activeRequests.length,
          bandUnit: activeRequests.length == 1 ? 'active' : 'actives',
          bandCountColor: cs.primary,
          activityDots: _buildActivityDots(activeRequests.length, cs.primary),
          viewAllLabel: 'Toutes les demandes',
          viewAllColor: cs.primary,
          onViewAll: onViewAll,
          child: isLoading
              ? const _CardLoading()
              : activeRequests.isEmpty
                  ? const _CardEmpty(label: 'Aucune demande active')
                  : Column(
                      children: preview
                          .asMap()
                          .entries
                          .map((e) => _RequestPreviewItem(
                                request: e.value,
                                isLast: e.key == preview.length - 1,
                                cs: cs,
                              ))
                          .toList(),
                    ),
        );
      },
    );
  }
}

// ── Envois card ───────────────────────────────────────────────────────────────

class _EnvoisCard extends StatelessWidget {
  const _EnvoisCard({required this.onViewAll});
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<BidBloc, BidState>(
      builder: (context, state) {
        final bids = state is BidListLoaded
            ? state.bids
                .where((b) =>
                    b.status == 'ACCEPTED' ||
                    b.status == 'PENDING' ||
                    b.status == 'AWAITING_PAYMENT')
                .toList()
            : <BidModel>[];
        final preview = bids.take(2).toList();
        final isLoading = state is BidLoading;

        return _ActivityHubCard(
          bandGradient: const LinearGradient(
            colors: [Color(0xFFE8F5EE), Color(0xFFD0EDDE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          bandIconBg: DonyColors.success500.withValues(alpha: 0.12),
          bandIcon: Icons.inventory_2_rounded,
          bandIconColor: DonyColors.success500,
          bandTitle: 'Envois',
          bandTitleColor: const Color(0xFF0B6B48),
          bandCount: bids.length,
          bandUnit: bids.length == 1 ? 'actif' : 'actifs',
          bandCountColor: DonyColors.success500,
          activityDots: _buildActivityDots(bids.length, DonyColors.success500),
          viewAllLabel: 'Tous les envois',
          viewAllColor: DonyColors.success500,
          onViewAll: onViewAll,
          child: isLoading
              ? const _CardLoading()
              : preview.isEmpty
                  ? const _CardEmpty(label: 'Aucun envoi en cours')
                  : Column(
                      children: preview
                          .asMap()
                          .entries
                          .map((e) => _BidPreviewItem(
                                bid: e.value,
                                isLast: e.key == preview.length - 1,
                                cs: cs,
                              ))
                          .toList(),
                    ),
        );
      },
    );
  }
}

// ── Négos card ────────────────────────────────────────────────────────────────

class _NegosCard extends StatelessWidget {
  const _NegosCard({required this.onViewAll});
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<NegotiationListBloc, NegotiationListState>(
      builder: (context, state) {
        final active = state.threads
            .where((t) =>
                t.status == NegotiationThreadStatus.open ||
                t.status == NegotiationThreadStatus.awaitingTrip ||
                t.status == NegotiationThreadStatus.awaitingPayment)
            .toList();
        final preview = active.take(2).toList();
        final isLoading =
            state.status == NegotiationListStatus.loading && state.threads.isEmpty;
        final hasActive = state.activeCount > 0;

        return _ActivityHubCard(
          bandGradient: const LinearGradient(
            colors: [Color(0xFFFBF2E3), Color(0xFFFDE8C4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          bandIconBg: DonyColors.warning500.withValues(alpha: 0.15),
          bandIcon: Icons.forum_rounded,
          bandIconColor: DonyColors.warning500,
          bandTitle: 'Négociations',
          bandTitleColor: const Color(0xFFB5781E),
          bandCount: state.activeCount,
          bandUnit: state.activeCount == 1 ? 'active' : 'actives',
          bandCountColor: DonyColors.warning500,
          activityDots: hasActive
              ? Row(
                  children: [
                    const _PulseDot(color: DonyColors.warning500),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      state.activeCount == 1
                          ? 'Nouveau message en attente'
                          : '${state.activeCount} négos en attente',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB5781E),
                      ),
                    ),
                  ],
                )
              : null,
          viewAllLabel: 'Toutes les négos',
          viewAllColor: DonyColors.warning500,
          onViewAll: onViewAll,
          extraBorder: hasActive
              ? Border.all(color: DonyColors.warning500.withValues(alpha: 0.25), width: 1.5)
              : null,
          child: isLoading
              ? const _CardLoading()
              : preview.isEmpty
                  ? const _CardEmpty(label: 'Aucune négociation active')
                  : Column(
                      children: preview
                          .asMap()
                          .entries
                          .map((e) => _NegoPreviewItem(
                                thread: e.value,
                                isLast: e.key == preview.length - 1,
                                cs: cs,
                              ))
                          .toList(),
                    ),
        );
      },
    );
  }
}

// ── Activity Hub Card shell ───────────────────────────────────────────────────

class _ActivityHubCard extends StatelessWidget {
  const _ActivityHubCard({
    required this.bandGradient,
    required this.bandIconBg,
    required this.bandIcon,
    required this.bandIconColor,
    required this.bandTitle,
    required this.bandTitleColor,
    required this.bandCount,
    required this.bandUnit,
    required this.bandCountColor,
    required this.viewAllLabel,
    required this.viewAllColor,
    required this.onViewAll,
    required this.child,
    this.activityDots,
    this.extraBorder,
  });

  final LinearGradient bandGradient;
  final Color bandIconBg;
  final IconData bandIcon;
  final Color bandIconColor;
  final String bandTitle;
  final Color bandTitleColor;
  final int bandCount;
  final String bandUnit;
  final Color bandCountColor;
  final Widget? activityDots;
  final String viewAllLabel;
  final Color viewAllColor;
  final VoidCallback onViewAll;
  final Widget child;
  final BoxBorder? extraBorder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card + 2),
        border: extraBorder ??
            Border.all(color: cs.outline.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF061B30).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DonyRadius.card + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient band ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.md,
                DonySpacing.base,
                DonySpacing.sm,
              ),
              decoration: BoxDecoration(gradient: bandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon square
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: bandIconBg,
                          borderRadius: BorderRadius.circular(DonyRadius.sm + 2),
                        ),
                        child: Icon(bandIcon, size: 17, color: bandIconColor),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      // Section title
                      Expanded(
                        child: Text(
                          bandTitle,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: bandTitleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      // Large count
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$bandCount',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: bandCountColor,
                                fontSize: 28,
                                letterSpacing: -0.5,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: ' $bandUnit',
                              style: tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: bandCountColor.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (activityDots != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    activityDots!,
                  ],
                ],
              ),
            ),

            // ── Items ──────────────────────────────────────────────────────
            child,

            // ── See all footer ─────────────────────────────────────────────
            Material(
              color: const Color(0xFFFAFBFC),
              child: InkWell(
                onTap: onViewAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.sm + 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        viewAllLabel,
                        style: tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: viewAllColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: viewAllColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity dots builder ─────────────────────────────────────────────────────

Widget _buildActivityDots(int count, Color color) {
  final total = count.clamp(0, 8);
  final filled = (total / 2).ceil().clamp(0, total);
  return Row(
    children: List.generate(total == 0 ? 3 : total, (i) {
      final isOn = i < (total == 0 ? 0 : filled);
      return Container(
        margin: const EdgeInsets.only(right: 4),
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: isOn ? color : color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }),
  );
}

// ── Pulse dot (négos alert) ───────────────────────────────────────────────────

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1.4, 1.4),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              )
              .fadeOut(duration: 1200.ms, curve: Curves.easeIn),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

// ── Request preview item ──────────────────────────────────────────────────────

class _RequestPreviewItem extends StatelessWidget {
  const _RequestPreviewItem({
    required this.request,
    required this.isLast,
    required this.cs,
  });
  final PackageRequest request;
  final bool isLast;
  final ColorScheme cs;

  ({Color bg, Color fg, String label, Color iconBg, IconData icon})
      get _cfg => switch (request.status) {
            PackageRequestStatus.open => (
                bg: DonyColors.success50,
                fg: DonyColors.success500,
                label: 'Ouverte',
                iconBg: DonyColors.success50,
                icon: Icons.schedule_rounded,
              ),
            PackageRequestStatus.negotiating => (
                bg: DonyColors.warning50,
                fg: DonyColors.warning500,
                label: 'Négo',
                iconBg: DonyColors.warning50,
                icon: Icons.forum_rounded,
              ),
            PackageRequestStatus.accepted => (
                bg: cs.primaryContainer,
                fg: cs.primary,
                label: 'Acceptée',
                iconBg: cs.primaryContainer,
                icon: Icons.check_circle_rounded,
              ),
            PackageRequestStatus.completed => (
                bg: DonyColors.success50,
                fg: DonyColors.success500,
                label: 'Livrée',
                iconBg: DonyColors.success50,
                icon: Icons.check_circle_rounded,
              ),
            PackageRequestStatus.expired => (
                bg: DonyColors.neutral100,
                fg: DonyColors.neutral500,
                label: 'Expirée',
                iconBg: DonyColors.neutral100,
                icon: Icons.timer_off_rounded,
              ),
            PackageRequestStatus.cancelled => (
                bg: DonyColors.danger50,
                fg: DonyColors.danger500,
                label: 'Annulée',
                iconBg: DonyColors.danger50,
                icon: Icons.cancel_rounded,
              ),
          };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cfg = _cfg;
    final date = DateFormat('d MMM', 'fr').format(request.desiredDate);
    final price = request.targetPriceEur != null
        ? ' · ≈${request.targetPriceEur!.toStringAsFixed(0)} €'
        : '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cfg.iconBg,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Icon(cfg.icon, size: 14, color: cfg.fg),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.departureCity} → ${request.arrivalCity}',
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$date · ${request.weightKg.toStringAsFixed(0)} kg$price',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.xs + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  cfg.label,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cfg.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: cs.outlineVariant),
      ],
    );
  }
}

// ── Bid preview item ──────────────────────────────────────────────────────────

class _BidPreviewItem extends StatelessWidget {
  const _BidPreviewItem({
    required this.bid,
    required this.isLast,
    required this.cs,
  });
  final BidModel bid;
  final bool isLast;
  final ColorScheme cs;

  ({Color bg, Color fg, String label}) get _cfg => switch (bid.status) {
        'ACCEPTED' => (
            bg: cs.primaryContainer,
            fg: cs.primary,
            label: 'Accepté'
          ),
        'AWAITING_PAYMENT' => (
            bg: DonyColors.warning50,
            fg: DonyColors.warning500,
            label: 'À payer'
          ),
        _ => (
            bg: DonyColors.success50,
            fg: DonyColors.success500,
            label: 'En cours'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cfg = _cfg;
    final traveler = bid.travelerName ?? 'Voyageur';
    final route = (bid.departureCity != null && bid.arrivalCity != null)
        ? '${bid.departureCity} → ${bid.arrivalCity}'
        : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm + 2,
          ),
          child: Row(
            children: [
              DonyAvatar(name: traveler, size: DonyAvatarSize.sm),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      traveler,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (route != null)
                      Text(
                        route,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.xs + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: cfg.bg,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  cfg.label,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cfg.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: cs.outlineVariant),
      ],
    );
  }
}

// ── Nego preview item ─────────────────────────────────────────────────────────

class _NegoPreviewItem extends StatelessWidget {
  const _NegoPreviewItem({
    required this.thread,
    required this.isLast,
    required this.cs,
  });
  final NegotiationThread thread;
  final bool isLast;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final traveler =
        thread.travelerName ?? 'Voyageur ${thread.travelerId.substring(0, 4)}';
    final route = (thread.departureCity != null && thread.arrivalCity != null)
        ? '${thread.departureCity} → ${thread.arrivalCity}'
        : null;
    final date = DateFormat('d MMM', 'fr').format(thread.travelerTravelDate);
    final isNew = thread.status == NegotiationThreadStatus.open &&
        thread.messages.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm + 2,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  DonyAvatar(
                    name: traveler,
                    imageUrl: thread.travelerPhotoUrl,
                    size: DonyAvatarSize.sm,
                  ),
                  if (isNew)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: DonyColors.warning500,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      traveler,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      route != null ? '$route · $date' : date,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Text(
                '${thread.currentPriceEur.toStringAsFixed(0)} €',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: cs.outlineVariant),
      ],
    );
  }
}

// ── Card loading / empty ──────────────────────────────────────────────────────

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _CardEmpty extends StatelessWidget {
  const _CardEmpty({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.lg,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
