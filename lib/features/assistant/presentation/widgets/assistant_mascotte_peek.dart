import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Côté de la mascotte qui sort de la bulle de l'assistant.
const double kAssistantMascotteSize = 56;

/// Part de la mascotte qui reste derrière la bulle une fois sortie : elle a
/// l'air de jaillir d'elle plutôt que d'être posée à côté.
const double _overlap = 8;

/// Écart entre la mascotte et la phrase.
const double _tipGap = 2;

/// Largeur maximale de la phrase (elle prend la largeur de son texte).
const double _tipMaxWidth = 148;

/// Premier passage après l'affichage de la bulle.
const Duration kAssistantMascotteFirstDelay = Duration(minutes: 1);

/// Délai entre la fin d'un passage et le suivant.
const Duration kAssistantMascotteInterval = Duration(minutes: 3);

/// Durée d'un passage : jaillit, salue, parle, rentre.
const Duration kAssistantMascotteShow = Duration(milliseconds: 6700);

/// Nombre de passages terminés après lesquels la mascotte ne sort plus : sans
/// question posée à l'assistant, la relancer encore agacerait.
const int kAssistantMascotteMaxPasses = 2;

/// Nouvel essai quand un passage tombe pendant un glissement ou l'aide.
const Duration _retryDelay = Duration(seconds: 5);

/// Réglage d'un canal : valeur à des instants (en ms) du passage, interpolée
/// en douceur entre deux repères.
typedef _Keys = List<(double ms, double value)>;

double _at(_Keys keys, double ms) {
  if (ms <= keys.first.$1) return keys.first.$2;
  if (ms >= keys.last.$1) return keys.last.$2;
  for (var i = 1; i < keys.length; i++) {
    final (t1, v1) = keys[i];
    if (ms <= t1) {
      final (t0, v0) = keys[i - 1];
      final f = (ms - t0) / (t1 - t0);
      return v0 + (v1 - v0) * Curves.easeInOut.transform(f);
    }
  }
  return keys.last.$2;
}

// Échelle : cachée sous la bulle (0,3), jaillit avec un dépassement (1,06),
// se pose, puis replonge.
const _Keys _scaleKeys = [
  (0, 0.3),
  (270, 0.3),
  (720, 1.06),
  (900, 1),
  (5580, 1),
  (5760, 1.03),
  (6300, 0.3),
  (6700, 0.3),
];

// Décalage vertical en points, vers la bulle quand il est positif.
const _Keys _offsetKeys = [
  (0, 14),
  (270, 14),
  (720, -4),
  (900, 0),
  (5580, 0),
  (5760, -2),
  (6300, 14),
  (6700, 14),
];

// Inclinaison en degrés : le coucou est un balancement de gauche à droite.
const _Keys _tiltKeys = [
  (0, 0),
  (270, 0),
  (720, -4),
  (900, 0),
  (1170, -9),
  (1530, 9),
  (1890, -9),
  (2250, 8),
  (2610, -4),
  (2790, 0),
  (6700, 0),
];

const _Keys _tipKeys = [
  (0, 0),
  (1080, 0),
  (1350, 1),
  (5220, 1),
  (5490, 0),
  (6700, 0),
];

// La bulle se tasse avant de lâcher la mascotte et « avale » en la reprenant.
const _Keys _bubbleKeys = [
  (0, 1),
  (180, 1),
  (315, 0.9),
  (540, 1.07),
  (720, 1),
  (6210, 1),
  (6345, 0.93),
  (6525, 1.05),
  (6660, 1),
  (6700, 1),
];

// Mouvement réduit : la mascotte apparaît et disparaît en fondu, sans bouger.
const _Keys _calmKeys = [
  (0, 0),
  (450, 0),
  (810, 1),
  (5580, 1),
  (6030, 0),
  (6700, 0),
];

/// Pose de la mascotte à [ms] millisecondes du début du passage.
@visibleForTesting
({double scale, double offset, double tiltDegrees}) assistantMascottePoseAt(
  double ms,
) => (
  scale: _at(_scaleKeys, ms),
  offset: _at(_offsetKeys, ms),
  tiltDegrees: _at(_tiltKeys, ms),
);

/// Opacité de la phrase à [ms] (0 à 1).
@visibleForTesting
double assistantMascotteTipAt(double ms) => _at(_tipKeys, ms);

/// Échelle de la bulle à [ms] : elle réagit à la sortie et au retour.
@visibleForTesting
double assistantMascotteBubbleScaleAt(double ms) => _at(_bubbleKeys, ms);

/// Opacité de la mascotte à [ms] quand le mouvement est réduit.
@visibleForTesting
double assistantMascotteCalmOpacityAt(double ms) => _at(_calmKeys, ms);

/// Mascotte qui jaillit de la bulle de l'assistant, fait coucou et demande
/// « Comment puis-je vous aider ? », puis rentre dans la bulle.
///
/// À placer dans le `Stack` de la bulle, avant elle : la mascotte passe
/// derrière. Elle revient tant que le parent la monte, toutes les
/// [interval] après la fin d'un passage ; elle ne joue jamais pendant que
/// [suspended] est vrai (glissement, aide de première fois), et reporte alors
/// son tour de quelques secondes. Toucher la mascotte ou sa phrase appelle
/// [onTap].
///
/// Elle écrit l'échelle de la bulle dans [bubbleScale] (la bulle se tasse
/// pendant le passage) ; le parent l'applique.
class AssistantMascottePeek extends StatefulWidget {
  const AssistantMascottePeek({
    super.key,
    required this.bubble,
    required this.bubbleSize,
    required this.area,
    required this.side,
    required this.topInset,
    required this.bubbleScale,
    required this.suspended,
    required this.onTap,
    required this.onShown,
    required this.onCompleted,
    this.firstDelay = kAssistantMascotteFirstDelay,
    this.interval = kAssistantMascotteInterval,
  });

  /// Coin haut gauche de la bulle, dans le repère du `Stack`.
  final Offset bubble;
  final double bubbleSize;

  /// Taille du `Stack` (la zone où la bulle flotte).
  final Size area;

  /// `left` ou `right` : côté où la bulle est posée (la mascotte est
  /// retournée à gauche pour que sa main reste visible, et sa phrase se met
  /// côté intérieur).
  final String side;

  /// Safe area du haut : sous ce seuil, la mascotte sort vers le bas.
  final double topInset;

  final ValueNotifier<double> bubbleScale;
  final bool suspended;
  final VoidCallback onTap;

  /// Début d'un passage ; reçoit son numéro depuis le montage (1 au premier).
  final void Function(int count) onShown;

  /// Le passage est allé jusqu'au bout (la mascotte est rentrée). Pas appelé
  /// quand il est interrompu (glissement, démontage) : seuls les passages vus
  /// en entier comptent pour le seuil [kAssistantMascotteMaxPasses].
  final VoidCallback onCompleted;

  final Duration firstDelay;
  final Duration interval;

  @override
  State<AssistantMascottePeek> createState() => _AssistantMascottePeekState();
}

class _AssistantMascottePeekState extends State<AssistantMascottePeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  int _count = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: kAssistantMascotteShow)
          ..addListener(_onTick)
          ..addStatusListener(_onStatus);
    _arm(widget.firstDelay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(AssistantMascottePeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bulle reprise en main en plein passage : la mascotte rentre d'un coup,
    // le prochain tour est celui de l'intervalle normal.
    if (widget.suspended && !oldWidget.suspended && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
      widget.bubbleScale.value = 1;
      _arm(widget.interval);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _arm(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _fire);
  }

  void _fire() {
    if (!mounted) return;
    if (widget.suspended) {
      _arm(_retryDelay);
      return;
    }
    _count++;
    widget.onShown(_count);
    unawaited(_controller.forward(from: 0));
  }

  void _onTick() {
    final ms = _controller.value * kAssistantMascotteShow.inMilliseconds;
    widget.bubbleScale.value = _reduceMotion
        ? 1
        : assistantMascotteBubbleScaleAt(ms);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Remet tout au repos (la mascotte n'est plus montée) avant d'attendre.
    _controller.value = 0;
    widget.bubbleScale.value = 1;
    _arm(widget.interval);
    widget.onCompleted();
  }

  /// Vers le haut tant qu'il y a la place au-dessus de la bulle, sinon vers
  /// le bas (bulle collée au haut de l'écran).
  bool get _emergesUp =>
      widget.bubble.dy >=
      widget.topInset + 8 + (kAssistantMascotteSize - _overlap);

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.none,
          children: [..._buildScene(context)],
        );
      },
    ),
  );

  List<Widget> _buildScene(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final greeting = context.l10n.assistantMascotteGreeting;
    final ms = _controller.value * kAssistantMascotteShow.inMilliseconds;
    final up = _emergesUp;
    final k = up ? 1.0 : -1.0;
    final onRight = widget.side != 'left';

    final mx =
        (widget.bubble.dx + widget.bubbleSize / 2 - kAssistantMascotteSize / 2)
            .clamp(
              0.0,
              math.max(0.0, widget.area.width - kAssistantMascotteSize),
            )
            .toDouble();
    final my = up
        ? widget.bubble.dy + _overlap - kAssistantMascotteSize
        : widget.bubble.dy + widget.bubbleSize - _overlap;

    final double mascotOpacity;
    final Matrix4 pose;
    if (_reduceMotion) {
      mascotOpacity = assistantMascotteCalmOpacityAt(ms);
      pose = Matrix4.identity();
    } else {
      mascotOpacity = 1;
      final p = assistantMascottePoseAt(ms);
      pose = Matrix4.identity()
        ..translateByDouble(0, k * p.offset, 0, 1)
        ..scaleByDouble(p.scale, p.scale, 1, 1)
        ..rotateZ(p.tiltDegrees * math.pi / 180);
    }
    final tipOpacity = _reduceMotion
        ? assistantMascotteCalmOpacityAt(ms)
        : assistantMascotteTipAt(ms);

    final mascot = Positioned(
      key: const ValueKey('assistant-mascotte'),
      left: mx,
      top: my,
      width: kAssistantMascotteSize,
      height: kAssistantMascotteSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: RepaintBoundary(
          child: Opacity(
            opacity: mascotOpacity,
            child: Transform(
              transform: pose,
              alignment: Alignment(0, up ? 1 : -1),
              child: ExcludeSemantics(
                child: Transform.flip(
                  flipX: !onRight,
                  child: const DonyMascotte(
                    type: DonyMascotteType.joyeux,
                    customDimension: kAssistantMascotteSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final tipTop = my + 8;
    final tip = Positioned(
      key: const ValueKey('assistant-mascotte-tip'),
      top: tipTop,
      left: onRight ? null : mx + kAssistantMascotteSize + _tipGap,
      right: onRight ? widget.area.width - mx + _tipGap : null,
      child: IgnorePointer(
        ignoring: tipOpacity < 0.5,
        child: Opacity(
          opacity: tipOpacity,
          child: Transform.scale(
            scale: _reduceMotion ? 1 : 0.92 + 0.08 * tipOpacity,
            alignment: onRight ? Alignment.centerRight : Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: greeting,
              excludeSemantics: true,
              onTap: widget.onTap,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _tipMaxWidth),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: onRight ? null : -5,
                        right: onRight ? -5 : null,
                        top: 14,
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: SizedBox.square(
                            dimension: 10,
                            child: ColoredBox(color: cs.inverseSurface),
                          ),
                        ),
                      ),
                      Material(
                        color: cs.inverseSurface,
                        elevation: 4,
                        shadowColor: cs.shadow.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Text(
                            greeting,
                            style: text.bodySmall?.copyWith(
                              color: cs.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // La phrase est posée avant la mascotte : si elles se touchent, la
    // mascotte reste devant.
    return [tip, mascot];
  }
}
