import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_sheet.dart';
import 'package:flutter/widgets.dart';

/// Un voyageur connecté qui n'a pas encore déclaré son statut légal. Sans
/// compte connu (écran monté hors de l'`AuthBloc`), il n'y a rien à demander.
bool travelerStatusMissing(BuildContext context) {
  final user = maybeRead<AuthBloc>(context)?.state.currentUser;
  return user != null && user.travelerStatus == null;
}

/// Rappel avant une publication : ouvre la feuille de déclaration (avec
/// « Plus tard ») si le statut manque. Ne bloque jamais : fermée ou reportée,
/// l'appelant publie quand même. Si Yadony exige la déclaration, c'est le 403
/// `traveler-status-required` du back qui rouvre la feuille, obligatoire.
///
/// Rend `true` si le statut vient d'être déclaré.
Future<bool> remindTravelerStatusBeforePublish(BuildContext context) async {
  if (!travelerStatusMissing(context)) return false;
  return (await TravelerStatusSheet.show(context)) == true;
}
