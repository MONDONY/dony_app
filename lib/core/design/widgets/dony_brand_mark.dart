import 'package:flutter/material.dart';

/// Pastille d'un réseau mobile money : initiale sur la couleur de la marque.
///
/// Les couleurs sont celles des marques, pas des tokens du thème : elles ne
/// changent pas en mode sombre, comme un logo. Une marque inconnue retombe
/// sur `primaryContainer` et sa première lettre. Les logos officiels sont
/// hors périmètre (spec du 2026-09-11) : cette pastille les remplace.
class DonyBrandMark extends StatelessWidget {
  const DonyBrandMark({super.key, required this.brand, this.size = 40});

  /// Marque en majuscules (`ORANGE`, `WAVE`, `MTN`, `MOOV`, `FREE`...),
  /// c'est-à-dire le préfixe d'un code pawaPay avant le premier `_`.
  final String brand;
  final double size;

  /// (fond, texte, sigle) par marque.
  static const Map<String, (Color, Color, String)> _palette = {
    'ORANGE': (Color(0xFFFF7900), Color(0xFFFFFFFF), 'O'),
    'WAVE': (Color(0xFF20B2E6), Color(0xFFFFFFFF), 'W'),
    'MTN': (Color(0xFFFFCC00), Color(0xFF0A2540), 'MTN'),
    'MOOV': (Color(0xFF0066B3), Color(0xFFFFFFFF), 'M'),
    'FREE': (Color(0xFFCD1E25), Color(0xFFFFFFFF), 'F'),
    'AIRTEL': (Color(0xFFE40000), Color(0xFFFFFFFF), 'A'),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final key = brand.trim().toUpperCase();
    final entry = _palette[key];
    final bg = entry?.$1 ?? cs.primaryContainer;
    final fg = entry?.$2 ?? cs.primary;
    final text = entry?.$3 ?? (key.isEmpty ? '?' : key.substring(0, 1));
    return Semantics(
      label: brand,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size / 4),
        ),
        // Exclut le sigle de la sémantique : sans ça, Flutter fusionne le
        // label du Text ('W') dans le même nœud que celui du Semantics
        // englobant ('WAVE'), et un lecteur d'écran annonce « WAVE, W ».
        child: ExcludeSemantics(
          child: Text(
            text,
            style: tt.headlineSmall?.copyWith(
              fontSize: text.length > 1 ? size * 0.28 : size * 0.45,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
