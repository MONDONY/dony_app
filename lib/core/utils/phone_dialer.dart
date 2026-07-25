import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre le composeur téléphonique avec [phone], et retombe sur la copie du numéro
/// si l'appareil ne sait pas traiter un `tel:`.
///
/// Ce repli n'est pas théorique : les émulateurs Android et le simulateur iOS n'ont
/// aucune application téléphone, et certaines tablettes non plus. Le numéro venant
/// d'être obtenu du serveur, le perdre avec un simple message d'erreur serait
/// dommage — on le propose donc à la copie.
///
/// Point d'entrée unique des trois endroits qui appellent une contrepartie (carte
/// expéditeur, carte voyageur, en-tête de conversation).
Future<void> dialPhoneNumber(BuildContext context, String? phone) async {
  if (phone == null || phone.isEmpty) {
    DonySnackbar.show(
      context,
      message: 'Aucun numéro disponible pour ce contact',
      type: DonySnackbarType.warning,
    );
    return;
  }

  final uri = Uri(scheme: 'tel', path: phone);
  bool launched = false;
  try {
    // externalApplication explicite : on veut le composeur du système, pas une vue
    // interne. La visibilité du paquet dialer est déclarée dans le <queries> du
    // AndroidManifest — sans elle, canLaunchUrl renvoie false sur Android 11+.
    launched = await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (launched || !context.mounted) {
    return;
  }

  // Pas de composeur : on montre le numéro et on offre de le copier plutôt que de
  // laisser l'utilisateur sans rien.
  DonySnackbar.show(
    context,
    message: 'Aucune application téléphone. Numéro : $phone',
    type: DonySnackbarType.warning,
    duration: const Duration(seconds: 8),
    actionLabel: 'Copier',
    onAction: () => Clipboard.setData(ClipboardData(text: phone)),
  );
}
