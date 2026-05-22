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
    test('état initial utilise les 6 defaults', () {
      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_activity_bids'], isTrue);
      expect(bloc.state.prefs['push_activity_negotiations'], isTrue);
      expect(bloc.state.prefs['push_messages'], isTrue);
      expect(bloc.state.prefs['push_trip_reminder'], isTrue);
      expect(bloc.state.prefs['push_promo'], isFalse);
      expect(bloc.state.prefs['email_promo'], isFalse);
      bloc.close();
    });

    test('état initial ne contient plus les anciennes clés obsolètes', () {
      final bloc = NotificationPrefsBloc(mockBox);
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
      'NotifPrefToggled push_activity_bids false → true',
      build: () {
        when(
          () => mockBox.get(
            'notif_push_activity_bids',
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(false);
        return NotificationPrefsBloc(mockBox);
      },
      act: (bloc) => bloc.add(const NotifPrefToggled('push_activity_bids')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_activity_bids'],
          'push_activity_bids',
          isTrue,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled push_activity_negotiations true → false',
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
      'NotifPrefToggled push_messages false → true',
      build: () {
        when(
          () => mockBox.get(
            'notif_push_messages',
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(false);
        return NotificationPrefsBloc(mockBox);
      },
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_messages'],
          'push_messages',
          isTrue,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled écrit la nouvelle valeur dans Hive',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) =>
          bloc.add(const NotifPrefToggled('push_activity_negotiations')),
      verify: (_) => verify(
        () => mockBox.put('notif_push_activity_negotiations', false),
      ).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'deux toggles successifs restituent la valeur initiale',
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
      'toggler une clé ne modifie pas les autres clés',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo', isTrue)
            .having(
              (s) => s.prefs['push_activity_bids'],
              'push_activity_bids',
              isTrue,
            )
            .having(
              (s) => s.prefs['push_trip_reminder'],
              'push_trip_reminder',
              isTrue,
            ),
      ],
    );

    test('NotificationPrefsState avec mêmes prefs sont égaux', () {
      const prefs = {'push_activity_bids': true, 'push_promo': false};
      const a = NotificationPrefsState(prefs: prefs);
      const b = NotificationPrefsState(prefs: prefs);
      expect(a, equals(b));
    });

    test('NotifPrefToggled props contient la clé', () {
      const event = NotifPrefToggled('push_activity_bids');
      expect(event.props, contains('push_activity_bids'));
    });
  });
}
