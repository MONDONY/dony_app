import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const double _kMinKg = 1;
const double _kMaxKg = 23;

/// Bottom sheet permettant au voyageur de modifier un trajet existant
/// (capacité + paiement liquide) depuis l'écran de liaison de trajet.
///
/// Précondition : [announcement] doit avoir `pickupAddress`, `deliveryAddress`
/// et `transportMode` non-null (garanti par le point d'entrée `TripTile`).
abstract final class ModifyTripSheet {
  /// Retourne `true` si l'annonce a été mise à jour, sinon `null`/`false`.
  static Future<bool?> show(
    BuildContext context, {
    required AnnouncementModel announcement,
  }) {
    VoidCallback? submit;
    return DonyBottomSheet.show<bool>(
      context,
      title: 'Modifier le trajet',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementBloc>(
              create: (_) => getIt<AnnouncementBloc>()),
          BlocProvider<CommissionMethodBloc>(
              create: (_) => getIt<CommissionMethodBloc>()),
        ],
        child: child,
      ),
      stickyBottom: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (ctx, state) {
          final isLoading = state is AnnouncementLoading;
          return DonyButton(
            key: const Key('modify-trip-submit'),
            label: 'Enregistrer les modifications',
            isLoading: isLoading,
            onPressed: isLoading ? null : () => submit?.call(),
          );
        },
      ),
      child: _ModifyTripContent(
        announcement: announcement,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }
}

class _ModifyTripContent extends StatefulWidget {
  const _ModifyTripContent({
    required this.announcement,
    required this.onSubmitReady,
  });

  final AnnouncementModel announcement;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_ModifyTripContent> createState() => _ModifyTripContentState();
}

class _ModifyTripContentState extends State<_ModifyTripContent> {
  late final ValueNotifier<double> _capacity;
  late final ValueNotifier<bool> _cashEnabled;
  bool _awaitingCardSetup = false;

  AnnouncementModel get _a => widget.announcement;

  @override
  void initState() {
    super.initState();
    _capacity = ValueNotifier<double>(
      _a.availableKg.clamp(_kMinKg, _kMaxKg).toDouble(),
    );
    _cashEnabled = ValueNotifier<bool>(
      _a.acceptedPaymentMethods.contains(BidPaymentMethod.cash),
    );
    widget.onSubmitReady(_submit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<CommissionMethodBloc>()
            .add(CommissionMethodLoadRequested());
      }
    });
  }

  @override
  void dispose() {
    _capacity.dispose();
    _cashEnabled.dispose();
    super.dispose();
  }

  // Implémenté en Task 2.
  void _submit() {}

  bool _hasValidCard(CommissionMethodState st) =>
      st is CommissionMethodLoaded &&
      st.card.expirationStatus != ExpirationStatus.expired;

  Future<void> _onCashToggled(bool want) async {
    if (!want) {
      _cashEnabled.value = false;
      return;
    }
    final st = context.read<CommissionMethodBloc>().state;
    if (_hasValidCard(st)) {
      _cashEnabled.value = true;
      return;
    }
    // Pas de carte commission → détour vers la configuration.
    // Le sheet reste monté ; au retour on recharge l'état de la carte.
    _awaitingCardSetup = true;
    await context.push('/payments/commission-method');
    if (!mounted) {
      return;
    }
    context.read<CommissionMethodBloc>().add(CommissionMethodLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CommissionMethodBloc, CommissionMethodState>(
      listener: (ctx, st) {
        // Retour du détour carte commission. On ignore l'état transitoire de
        // chargement ; dès qu'un état réglé arrive, on consomme l'intention —
        // qu'une carte valide ait été configurée ou non. Sans ce reset, un
        // détour annulé laisserait le flag actif et activerait le liquide à
        // tort sur un état ultérieur.
        if (!_awaitingCardSetup || st is CommissionMethodLoading) {
          return;
        }
        _awaitingCardSetup = false;
        if (_hasValidCard(st)) {
          _cashEnabled.value = true;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LockedInfoBlock(announcement: _a),
          const SizedBox(height: DonySpacing.lg),
          if ((_a.bidsCount ?? 0) > 0) ...[
            const _OffersWarningBanner(),
            const SizedBox(height: DonySpacing.lg),
          ],
          _ModifiableBlock(
            capacity: _capacity,
            cashEnabled: _cashEnabled,
            onCashToggled: _onCashToggled,
          ),
        ],
      ),
    );
  }
}

// ── Bloc verrouillé (lecture seule) ──────────────────────────────────────────

class _LockedInfoBlock extends StatelessWidget {
  const _LockedInfoBlock({required this.announcement});
  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('EEE d MMM yyyy', 'fr')
        .format(announcement.departureDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_rounded, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Text('NON MODIFIABLE',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          _LockedRow(
            icon: Icons.swap_horiz_rounded,
            label: 'Corridor',
            value:
                '${announcement.departureCity} → ${announcement.arrivalCity}',
          ),
          const SizedBox(height: DonySpacing.sm),
          _LockedRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date de voyage',
            value: date,
          ),
          const SizedBox(height: DonySpacing.sm),
          _LockedRow(
            icon: Icons.flight_takeoff_rounded,
            label: 'Lieu de remise',
            value: announcement.pickupAddress?.label ?? '—',
          ),
          const SizedBox(height: DonySpacing.sm),
          _LockedRow(
            icon: Icons.flight_land_rounded,
            label: 'Lieu de récupération',
            value: announcement.deliveryAddress?.label ?? '—',
          ),
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(value,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bannière d'information « offres existantes » ─────────────────────────────

class _OffersWarningBanner extends StatelessWidget {
  const _OffersWarningBanner();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('modify-trip-offers-warning'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.warning),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Ce trajet a déjà reçu des offres. Si un colis y est déjà '
              'accepté, la modification sera refusée.',
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bloc modifiable ──────────────────────────────────────────────────────────

class _ModifiableBlock extends StatelessWidget {
  const _ModifiableBlock({
    required this.capacity,
    required this.cashEnabled,
    required this.onCashToggled,
  });
  final ValueNotifier<double> capacity;
  final ValueNotifier<bool> cashEnabled;
  final ValueChanged<bool> onCashToggled;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MODIFIABLE',
              style: tt.bodySmall?.copyWith(
                color: cs.success,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: DonySpacing.md),
          Text('Capacité disponible',
              style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w600)),
          const SizedBox(height: DonySpacing.sm),
          _CapacityStepper(capacity: capacity),
          const SizedBox(height: DonySpacing.base),
          Divider(color: cs.success.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: DonySpacing.sm),
          _CashToggleRow(cashEnabled: cashEnabled, onChanged: onCashToggled),
        ],
      ),
    );
  }
}

class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({required this.capacity});
  final ValueNotifier<double> capacity;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: capacity,
      builder: (context, kg, _) {
        return Row(
          children: [
            _StepperButton(
              key: const Key('capacity-decrement'),
              icon: Icons.remove_rounded,
              onPressed: kg > _kMinKg
                  ? () => capacity.value =
                      (kg - 1).clamp(_kMinKg, _kMaxKg).toDouble()
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${kg.toStringAsFixed(0)} kg',
                  key: const Key('capacity-value'),
                  style: tt.headlineMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _StepperButton(
              key: const Key('capacity-increment'),
              icon: Icons.add_rounded,
              onPressed: kg < _kMaxKg
                  ? () => capacity.value =
                      (kg + 1).clamp(_kMinKg, _kMaxKg).toDouble()
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Material(
      color: enabled ? cs.surface : cs.surface.withValues(alpha: 0.5),
      shape: CircleBorder(side: BorderSide(color: cs.outline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          // padding 12 + icône 22 ≈ 46 → cible tactile ≥ 44 (HIG).
          padding: const EdgeInsets.all(DonySpacing.md),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CashToggleRow extends StatelessWidget {
  const _CashToggleRow({required this.cashEnabled, required this.onChanged});
  final ValueNotifier<bool> cashEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: cashEnabled,
      builder: (context, enabled, _) {
        return Row(
          children: [
            Icon(Icons.payments_rounded, size: 20, color: cs.onSurface),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paiement en liquide',
                      style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w600)),
                  Text(
                    "L'expéditeur peut payer en espèces à la remise",
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('modify-trip-cash-switch'),
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: cs.primary,
            ),
          ],
        );
      },
    );
  }
}
