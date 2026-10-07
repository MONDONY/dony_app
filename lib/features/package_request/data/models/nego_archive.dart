import 'package:dio/dio.dart' show DioException;
import 'package:dony/core/error/app_exception.dart';
import 'package:equatable/equatable.dart';

/// Action de rangement d'une discussion de prix terminée, pour soi seulement
/// (yadony-back #423) : l'autre participant garde la discussion.
enum NegoArchiveAction { archive, unarchive, delete }

/// Issue d'une [NegoArchiveAction], telle que l'écran doit la traiter.
enum NegoArchiveOutcome {
  /// Le serveur a pris l'action en compte.
  success,

  /// 409 `negotiation-still-open` : le fil s'est rouvert ou n'était pas
  /// terminé. Le rechargement remet la tuile à sa place.
  stillOpen,

  /// 403 (plus participant) ou 404 métier (fil retiré) : la tuile n'a plus
  /// lieu d'être, elle reste retirée.
  gone,

  /// 404 sans code métier ou 405 : backend antérieur à #423, l'endpoint
  /// n'existe pas encore. Retour arrière, sans crash.
  unsupported,

  /// Tout autre échec (réseau, 5xx) : retour arrière.
  failed,
}

/// Résultat ponctuel d'une action, porté par l'état des BLoCs de liste.
///
/// [seq] rend chaque résultat unique : deux échecs identiques d'affilée
/// doivent tous deux déclencher le `listener` de l'écran.
class NegoArchiveResult extends Equatable {
  const NegoArchiveResult({
    required this.id,
    required this.action,
    required this.outcome,
    required this.seq,
    this.fromDetail = false,
    this.error,
  });

  /// Id du fil (demande) ou du bid (trajet).
  final String id;
  final NegoArchiveAction action;
  final NegoArchiveOutcome outcome;
  final int seq;

  /// Action lancée depuis l'écran de détail : c'est lui qui la commente et
  /// revient à la liste. La liste, montée dessous, ne doit pas la doubler.
  final bool fromDetail;

  /// Erreur d'origine, pour [NegoArchiveOutcome.failed].
  final Object? error;

  bool get isSuccess => outcome == NegoArchiveOutcome.success;

  @override
  List<Object?> get props => [id, action, outcome, seq, fromDetail, error];
}

/// Code ProblemDetail du 409 renvoyé sur un fil encore ouvert.
const kNegotiationStillOpenCode = 'negotiation-still-open';

/// Classe une erreur d'archivage / suppression.
///
/// Un 404 métier porte un `code` (`thread/not-found`, `negotiation-not-found`,
/// …) ; celui d'une route inconnue (backend ancien) n'en porte pas, et
/// `mapHttpError` le range alors sous le code générique `NOT_FOUND`. Le 405
/// (DELETE sur une route qui n'accepte que GET) n'a pas non plus de code et
/// devient `NetworkException('405')`.
NegoArchiveOutcome classifyNegoArchiveError(Object error) {
  final e = _unwrap(error);
  return switch (e) {
    ConflictException() => NegoArchiveOutcome.stillOpen,
    ForbiddenException() => NegoArchiveOutcome.gone,
    NotFoundException(:final code) =>
      code == null || code == 'NOT_FOUND'
          ? NegoArchiveOutcome.unsupported
          : NegoArchiveOutcome.gone,
    NetworkException(:final code) when code == '405' =>
      NegoArchiveOutcome.unsupported,
    _ => NegoArchiveOutcome.failed,
  };
}

/// Sans intercepteur (tests, client nu), une [DioException] brute arrive ici :
/// on la ramène au même [AppException] que `mapHttpError`.
Object _unwrap(Object error) {
  if (error is DioException && error.error is! AppException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final code = data is Map ? data['code'] as String? : null;
    return switch (status) {
      409 => ConflictException('', code: code),
      403 => ForbiddenException('', code),
      404 => NotFoundException(apiCode: code),
      405 => const NetworkException('', code: '405'),
      _ => unwrapDioError(error),
    };
  }
  return unwrapDioError(error);
}
