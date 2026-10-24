import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:get_it/get_it.dart';

/// Actions des cartes de modification de colis : annuler, refuser, « les
/// kilos en plus ne sont pas là » et accepter (commission en espèces, 3DS par
/// `Stripe.instance`). Appelé par `setupDependencies`
/// (`lib/core/di/injection.dart`).
void registerAmendmentActionDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<AmendmentCommissionFlow>(
      () => AmendmentCommissionFlow(
        getIt<BidAmendmentRepository>(),
        getIt<AnalyticsService>(),
      ),
    )
    ..registerFactory<AmendmentActionCubit>(
      () => AmendmentActionCubit(
        getIt<BidAmendmentRepository>(),
        getIt<AnalyticsService>(),
      ),
    )
    ..registerFactory<AmendmentAcceptCubit>(
      () => AmendmentAcceptCubit(
        getIt<BidAmendmentRepository>(),
        getIt<AnalyticsService>(),
        getIt<AmendmentCommissionFlow>(),
      ),
    );
}
