import 'package:dony/core/error/app_exception.dart';

/// Code d'erreur à signaler pour une lecture ratée des frais d'annulation
/// (aperçu ou configuration), ou `null` quand l'échec est attendu et ne se
/// signale pas : un 404, back antérieur à la route.
///
/// `invalid_payload` pour un corps illisible ([FormatException],
/// [TypeError]), sinon le code de l'[AppException], `unknown` sans code.
String? cancellationFeeFailureCode(Object error) {
  final malformed = error is FormatException || error is TypeError;
  final app = malformed ? null : unwrapDioError(error);
  if (app is NotFoundException) return null;
  return malformed ? 'invalid_payload' : app?.code ?? 'unknown';
}
