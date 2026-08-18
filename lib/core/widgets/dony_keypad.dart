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
    this.compact = false,
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

  /// Touches resserrées, pour les feuilles où le pavé partage la hauteur avec
  /// un en-tête et un bouton collé en bas. À taille pleine, la dernière rangée
  /// tombe alors sous la ligne de flottaison et n'est atteignable qu'en
  /// faisant défiler, ce qui n'a pas de sens pour saisir un montant.
  /// La cible tactile reste au-dessus de [kDonyMinTapTarget].
  final bool compact;

  final bool enabled;

  double get _keySize => compact ? 62 : 80;
  double get _gap => compact ? 8 : 12;

  @override
  Widget build(BuildContext context) {
    final bottomLeft = onBiometric ?? onDecimal;
    return Column(
      children: [
        _buildRow(const ['1', '2', '3']),
        SizedBox(height: _gap),
        _buildRow(const ['4', '5', '6']),
        SizedBox(height: _gap),
        _buildRow(const ['7', '8', '9']),
        SizedBox(height: _gap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadKey(
              size: _keySize,
              onTap: bottomLeft,
              enabled: enabled && bottomLeft != null,
              // L'assert du constructeur garantit qu'au plus une des deux
              // fonctions occupe ce slot.
              child: onBiometric != null
                  ? const DonyIcon('fingerprint', size: 28)
                  : onDecimal != null
                  ? const Text(',')
                  : const SizedBox.shrink(),
            ),
            SizedBox(width: _gap),
            _KeypadKey(
              size: _keySize,
              onTap: () => onDigit('0'),
              enabled: enabled,
              child: const Text('0'),
            ),
            SizedBox(width: _gap),
            _KeypadKey(
              size: _keySize,
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
          if (i > 0) SizedBox(width: _gap),
          _KeypadKey(
            size: _keySize,
            // Taille et graisse viennent du DefaultTextStyle de _KeypadKey.
            onTap: () => onDigit(digits[i]),
            enabled: enabled,
            child: Text(digits[i]),
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
    required this.size,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;
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
          width: size,
          height: size,
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
