import 'package:dony/features/support/bloc/support_summary_cubit.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupportRepository extends Mock implements SupportRepository {}

const _summary = SupportSummary(
  unreadCount: 2,
  openTicketCount: 1,
  latestTicket: SupportSummaryTicket(
    id: 't1',
    subject: 'Aide',
    lastMessagePreview: 'Bonjour',
    lastMessageFromAdmin: true,
    unreadCount: 2,
  ),
);

void main() {
  late MockSupportRepository repository;

  setUp(() {
    repository = MockSupportRepository();
  });

  group('SupportSummaryCubit', () {
    test('état initial : aucun résumé, statut initial', () async {
      final cubit = SupportSummaryCubit(repository);
      expect(cubit.state.status, SupportSummaryStatus.initial);
      expect(cubit.state.summary, isNull);
      await cubit.close();
    });

    test('refresh publie le résumé du serveur', () async {
      when(() => repository.getSummary()).thenAnswer((_) async => _summary);
      final cubit = SupportSummaryCubit(repository);

      final result = await cubit.refresh();

      expect(result, _summary);
      expect(cubit.state.status, SupportSummaryStatus.ready);
      expect(cubit.state.summary, _summary);
      await cubit.close();
    });

    test('ancien back (404) : statut indisponible, sans résumé', () async {
      when(() => repository.getSummary()).thenAnswer((_) async => null);
      final cubit = SupportSummaryCubit(repository);

      final result = await cubit.refresh();

      expect(result, isNull);
      expect(cubit.state.status, SupportSummaryStatus.unavailable);
      expect(cubit.state.summary, isNull);
      await cubit.close();
    });

    test('erreur réseau : garde le résumé courant', () async {
      var calls = 0;
      when(() => repository.getSummary()).thenAnswer((_) async {
        calls++;
        if (calls == 2) throw Exception('hors ligne');
        return _summary;
      });
      final cubit = SupportSummaryCubit(repository);

      await cubit.refresh();
      final result = await cubit.refresh();

      expect(result, isNull);
      expect(cubit.state.status, SupportSummaryStatus.ready);
      expect(cubit.state.summary, _summary);
      await cubit.close();
    });

    test('un rafraîchissement suivant remplace le résumé', () async {
      const next = SupportSummary(unreadCount: 0, openTicketCount: 0);
      var calls = 0;
      when(
        () => repository.getSummary(),
      ).thenAnswer((_) async => ++calls == 1 ? _summary : next);
      final cubit = SupportSummaryCubit(repository);

      await cubit.refresh();
      await cubit.refresh();

      expect(cubit.state.summary, next);
      await cubit.close();
    });
  });

  group('SupportUnreadCubit branché sur le résumé', () {
    test('le compteur vient du résumé, sans second appel', () async {
      when(() => repository.getSummary()).thenAnswer((_) async => _summary);
      final summaryCubit = SupportSummaryCubit(repository);
      final cubit = SupportUnreadCubit(repository, summaryCubit: summaryCubit);

      await cubit.refresh();

      expect(cubit.state, 2);
      expect(summaryCubit.state.summary, _summary);
      verifyNever(() => repository.loadUnreadCount());
      await cubit.close();
      await summaryCubit.close();
    });

    test('ancien back : repli sur /support/unread-count', () async {
      when(() => repository.getSummary()).thenAnswer((_) async => null);
      when(() => repository.loadUnreadCount()).thenAnswer((_) async => 4);
      final summaryCubit = SupportSummaryCubit(repository);
      final cubit = SupportUnreadCubit(repository, summaryCubit: summaryCubit);

      await cubit.refresh();

      expect(cubit.state, 4);
      expect(summaryCubit.state.status, SupportSummaryStatus.unavailable);
      await cubit.close();
      await summaryCubit.close();
    });

    test('tout échoue : garde la valeur courante sans lever', () async {
      when(() => repository.getSummary()).thenThrow(Exception('hors ligne'));
      when(
        () => repository.loadUnreadCount(),
      ).thenThrow(Exception('hors ligne'));
      final summaryCubit = SupportSummaryCubit(repository);
      final cubit = SupportUnreadCubit(repository, summaryCubit: summaryCubit);

      await cubit.refresh();

      expect(cubit.state, 0);
      await cubit.close();
      await summaryCubit.close();
    });
  });
}
