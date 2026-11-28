import 'package:dony/features/tour/bloc/tour_cubit.dart';
import 'package:flutter/widgets.dart';

/// Repère un bouton de l'app pour que le petit tour sache où poser sa bulle.
///
/// Pas de `GlobalKey` : deux exemplaires montés en même temps (tests, écrans
/// reconstruits) en feraient planter l'arbre. Le dernier monté l'emporte, et
/// un exemplaire démonté ne retire que son propre repère.
class TourAnchor extends StatefulWidget {
  const TourAnchor({super.key, required this.step, required this.child});

  final TourStep step;
  final Widget child;

  /// Zone à l'écran du bouton repéré pour [step], ou `null` s'il n'est pas
  /// monté, pas encore mesuré ou hors de la vue.
  static Rect? rectOf(TourStep step) {
    final context = _anchors[step];
    if (context == null || !context.mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static final Map<TourStep, BuildContext> _anchors = {};

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  @override
  void initState() {
    super.initState();
    TourAnchor._anchors[widget.step] = context;
  }

  @override
  void dispose() {
    if (TourAnchor._anchors[widget.step] == context) {
      TourAnchor._anchors.remove(widget.step);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
