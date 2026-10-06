import 'dart:async';

import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:flutter/foundation.dart';

/// Garde l'appel en cours au-delà de son écran (FLUTTER-DF/DG).
///
/// L'appel vivait dans un [CallBloc] créé et fermé par la route
/// `/calls/:callId` : quitter l'écran raccrochait, et le seul moyen de
/// retourner dans l'app pendant un appel était de raccrocher. Le bloc de
/// l'appel est désormais tenu ici : l'écran peut être réduit (l'appel
/// continue, une barre en haut de l'app y ramène) puis rouvert.
///
/// Un seul appel à la fois, comme la passerelle Stream sous-jacente. Le bloc
/// d'un appel terminé est gardé jusqu'au suivant : l'écran peut encore
/// afficher « Appel terminé » le temps de se fermer.
class ActiveCallHolder {
  ActiveCallHolder(this._createBloc);

  final CallBloc Function() _createBloc;

  /// Bloc de l'appel courant (en cours ou dernier terminé), `null` avant le
  /// premier appel de la session.
  final ValueNotifier<CallBloc?> current = ValueNotifier<CallBloc?>(null);

  /// L'écran d'appel est affiché : la barre d'appel se masque.
  final ValueNotifier<bool> callScreenVisible = ValueNotifier<bool>(false);

  /// Photo de l'interlocuteur de l'appel courant, pour rouvrir l'écran
  /// depuis la barre sans repasser par la conversation.
  String? remoteAvatarUrl;

  /// Bloc à donner à l'écran d'appel.
  ///
  /// Un appel déjà en cours est toujours repris, quel que soit
  /// [initialEvent] : retour depuis la barre, ou second appel entrant
  /// pendant le premier (la passerelle n'en gère qu'un). Sans événement
  /// initial, l'écran rouvre le dernier appel s'il existe. Sinon, un nouvel
  /// appel commence et le bloc de l'appel précédent, terminé, est fermé.
  CallBloc blocFor(CallEvent? initialEvent, {String? avatarUrl}) {
    final existing = current.value;
    final reusable = existing != null && !existing.isClosed;
    if (reusable && (existing.isLive || initialEvent == null)) {
      return existing;
    }
    if (reusable) unawaited(existing.close());
    final bloc = _createBloc();
    remoteAvatarUrl = avatarUrl;
    if (initialEvent != null) bloc.add(initialEvent);
    current.value = bloc;
    return bloc;
  }

  /// Appel en cours, écran d'appel masqué : la barre s'affiche.
  bool get showsBanner {
    final bloc = current.value;
    return bloc != null &&
        !bloc.isClosed &&
        bloc.isLive &&
        !callScreenVisible.value;
  }
}
