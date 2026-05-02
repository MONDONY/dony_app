import 'package:flutter/material.dart';
import 'package:dony/core/design/design_system.dart';

class NearMeRadiusSheet extends StatefulWidget {
  const NearMeRadiusSheet({
    super.key,
    this.initialRadiusKm = 25,
  });

  final double initialRadiusKm;

  static const double minRadiusKm = 5;
  static const double maxRadiusKm = 200;

  @override
  State<NearMeRadiusSheet> createState() => _NearMeRadiusSheetState();
}

class _NearMeRadiusSheetState extends State<NearMeRadiusSheet> {
  late double _radius;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadiusKm.clamp(
        NearMeRadiusSheet.minRadiusKm, NearMeRadiusSheet.maxRadiusKm);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: DonyColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.my_location_rounded, color: DonyColors.primary),
              const SizedBox(width: DonySpacing.xs),
              Text('Près de moi', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            "On garde uniquement les annonces dont le point de remise est dans ce rayon autour de toi.",
            style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
          ),
          const SizedBox(height: DonySpacing.lg),
          Center(
            child: Text(
              '${_radius.round()} km',
              style: tt.displaySmall?.copyWith(
                color: DonyColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Slider(
            value: _radius,
            min: NearMeRadiusSheet.minRadiusKm,
            max: NearMeRadiusSheet.maxRadiusKm,
            divisions: 39, // 5km steps
            label: '${_radius.round()} km',
            activeColor: DonyColors.primary,
            onChanged: (v) => setState(() => _radius = v),
          ),
          const SizedBox(height: DonySpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DonyColors.primary,
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              ),
              onPressed: () => Navigator.pop(context, _radius),
              child: const Text('Activer le filtre'),
            ),
          ),
        ],
      ),
    );
  }
}
