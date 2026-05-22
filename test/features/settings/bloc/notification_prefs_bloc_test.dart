import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('NotificationPrefsBloc', () {
    test('état initial utilise les 6 nouvelles defaults', () {
      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_activity_bids'], isTrue);
      expect(bloc.state.prefs['push_activity_negotiations'], isTrue);
      expect(bloc.state.prefs['push_messages'], isTrue);
      expect(bloc.state.prefs['push_trip_reminder'], isTrue);
      expect(bloc.state.prefs['push_promo'], isFalse);
      expect(bloc.state.prefs['email_promo'], isFalse);
      // Anciennes clés supprimées
      expect(bloc.state.prefs.containsKey('push_payment'), isFalse);
      expect(bloc.state.prefs.containsKey('sms_payment'), isFalse);
      expect(bloc.state.prefs.containsKey('push_delivery'), isFalse);
      expect(bloc.state.prefs.containsKey('sms_delivery'), isFalse);
      expect(bloc.state.prefs.containsKey('push_match'), isFalse);
      expect(bloc.state.prefs.containsKey('push_dispute'), isFalse);
      expect(bloc.state.prefs.containsKey('sms_dispute'), isFalse);
      expect(bloc.state.prefs.containsKey('email_dispute'), isFalse);
      bloc.close();
    });

    test('état initial lit une valeur persistée depuis Hive', () {
      when(
        () => mockBox.get(
          'notif_push_activity_bids',
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(false);

      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_activity_bids'], isFalse);
      bloc.close();
    });

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_activity_bids (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_activity_bids')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_activity_bids'],
          'push_activity_bids',
          isFalse,
        ),
      ],
      verify: (_) => verify(
        () => mockBox.put('notif_push_activity_bids', false),
      ).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_activity_negotiations (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) =>
          bloc.add(const NotifPrefToggled('push_activity_negotiations')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_activity_negotiations'],
          'push_activity_negotiations',
          isFalse,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_messages (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_messages'],
          'push_messages',
          isFalse,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled écrit la nouvelle valeur dans Hive',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      verify: (_) =>
          verify(() => mockBox.put('notif_push_promo', true)).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'Deux toggles successifs restituent la valeur initiale',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc
        ..add(const NotifPrefToggled('push_promo'))
        ..add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo_on', isTrue),
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo_off', isFalse),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'Toggler une clé ne modifie pas les autres clés',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo', isTrue)
            .having((s) => s.prefs['push_activity_bids'], 'bids', isTrue)
            .having(
                (s) => s.prefs['push_activity_negotiations'], 'negs', isTrue),
      ],
    );

    test('NotifPrefToggled props contient la clé', () {
      const event = NotifPrefToggled('push_activity_bids');
      expect(event.props, contains('push_activity_bids'));
    });
  });
}
