import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// « Fiabilité 96 % » sur le profil public (FLUTTER-NV) : part des envois
/// menés à bien, calculée par le serveur (`reliabilityPercent`). Remplace les
/// compteurs publics d'annulations et d'absences. Un appui affiche ce que le
/// taux mesure.
class ProfileReliabilityLabel extends StatelessWidget {
  const ProfileReliabilityLabel({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = l.profileReliabilityPercent(percent);
    return Tooltip(
      message: l.profileReliabilityHelp,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: Semantics(
        label: '$label. ${l.profileReliabilityHelp}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            key: const Key('profile-reliability-label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('shield-check', size: 16, color: cs.success),
              const SizedBox(width: DonySpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.xxs),
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
