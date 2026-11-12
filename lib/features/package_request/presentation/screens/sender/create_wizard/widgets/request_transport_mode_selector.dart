import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Mode de transport de la demande de colis (étape « Le trajet ») : une puce
/// « Peu importe » puis une par mode proposé, et une aide qui dit qui verra la
/// demande.
///
/// Sans état : l'étape pose [selected] depuis le bloc du formulaire et reçoit
/// le choix par [onChanged] (`null` = « Peu importe »).
class RequestTransportModeSelector extends StatelessWidget {
  const RequestTransportModeSelector({
    super.key,
    required this.modes,
    required this.selected,
    required this.onChanged,
  });

  /// Modes proposés (`transportModes.requestModes`).
  final List<TransportMode> modes;

  /// Mode retenu ; `null` quand « Peu importe » est retenu.
  final TransportMode? selected;
  final ValueChanged<TransportMode?> onChanged;

  static const double _gap = DonySpacing.sm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final help = _helpFor(l10n, selected);
    return Column(
      key: const Key('request-mode-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.requestCreateTransportModeLabel,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: DonySpacing.xs + 2),
        // Deux colonnes : à 360 dp, chaque puce garde de la place pour son
        // libellé sur une seule ligne, en français comme en anglais.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - _gap) / 2;
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                SizedBox(
                  width: width,
                  child: _ModeChip(
                    key: const Key('request-mode-any'),
                    iconAsset: 'layout-grid',
                    label: l10n.requestCreateTransportAny,
                    selected: selected == null,
                    onTap: () => onChanged(null),
                  ),
                ),
                for (final mode in modes)
                  SizedBox(
                    width: width,
                    child: _ModeChip(
                      key: Key('request-mode-${mode.name}'),
                      iconAsset: mode.iconAsset,
                      label: mode.label(l10n),
                      selected: selected?.displayGroup == mode.displayGroup,
                      onTap: () => onChanged(mode),
                    ),
                  ),
              ],
            );
          },
        ),
        if (help != null) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            help,
            key: const Key('request-mode-help'),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  static String? _helpFor(AppLocalizations l10n, TransportMode? mode) =>
      switch (mode) {
        null => l10n.requestCreateModeHelpAny,
        TransportMode.plane => l10n.requestCreateModeHelpPlane,
        TransportMode.boat => l10n.requestCreateModeHelpBoat,
        TransportMode.car ||
        TransportMode.bus => l10n.requestCreateModeHelpRoad,
        TransportMode.train || TransportMode.other => null,
      };
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = selected ? cs.primary : cs.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              // Épaisseur fixe : une puce choisie ne doit pas grandir.
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              DonyIcon(iconAsset, size: 18, color: fg),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
