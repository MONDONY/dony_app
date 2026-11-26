import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';

/// Relit le profil auprès du serveur avant d'afficher un blocage « identité à
/// vérifier ». Le profil en cache peut être périmé : l'identité a pu être
/// validée hors du flux Didit (admin, webhook) sans qu'aucune push n'arrive.
///
/// Si le serveur dit VERIFIED, le profil de l'app est resynchronisé
/// (`AuthUserSynced`) et la fonction rend `true` : l'appelant laisse passer.
/// Sans réponse (hors ligne, délai dépassé, dépôt absent), elle rend `false` :
/// le blocage reste, comme avant.
Future<bool> recheckKycVerified(
  AuthBloc authBloc, {
  Duration timeout = const Duration(seconds: 5),
}) async =>
    await recheckKycStatus(authBloc, timeout: timeout) == kKycVerifiedStatus;

/// Statut d'identité renvoyé par le serveur (`VERIFIED`, `PENDING`,
/// `REJECTED`, `NOT_STARTED`…), profil de l'app resynchronisé au passage.
/// `null` sans réponse (hors ligne, délai dépassé, dépôt absent).
Future<String?> recheckKycStatus(
  AuthBloc authBloc, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final repository = getItSafe<AuthRepository>();
  if (repository == null) return null;
  try {
    final user = await repository.getProfile().timeout(timeout);
    if (!authBloc.isClosed) authBloc.add(AuthUserSynced(user));
    return user.isKycVerified ? kKycVerifiedStatus : user.kycStatus;
  } on Object {
    return null;
  }
}

/// Statut d'une identité vérifiée.
const String kKycVerifiedStatus = 'VERIFIED';
