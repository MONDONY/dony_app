import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_leg_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Section « Voyage à plusieurs étapes » en fin de formulaire de publication
/// (FLUTTER-4D). Le premier trajet est celui du formulaire ; chaque étape
/// ajoutée part de la ville d'arrivée de la précédente.
///
/// [origin] est l'arrivée du premier trajet, `null` tant qu'elle n'est pas
/// connue (ville ou date manquante) : l'ajout est alors désactivé.
class TripLegsSection extends StatelessWidget {
  const TripLegsSection({
    super.key,
    required this.origin,
    required this.showPrice,
    this.defaultKg,
    this.defaultPrice,
  });

  final TripLegOrigin? origin;
  final bool showPrice;
  final double? defaultKg;
  final double? defaultPrice;

  Future<void> _openSheet(
    BuildContext context,
    TripLegsState state, {
    int? editIndex,
  }) async {
    final first = origin;
    if (first == null) return;
    final cubit = context.read<TripLegsCubit>();
    final index = editIndex ?? state.legs.length;
    final legOrigin = TripLegChain.originOf(first, state.legs, index);
    final previous = index > 0 ? state.legs[index - 1] : null;
    final draft = await TripLegSheet.show(
      context,
      legNumber: index + 2,
      origin: legOrigin,
      initial: editIndex != null ? state.legs[editIndex] : null,
      showPrice: showPrice,
      defaultKg: previous?.availableKg ?? defaultKg,
      defaultPrice: previous?.pricePerKg ?? defaultPrice,
    );
    if (draft == null) return;
    if (editIndex != null) {
      cubit.replace(editIndex, draft);
    } else {
      cubit.add(draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<TripLegsCubit, TripLegsState>(
      builder: (context, state) {
        final first = origin;
        final invalid = first == null
            ? const <int>{}
            : TripLegChain.invalidIndexes(first, state.legs);
        return Container(
          key: const Key('trip-legs-section'),
          margin: const EdgeInsets.only(top: DonySpacing.xl),
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.alt_route_rounded, color: cs.primary, size: 22),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(l.tripLegsSectionTitle, style: tt.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                l.tripLegsSectionSubtitle,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              for (var i = 0; i < state.legs.length; i++) ...[
                const SizedBox(height: DonySpacing.md),
                _LegTile(
                      key: ValueKey('trip-leg-$i'),
                      number: i + 2,
                      from: first == null
                          ? ''
                          : TripLegChain.originOf(first, state.legs, i).city,
                      leg: state.legs[i],
                      invalid: invalid.contains(i),
                      onEdit: () => _openSheet(context, state, editIndex: i),
                      onRemove: () =>
                          context.read<TripLegsCubit>().removeFrom(i),
                    )
                    .animate()
                    .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
                    .slideY(begin: 0.06, curve: Curves.easeOutCubic),
              ],
              const SizedBox(height: DonySpacing.md),
              if (first == null)
                Text(
                  l.tripLegsNeedFirstLeg,
                  key: const Key('trip-legs-need-first'),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
              else if (!state.canAdd)
                Text(
                  l.tripLegsMaxReached(TripLegChain.maxLegs),
                  key: const Key('trip-legs-max'),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (first == null || state.canAdd) ...[
                const SizedBox(height: DonySpacing.sm),
                DonyButton(
                  key: const Key('trip-legs-add'),
                  label: l.tripLegsAddButton,
                  icon: DonyIcons.add,
                  variant: DonyButtonVariant.secondary,
                  onPressed: first == null
                      ? null
                      : () => _openSheet(context, state),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LegTile extends StatelessWidget {
  const _LegTile({
    super.key,
    required this.number,
    required this.from,
    required this.leg,
    required this.invalid,
    required this.onEdit,
    required this.onRemove,
  });

  final int number;
  final String from;
  final TripLegDraft leg;
  final bool invalid;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final kg = leg.availableKg == leg.availableKg.roundToDouble()
        ? leg.availableKg.toInt().toString()
        : leg.availableKg.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.md,
        DonySpacing.sm,
        DonySpacing.xs,
        DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        // Concentrique : rayon de la carte parente moins son padding.
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: invalid ? cs.error : cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: tt.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$from → ${leg.arrivalCity}',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  l.tripLegsLegSummary(
                    '${DateFormat.MMMEd(locale).format(leg.departureDate)} ${leg.departureTime}',
                    kg,
                  ),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (invalid) ...[
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    l.tripLegsDateInvalid,
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: Key('trip-leg-edit-${number - 2}'),
            tooltip: l.tripLegsEditTooltip,
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
          ),
          IconButton(
            key: Key('trip-leg-remove-${number - 2}'),
            tooltip: l.tripLegsRemoveTooltip,
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
