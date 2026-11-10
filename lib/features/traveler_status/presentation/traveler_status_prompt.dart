import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
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
/// voyageur n'a pas répondu. Ne bloque jamais : « Plus tard », un geste ou
/// l'ouverture du formulaire GP Pro laissent l'appelant publier quand même (le
/// voyageur publie comme particulier pendant la validation). Si la limite
/// mensuelle est atteinte, c'est le 403 du back qui arrête la publication.
///
/// Rend la réponse, ou `null` si rien n'a été demandé.
Future<TravelerStatusOutcome?> remindTravelerStatusBeforePublish(
  BuildContext context,
) async {
  if (!travelerStatusMissing(context)) return null;
  return TravelerStatusSheet.show(context);
}
