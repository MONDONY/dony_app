import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:flutter/widgets.dart';

/// À appeler une fois l'acceptation d'un colis aboutie, côté voyageur. Ne
/// bloque rien et n'attend rien : la feuille (au plus une par installation)
/// s'ouvre par-dessus l'écran courant, et un refus ne change aucun parcours.
void askTrackingConsentAfterAccept(BuildContext context) {
  if (!getIt.isRegistered<TrackingConsentCubit>()) return;
  unawaited(getIt<TrackingConsentCubit>().onParcelAccepted(context));
}
