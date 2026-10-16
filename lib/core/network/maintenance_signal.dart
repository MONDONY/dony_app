import 'dart:async';

import 'package:dio/dio.dart';

/// Code ProblemDetail du 503 renvoyé par le back pendant la maintenance
/// (dony-back `MaintenanceFilter`).
const kMaintenanceProblemCode = 'maintenance';

/// Vrai pour le 503 de maintenance : à ne pas rejouer (le retry transitoire
/// insisterait trois fois pour rien) ni rapporter à Sentry (ce n'est pas une
/// panne, c'est un choix de l'administrateur).
bool isMaintenanceResponse(Response<dynamic>? response) {
  if (response?.statusCode != 503) return false;
  final data = response?.data;
  return data is Map && data['code'] == kMaintenanceProblemCode;
}

/// Ce que le 503 de maintenance apprend à l'application.
class MaintenanceNotice {
  const MaintenanceNotice({this.message, this.estimatedEndAt});

  /// Lit le corps ProblemDetail du 503 : `detail` (message de l'admin, ou
  /// texte par défaut du serveur) et `estimatedEndAt` (ISO 8601 UTC).
  factory MaintenanceNotice.fromProblem(Object? data) {
    if (data is! Map) return const MaintenanceNotice();
    final end = data['estimatedEndAt'];
    return MaintenanceNotice(
      message: data['detail'] as String?,
      estimatedEndAt: end is String ? DateTime.tryParse(end) : null,
    );
  }

  final String? message;
  final DateTime? estimatedEndAt;
}

/// Pont entre la couche réseau et la feature maintenance : chaque réponse 503
/// `maintenance` y est publiée, et `MaintenanceCubit` affiche aussitôt l'écran
/// de maintenance, même si le document Firestore n'a pas encore été reçu.
class MaintenanceSignal {
  final _controller = StreamController<MaintenanceNotice>.broadcast();

  Stream<MaintenanceNotice> get notices => _controller.stream;

  void notify(MaintenanceNotice notice) => _controller.add(notice);
}

/// Publie le 503 de maintenance sur [MaintenanceSignal], puis laisse
/// l'erreur suivre son cours dans la chaîne.
class MaintenanceInterceptor extends Interceptor {
  MaintenanceInterceptor(this._signal);

  final MaintenanceSignal _signal;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isMaintenanceResponse(err.response)) {
      _signal.notify(MaintenanceNotice.fromProblem(err.response?.data));
    }
    handler.next(err);
  }
}
