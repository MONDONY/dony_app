import 'dart:async';
import 'dart:math' as math;

import 'package:dony/l10n/l10n.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Diamètre de la bulle (cible tactile de 56 px, au-delà du minimum de 44).
const double kAssistantBubbleSize = 56;

/// Distance entre la bulle posée et le bord de l'écran.
const double kAssistantBubbleMargin = 12;

/// Écart vertical minimal avec la safe area du haut et la barre d'onglets.
const double _verticalGap = 8;

/// Écart entre la bulle et sa bulle d'aide.
const double _hintGap = 8;

const double _hintMaxWidth = 260;

/// L'aide se ferme toute seule après ce délai.
const Duration _hintTimeout = Duration(seconds: 8);

/// Ressort court (amortissement 0,8, dépassement d'environ 1,5 %, écrêté à la
/// zone) : la bulle s'aimante en moins de 300 ms sans jamais sortir de la
/// zone, et reste interruptible.
const _snapSpring = SpringDescription(mass: 1, stiffness: 900, damping: 48);

/// Zone où le coin haut gauche de la bulle peut se poser.
///
/// Calculée à partir de la zone utile (safe area, barre d'onglets) à chaque
/// mise en page : la position gardée (côté + fraction) est donc toujours
/// ramenée dans l'écran, quels que soient la rotation, le clavier, l'échelle
/// du texte ou la taille de l'écran.
class AssistantBubbleZone {
  const AssistantBubbleZone({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  /// [area] : espace où la bulle flotte ; [padding] : safe area ;
  /// [bottomInset] : hauteur de la barre d'onglets, à ne pas recouvrir.
  factory AssistantBubbleZone.from({
    required Size area,
    required EdgeInsets padding,
    required double bottomInset,
  }) {
    const left = kAssistantBubbleMargin;
    final right = math.max(
      left,
      area.width - kAssistantBubbleMargin - kAssistantBubbleSize,
    );
    final top = padding.top + _verticalGap;
    // Écran trop bas : le haut l'emporte, la zone se réduit à une ligne.
    final bottom = math.max(
      top,
      area.height -
          bottomInset -
          padding.bottom -
          _verticalGap -
          kAssistantBubbleSize,
    );
    return AssistantBubbleZone(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
    );
  }

  final double left;
  final double right;
  final double top;
  final double bottom;

  /// Coin haut gauche de la bulle posée sur [side] (`left`, sinon droite) à la
  /// fraction [yFraction] de la hauteur utile (0 en haut, 1 en bas).
  Offset rest(String side, double yFraction) {
    final f = yFraction.isNaN ? 0.5 : yFraction.clamp(0.0, 1.0);
    return Offset(side == 'left' ? left : right, top + (bottom - top) * f);
  }

  /// Fraction (0 à 1) de la hauteur utile qui correspond à l'ordonnée [y].
  double fractionFor(double y) {
    final span = bottom - top;
    if (span <= 0) return 0;
    return ((y - top) / span).clamp(0.0, 1.0);
  }

  /// Côté le plus proche d'un coin haut gauche [offset].
  String sideFor(Offset offset, double areaWidth) =>
      offset.dx + kAssistantBubbleSize / 2 < areaWidth / 2 ? 'left' : 'right';

  /// Ramène [offset] dans la zone.
  Offset clamp(Offset offset) =>
      Offset(offset.dx.clamp(left, right), offset.dy.clamp(top, bottom));
}

/// Bulle flottante qui ouvre l'assistant.
///
/// Se glisse n'importe où et s'aimante au bord gauche ou droit ; un toucher
/// l'ouvre, un glissement ne l'ouvre jamais. À placer comme enfant d'un
/// `Stack` qui occupe la zone où elle flotte.
///
/// Aucune reconstruction du reste de l'app pendant le geste : la position
/// vit dans un `ValueNotifier` local. [onMoved] n'est appelé qu'au lâcher
/// (c'est lui qui écrit dans Hive).
class AssistantBubble extends StatefulWidget {
  const AssistantBubble({
    super.key,
    required this.side,
    required this.yFraction,
    required this.bottomInset,
    required this.showHint,
    required this.onTap,
    required this.onMoved,
    required this.onHintDismissed,
  });

  /// `left` ou `right`.
  final String side;

  /// Hauteur dans la zone utile, de 0 (haut) à 1 (bas).
  final double yFraction;

  /// Hauteur à laisser libre en bas (barre d'onglets), hors safe area.
  final double bottomInset;

  final bool showHint;
  final VoidCallback onTap;
  final void Function(String side, double yFraction) onMoved;
  final VoidCallback onHintDismissed;

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble>
    with SingleTickerProviderStateMixin {
  /// Position (coin haut gauche) pendant un glissement ou une aimantation ;
  /// `null` au repos, où elle se déduit de [_side] et [_y].
  final ValueNotifier<Offset?> _moving = ValueNotifier<Offset?>(null);
  final ValueNotifier<bool> _pressed = ValueNotifier<bool>(false);
  late final AnimationController _spring;

  /// Pose au repos. Écrite au lâcher puis relue quand [_moving] repasse à
  /// `null` ; elle suit aussi les propriétés quand le parent les change
  /// (réinitialisation depuis les réglages).
  late String _side = widget.side;
  late double _y = widget.yFraction;

  AssistantBubbleZone _zone = const AssistantBubbleZone(
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
  );
  double _areaWidth = 0;

  bool _dragging = false;
  Offset _dragOrigin = Offset.zero;
  Offset _pointerOrigin = Offset.zero;
  Offset _snapFrom = Offset.zero;
  Offset _snapTo = Offset.zero;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(_onSpringTick);
    _syncHintTimer();
  }

  Timer? _hintTimer;

  void _syncHintTimer() {
    if (widget.showHint) {
      _hintTimer ??= Timer(_hintTimeout, () => widget.onHintDismissed());
    } else {
      _hintTimer?.cancel();
      _hintTimer = null;
    }
  }

  @override
  void didUpdateWidget(AssistantBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHintTimer();
    if (oldWidget.side != widget.side ||
        oldWidget.yFraction != widget.yFraction) {
      _side = widget.side;
      _y = widget.yFraction;
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _spring.dispose();
    _moving.dispose();
    _pressed.dispose();
    super.dispose();
  }

  void _onSpringTick() {
    if (_dragging) return;
    final t = _spring.value;
    _moving.value = _zone.clamp(Offset.lerp(_snapFrom, _snapTo, t)!);
  }

  void _onPanStart(DragStartDetails details) {
    // Reprendre la bulle en pleine aimantation : le ressort s'arrête là où
    // elle est, sans saut.
    _spring.stop();
    _dragging = true;
    _pressed.value = true;
    _dragOrigin = _moving.value ?? _zone.rest(_side, _y);
    _pointerOrigin = details.globalPosition;
    _moving.value = _dragOrigin;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _moving.value = _zone.clamp(
      _dragOrigin + (details.globalPosition - _pointerOrigin),
    );
  }

  void _onPanEnd(DragEndDetails details) => _release();

  void _onPanCancel() {
    if (_dragging) _release();
  }

  void _release() {
    _dragging = false;
    _pressed.value = false;
    final current = _moving.value;
    if (current == null) return;
    final side = _zone.sideFor(current, _areaWidth);
    final y = _zone.fractionFor(current.dy);
    final target = _zone.rest(side, y);
    _side = side;
    _y = y;
    // Une seule écriture, au lâcher (position, puis fermeture de l'aide).
    widget.onMoved(side, y);
    if (widget.showHint) widget.onHintDismissed();
    if (MediaQuery.disableAnimationsOf(context) || current == target) {
      _moving.value = null;
      return;
    }
    _snapFrom = current;
    _snapTo = target;
    _spring
        .animateWith(
          SpringSimulation(
            _snapSpring,
            0,
            1,
            0,
            tolerance: const Tolerance(distance: 0.002, velocity: 0.05),
          ),
        )
        .then((_) {
          // Si le ressort est interrompu (bulle reprise), la suite ne
          // s'exécute pas : la bulle est déjà tenue au doigt.
          if (mounted) _moving.value = null;
        });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final zone = AssistantBubbleZone.from(
        area: constraints.biggest,
        padding: MediaQuery.paddingOf(context),
        bottomInset: widget.bottomInset,
      );
      _zone = zone;
      _areaWidth = constraints.maxWidth;
      return ValueListenableBuilder<Offset?>(
        valueListenable: _moving,
        child: _buildBubble(context),
        builder: (context, moving, bubble) {
          final position = moving ?? zone.rest(_side, _y);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.showHint && moving == null)
                _buildHint(context, constraints.biggest, position),
              // Clé : sans elle, l'aide qui disparaît au début du glissement
              // décale la bulle d'un rang dans le `Stack`, son sous-arbre est
              // reconstruit et le geste en cours est perdu.
              Positioned(
                key: const ValueKey('assistant-bubble-position'),
                left: position.dx,
                top: position.dy,
                width: kAssistantBubbleSize,
                height: kAssistantBubbleSize,
                // Couche propre : le glissement ne repeint que la bulle.
                child: RepaintBoundary(
                  key: const ValueKey('assistant-bubble-layer'),
                  child: bubble,
                ),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _buildBubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.assistantOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `down` : la distance avant le seuil de glissement compte, la bulle
        // reste sous le doigt dès le début du geste.
        dragStartBehavior: DragStartBehavior.down,
        onTap: widget.onTap,
        onTapDown: (_) => _pressed.value = true,
        onTapUp: (_) => _pressed.value = false,
        onTapCancel: () {
          if (!_dragging) _pressed.value = false;
        },
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: SizedBox(
          key: const ValueKey('assistant-bubble'),
          width: kAssistantBubbleSize,
          height: kAssistantBubbleSize,
          child: ValueListenableBuilder<bool>(
            valueListenable: _pressed,
            builder: (context, pressed, child) => AnimatedScale(
              scale: pressed ? 0.94 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: child,
            ),
            child: Material(
              color: cs.primary,
              elevation: 6,
              shadowColor: cs.shadow.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: cs.onPrimary,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Carte d'aide posée du côté opposé au bord, alignée sur le haut de la
  /// bulle dans la moitié haute de l'écran, sur son bas sinon : elle ne sort
  /// jamais de l'écran.
  Widget _buildHint(BuildContext context, Size area, Offset bubble) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final width = math.min(
      _hintMaxWidth,
      area.width - 2 * kAssistantBubbleMargin - kAssistantBubbleSize - _hintGap,
    );
    final onRight = _side != 'left';
    final left = onRight
        ? bubble.dx - _hintGap - width
        : bubble.dx + kAssistantBubbleSize + _hintGap;
    final upperHalf = _zone.fractionFor(bubble.dy) < 0.5;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: left,
      width: width,
      top: upperHalf ? bubble.dy : null,
      bottom: upperHalf ? null : area.height - bubble.dy - kAssistantBubbleSize,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.96 + 0.04 * t,
            alignment: onRight
                ? (upperHalf ? Alignment.topRight : Alignment.bottomRight)
                : (upperHalf ? Alignment.topLeft : Alignment.bottomLeft),
            child: child,
          ),
        ),
        child: Material(
          key: const ValueKey('assistant-hint'),
          color: cs.inverseSurface,
          elevation: 4,
          shadowColor: cs.shadow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onHintDismissed,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.assistantHintTitle,
                    style: text.titleSmall?.copyWith(
                      color: cs.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.assistantHintBody,
                    style: text.bodyMedium?.copyWith(
                      color: cs.onInverseSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
