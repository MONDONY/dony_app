import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockKycRepo extends Mock implements KycRepository {}

void main() {
  late _MockKycRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockKycRepo();
    backend = MockAnalyticsBackend();
  });

  KycBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return KycBloc(repo, a);
  }

  test('kyc_started fires on KycSessionRequested success', () async {
    when(() => repo.createSession()).thenAnswer((_) async => {
      'stripeUrl': 'https://stripe.com',
      'sessionId': 'sess_1',
    });
    final bloc = makeBloc();
    bloc.add(const KycSessionRequested());
    await bloc.stream.firstWhere((s) => s is KycSessionCreated);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.kycStarted, any())).called(1);
  });

  test('kyc_failed fires on KycSessionRequested error', () async {
    when(() => repo.createSession()).thenThrow(Exception('KYC error'));
    final bloc = makeBloc();
    bloc.add(const KycSessionRequested());
    await bloc.stream.firstWhere((s) => s is KycError);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.kycFailed, any())).called(1);
  });

  test('kyc_completed fires on KycStatusRefreshed when kycStatus=VERIFIED', () async {
    when(() => repo.getStatus()).thenAnswer((_) async => {
      'kycStatus': 'VERIFIED',
      'verificationStatus': 'verified',
    });
    final bloc = makeBloc();
    bloc.add(const KycStatusRefreshed());
    await bloc.stream.firstWhere((s) => s is KycStatusLoaded);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.kycCompleted, any())).called(1);
  });

  test('no event when analytics disabled', () async {
    when(() => repo.createSession()).thenAnswer((_) async => {
      'stripeUrl': 'https://stripe.com',
      'sessionId': 'sess_1',
    });
    final bloc = makeBloc(enabled: false);
    bloc.add(const KycSessionRequested());
    await bloc.stream.firstWhere((s) => s is KycSessionCreated);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
