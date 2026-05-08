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
  const _NearMeRadiusContent({required this.radiusNotifier});

  final ValueNotifier<double> radiusNotifier;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.my_location_rounded, color: DonyColors.primary),
            const SizedBox(width: DonySpacing.xs),
            Text('Rayon de recherche', style: tt.titleMedium),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          "On garde uniquement les annonces dont le point de remise est dans ce rayon autour de toi.",
          style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
        ),
        const SizedBox(height: DonySpacing.lg),
        ValueListenableBuilder<double>(
          valueListenable: radiusNotifier,
          builder: (_, radius, __) => Column(
            children: [
              Center(
                child: Text(
                  '${radius.round()} km',
                  style: tt.displaySmall?.copyWith(
                    color: DonyColors.primary,
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
                activeColor: DonyColors.primary,
                onChanged: (v) => radiusNotifier.value = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}
