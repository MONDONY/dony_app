import 'package:dio/dio.dart';
import 'package:dony/core/config/cancellation_fee_flag.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_config/cancellation_fee_config_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Outils partagés des tests des textes des frais d'annulation.

class MockFeeConfigRepository extends Mock implements CancellationRepository {}

class MockFeeConfigAnalytics extends Mock implements AnalyticsService {}

/// Date d'effet des tests : les colis créés à partir de cet instant sont
/// couverts.
final kFeeEffectiveFrom = DateTime.utc(2026, 12, 15);

/// Configuration allumée (forme de `GET /config/cancellation-fee`).
final kActiveFeeConfig = CancellationFeeConfigModel(
  effectiveFrom: kFeeEffectiveFrom,
  capEur: 30,
  tiers: const [
    CancellationFeeTier(minDaysBefore: 5, rate: 0),
    CancellationFeeTier(minDaysBefore: 3, rate: 0.1),
    CancellationFeeTier(minDaysBefore: 1, rate: 0.2),
    CancellationFeeTier(minDaysBefore: 0, rate: 0.3),
  ],
);

/// Date de création d'un colis couvert (après la date d'effet).
final kCoveredCreatedAt = DateTime.utc(2026, 12, 20, 9);

/// 404 tel que l'intercepteur le livre : back antérieur à la route.
DioException feeConfigNotFound() => DioException(
  requestOptions: RequestOptions(path: '/config/cancellation-fee'),
  response: Response(
    statusCode: 404,
    requestOptions: RequestOptions(path: '/config/cancellation-fee'),
  ),
  type: DioExceptionType.badResponse,
  error: const NotFoundException(),
);

/// Enregistre le cubit de la configuration dans GetIt et le charge :
/// [config] renvoyée par le back, ou, sans [config], un back antérieur
/// (404). [repository] : pour compter les lectures. Remet le drapeau et
/// GetIt à zéro en fin de test.
Future<CancellationFeeConfigCubit> registerFeeConfig({
  CancellationFeeConfigModel? config,
  MockFeeConfigRepository? repository,
}) async {
  repository ??= MockFeeConfigRepository();
  if (config == null) {
    when(repository.getFeeConfig).thenThrow(feeConfigNotFound());
  } else {
    when(repository.getFeeConfig).thenAnswer((_) async => config);
  }
  final analytics = MockFeeConfigAnalytics();
  when(
    () => analytics.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  final cubit = CancellationFeeConfigCubit(repository, analytics);
  if (getIt.isRegistered<CancellationFeeConfigCubit>()) {
    await getIt.unregister<CancellationFeeConfigCubit>();
  }
  getIt.registerSingleton<CancellationFeeConfigCubit>(cubit);
  addTearDown(() async {
    if (getIt.isRegistered<CancellationFeeConfigCubit>()) {
      await getIt.unregister<CancellationFeeConfigCubit>();
    }
    await cubit.close();
    resetCancellationFeeFlagForTest();
  });
  await cubit.ensureLoaded();
  return cubit;
}
