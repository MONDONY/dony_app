import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/conversation_selection/conversation_selection_cubit.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

Matcher _ids(Set<String> ids) => isA<ConversationSelectionState>().having(
  (s) => s.selectedIds,
  'selectedIds',
  ids,
);

ConversationModel _conv({
  String? bidStatus,
  String? parcelStatus,
  bool returnPending = false,
}) => ConversationModel(
  id: 'c',
  bidId: 'b',
  firestoreConversationId: 'f',
  otherParticipant: const ParticipantModel(id: 'u', name: 'N'),
  bidStatus: bidStatus,
  parcelStatus: parcelStatus,
  returnPending: returnPending,
);

void main() {
  group('ConversationSelectionCubit', () {
    test('inactif au départ', () {
      final cubit = ConversationSelectionCubit();
      expect(cubit.state.isActive, isFalse);
      expect(cubit.state.count, 0);
      expect(cubit.source, ConversationSelectionSource.list);
    });

    blocTest<ConversationSelectionCubit, ConversationSelectionState>(
      'appui long ouvre le mode, puis coche sans dupliquer',
      build: ConversationSelectionCubit.new,
      act: (c) => c
        ..startWith('a')
        ..startWith('b')
        ..startWith('b'),
      expect: () => [
        _ids({'a'}),
        _ids({'a', 'b'}),
      ],
    );

    blocTest<ConversationSelectionCubit, ConversationSelectionState>(
      'décocher la dernière case referme le mode',
      build: ConversationSelectionCubit.new,
      act: (c) => c
        ..startWith('a')
        ..toggle('b')
        ..toggle('a')
        ..toggle('b'),
      expect: () => [
        _ids({'a'}),
        _ids({'a', 'b'}),
        _ids({'b'}),
        _ids({}),
      ],
      verify: (c) => expect(c.state.isActive, isFalse),
    );

    test('addAll rend le nombre ajouté et ignore les déjà cochés', () {
      final cubit = ConversationSelectionCubit()..startWith('a');
      expect(cubit.addAll(['a', 'b', 'c']), 2);
      expect(cubit.addAll(['b']), 0);
      expect(cubit.state.selectedIds, {'a', 'b', 'c'});
    });

    blocTest<ConversationSelectionCubit, ConversationSelectionState>(
      'retainOnly retire les ids qui ne sont plus affichés, clear ferme',
      build: ConversationSelectionCubit.new,
      act: (c) => c
        ..startWith('a')
        ..toggle('b')
        ..retainOnly({'b', 'z'})
        ..retainOnly({'b'})
        ..clear()
        ..clear(),
      expect: () => [
        _ids({'a'}),
        _ids({'a', 'b'}),
        _ids({'b'}),
        _ids({}),
      ],
    );

    test('ouverture du mode tracée une fois, avec sa source', () async {
      final backend = MockAnalyticsBackend();
      final analytics = makeEnabledAnalytics(backend)..onConfigured();
      ConversationSelectionCubit(
          analytics: analytics,
          source: ConversationSelectionSource.archives,
        )
        ..startWith('a')
        ..startWith('b');
      await Future<void>.delayed(Duration.zero);
      verify(
        () => backend.capture(AnalyticsEvents.conversationSelectionStarted, {
          'source': 'archives',
        }),
      ).called(1);
    });
  });

  group('ConversationModel.isFinished', () {
    test('livré ou annulé (bidStatus)', () {
      expect(_conv(bidStatus: 'DELIVERY_CONFIRMED').isFinished, isTrue);
      expect(_conv(bidStatus: 'TRIP_CANCELLED').isFinished, isTrue);
      expect(_conv(bidStatus: 'BID_ACCEPTED').isFinished, isFalse);
      expect(_conv(bidStatus: 'IN_TRANSIT').isFinished, isFalse);
    });

    test('à défaut, statut brut du colis', () {
      expect(_conv(parcelStatus: 'COMPLETED').isFinished, isTrue);
      expect(_conv(parcelStatus: 'CANCELLED').isFinished, isTrue);
      expect(_conv(parcelStatus: 'IN_TRANSIT').isFinished, isFalse);
      expect(_conv().isFinished, isFalse);
    });

    test('un retour de colis en cours n\'est pas terminé', () {
      expect(
        _conv(bidStatus: 'TRIP_CANCELLED', returnPending: true).isFinished,
        isFalse,
      );
    });
  });
}
