import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/data/payer_account_source.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

/// Flux du compte qui paie servi par le catalogue des versements.
const payerAccountPayoutFlow = 'payout';

/// Composant « compte qui paie » (`getIt<PayerAccountCubit>(param1: flow)`).
/// [flow] étiquette les events et choisit le catalogue : `payout` (ajout d'un
/// compte de versement) lit les versements, sans mémoire du dernier payeur ;
/// tout autre flux (`topup`...) lit les dépôts et préremplit depuis la
/// mémoire. Appelé par `setupDependencies` (`lib/core/di/injection.dart`),
/// après l'enregistrement des dépôts et de [PayerPhoneMemory].
void registerPayerAccountDependencies(GetIt getIt) {
  getIt.registerFactoryParam<PayerAccountCubit, String, void>(
    (flow, _) => flow == payerAccountPayoutFlow
        ? PayerAccountCubit(
            PayoutPayerAccountSource(getIt<MobileMoneyAccountRepository>()),
            null,
            getIt<AnalyticsService>(),
            flow: flow,
          )
        : PayerAccountCubit(
            TopupPayerAccountSource(getIt<WalletRepository>()),
            getIt<PayerPhoneMemory>(),
            getIt<AnalyticsService>(),
            flow: flow,
          ),
  );
}
