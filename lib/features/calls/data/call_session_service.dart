import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';

/// Branche le client d'appel sur la session : connecté à la connexion (pour
/// recevoir les appels), déconnecté à la sortie (plus aucune sonnerie pour
/// l'ancien compte). Jamais bloquant : un échec laisse simplement les appels
/// indisponibles jusqu'à la prochaine connexion.
class CallSessionService {
  CallSessionService(this._repository, this._gateway);

  final CallsRepository _repository;
  final CallGateway _gateway;
  String? _connectedUserId;

  /// Les changements de session passent un par un : deux connexions
  /// rapprochées ne créent pas deux clients, une déconnexion attend la
  /// connexion en cours au lieu de la manquer.
  Future<void> _queue = Future<void>.value();

  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> onSignedIn(UserModel user) => _serial(() async {
    if (_connectedUserId == user.id && _gateway.isConnected) return;
    try {
      if (_gateway.isConnected) await _gateway.disconnect();
      final token = await _repository.fetchToken();
      await _gateway.connect(
        apiKey: token.apiKey,
        user: CallUser(
          id: token.userId,
          name: publicName(user),
          imageUrl: user.avatarUrl,
        ),
        tokenLoader: () async => (await _repository.fetchToken()).token,
      );
      _connectedUserId = user.id;
    } catch (e) {
      _connectedUserId = null;
      AppLog.warn('Calls unavailable for this session: $e');
    }
  });

  Future<void> onSignedOut() => _serial(() async {
    _connectedUserId = null;
    if (_gateway.isConnected) await _gateway.disconnect();
  });

  /// Nom montré à l'autre partie sur l'écran d'appel : prénom + initiale,
  /// comme le back (`publicDisplayName`), jamais le nom complet.
  static String publicName(UserModel user) {
    final first = user.firstName?.trim() ?? '';
    final last = user.lastName?.trim() ?? '';
    if (first.isEmpty) return user.username ?? 'Yadony';
    return last.isEmpty ? first : '$first ${last[0]}.';
  }
}

/// Suit l'état d'authentification : session d'appel ouverte pour un compte
/// connecté, fermée à la déconnexion ou à la suppression du compte.
Future<void> syncCallSession(
  AuthState state,
  CallSessionService service,
) async {
  if (state is AuthAuthenticated) {
    await service.onSignedIn(state.user);
  } else if (state is AuthInitial || state is AuthAccountDeleted) {
    await service.onSignedOut();
  }
}
