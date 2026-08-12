import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/zone_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:intl/intl.dart';

abstract final class CorridorAlertFormSheet {
  static Future<void> show(
    BuildContext context, {
    CorridorAlertModel? alert,
    bool isTraveler = false,
    bool isSender = false,
  }) {
    final bothRoles = isTraveler && isSender;
    final forcedDirection = isSender && !isTraveler
        ? AlertDirection.senderWantsTrips
        : AlertDirection.travelerWantsPackages;
    final initialDirection = alert?.direction ?? forcedDirection;

    final cubit = getIt<CorridorAlertFormCubit>(
      param1: (editing: alert, direction: initialDirection),
    );
    final canSubmitNotifier = ValueNotifier<bool>(cubit.state.isValid);

    return DonyBottomSheet.show<void>(
      context,
      title: alert == null ? 'Créer une alerte' : 'Modifier l\'alerte',
      wrapper: (content) => BlocProvider<CorridorAlertFormCubit>.value(
        value: cubit,
        child: BlocListener<CorridorAlertFormCubit, CorridorAlertFormState>(
          listener: (ctx, state) {
            canSubmitNotifier.value =
                state.isValid &&
                state.status != CorridorAlertFormStatus.submitting;
            if (state.status == CorridorAlertFormStatus.success) {
              ctx.pop();
            } else if (state.status == CorridorAlertFormStatus.error) {
              DonySnackbar.show(
                ctx,
                message:
                    state.errorMessage ?? 'Impossible d\'enregistrer l\'alerte',
                type: DonySnackbarType.error,
              );
            }
          },
          child: content,
        ),
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmitNotifier,
        builder: (ctx, canSubmit, _) =>
            BlocBuilder<CorridorAlertFormCubit, CorridorAlertFormState>(
              builder: (bCtx, state) {
                final loading =
                    state.status == CorridorAlertFormStatus.submitting;
                return DonyButton(
                  key: const Key('corridor-alert-submit'),
                  label: alert == null ? 'Créer l\'alerte' : 'Enregistrer',
                  isLoading: loading,
                  onPressed: (canSubmit && !loading)
                      ? () => bCtx.read<CorridorAlertFormCubit>().submit()
                      : null,
                );
              },
            ),
      ),
      child: _CorridorAlertFormBody(
        bothRoles: bothRoles,
        isEditing: alert != null,
      ),
    ).whenComplete(canSubmitNotifier.dispose);
  }
}

class _CorridorAlertFormBody extends StatefulWidget {
  const _CorridorAlertFormBody({
    required this.bothRoles,
    required this.isEditing,
  });

  final bool bothRoles;
  final bool isEditing;

  @override
  State<_CorridorAlertFormBody> createState() => _CorridorAlertFormBodyState();
}

class _CorridorAlertFormBodyState extends State<_CorridorAlertFormBody> {
  /// Coords de la dernière ville de départ choisie → centre par défaut de la zone.
  LatLng? _departureLatLng;

  /// État local du toggle « Zone de remise » (découplé du timing de [hasZone],
  /// car la zone n'est émise qu'après le 1er frame du picker).
  late bool _zoneOn;

  // Le catalogue est chargé par ContentCategorySelector lui-même.

  @override
  void initState() {
    super.initState();
    _zoneOn = context.read<CorridorAlertFormCubit>().state.hasZone;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CorridorAlertFormCubit>();
    final state = cubit.state;
    final showColisFilters =
        state.direction == AlertDirection.travelerWantsPackages;
    final isTrips = state.direction == AlertDirection.senderWantsTrips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Direction segment — only for both-role users in create mode
        if (widget.bothRoles && !widget.isEditing) ...[
          _DirectionSegment(
            key: const Key('alert-direction-segment'),
            direction: state.direction,
            onChanged: cubit.setDirection,
          ),
          const SizedBox(height: DonySpacing.lg),
        ],
        CityCorridorFields(
          departureValue: state.departureCity,
          arrivalValue: state.arrivalCity,
          departureFieldKey: const Key('alertDepartureCityField'),
          arrivalFieldKey: const Key('alertArrivalCityField'),
          requiredLabels: true,
          onDepartureSelected: (c) {
            setState(() => _departureLatLng = LatLng(c.lat, c.lng));
            cubit.setDeparture(c.name, c.countryCode);
          },
          onArrivalSelected: (c) => cubit.setArrival(c.name, c.countryCode),
          onDepartureCleared: cubit.clearDeparture,
          onArrivalCleared: cubit.clearArrival,
          onSwap: () {
            // `_departureLatLng` ne suivait que l'ancien champ départ : après
            // l'échange il désignerait la mauvaise ville pour le centre par
            // défaut de la zone de remise. On l'efface plutôt que de le
            // trahir ; le picker retombe sur son centre par défaut.
            setState(() => _departureLatLng = null);
            cubit.swapCorridor();
          },
        ),
        const SizedBox(height: DonySpacing.lg),
        // Weight and categories — only for colis direction
        if (showColisFilters) ...[
          _MinWeightField(
            key: const Key('corridor-alert-min-weight'),
            initial: state.minWeightKg,
            onChanged: cubit.setMinWeight,
          ),
          const SizedBox(height: DonySpacing.lg),
        ],
        // Fix 1: date-window field
        _DateWindowField(
          key: const Key('corridor-alert-date-window'),
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
          onPicked: cubit.setDateWindow,
          onClear: cubit.clearDateWindow,
        ),
        // Zone de remise — option en plus du corridor, alertes trajet seulement
        if (isTrips) ...[
          const SizedBox(height: DonySpacing.lg),
          _ZoneToggleRow(
            value: _zoneOn,
            onChanged: (on) {
              setState(() => _zoneOn = on);
              if (!on) cubit.clearZone();
            },
          ),
          if (_zoneOn) ...[
            const SizedBox(height: DonySpacing.md),
            ZonePickerField(
              key: const Key('zone-picker'),
              initialCenter: state.hasZone
                  ? LatLng(state.centerLat!, state.centerLng!)
                  : _departureLatLng,
              initialRadiusKm: state.radiusKm ?? 25,
              initialLabel: state.centerLabel,
              onChanged: (lat, lng, r, label) =>
                  cubit.setZone(lat: lat, lng: lng, radiusKm: r, label: label),
            ),
          ],
        ],
        if (showColisFilters) ...[
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Types de contenu (optionnel)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: DonySpacing.sm),
          // Multi-sélection ici, contrairement aux filtres de recherche :
          // une alerte peut porter sur plusieurs types de contenu.
          ContentCategorySelector(
            repository: getIt<IContentCategoryRepository>(),
            keyPrefix: 'alert-content',
            selected: state.contentCategories.toList(),
            // Le composant émet la sélection complète : on l'affecte
            // directement plutôt que de la redécomposer en toggles, ce qui
            // produisait un emit (et un rebuild du formulaire) par élément.
            onChanged: cubit.setCategories,
          ),
        ],
        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

/// Ligne toggle « Zone de remise (optionnel) » au-dessus du picker carte.
class _ZoneToggleRow extends StatelessWidget {
  const _ZoneToggleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zone de remise sur la carte', style: tt.titleSmall),
              Text(
                'Filtre par point de récupération (optionnel)',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Switch(
          key: const Key('zone-toggle'),
          value: value,
          onChanged: onChanged,
          activeThumbColor: cs.primary,
        ),
      ],
    );
  }
}

/// Direction segmented control (colis / trajets).
/// Mirrors [HomeFocusFilter._Segment] idiom: AnimatedContainer pills.
/// Only shown for both-role users in create mode.
class _DirectionSegment extends StatelessWidget {
  const _DirectionSegment({
    super.key,
    required this.direction,
    required this.onChanged,
  });

  final AlertDirection direction;
  final ValueChanged<AlertDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: [
          Expanded(
            child: _Pill(
              label: 'Colis',
              emoji: '📦',
              isActive: direction == AlertDirection.travelerWantsPackages,
              onTap: () => onChanged(AlertDirection.travelerWantsPackages),
            ),
          ),
          Expanded(
            child: _Pill(
              label: 'Trajets',
              emoji: '✈️',
              isActive: direction == AlertDirection.senderWantsTrips,
              onTap: () => onChanged(AlertDirection.senderWantsTrips),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isActive ? cs.primary : null,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable row that opens [showDateRangePicker] and shows the chosen range.
class _DateWindowField extends StatelessWidget {
  const _DateWindowField({
    super.key,
    required this.dateFrom,
    required this.dateTo,
    required this.onPicked,
    required this.onClear,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final void Function(DateTime from, DateTime to) onPicked;
  final VoidCallback onClear;

  String get _label {
    if (dateFrom != null && dateTo != null) {
      final fmt = DateFormat('d MMM', 'fr');
      return '${fmt.format(dateFrom!)} → ${fmt.format(dateTo!)}';
    }
    return 'Toute date';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRange = dateFrom != null && dateTo != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fenêtre de dates (optionnel)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: DonySpacing.xs),
        InkWell(
          key: const Key('corridor-alert-date-window-tap'),
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          onTap: () async {
            final now = DateTime.now();
            final initial = hasRange
                ? DateTimeRange(start: dateFrom!, end: dateTo!)
                : null;
            final picked = await showDateRangePicker(
              context: context,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
              initialDateRange: initial,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: Theme.of(
                    ctx,
                  ).colorScheme.copyWith(primary: cs.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              onPicked(picked.start, picked.end);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: hasRange ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    _label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: hasRange ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasRange)
                  Semantics(
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    label: 'Effacer la période',
                    child: GestureDetector(
                      key: const Key('corridor-alert-date-window-clear'),
                      onTap: onClear,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(left: DonySpacing.xs),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MinWeightField extends StatefulWidget {
  const _MinWeightField({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final double? initial;
  final ValueChanged<double?> onChanged;

  @override
  State<_MinWeightField> createState() => _MinWeightFieldState();
}

class _MinWeightFieldState extends State<_MinWeightField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Fix 2: preserve decimals (e.g. 1.5→"1.5") but strip trailing ".0" for
    // whole numbers (e.g. 2.0→"2").
    _controller = TextEditingController(
      text: widget.initial != null
          ? (widget.initial! % 1 == 0
                ? widget.initial!.toStringAsFixed(0)
                : widget.initial.toString())
          : null,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DonyTextField(
      controller: _controller,
      label: 'Poids minimum (optionnel)',
      suffixIcon: const Padding(
        padding: EdgeInsets.only(right: DonySpacing.base),
        child: Align(widthFactor: 1, child: Text('kg')),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        widget.onChanged(parsed);
      },
    );
  }
}
