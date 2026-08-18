import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DonyKeypad extends StatelessWidget {
  const DonyKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.onDecimal,
    this.decimalLabel = ',',
    this.enabled = true,
  }) : assert(
         onBiometric == null || onDecimal == null,
         'Le slot bas-gauche ne peut porter qu\'une seule fonction : '
         'biométrie (saisie de code) ou séparateur décimal (saisie de montant).',
       );

  final void Function(String) onDigit;
  final VoidCallback onDelete;

  /// Occupe le slot bas-gauche pour un déverrouillage biométrique.
  /// Exclusif avec [onDecimal].
  final VoidCallback? onBiometric;

  /// Occupe le slot bas-gauche pour un séparateur décimal, quand le pavé sert
  /// à saisir un montant et non un code. Exclusif avec [onBiometric].
  final VoidCallback? onDecimal;

  /// Caractère affiché sur la touche décimale. Virgule par défaut, la
  /// convention francophone.
  final String decimalLabel;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadKey(
              onTap: onBiometric ?? onDecimal,
              enabled: enabled && (onBiometric ?? onDecimal) != null,
              child: onBiometric != null
                  ? const DonyIcon('fingerprint', size: 28)
                  : onDecimal != null
                  ? Text(
                      decimalLabel,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            _KeypadKey(
              onTap: () => onDigit('0'),
              enabled: enabled,
              child: const Text(
                '0',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 12),
            _KeypadKey(
              onTap: onDelete,
              enabled: enabled,
              child: const DonyIcon('delete'),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05);
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          _KeypadKey(
            onTap: () => onDigit(digits[i]),
            enabled: enabled,
            child: Text(
              digits[i],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Couleurs lues au thème : le pavé sert aussi bien sur un fond clair
    // (saisie de code) que sur les surfaces chaudes de la grille de prix, et
    // il doit rester lisible en mode sombre.
    final keyColor = enabled
        ? cs.surfaceContainerHighest
        : cs.surfaceContainerLow;
    final inkColor = enabled
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: 0.45);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: (enabled && onTap != null) ? onTap : null,
        borderRadius: BorderRadius.circular(40),
        splashColor: cs.primary.withValues(alpha: 0.15),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: keyColor),
          child: DefaultTextStyle(
            style: TextStyle(
              color: inkColor,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
            child: IconTheme(
              data: IconThemeData(color: inkColor),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
