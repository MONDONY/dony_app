import 'package:dony/core/di/amendment_injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

void main() {
  test('cubits d\'actions de la modification : neufs à chaque encart, flux '
      'de commission partagé', () async {
    final getIt = GetIt.asNewInstance();
    getIt
      ..registerSingleton<BidAmendmentRepository>(_MockRepository())
      ..registerSingleton<AnalyticsService>(
        makeDisabledAnalytics(MockAnalyticsBackend()),
      );

    registerAmendmentActionDependencies(getIt);

    final action = getIt<AmendmentActionCubit>();
    final accept = getIt<AmendmentAcceptCubit>();
    expect(getIt<AmendmentActionCubit>(), isNot(same(action)));
    expect(getIt<AmendmentAcceptCubit>(), isNot(same(accept)));
    expect(
      getIt<AmendmentCommissionFlow>(),
      same(getIt<AmendmentCommissionFlow>()),
    );
    await action.close();
    await accept.close();
  });
}
