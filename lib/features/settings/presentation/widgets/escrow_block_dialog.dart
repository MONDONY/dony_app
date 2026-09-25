import 'package:dony/core/design/widgets/dony_dialog.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;
    final goToShipments = await DonyDialog.show(
      context,
      title: l.deletionEscrowBlockedTitle,
      message: l.deletionEscrowBlockedMessage,
      confirmLabel: l.deletionEscrowBlockedCta,
      cancelLabel: l.commonClose,
      iconAsset: 'lock',
    );
    if (goToShipments == true && context.mounted) {
      context.go('/announcements');
    }
  }
}
