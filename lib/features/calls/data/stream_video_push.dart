import 'dart:async';

import 'package:dony/features/calls/data/stream_call_gateway.dart';

/// Les push de Stream Video (sonnerie d'un appel entrant) arrivent par le même
/// canal FCM que ceux de Yadony : ils doivent aller au SDK d'appel, jamais au
/// chemin des notifications Yadony (notification locale, ACK).
typedef StreamVideoPushHandler =
    Future<void> Function(Map<String, dynamic> data);

bool isStreamVideoPush(Map<String, dynamic> data) =>
    data['sender'] == 'stream.video';

/// Premier plan : relaie un push Stream au client d'appel ouvert. Renvoie vrai
/// si le message était destiné à Stream (l'appelant s'arrête alors là).
bool dispatchStreamVideoPush(
  Map<String, dynamic> data,
  StreamVideoPushHandler? handler,
) {
  if (!isStreamVideoPush(data)) return false;
  if (handler != null) unawaited(handler(data));
  return true;
}

/// Premier plan : branché par l'injection de dépendances sur le client
/// d'appel de la session (`CallGateway.handlePush`).
StreamVideoPushHandler? foregroundStreamVideoPushHandler;

/// Arrière-plan (isolate sans GetIt) : reconstruit un client Stream le temps
/// de faire sonner. Remplaçable en test.
StreamVideoPushHandler backgroundStreamVideoPushHandler =
    handleStreamVideoBackgroundPush;
