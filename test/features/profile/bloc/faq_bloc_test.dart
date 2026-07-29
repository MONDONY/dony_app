import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

void main() {
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  blocTest<FaqBloc, FaqState>(
    'met à jour la recherche sans modifier le texte saisi',
    build: () => FaqBloc(analytics),
    act: (bloc) => bloc.add(const FaqSearchChanged('  Remboursement  ')),
    expect: () => const [FaqState(query: '  Remboursement  ')],
  );

  test('trace une question avec des identifiants non sensibles', () async {
    final bloc = FaqBloc(analytics);

    bloc.add(
      const FaqQuestionOpened(categoryId: 'payments', questionId: 'refund'),
    );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.faqQuestionOpened, {
        'category': 'payments',
        'question_id': 'refund',
      }),
    ).called(1);
    await bloc.close();
  });

  test('trace le passage de la FAQ vers le support', () async {
    final bloc = FaqBloc(analytics);

    bloc.add(const FaqContactRequested());
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.faqContactRequested, null),
    ).called(1);
    await bloc.close();
  });
}
