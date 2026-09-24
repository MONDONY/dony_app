// Explication du garde-fou « Pour mes trajets », extraite de l'ancienne
// `search_filter_sheet.dart` (supprimée avec le reste de la feuille de
// filtres, remplacée par `SearchComposerScreen`). Cette fonction, elle,
// reste vivante : elle a deux appelants réels, la rangée de chips de
// `home_screen.dart` (pastille hors composer) et `SearchComposerScreen`
// lui-même (pastille dans le bloc « FILTRES RAPIDES » du mode colis).

import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Explique pourquoi « Pour mes trajets » est indisponible et propose l'action
/// qui le débloque. Source unique de cette formulation : le filtre est offert à
/// deux endroits, la rangée de chips et l'écran de composition, et les deux
/// doivent dire la même chose.
///
/// [sheetsToPop] vaut 1 dans les deux appels actuels (rangée de chips et
/// écran de composition) : dans les deux cas, une seule feuille (celle-ci)
/// est ouverte par-dessus l'écran hôte, qui lui-même n'est pas une feuille et
/// n'a donc rien à fermer.
///
/// La navigation appartient à l'appelant, seul à survivre à la fermeture : lui
/// seul peut attendre le retour de la création de trajet puis recharger le
/// résumé, sans quoi la pastille resterait grisée au retour.
Future<void> showNoActiveTripSheet(
  BuildContext context, {
  required int sheetsToPop,
  VoidCallback? onPublishTrip,
}) {
  final sheetNavigator = Navigator.of(context, rootNavigator: true);
  final l = context.l10n;
  return DonyBottomSheet.show<void>(
    context,
    title: l.homeNoActiveTripTitle,
    subtitle: l.homeNoActiveTripBody,
    stickyBottom: DonyButton(
      label: l.homeNoActiveTripPublish,
      onPressed: () {
        for (var i = 0; i < sheetsToPop; i++) {
          sheetNavigator.pop();
        }
        onPublishTrip?.call();
      },
    ),
    child: const SizedBox.shrink(),
  );
}
