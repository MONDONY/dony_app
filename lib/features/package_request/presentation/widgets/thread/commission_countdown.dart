import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Compte à rebours jusqu'à [deadline] (UTC), isolé dans son propre widget
/// pour ne rafraîchir que ce texte chaque seconde, jamais le reste de l'écran.
/// S'arrête proprement à zéro (pas de durée négative affichée) et annule son
/// timer aussi bien à l'échéance qu'à la destruction du widget.
///
/// Partagé par les deux fils de prix où le voyageur règle une commission : la
/// demande de colis (`thread_state_cta_bar.dart`) et le trajet
/// (`bid_negotiation_thread_screen.dart`, FLUTTER-H7).
class CommissionCountdown extends StatefulWidget {
  const CommissionCountdown({super.key, required this.deadline});
  final DateTime deadline;

  @override
  State<CommissionCountdown> createState() => _CommissionCountdownState();
}

class _CommissionCountdownState extends State<CommissionCountdown> {
  Timer? _timer;

  /// Le restant vit dans un notifier, jamais dans un `setState` : la règle du
  /// projet l'interdit, et cela évite surtout de reconstruire toute la barre
  /// d'action à chaque tick. Seul le texte se redessine.
  late final ValueNotifier<Duration> _remaining = ValueNotifier(
    _computeRemaining(),
  );

  @override
  void initState() {
    super.initState();
    if (_remaining.value > Duration.zero) {
      _timer = Timer.periodic(_tickInterval(_remaining.value), (_) => _tick());
    }
  }

  /// La cadence suit la précision affichée : inutile de réveiller l'écran
  /// chaque seconde quand on affiche « 1h 45min ».
  Duration _tickInterval(Duration remaining) => remaining.inHours > 0
      ? const Duration(minutes: 1)
      : const Duration(seconds: 1);

  Duration _computeRemaining() {
    final diff = widget.deadline.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _computeRemaining();
    final wasHours = _remaining.value.inHours > 0;
    _remaining.value = remaining;
    if (remaining == Duration.zero) {
      _timer?.cancel();
      return;
    }
    // On vient de passer sous l'heure : repasser à la seconde.
    if (wasHours && remaining.inHours == 0) {
      _timer?.cancel();
      _timer = Timer.periodic(_tickInterval(remaining), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remaining.dispose();
    super.dispose();
  }

  static String _labelFor(AppLocalizations l, Duration remaining) {
    if (remaining == Duration.zero) {
      return l.negotiationCommissionCountdownExpired;
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    if (h > 0) {
      return l.negotiationCommissionCountdownHours(
        h,
        m.toString().padLeft(2, '0'),
      );
    }
    return l.negotiationCommissionCountdownMinutes(
      m.toString().padLeft(2, '0'),
      s.toString().padLeft(2, '0'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon('timer', size: 14, color: cs.warning),
        const SizedBox(width: DonySpacing.xs),
        ValueListenableBuilder<Duration>(
          valueListenable: _remaining,
          builder: (context, remaining, _) => Text(
            _labelFor(context.l10n, remaining),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.warning,
              fontWeight: FontWeight.w700,
              // Chasse fixe : le texte ne doit pas sauter à chaque tick.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
