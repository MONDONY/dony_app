import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/di/pending_search_notifier.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/search_form_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_period_filter_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_status_filter_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _ctaLabel(String status) => switch (status) {
  'AWAITING_PAYMENT' => 'Payer →',
  'ACCEPTED' || 'HANDED_OVER' || 'IN_TRANSIT' => 'Voir →',
  _ => 'Détail →',
};

class ShipmentListScreen extends StatelessWidget {
  const ShipmentListScreen({super.key, this.embedded = false});

  /// Quand `true`, l'écran omet son header sombre — adapté pour servir de
  /// sous-onglet dans le hub `EnvoyerHubScreen`.
  final bool embedded;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<ShipmentFilterCubit>(),
    child: _ShipmentListContent(embedded: embedded),
  );
}

/// Body extrait pour usage en sous-onglet du hub `EnvoyerHubScreen`.
///
/// Délègue à [ShipmentListScreen] en mode `embedded: true`.
class ShipmentListBody extends StatelessWidget {
  const ShipmentListBody({super.key});

  @override
  Widget build(BuildContext context) =>
      const ShipmentListScreen(embedded: true);
}

class _ShipmentListContent extends StatefulWidget {
  const _ShipmentListContent({required this.embedded});
  final bool embedded;
  @override
  State<_ShipmentListContent> createState() => _ShipmentListContentState();
}

class _ShipmentListContentState extends State<_ShipmentListContent> {
  late final EnvoisRefreshNotifier _refreshNotifier;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _payingBidId;

  @override
  void initState() {
    super.initState();
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
    context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
  }

  void _onTabRefreshRequested() {
    if (mounted) {
      context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
    }
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => context.read<ShipmentFilterCubit>().setQuery(q),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _refreshNotifier.removeListener(_onTabRefreshRequested);
    super.dispose();
  }

  void _startPayment(BidModel bid) {
    setState(() => _payingBidId = bid.id);
    context.read<BidBloc>().add(
      BidCheckoutRequested(
        announcementId: bid.announcementId,
        weightKg: bid.weightKg ?? 0,
        declaredValueEur: bid.declaredValueEur ?? 0,
        description: bid.description ?? '',
        contentCategory: bid.contentCategory ?? '',
        recipientName: bid.recipientName ?? '',
        recipientPhone: bid.recipientPhone ?? '',
      ),
    );
  }

  Future<void> _presentPaymentSheet(
    BuildContext context,
    CheckoutPaymentSheetReady state,
  ) async {
    final authenticated = await requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );
    if (!context.mounted) return;
    if (!authenticated) {
      setState(() => _payingBidId = null);
      DonySnackbar.show(
        context,
        message: 'Authentification requise pour effectuer le paiement',
        type: DonySnackbarType.error,
      );
      return;
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: state.clientSecret,
          merchantDisplayName: 'Dony',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (!context.mounted) return;
      context.read<BidBloc>().add(BidConfirmPaymentRequested(state.bidId));
      context.push('/bids/${state.bidId}?from=payment');
    } on StripeException catch (e) {
      if (!context.mounted) return;
      setState(() => _payingBidId = null);
      if (e.error.code != FailureCode.Canceled) {
        DonySnackbar.show(
          context,
          message: 'Erreur de paiement: ${e.error.message}',
          type: DonySnackbarType.error,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _payingBidId = null);
      DonySnackbar.show(
        context,
        message: 'Erreur: ${e.toString()}',
        type: DonySnackbarType.error,
      );
    }
  }

  void _onBidState(BuildContext context, BidState state) {
    if (state is BidCheckoutReady) {
      context.read<PaymentBloc>().add(
        BidCheckoutPaymentRequested(
          clientSecret: state.response.clientSecret,
          publishableKey: state.response.publishableKey,
          bidId: state.response.bidId,
        ),
      );
    } else if (state is BidDeleted) {
      DonySnackbar.show(
        context,
        message: 'Envoi supprimé',
        type: DonySnackbarType.success,
      );
      context.read<BidBloc>().add(
        const BidMyListAutoRefreshRequested(force: true),
      );
    } else if (state is BidError && _payingBidId != null) {
      setState(() => _payingBidId = null);
      ErrorPresenter.show(context, state.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(listener: _onBidState),
        BlocListener<PaymentBloc, PaymentState>(
          listener: (context, state) async {
            if (state is CheckoutPaymentSheetReady) {
              await _presentPaymentSheet(context, state);
            }
          },
        ),
      ],
      child: BlocBuilder<ShipmentFilterCubit, ShipmentFilterState>(
        builder: (context, filter) => BlocBuilder<BidBloc, BidState>(
          builder: (context, bidState) {
            final hasData = bidState is BidListLoaded;
            final filtered = hasData
                ? applyShipmentFilters(bidState.bids, filter, DateTime.now())
                : <BidModel>[];

            Widget body;
            if (!hasData &&
                (bidState is BidLoading || bidState is BidInitial)) {
              body = const _LoadingView();
            } else if (!hasData && bidState is BidError) {
              body = _ErrorView(
                message: ErrorPresenter.resolve(bidState.error).message,
              );
            } else if (bidState is BidListLoaded && bidState.bids.isEmpty) {
              body = const _EmptyView(
                icon: Icons.local_shipping_outlined,
                title: 'Aucun envoi',
                subtitle:
                    'Vos colis acceptés par un voyageur apparaîtront ici.',
              );
            } else if (filtered.isEmpty) {
              body = _FilteredEmptyView(
                onReset: () => context.read<ShipmentFilterCubit>().reset(),
              );
            } else {
              body = _ShipmentListView(
                bids: filtered,
                emptyMessage: '',
                emptySubtitle: '',
                emptyIcon: Icons.inbox_rounded,
                hPadding: DonyLayout.hPadding(context),
                payingBidId: _payingBidId,
                onPayTap: _startPayment,
                onRefresh: () async => context.read<BidBloc>().add(
                  const BidMyListAutoRefreshRequested(force: true),
                ),
                onDelete: (bid) =>
                    context.read<BidBloc>().add(BidDeleteRequested(bid.id)),
              );
            }

            if (hasData && bidState.isRefreshing) {
              body = Stack(
                children: [
                  body,
                  LinearProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 2,
                  ),
                ],
              );
            }

            return Scaffold(
              backgroundColor: widget.embedded
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFF2F1EF),
              body: Column(
                children: [
                  if (!widget.embedded)
                    SafeArea(
                      bottom: false,
                      child: _DarkHeader(
                        total: hasData ? bidState.bids.length : 0,
                      ),
                    ),
                  _ShipmentFilterBar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    resultCount: filtered.length,
                    hasData: hasData,
                  ),
                  Expanded(child: body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

String? _activeQuickPreset(Set<String> s) {
  if (s.isEmpty) {
    return 'all';
  }
  if (setEquals(s, kEnvoisEnCours)) {
    return 'encours';
  }
  if (setEquals(s, kEnvoisAVenir)) {
    return 'avenir';
  }
  if (setEquals(s, kEnvoisPasses)) {
    return 'passes';
  }
  return null;
}

const _quickPresets = <(String, String, Set<String>)>[
  ('all', 'Tous', {}),
  ('encours', 'En cours', kEnvoisEnCours),
  ('avenir', 'À venir', kEnvoisAVenir),
  ('passes', 'Passés', kEnvoisPasses),
];

class _ShipmentFilterBar extends StatelessWidget {
  const _ShipmentFilterBar({
    required this.controller,
    required this.onQueryChanged,
    required this.resultCount,
    required this.hasData,
  });
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final int resultCount;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShipmentFilterCubit>();
    final filter = context.watch<ShipmentFilterCubit>().state;
    final active = _activeQuickPreset(filter.statuses);
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        DonySpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonySearchField(
            hint: 'Ville, destinataire, voyageur…',
            controller: controller,
            onChanged: onQueryChanged,
            onClear: () {
              controller.clear();
              cubit.setQuery('');
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              _SelectorButton(
                label: 'Statut',
                onTap: () async {
                  final r = await ShipmentStatusFilterSheet.show(
                    context,
                    filter.statuses,
                  );
                  if (r != null) {
                    cubit.setStatuses(r);
                  }
                },
              ),
              const SizedBox(width: DonySpacing.xs),
              _SelectorButton(
                label: 'Période',
                onTap: () async {
                  final r = await ShipmentPeriodFilterSheet.show(
                    context,
                    basis: filter.periodBasis,
                    preset: filter.periodPreset,
                    range: filter.customRange,
                  );
                  if (r != null) {
                    cubit.setPeriod(
                      basis: r.basis,
                      preset: r.preset,
                      range: r.range,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _quickPresets) ...[
                  DonyChip(
                    label: p.$2,
                    selected: active == p.$1,
                    onTap: () => cubit.applyQuickPreset(p.$3),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                ],
              ],
            ),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Text(
                  hasData
                      ? '$resultCount résultat${resultCount > 1 ? 's' : ''}'
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    cubit.reset();
                  },
                  child: Text(
                    'Tout effacer',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.onSurface,
          borderRadius: BorderRadius.circular(DonyRadius.sm + 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: cs.surface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: cs.surface, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Dark Header ───────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  const _DarkHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canGoBack = context.canPop();

    return Container(
      color: const Color(0xFF0A2540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xs,
              DonySpacing.sm,
              DonySpacing.base,
              DonySpacing.sm,
            ),
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
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xxs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      '$total',
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
        ],
      ),
    );
  }
}

// ── Progress Stepper ──────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.status});
  final String status;

  List<String> get _labels => [
    'Proposé',
    status == 'PAYMENT_ESCROWED' ? 'Payé' : 'À payer',
    'Confirmé',
    'En route',
    'Livré',
  ];

  int get _active => switch (status) {
    'PENDING' => 0,
    'AWAITING_PAYMENT' => 1,
    'PAYMENT_ESCROWED' => 1,
    'ACCEPTED' => 2,
    'HANDED_OVER' => 3,
    'IN_TRANSIT' => 3,
    'COMPLETED' => 5,
    _ => -1,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _active;

    Color dotColor(int i) {
      if (active == 5) return cs.primary;
      if (active == -1) return cs.outlineVariant;
      if (i < active) return cs.primary;
      if (i == active) return cs.success;
      return cs.outlineVariant;
    }

    Color connectorColor(int i) {
      if (active == 5) return cs.primary;
      if (active == -1) return cs.outlineVariant;
      if (i < active) return cs.primary;
      return cs.outlineVariant;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 5; i++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i == active && active != 5 && active != -1)
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: dotColor(i),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.success.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor(i),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: (i == active && active != 5)
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: (i == active && active != -1 && active != 5)
                      ? dotColor(i)
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (i < 4)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(height: 2, color: connectorColor(i)),
              ),
            ),
        ],
      ],
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ShipmentListView extends StatelessWidget {
  final List<BidModel> bids;
  final String emptyMessage;
  final String emptySubtitle;
  final IconData emptyIcon;
  final double hPadding;
  final String? payingBidId;
  final void Function(BidModel)? onPayTap;
  final Future<void> Function()? onRefresh;
  final void Function(BidModel)? onDelete;

  const _ShipmentListView({
    required this.bids,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.hPadding,
    this.payingBidId,
    this.onPayTap,
    this.onRefresh,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final child = bids.isEmpty
        ? _EmptyView(
            icon: emptyIcon,
            title: emptyMessage,
            subtitle: emptySubtitle,
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              hPadding,
              DonySpacing.base,
              hPadding,
              100,
            ),
            itemCount: bids.length,
            separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.md),
            itemBuilder: (_, i) {
              final bid = bids[i];
              final card = _ShipmentCard(
                bid: bid,
                index: i,
                isPaymentLoading: payingBidId == bid.id,
                onPayTap: onPayTap != null ? () => onPayTap!(bid) : null,
              );
              if (onDelete == null || !kEnvoisPasses.contains(bid.status)) {
                return card;
              }
              return Dismissible(
                key: ValueKey('dismiss_${bid.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => onDelete!(bid),
                background: _DeleteBackground(),
                child: card,
              );
            },
          );

    if (onRefresh == null) return child;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final confirmed = await DonyDialog.show(
    context,
    title: 'Supprimer cet envoi ?',
    message:
        'Il sera retiré de votre historique. Cette action est irréversible.',
    confirmLabel: 'Supprimer',
    variant: DonyDialogVariant.destructive,
    icon: Icons.delete_outline_rounded,
  );
  return confirmed == true;
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            color: DonyColors.white,
            size: 26,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Supprimer',
            style: tt.labelSmall?.copyWith(color: DonyColors.white),
          ),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.bid,
    required this.index,
    this.isPaymentLoading = false,
    this.onPayTap,
  });

  final BidModel bid;
  final int index;
  final bool isPaymentLoading;
  final VoidCallback? onPayTap;

  Color _statusColor(ColorScheme cs) => switch (bid.status) {
    'PENDING' || 'AWAITING_PAYMENT' || 'PAYMENT_ESCROWED' => cs.warning,
    'ACCEPTED' || 'COMPLETED' => cs.success,
    'HANDED_OVER' || 'IN_TRANSIT' => cs.primary,
    _ => cs.onSurfaceVariant,
  };

  String get _statusLabel => switch (bid.status) {
    'PENDING' => 'EN ATTENTE',
    'AWAITING_PAYMENT' => 'À PAYER',
    'PAYMENT_ESCROWED' => 'EN ATTENTE',
    'ACCEPTED' => 'CONFIRMÉ',
    'HANDED_OVER' => 'EN ROUTE',
    'IN_TRANSIT' => 'EN TRANSIT',
    'COMPLETED' => 'LIVRÉ',
    'REJECTED' => 'REFUSÉ',
    'CANCELLED' => 'ANNULÉ',
    'NO_SHOW' => 'ABSENT',
    'EXPIRED' => 'EXPIRÉ',
    'PARCEL_REFUSED' => 'REFUSÉ',
    _ => bid.status,
  };

  bool get _isDisabled => switch (bid.status) {
    'REJECTED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'EXPIRED' ||
    'PARCEL_REFUSED' => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final statusColor = _statusColor(cs);
    final label = _ctaLabel(bid.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () async {
          await context.push('/bids/${bid.id}', extra: bid);
          if (context.mounted) {
            context.read<BidBloc>().add(BidMyListRequested());
          }
        },
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
                  Text(
                    _statusLabel,
                    style: tt.bodySmall?.copyWith(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${(bid.id.length >= 8 ? bid.id.substring(0, 8) : bid.id).toUpperCase()}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                '${bid.departureCity ?? '—'} → ${bid.arrivalCity ?? '—'}',
                style: tt.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: DonySpacing.sm + 2),
              _ProgressStepper(status: bid.status),
              const SizedBox(height: DonySpacing.sm + 2),
              Text(
                _buildMeta(),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Row(
                children: [
                  Text(
                    '📅 ${DateFormat('d MMM yyyy', 'fr').format(bid.createdAt)}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (bid.status == 'AWAITING_PAYMENT' && onPayTap != null)
                    GestureDetector(
                      onTap: isPaymentLoading ? null : onPayTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.warning,
                          borderRadius: BorderRadius.circular(DonyRadius.sm),
                        ),
                        child: isPaymentLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DonyColors.white,
                                ),
                              )
                            : const Text(
                                'Payer →',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: DonyColors.white,
                                ),
                              ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _isDisabled
                          ? null
                          : () async {
                              await context.push('/bids/${bid.id}', extra: bid);
                              if (context.mounted) {
                                context.read<BidBloc>().add(
                                  BidMyListRequested(),
                                );
                              }
                            },
                      child: Text(
                        label,
                        style: tt.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isDisabled ? cs.onSurfaceVariant : cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeta() {
    final parts = <String>[
      bid.weightKg != null
          ? '${bid.weightKg!.toStringAsFixed(0)} kg'
          : bid.pricingMode == BidPricingMode.grid
          ? 'Forfait'
          : '—',
    ];
    if (bid.contentCategory != null) parts.add(bid.contentCategory!);
    return parts.join(' · ');
  }
}

// ── Empty / Loading / Error ───────────────────────────────────────────────────

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 40, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucun envoi ne correspond à tes filtres',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              label: 'Réinitialiser',
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xxl),
              child:
                  Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 30, color: cs.primary),
                          ),
                          const SizedBox(height: DonySpacing.base),
                          Text(
                            title,
                            style: tt.titleLarge?.copyWith(color: cs.onSurface),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DonySpacing.xl),
                          GestureDetector(
                            onTap: () async {
                              final params = await SearchFormBottomSheet.show(
                                context,
                              );
                              if (params != null && context.mounted) {
                                getIt<PendingSearchNotifier>().setPending(
                                  params,
                                );
                                context.go('/home');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.xl,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [DonyColors.blue700, cs.primary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.md,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: DonyColors.textOnBrand,
                                    size: 16,
                                  ),
                                  const SizedBox(width: DonySpacing.sm),
                                  Text(
                                    'Rechercher un trajet',
                                    style: tt.labelLarge?.copyWith(
                                      color: DonyColors.textOnBrand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOutCubic),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 32, color: cs.error),
            ),
            const SizedBox(height: DonySpacing.lg),
            Text(
              'Erreur de chargement',
              style: tt.titleLarge?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            GestureDetector(
              onTap: () => context.read<BidBloc>().add(BidMyListRequested()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.lg,
                  vertical: DonySpacing.md,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Réessayer',
                  style: tt.labelLarge?.copyWith(color: cs.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
