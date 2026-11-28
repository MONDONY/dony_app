import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:dony/features/tour/bloc/tour_cubit.dart';
import 'package:dony/features/tour/presentation/tour_anchors.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Délai entre le moment où la bulle pourrait s'afficher et son apparition :
/// laisse passer la vidéo « Bienvenue » et les premières feuilles de l'app, qui
/// la masquent (et font repartir ce délai à leur fermeture).
const kTourArmDelay = Duration(seconds: 3);

/// Couche du petit tour, posée par-dessus l'écran du shell.
///
/// Elle n'affiche une bulle que sur l'onglet Rechercher, sans feuille ni
/// dialogue ouvert, sans écran poussé par-dessus, clavier fermé et pour un
/// compte connecté. Elle ne capte aucun toucher en dehors de la bulle.
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.tabIndex,
    this.blockers,
    this.hasRealSession,
    this.armDelay = kTourArmDelay,
  });

  /// Onglet affiché par le shell ; le tour ne parle que sur le premier.
  final int tabIndex;

  /// Registre des feuilles ouvertes ; celui de l'app par défaut.
  final AssistantBubbleBlockers? blockers;

  /// Compte connecté ; la sonde de l'app par défaut (tests : valeur fixe).
  final bool Function()? hasRealSession;

  final Duration armDelay;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  Timer? _arm;
  bool _armed = false;
  int _measureRetries = 0;

  @override
  void dispose() {
    _arm?.cancel();
    super.dispose();
  }

  bool _signedIn() =>
      widget.hasRealSession?.call() ??
      getIt<FirebaseSessionProbe>().hasRealSession;

  /// Arme ou désarme le délai selon l'éligibilité, jamais pendant la
  /// construction de l'arbre.
  void _sync(bool eligible) {
    if (eligible) {
      if (_armed || _arm != null) return;
      _arm = Timer(widget.armDelay, () {
        _arm = null;
        if (mounted) setState(() => _armed = true);
      });
      return;
    }
    _arm?.cancel();
    _arm = null;
    _measureRetries = 0;
    if (_armed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _armed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockers = widget.blockers ?? assistantBubbleBlockers;
    return BlocBuilder<TourCubit, TourState>(
      builder: (context, state) => ValueListenableBuilder<bool>(
        valueListenable: blockers.active,
        builder: (context, blocked, _) {
          final step = state.step;
          final onTop = ModalRoute.of(context)?.isCurrent ?? true;
          final eligible =
              step != null &&
              widget.tabIndex == 0 &&
              !blocked &&
              onTop &&
              MediaQuery.viewInsetsOf(context).bottom == 0 &&
              _signedIn();
          _sync(eligible);
          if (!eligible || !_armed) return const SizedBox.shrink();

          final target = TourAnchor.rectOf(step);
          final box = context.findRenderObject();
          if (target == null || box is! RenderBox || !box.hasSize) {
            // Le bouton n'est pas encore mesuré : un nouvel essai à l'image
            // suivante, quelques fois seulement.
            if (_measureRetries < 8) {
              _measureRetries++;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            }
            return const SizedBox.shrink();
          }
          _measureRetries = 0;
          final local = box.globalToLocal(target.topLeft) & target.size;
          // Un bouton défilé hors de la vue (chips) ne reçoit pas de bulle.
          if (!(Offset.zero & box.size).contains(local.center) ||
              local.left < 0 ||
              local.right > box.size.width) {
            return const SizedBox.shrink();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.read<TourCubit>().shown();
          });
          return _TourBubble(
            step: step,
            target: local,
            screen: box.size,
            isLast: step == TourStep.activities,
          );
        },
      ),
    );
  }
}

class _TourBubble extends StatelessWidget {
  const _TourBubble({
    required this.step,
    required this.target,
    required this.screen,
    required this.isLast,
  });

  final TourStep step;
  final Rect target;
  final Size screen;
  final bool isLast;

  static const double _maxWidth = 280;
  static const double _margin = 12;
  static const double _gap = 12;
  static const double _arrow = 12;

  String _title(AppLocalizations l) => switch (step) {
    TourStep.plus => l.tourStepPlusTitle,
    TourStep.modeTrips => l.homeModeSelectorSending,
    TourStep.modeParcels => l.homeModeSelectorTraveling,
    TourStep.activities => l.shellTabActivity,
    TourStep.urgent => l.tourStepUrgentTitle,
    TourStep.favorites => l.favoritesTitle,
    TourStep.support => l.tourStepSupportTitle,
  };

  String _body(AppLocalizations l) => switch (step) {
    TourStep.plus => l.tourStepPlusBody,
    TourStep.modeTrips => l.tourStepModeTripsBody,
    TourStep.modeParcels => l.tourStepModeParcelsBody,
    TourStep.activities => l.tourStepActivitiesBody,
    TourStep.urgent => l.tourStepUrgentBody,
    TourStep.favorites => l.tourStepFavoritesBody,
    TourStep.support => l.tourStepSupportBody,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<TourCubit>();

    final width = math.min(_maxWidth, screen.width - 2 * _margin);
    final left = (target.center.dx - width / 2).clamp(
      _margin,
      screen.width - width - _margin,
    );
    final arrowX = (target.center.dx - left).clamp(
      _arrow * 2,
      width - _arrow * 2,
    );
    // Sous le bouton quand il est dans la moitié haute de l'écran, au-dessus
    // sinon (barre d'onglets).
    final below = target.center.dy < screen.height * 0.5;
    final bg = cs.inverseSurface;
    final fg = cs.onInverseSurface;
    final accent = cs.inversePrimary;

    final bubble = Material(
      color: bg,
      elevation: 6,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.tourCounter(step.index + 1, kTourTotalSteps),
              style: tt.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              _title(l),
              style: tt.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(_body(l), style: tt.bodyMedium?.copyWith(color: fg)),
            const SizedBox(height: DonySpacing.sm),
            if (step.isContextual)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('tour-next'),
                  onPressed: cubit.next,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: Text(l.tourGotIt, maxLines: 1, softWrap: false),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton(
                      key: const Key('tour-skip'),
                      onPressed: cubit.skip,
                      style: TextButton.styleFrom(
                        foregroundColor: fg.withValues(alpha: 0.7),
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        l.tourSkip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('tour-next'),
                    onPressed: cubit.next,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: Text(
                      isLast ? l.tourDone : l.tourNext,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    final pointer = Positioned(
      left: arrowX - _arrow / 2,
      top: below ? -_arrow / 2 + 1 : null,
      bottom: below ? null : -_arrow / 2 + 1,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: SizedBox(
          width: _arrow,
          height: _arrow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );

    final ringRadius = math.min(target.width, target.height) / 2;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: target.inflate(4),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  ringRadius < 26 ? ringRadius + 4 : 18,
                ),
                border: Border.all(color: cs.primary, width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: width,
          top: below ? target.bottom + _gap : null,
          bottom: below ? null : screen.height - target.top + _gap,
          child: Semantics(
            container: true,
            liveRegion: true,
            label: '${_title(l)}. ${_body(l)}',
            child: Stack(clipBehavior: Clip.none, children: [bubble, pointer]),
          ),
        ),
      ],
    );
  }
}
