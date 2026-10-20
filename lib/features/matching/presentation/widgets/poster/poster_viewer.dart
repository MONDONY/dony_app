import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `true` si la personne connectée possède l'annonce dont on montre l'affiche.
///
/// Les affiches (trajet, demande d'envoi) s'ouvrent aussi pour un visiteur qui
/// partage l'annonce d'un autre : le titre et la mesure d'usage diffèrent. Un
/// contexte sans `AuthBloc` (tests, aperçus isolés) se lit comme « pas le
/// propriétaire ».
bool isPosterOwner(BuildContext context, String? ownerId) {
  if (ownerId == null) return false;
  try {
    return context.read<AuthBloc>().state.currentUserId == ownerId;
  } catch (_) {
    return false;
  }
}
