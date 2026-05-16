import 'package:flutter/material.dart';

/// Ligne de perforation d'un billet : pointillés + deux encoches latérales.
/// [notchColor] doit être la couleur du fond derrière le billet.
class BilletPerforation extends StatelessWidget {
  final Color notchColor;
  const BilletPerforation({super.key, required this.notchColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(
              40,
              (i) => Expanded(
                child: Container(
                  height: 1.5,
                  color: i.isEven ? cs.outline : Colors.transparent,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-8, 0),
              child: _notch(notchColor),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Transform.translate(
              offset: const Offset(8, 0),
              child: _notch(notchColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notch(Color c) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
