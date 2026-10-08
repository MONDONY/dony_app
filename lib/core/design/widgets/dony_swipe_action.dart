import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Action d'un volet `Slidable` : icône lisible et libellé jamais tronqué.
///
/// `SlidableAction` dessine une icône de 24 et un libellé qui s'ellipse dès que
/// le volet est étroit : « Archi… », « Supp… » en français (FLUTTER-FR). Ici
/// l'icône fait 28 et le libellé tient sur une ligne : s'il dépasse malgré la
/// largeur prévue par l'`extentRatio`, il rétrécit au lieu d'être coupé.
class DonySwipeAction extends StatelessWidget {
  const DonySwipeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderRadius = BorderRadius.zero,
  });

  final IconData icon;
  final String label;
  final SlidableActionCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final BorderRadius borderRadius;

  /// Taille de l'icône, partagée par les volets de l'app.
  static const double iconSize = 28;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return CustomSlidableAction(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderRadius: borderRadius,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: foregroundColor),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: tt.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
