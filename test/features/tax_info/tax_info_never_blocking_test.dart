import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arbitrage R1 (DAC7, collecte ciblée) : jamais bloquant. Aucune
/// acceptation de réservation, publication, paiement ni retrait ne dépend de
/// l'écran « Informations fiscales » ni de la lecture `GET
/// /travelers/me/tax-info` : la demande arrive par la notification
/// `TAX_INFO_REQUEST`, envoyée par le back après l'acceptation.
///
/// Garde de structure : seuls le routeur, l'injection, le shell (onglet
/// Profil) et l'entrée du Profil connaissent la fonctionnalité. Un parcours métier qui importerait
/// `features/tax_info/` (et pourrait attendre sa réponse) fait échouer ce
/// test.
void main() {
  test('seuls le routeur, l\'injection et le Profil importent tax_info', () {
    const allowed = {
      'lib/app/router.dart',
      'lib/core/di/injection.dart',
      // Onglet Profil sélectionné : relecture du statut (pas un parcours
      // métier, rien n'attend la réponse).
      'lib/app/main_shell.dart',
      'lib/features/profile/presentation/widgets/profile_tax_info_entry.dart',
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/features/tax_info/')) continue;
      if (path.startsWith('lib/l10n/')) continue;
      if (allowed.contains(path)) continue;
      final source = entity.readAsStringSync();
      if (source.contains('features/tax_info/') ||
          source.contains('/travelers/me/tax-info')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });
}
