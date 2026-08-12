import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Bouton rond « interchanger » réutilisé partout où un champ départ et un
/// champ arrivée se côtoient — la logique d'échange appartient à l'appelant
/// ([CityCorridorFields] ou tout écran qui pose ses propres champs.
class CitySwapButton extends StatefulWidget {
  const CitySwapButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<CitySwapButton> createState() => _CitySwapButtonState();
}

class _CitySwapButtonState extends State<CitySwapButton> {
  // Demi-tour supplémentaire à chaque tap plutôt qu'un booléen 0/180 : deux
  // taps consécutifs tournent bien dans le même sens visuel (jamais de
  // retour en arrière brusque de l'icône).
  double _turns = 0;

  void _handleTap() {
    setState(() => _turns += 0.5);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Interchanger départ et arrivée',
      child: InkWell(
        key: const Key('swap-corridor-cities'),
        onTap: _handleTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: kDonyMinTapTarget,
          height: kDonyMinTapTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surface,
            border: Border.all(color: cs.outline),
            boxShadow: DonyShadow.sm,
          ),
          child: Center(
            child: AnimatedRotation(
              turns: _turns,
              duration: 250.ms,
              curve: Curves.easeOutCubic,
              child: Icon(DonyIcons.swapVertical, size: 20, color: cs.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
