import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Initiales des jours de la semaine (lundi → dimanche), dans la langue de
/// l'app. `EEEEE` (narrow) rend exactement l'ancien motif figé en français
/// (L, M, M, J, V, S, D) et son équivalent anglais (M, T, W, T, F, S, S).
/// 2024-01-01 est un lundi, semaine de référence pour les sept jours.
List<String> _weekdayLabels(String locale) {
  final format = DateFormat.EEEEE(locale);
  return List.generate(7, (i) => format.format(DateTime(2024, 1, 1 + i)));
}

class TripRecurrenceEditScreen extends StatefulWidget {
  const TripRecurrenceEditScreen({super.key, required this.template});

  final TripTemplate template;

  @override
  State<TripRecurrenceEditScreen> createState() =>
      _TripRecurrenceEditScreenState();
}

class _TripRecurrenceEditScreenState extends State<TripRecurrenceEditScreen> {
  final List<bool> _days = List.filled(7, false);
  TimeOfDay? _departureTime;
  AddressData? _pickup;
  AddressData? _delivery;
  bool _active = true;
  bool _submitted = false;

  /// Le modèle n'a pas de prix au kilo (grille seule) : cet écran n'a pas de
  /// champ prix éditable, une récurrence ne doit donc jamais envoyer 0
  /// (constat #3).
  bool get _hasPricePerKg => widget.template.pricePerKg != null;

  bool get _isValid =>
      _hasPricePerKg &&
      _days.contains(true) &&
      _pickup != null &&
      _delivery != null;

  String get _weekdaysString => _days.map((d) => d ? '1' : '0').join();

  String? get _timeWire => _departureTime == null
      ? null
      : '${_departureTime!.hour.toString().padLeft(2, '0')}:${_departureTime!.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _departureTime = picked);
  }

  void _submit(BuildContext context) {
    if (!_isValid) return;
    _submitted = true;
    final t = widget.template;
    final data = <String, dynamic>{
      'sourceTemplateId': t.id,
      'departureCity': t.departureCity,
      'arrivalCity': t.arrivalCity,
      'transportMode': t.transportMode,
      'capacityUnit': t.capacityUnit,
      'availableKg': t.availableKg,
      // Jamais de repli à 0 : `_isValid` (et donc le CTA) bloque déjà la
      // soumission tant que `t.pricePerKg` est nul (constat #3).
      'pricePerKg': t.pricePerKg,
      'acceptedCategories': t.acceptedCategories,
      'pickupAddress': {
        'label': _pickup!.label,
        'lat': _pickup!.lat,
        'lng': _pickup!.lng,
      },
      'deliveryAddress': {
        'label': _delivery!.label,
        'lat': _delivery!.lat,
        'lng': _delivery!.lng,
      },
      'departureTime': _timeWire,
      'arrivalTime': t.arrivalTime,
      'cashAccepted': t.cashAccepted,
      'weekdays': _weekdaysString,
      'horizonDays': 14,
      'active': _active,
    };
    context.read<TripRecurrenceBloc>().add(TripRecurrenceCreated(data));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = widget.template;

    return BlocConsumer<TripRecurrenceBloc, TripRecurrenceState>(
      listener: (context, state) {
        if (_submitted && state.status == TripRecurrenceStatus.success) {
          DonySnackbar.show(
            context,
            message: context.l10n.tripTemplateRecurrenceActivatedMessage,
            type: DonySnackbarType.success,
          );
          context.pop(true);
        }
        if (state.status == TripRecurrenceStatus.error && state.error != null) {
          _submitted = false;
          unawaited(ErrorPresenter.show(context, state.error));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == TripRecurrenceStatus.loading;
        final l = context.l10n;
        final weekdayInitials = _weekdayLabels(l.localeName);
        return DonyPageScaffold(
          title: l.tripTemplateRecurrenceTitle,
          stickyBottom: DonyButton(
            label: l.tripTemplateActivateRecurrenceButton,
            onPressed: (_isValid && !isLoading) ? () => _submit(context) : null,
            isLoading: isLoading,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Récapitulatif du modèle (lecture seule)
              Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    if (t.emoji != null) ...[
                      Text(t.emoji!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: DonySpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.label,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${t.departureCity} → ${t.arrivalCity} · ${t.pricePerKg == null ? l.tripTemplateGridPriceLabel : '${formatPriceActive(t.pricePerKg!)}/kg'}',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 280.ms),
              if (!_hasPricePerKg) ...[
                const SizedBox(height: DonySpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DonyIcon('triangle-alert', size: 16, color: cs.error),
                    const SizedBox(width: DonySpacing.xs),
                    Expanded(
                      child: Text(
                        l.tripTemplateNoPricePerKgWarning,
                        style: tt.bodySmall?.copyWith(color: cs.error),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 20.ms, duration: 280.ms),
              ],
              const SizedBox(height: DonySpacing.xxl),

              _SectionLabel(
                label: l.tripTemplateRepeatDaysSectionLabel,
                iconAsset: 'calendar-sync',
              ),
              const SizedBox(height: DonySpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final selected = _days[i];
                  return GestureDetector(
                    onTap: () => setState(() => _days[i] = !_days[i]),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? cs.primary : cs.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? cs.primary : cs.outline,
                        ),
                      ),
                      child: Text(
                        weekdayInitials[i],
                        style: tt.bodyMedium?.copyWith(
                          color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }),
              ).animate().fadeIn(delay: 40.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.xxl),

              _SectionLabel(
                label: l.tripTemplateRecurrenceDepartureTimeSectionLabel,
                iconAsset: 'clock',
              ),
              const SizedBox(height: DonySpacing.sm),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Row(
                    children: [
                      DonyIcon('clock', color: cs.primary, size: 20),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Text(
                          _departureTime == null
                              ? l.tripTemplateOptionalTimeHint
                              : _timeWire!,
                          style: tt.bodyMedium?.copyWith(
                            color: _departureTime == null
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                      ),
                      if (_departureTime != null)
                        Semantics(
                          button: true,
                          container: true,
                          excludeSemantics: true,
                          label: l.tripTemplateClearTimeSemantic,
                          child: GestureDetector(
                            onTap: () => setState(() => _departureTime = null),
                            child: DonyIcon(
                              'x',
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 80.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.xxl),

              _SectionLabel(
                label: l.tripTemplateLocationsSectionLabel,
                iconAsset: 'arrow-left-right',
              ),
              const SizedBox(height: DonySpacing.sm),
              AddressPickerField(
                fieldLabel: l.tripTemplatePickupFieldLabel,
                autocompleteService: getIt<AddressAutocompleteService>(),
                onChanged: (addr) => setState(() => _pickup = addr),
              ).animate().fadeIn(delay: 120.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.base),
              AddressPickerField(
                fieldLabel: l.tripTemplateDeliveryFieldLabel,
                showGpsButton: false,
                autocompleteService: getIt<AddressAutocompleteService>(),
                onChanged: (addr) => setState(() => _delivery = addr),
              ).animate().fadeIn(delay: 140.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.xxl),

              GestureDetector(
                onTap: () => setState(() => _active = !_active),
                child: Container(
                  padding: const EdgeInsets.all(DonySpacing.base),
                  decoration: BoxDecoration(
                    color: _active
                        ? cs.primary.withValues(alpha: 0.08)
                        : cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    border: Border.all(
                      color: _active
                          ? cs.primary.withValues(alpha: 0.4)
                          : cs.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      DonyIcon(
                        'circle-play',
                        color: _active ? cs.primary : cs.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.tripTemplateActiveLabel,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l.tripTemplateActiveDescription,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 180.ms, duration: 280.ms),
              const SizedBox(height: DonySpacing.md),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.iconAsset});
  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 18, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
