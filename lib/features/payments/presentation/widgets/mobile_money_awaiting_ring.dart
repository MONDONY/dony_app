import 'dart:async';

import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Anneau d'attente d'un paiement mobile money : un arc qui tourne, avec au
/// centre le temps restant (`mm:ss`, `h:mm:ss` dès une heure) jusqu'à l'échéance donnée par le
/// serveur, et la légende « pour valider ».
///
/// Le chrono se recalcule chaque seconde à partir de [expiresAt] et [now]
/// (jamais un décompte local qui dériverait) et s'arrête à `00:00`. Seul le
/// texte du chrono se redessine à chaque seconde. Quand la réduction du
/// mouvement est active, l'arc reste immobile.
class MobileMoneyAwaitingRing extends StatefulWidget {
  const MobileMoneyAwaitingRing({
    super.key,
    required this.expiresAt,
    required this.now,
  });

  /// Échéance de la demande de paiement (instant du serveur).
  final DateTime expiresAt;

  /// Horloge, injectable pour les tests.
  final DateTime Function() now;

  static const double size = 118;
  static const double strokeWidth = 7;

  @override
  State<MobileMoneyAwaitingRing> createState() =>
      _MobileMoneyAwaitingRingState();
}

class _MobileMoneyAwaitingRingState extends State<MobileMoneyAwaitingRing> {
  static const _tick = Duration(seconds: 1);

  late final ValueNotifier<Duration> _remaining = ValueNotifier(_compute());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => _remaining.value = _compute());
  }

  @override
  void didUpdateWidget(covariant MobileMoneyAwaitingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _remaining.value = _compute();
    }
  }

  Duration _compute() {
    final diff = widget.expiresAt.difference(widget.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remaining.dispose();
    super.dispose();
  }

  /// `mm:ss` sous l'heure, `h:mm:ss` dès une heure restante (une demande de
  /// paiement de colis peut courir plus d'une heure : `75:00` se lirait mal).
  static String _format(Duration d) {
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours >= 1) return '${d.inHours}:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox.square(
      key: const Key('mobile-money-awaiting-ring'),
      dimension: MobileMoneyAwaitingRing.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: CircularProgressIndicator(
              // Immobile en réduction du mouvement : un arc fixe garde la
              // forme de l'anneau sans rien faire tourner.
              value: reduceMotion ? 0.3 : null,
              strokeWidth: MobileMoneyAwaitingRing.strokeWidth,
              strokeCap: StrokeCap.round,
              color: cs.primary,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<Duration>(
                  valueListenable: _remaining,
                  builder: (context, value, _) => Text(
                    _format(value),
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.walletTopupMmRingCaption,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
