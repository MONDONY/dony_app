import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Prévient que l'étape est enregistrée sans la photo refusée par le
/// serveur (limite de photos du colis, taille).
void warnTrackingPhotoDropped(BuildContext context) => DonySnackbar.show(
  context,
  message: context.l10n.trackingPhotoDropped,
  type: DonySnackbarType.warning,
);
