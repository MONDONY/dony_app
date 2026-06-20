import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Catégories de contenu sélectionnables pour filtrer l'alerte (optionnel).
const _kAlertContentTypes = <String>[
  'Documents',
  'Vêtements',
  'Électronique',
  'Nourriture',
  'Cosmétiques',
  'Médicaments',
];

abstract final class CorridorAlertFormSheet {
  static Future<void> show(BuildContext context, {CorridorAlertModel? alert}) {
    final cubit = getIt<CorridorAlertFormCubit>(param1: alert);
    final canSubmitNotifier = ValueNotifier<bool>(cubit.state.isValid);

    return DonyBottomSheet.show<void>(
      context,
      title: alert == null ? 'Créer une alerte' : 'Modifier l\'alerte',
      wrapper: (content) => BlocProvider<CorridorAlertFormCubit>.value(
        value: cubit,
        child: BlocListener<CorridorAlertFormCubit, CorridorAlertFormState>(
          listener: (ctx, state) {
            canSubmitNotifier.value = state.isValid &&
                state.status != CorridorAlertFormStatus.submitting;
            if (state.status == CorridorAlertFormStatus.success) {
              ctx.pop();
            } else if (state.status == CorridorAlertFormStatus.error) {
              ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ??
                      'Impossible d\'enregistrer l\'alerte'),
                ),
              );
            }
          },
          child: content,
        ),
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmitNotifier,
        builder: (ctx, canSubmit, _) => BlocBuilder<CorridorAlertFormCubit,
            CorridorAlertFormState>(
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
      child: const _CorridorAlertFormBody(),
    ).whenComplete(canSubmitNotifier.dispose);
  }
}

// Fix 3: removed `alert` field — prefill comes from cubit initial state.
class _CorridorAlertFormBody extends StatelessWidget {
  const _CorridorAlertFormBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CorridorAlertFormCubit>();
    final state = cubit.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocProvider(
          create: (_) => getIt<CitySearchBloc>(),
          child: CityAutocompleteField(
            label: 'Ville de départ',
            fieldKey: const Key('alertDepartureCityField'),
            initialValue: state.departureCity,
            requiredLabel: true,
            onSelected: (CityModel c) =>
                cubit.setDeparture(c.name, c.countryCode),
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        BlocProvider(
          create: (_) => getIt<CitySearchBloc>(),
          child: CityAutocompleteField(
            label: 'Ville d\'arrivée',
            fieldKey: const Key('alertArrivalCityField'),
            initialValue: state.arrivalCity,
            requiredLabel: true,
            onSelected: (CityModel c) =>
                cubit.setArrival(c.name, c.countryCode),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        _MinWeightField(
          initial: state.minWeightKg,
          onChanged: cubit.setMinWeight,
        ),
        const SizedBox(height: DonySpacing.lg),
        // Fix 1: date-window field
        _DateWindowField(
          key: const Key('corridor-alert-date-window'),
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
          onPicked: cubit.setDateWindow,
          onClear: cubit.clearDateWindow,
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Types de contenu (optionnel)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: DonySpacing.sm),
        Wrap(
          spacing: DonySpacing.xs,
          runSpacing: DonySpacing.xs,
          children: _kAlertContentTypes.map((type) {
            final selected = state.contentCategories.contains(type);
            return DonyChip(
              label: type,
              selected: selected,
              onTap: () => cubit.toggleCategory(type),
            );
          }).toList(),
        ),
        const SizedBox(height: DonySpacing.md),
      ],
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
                  colorScheme: Theme.of(ctx)
                      .colorScheme
                      .copyWith(primary: cs.primary),
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
                          color: hasRange
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasRange)
                  GestureDetector(
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MinWeightField extends StatefulWidget {
  const _MinWeightField({required this.initial, required this.onChanged});
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
        child: Align(
          widthFactor: 1,
          child: Text('kg'),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        widget.onChanged(parsed);
      },
    );
  }
}
