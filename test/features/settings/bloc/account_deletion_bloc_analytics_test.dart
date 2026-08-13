import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockDeletionRepo extends Mock implements AccountDeletionRepository {}

void main() {
  late _MockDeletionRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockDeletionRepo();
    backend = MockAnalyticsBackend();
  });

  AccountDeletionBloc makeBloc({bool enabled = true}) {
    final a = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    a.onConfigured();
    return AccountDeletionBloc(repo, a);
  }

  test('account_deletion_requested fires on RequestDeletion success', () async {
    when(() => repo.requestDeletion()).thenAnswer((_) async {});
    final bloc = makeBloc();
    bloc.add(const RequestDeletion());
    await bloc.stream.firstWhere((s) => s is AccountDeletionRequested);
    await Future<void>.delayed(Duration.zero);
    verify(
      () => backend.capture(AnalyticsEvents.accountDeletionRequested, any()),
    ).called(1);
  });
}
