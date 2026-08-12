import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/error_reporting_service.dart';

/// Sink inerte : les tests d'écran vérifient la navigation et les états, pas la
/// remontée d'erreurs, qui a sa propre couverture dans
/// `test/core/services/error_reporting_service_test.dart`.
class NoopErrorReportingSink implements ErrorReportingSink {
  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async {}
}

/// Enregistre un [ErrorReportingService] inerte dans GetIt.
///
/// Toute surface qui construit `PaymentSheetBloc` passe par
/// `DonyPaymentSheet.show`, qui résout ce service via GetIt : sans cet
/// enregistrement, le widget lève avant même d'atteindre les assertions.
void registerNoopErrorReporting() {
  if (getIt.isRegistered<ErrorReportingService>()) {
    getIt.unregister<ErrorReportingService>();
  }
  getIt.registerSingleton<ErrorReportingService>(
    ErrorReportingService(NoopErrorReportingSink()),
  );
}
