import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Couleurs de l'étape 3 « Le prix », celles de la maquette validée
/// (`sorties/maquettes/demande_etape3.html`).
///
/// En clair, les valeurs littérales de la maquette (certaines ne sont pas
/// celles du thème : vert, rouge, avertissement). En sombre, l'équivalent du
/// thème, pour ne pas poser de pastels clairs sur un fond sombre.
class WizardPalette {
  const WizardPalette._(this._cs);

  factory WizardPalette.of(BuildContext context) =>
      WizardPalette._(Theme.of(context).colorScheme);

  factory WizardPalette.fromScheme(ColorScheme cs) => WizardPalette._(cs);

  final ColorScheme _cs;

  bool get _light => _cs.brightness == Brightness.light;

  Color _pick(int lightValue, Color dark) => _light ? Color(lightValue) : dark;

  Color get blue => _cs.primary;
  Color get white => _cs.surface;
  Color get border => _cs.outline;
  Color get blue50 => _pick(0xFFEDF2FF, _cs.primaryContainer);
  Color get n100 => _pick(0xFFF2F1ED, _cs.surfaceContainerHighest);
  Color get n500 => _pick(0xFF797367, _cs.onSurfaceVariant);
  Color get n600 => _pick(0xFF54504A, _cs.onSurfaceVariant);
  Color get n800 => _pick(0xFF25231F, _cs.onSurface);
  Color get dot => _pick(0xFFA8A294, _cs.onSurfaceVariant);
  Color get placeholder => _pick(0xFFB5B0A5, _cs.onSurfaceVariant);
  Color get red => _pick(0xFFC0392B, _cs.error);
  Color get info => _pick(0xFFEAF2FF, _cs.infoLight);
  Color get infoBorder => _pick(0xFFB9D0FF, _cs.info.withValues(alpha: 0.35));
  Color get summaryBorder =>
      _pick(0xFFCFDCFF, _cs.primary.withValues(alpha: 0.2));
  Color get calcText => _pick(0xFF083CAB, _cs.primary);
  Color get ok => _pick(0xFFE4F3EA, _cs.successLight);
  Color get okText => _pick(0xFF1B7A46, _cs.success);
  Color get okRule => _pick(0xFFB9DCC6, _cs.success.withValues(alpha: 0.3));
  Color get warnBg => _pick(0xFFFFF1E8, _cs.warningLight);
  Color get warnBorder => _pick(0xFFF2B898, _cs.warning.withValues(alpha: 0.5));
  Color get warnText => _pick(0xFF7A3A18, _cs.onSurface);

  /// Style de la maquette : police du corps de l'app, taille et graisse
  /// littérales, interligne « normal » sauf indication.
  static TextStyle text({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: DonyTypography.fontBody,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
