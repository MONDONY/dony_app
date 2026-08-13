import 'package:dony/core/design/widgets/dony_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Averti l'utilisateur que la suppression est bloquée par un envoi dont les
/// fonds sont encore en séquestre, avec un raccourci direct vers ses envois.
///
/// Utilise le style standardisé [DonyDialog] (icône, texte explicite) au lieu
/// d'un `AlertDialog` générique — l'ancien rendu ne se distinguait pas d'une
/// erreur système et n'expliquait pas clairement la marche à suivre.
abstract final class EscrowBlockDialog {
  static Future<void> show(BuildContext context) async {
    final goToShipments = await DonyDialog.show(
      context,
      title: 'Suppression impossible pour l\'instant',
      message:
          'Un de vos envois est en cours de livraison et ses fonds '
          'sont bloqués en séquestre. Vous pourrez supprimer votre compte '
          'dès que la livraison aura été confirmée.',
      confirmLabel: 'Voir mes envois',
      cancelLabel: 'Fermer',
      iconAsset: 'lock',
    );
    if (goToShipments == true && context.mounted) {
      context.go('/announcements');
    }
  }
}
