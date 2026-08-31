import 'package:dony/core/config/pro_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Dialogue « limite atteinte » renvoyé par le serveur (`pro-limit-reached`,
/// `draft-limit-reached`), partagé par la création de trajet, le détail d'un
/// trajet et la création d'une demande d'envoi.
///
/// Rend `true` si l'utilisateur a choisi de passer en PRO : c'est l'appelant
/// qui navigue, le dialogue n'a pas à connaître le routeur.
///
/// Quand l'offre PRO est fermée (`pro_enabled=false`), l'invitation « Passer
/// en PRO » disparaît : elle mènerait à une route redirigée vers le profil.
/// Le serveur lève alors les quotas standard, donc ce dialogue ne peut plus
/// se produire qu'au plafond PRO lui-même, sans issue à proposer — un seul
/// bouton, jamais `true`.
Future<bool> showProLimitReachedDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!proEnabledListenable.value) {
    await DonyDialog.show(
      context,
      title: title,
      message: message,
      confirmLabel: 'Compris',
      cancelLabel: null,
    );
    return false;
  }
  final confirmed = await DonyDialog.show(
    context,
    title: title,
    message: message,
    confirmLabel: 'Passer en PRO',
    cancelLabel: 'Plus tard',
  );
  return confirmed == true;
}
