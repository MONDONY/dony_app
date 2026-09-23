import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

class NearMeRadiusSheet {
  static const double minRadiusKm = 5;
  static const double maxRadiusKm = 200;

  static Future<double?> show(
    BuildContext context, {
    double initialRadiusKm = 25,
    String? confirmLabel,
  }) {
    final radiusNotifier = ValueNotifier<double>(
      initialRadiusKm.clamp(minRadiusKm, maxRadiusKm),
    );

    return DonyBottomSheet.show<double>(
      context,
      title: context.l10n.homeNearMeTitle,
      stickyBottom: ValueListenableBuilder<double>(
        valueListenable: radiusNotifier,
        builder: (ctx, radius, _) => DonyButton(
          label: confirmLabel ?? ctx.l10n.homeNearMeConfirm,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(radius),
        ),
      ),
      child: _NearMeRadiusContent(radiusNotifier: radiusNotifier),
    ).whenComplete(radiusNotifier.dispose);
  }
}

class _NearMeRadiusContent extends StatelessWidget {
  final ValueNotifier<double> radiusNotifier;

  const _NearMeRadiusContent({required this.radiusNotifier});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: radiusNotifier,
      builder: (context, radius, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.homeNearMeExplanation,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.lg),
            Center(
              child: Text(
                '${radius.round()} km',
                style: tt.displaySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Slider(
              value: radius,
              min: NearMeRadiusSheet.minRadiusKm,
              max: NearMeRadiusSheet.maxRadiusKm,
              divisions: 39,
              label: '${radius.round()} km',
              activeColor: cs.primary,
              onChanged: (v) => radiusNotifier.value = v,
            ),
          ],
        );
      },
    );
  }
}
