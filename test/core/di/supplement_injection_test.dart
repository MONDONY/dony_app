import 'package:dony/core/di/supplement_injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

/// Garde chaque capture : un échec de confirmation doit atteindre Sentry.
class _RecordingSink implements ErrorReportingSink {
  final captures = <Map<String, Object>>[];

  @override
  Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    required Map<String, Object> context,
  }) async => captures.add(context);
}

void main() {
  test('le cubit de paiement du supplément reçoit le rapporteur d\'erreurs : '
      'un échec de confirmation part à Sentry', () async {
    final getIt = GetIt.asNewInstance();
    final repository = _MockRepository();
    final sink = _RecordingSink();
    when(
      () => repository.confirmPayment(any(), any()),
    ).thenThrow(StateError('boom'));
    getIt
      ..registerSingleton<BidSupplementRepository>(repository)
      ..registerSingleton<AnalyticsService>(
        makeDisabledAnalytics(MockAnalyticsBackend()),
      )
      ..registerSingleton<ErrorReportingService>(ErrorReportingService(sink));

    registerSupplementPaymentDependencies(getIt);

    final cubit = getIt<SupplementPaymentCubit>();
    expect(getIt<SupplementPaymentCubit>(), isNot(same(cubit)));
    await cubit.confirmPayment(
      BidModel(
        id: 'bid-1',
        announcementId: 'ann-1',
        senderId: 'sender-1',
        status: 'ACCEPTED',
        createdAt: DateTime(2026, 10),
        updatedAt: DateTime(2026, 10),
      ),
      const BidSupplement(
        id: 'sup-1',
        status: BidSupplementStatus.paymentPending,
        grossAmount: 16.8,
      ),
    );

    expect(sink.captures, hasLength(1));
    expect(sink.captures.single['operation'], 'bid.supplement.confirmPayment');
    await cubit.close();
  });
}
