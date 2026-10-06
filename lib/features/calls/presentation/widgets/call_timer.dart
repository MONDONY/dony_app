import 'package:flutter/material.dart';

/// Durée d'un appel décroché, « mm:ss », rafraîchie chaque seconde. Partagé
/// par l'écran d'appel et la barre d'appel en cours.
class CallTimer extends StatelessWidget {
  const CallTimer({super.key, required this.since, this.style});

  final DateTime since;
  final TextStyle? style;

  /// « mm:ss » écoulées depuis [since] à [now].
  static String format(DateTime since, DateTime now) {
    final elapsed = now.difference(since);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) => Text(
        format(since, DateTime.now()),
        style: style?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
