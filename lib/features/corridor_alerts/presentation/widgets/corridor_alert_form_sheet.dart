import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
      child: _CorridorAlertFormBody(alert: alert),
    ).whenComplete(canSubmitNotifier.dispose);
  }
}

class _CorridorAlertFormBody extends StatelessWidget {
  const _CorridorAlertFormBody({this.alert});
  final CorridorAlertModel? alert;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CorridorAlertFormCubit>();
    final state = context.watch<CorridorAlertFormCubit>().state;
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
    _controller = TextEditingController(
      text: widget.initial != null
          ? widget.initial!.toStringAsFixed(0)
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
          alignment: Alignment.center,
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
