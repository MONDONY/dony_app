import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter/material.dart';

/// Équivalent estimé d'un prix au kilo dans la devise du lecteur courant,
/// affiché à côté du montant d'origine (celui de l'annonce, jamais modifié).
///
/// La conversion est calculée UNIQUEMENT par le serveur
/// (`ExchangeRateService.convert`, tâche 10) : ce widget se contente
/// d'afficher [convertedPricePerKg]/[convertedCurrency] tels que reçus, il ne
/// recalcule jamais de taux côté client (le taux vit en base côté backend).
///
/// N'affiche rien quand :
/// - [convertedPricePerKg] ou [convertedCurrency] est absent (le serveur n'a
///   rien eu à convertir, ex. lecteur anonyme ou ancien payload) ;
/// - [convertedCurrency] est identique à [originalCurrency] (rien à
///   convertir, la devise de l'annonce est déjà celle du lecteur).
///
/// Le libellé « environ » est volontaire : ce montant est une ESTIMATION,
/// jamais celui réellement débité (le paiement reste dans la devise de
/// l'annonce). Ne jamais retirer ce mot ni le remplacer par une formulation
/// qui suggère un montant exact.
class ConvertedPriceLabel extends StatelessWidget {
  const ConvertedPriceLabel({
    super.key,
    required this.originalCurrency,
    this.convertedPricePerKg,
    this.convertedCurrency,
    this.style,
  });

  /// Devise de l'annonce (celle du montant d'origine, affiché ailleurs par
  /// l'appelant). Sert uniquement à décider si une conversion a un sens.
  final String originalCurrency;

  /// Prix au kilo déjà converti par le serveur dans [convertedCurrency].
  final double? convertedPricePerKg;

  /// Devise cible de [convertedPricePerKg], celle du lecteur courant.
  final String? convertedCurrency;

  final TextStyle? style;

  bool get _shouldShow {
    final amount = convertedPricePerKg;
    final target = convertedCurrency;
    if (amount == null || target == null) return false;
    return target.toUpperCase() != originalCurrency.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final formatted = formatPriceIn(convertedPricePerKg!, convertedCurrency);
    return Text(
      'environ $formatted/kg',
      style:
          style ??
          tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
    );
  }
}
