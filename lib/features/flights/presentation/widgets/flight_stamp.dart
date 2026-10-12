import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Tampon incliné d'un billet de vol (« Le moins cher », « −32 % »), même
/// dessin que `BilletStatusStamp` du billet de colis.
class FlightStamp extends StatelessWidget {
  const FlightStamp({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.087, // −5° en radians
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
