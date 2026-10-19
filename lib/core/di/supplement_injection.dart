import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:get_it/get_it.dart';

/// Paiement du supplément de prix par l'expéditeur. Appelé par
/// `setupDependencies` (`lib/core/di/injection.dart`). Le rapporteur
/// d'erreurs est obligatoire : sans lui, une confirmation de paiement en
/// échec n'atteindrait jamais Sentry.
void registerSupplementPaymentDependencies(GetIt getIt) {
  getIt.registerFactory<SupplementPaymentCubit>(
    () => SupplementPaymentCubit(
      getIt<BidSupplementRepository>(),
      getIt<AnalyticsService>(),
      errorReporter: getIt<ErrorReportingService>(),
    ),
  );
}
