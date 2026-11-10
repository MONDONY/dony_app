import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_sheet.dart';
import 'package:flutter/widgets.dart';

/// Un voyageur connecté qui n'a pas encore répondu « particulier ou GP Pro ».
/// Un GP Pro (badge déjà accordé) a répondu : on ne lui demande rien. Sans
/// compte connu (écran monté hors de l'`AuthBloc`), il n'y a rien à demander.
bool travelerStatusMissing(BuildContext context) {
  final user = maybeRead<AuthBloc>(context)?.state.currentUser;
  return user != null && user.travelerStatus == null && !user.gpPro;
}

/// Question du statut au clic sur « Publier », à chaque publication tant que le
/// voyageur n'a pas répondu. « Plus tard », un geste, « Particulier » ou une
/// demande GP Pro envoyée laissent l'appelant publier (le voyageur publie comme
/// particulier pendant la validation). Un formulaire GP Pro quitté sans envoyer
/// la demande rend [TravelerStatusOutcome.gpProAbandoned] : l'appelant ne publie
/// rien. Si la limite mensuelle est atteinte, c'est le 403 du back qui arrête
/// la publication.
///
/// Une demande GP Pro déjà ouverte (en validation ou en attente d'identité)
/// vaut réponse : la question ne revient pas, la publication suit son cours (à
/// la limite, le back répond 403 `gp-pro-pending`). Une lecture de la demande en
/// échec ne change rien : on pose la question.
///
/// Rend la réponse, ou `null` si rien n'a été demandé.
Future<TravelerStatusOutcome?> remindTravelerStatusBeforePublish(
  BuildContext context,
) async {
  if (!travelerStatusMissing(context)) return null;
  if (await _gpProApplicationOpen()) return null;
  if (!context.mounted) return null;
  return TravelerStatusSheet.show(context);
}

/// Délai de la lecture de la demande avant la feuille : au-delà, la question est
/// posée (on ne fait pas attendre le voyageur sur une lecture accessoire).
const Duration _applicationReadTimeout = Duration(seconds: 8);

Future<bool> _gpProApplicationOpen() async {
  try {
    final status = await getIt<GpProRepository>().fetchStatus().timeout(
      _applicationReadTimeout,
    );
    return status.isOpen;
  } on Object {
    return false;
  }
}
