import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';

class NearMeRadiusSheet {
  static const double minRadiusKm = 5;
  static const double maxRadiusKm = 200;

  static Future<double?> show(
    BuildContext context, {
    double initialRadiusKm = 25,
  }) {
    final radiusNotifier = ValueNotifier<double>(
      initialRadiusKm.clamp(minRadiusKm, maxRadiusKm),
    );

    return DonyBottomSheet.show<double>(
      context,
      title: 'Près de moi',
      stickyBottom: ValueListenableBuilder<double>(
        valueListenable: radiusNotifier,
        builder: (_, radius, __) => DonyButton(
          label: 'Activer le filtre',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(radius),
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
              'On garde uniquement les annonces dont le point de remise est dans ce rayon autour de toi.',
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
