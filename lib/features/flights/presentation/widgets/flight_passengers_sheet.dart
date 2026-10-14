import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille « Qui voyage ? » : un compteur − / + par catégorie (adultes,
/// enfants, bébés), boutons désactivés aux bornes (un adulte au moins, neuf
/// passagers au plus, un bébé par adulte). Rend le choix validé, `null` si
/// la feuille est fermée sans valider.
abstract final class FlightPassengersSheet {
  static Future<FlightPassengers?> show(
    BuildContext context, {
    FlightPassengers initial = FlightPassengers.single,
  }) {
    // Seuls les compteurs (gestes) écrivent dans ce notifier : il peut être
    // libéré à la fermeture.
    final value = ValueNotifier<FlightPassengers>(
      initial.isValid ? initial : FlightPassengers.single,
    );
    return DonyBottomSheet.show<FlightPassengers>(
      context,
      title: context.l10n.flightsPassengersSheetTitle,
      stickyBottom: Builder(
        builder: (sheetContext) => DonyButton(
          key: const Key('flight-passengers-validate'),
          label: sheetContext.l10n.flightsPassengersValidate,
          onPressed: () => Navigator.of(sheetContext).pop(value.value),
        ),
      ),
      child: _PassengersBody(value: value),
    ).whenComplete(value.dispose);
  }
}

class _PassengersBody extends StatelessWidget {
  const _PassengersBody({required this.value});

  final ValueNotifier<FlightPassengers> value;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<FlightPassengers>(
      valueListenable: value,
      builder: (context, p, _) {
        Widget counter(
          FlightPassengerKind kind,
          String title,
          String hint, {
          bool last = false,
        }) => _CounterRow(
          kind: kind,
          title: title,
          hint: hint,
          count: p.count(kind),
          canDecrement: p.canDecrement(kind),
          canIncrement: p.canIncrement(kind),
          onDecrement: () => value.value = value.value.decrement(kind),
          onIncrement: () => value.value = value.value.increment(kind),
          last: last,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            counter(
              FlightPassengerKind.adults,
              l.flightsPassengersAdultsTitle,
              l.flightsPassengersAdultsHint,
            ),
            counter(
              FlightPassengerKind.children,
              l.flightsPassengersChildrenTitle,
              l.flightsPassengersChildrenHint,
            ),
            counter(
              FlightPassengerKind.infants,
              l.flightsPassengersInfantsTitle,
              l.flightsPassengersInfantsHint,
              last: true,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.flightsPassengersRules,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.flightsPassengersPriceNote,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

/// Une catégorie : titre, âge en gris, puis − compte +.
class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.kind,
    required this.title,
    required this.hint,
    required this.count,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.last,
  });

  final FlightPassengerKind kind;
  final String title;
  final String hint;
  final int count;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  hint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _StepButton(
            key: Key('flight-passengers-${kind.name}-minus'),
            icon: 'minus',
            label: l.flightsPassengersDecrease(title),
            onPressed: canDecrement ? onDecrement : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              key: Key('flight-passengers-${kind.name}-count'),
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            key: Key('flight-passengers-${kind.name}-plus'),
            icon: 'plus',
            label: l.flightsPassengersIncrease(title),
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

/// Bouton rond − ou + : cible de 44 points, cercle de 34 points dessiné
/// dedans ; estompé quand la borne est atteinte.
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: kDonyMinTapTarget,
          child: Center(
            child: AnimatedOpacity(
              duration: DonyDuration.micro,
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: enabled ? cs.primary : cs.outline),
                ),
                child: DonyIcon(
                  icon,
                  size: 16,
                  color: enabled ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
