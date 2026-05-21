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
    // Par défaut, retourne la defaultValue pour toute clé
    when(() => mockBox.get(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
  });

  group('NotificationPrefsBloc', () {
    test('état initial utilise les defaults', () {
      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_payment'], isTrue);
      expect(bloc.state.prefs['sms_payment'], isFalse);
      expect(bloc.state.prefs['push_delivery'], isTrue);
      expect(bloc.state.prefs['sms_delivery'], isFalse);
      expect(bloc.state.prefs['push_match'], isTrue);
      expect(bloc.state.prefs['push_dispute'], isTrue);
      expect(bloc.state.prefs['sms_dispute'], isFalse);
      expect(bloc.state.prefs['email_dispute'], isFalse);
      expect(bloc.state.prefs['push_trip_reminder'], isTrue);
      expect(bloc.state.prefs['push_promo'], isFalse);
      expect(bloc.state.prefs['email_promo'], isFalse);
      bloc.close();
    });

    test('état initial lit une valeur persistée depuis Hive', () {
      when(
        () => mockBox.get(
          'notif_push_payment',
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(false);

      final bloc = NotificationPrefsBloc(mockBox);
      expect(bloc.state.prefs['push_payment'], isFalse);
      bloc.close();
    });

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_payment (true → false)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_payment')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_payment'],
          'push_payment',
          isFalse,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse sms_payment (false → true)',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('sms_payment')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['sms_payment'],
          'sms_payment',
          isTrue,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled écrit la nouvelle valeur dans Hive',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('sms_payment')),
      verify: (_) =>
          verify(() => mockBox.put('notif_sms_payment', true)).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled écrit false dans Hive quand on désactive',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_payment')),
      verify: (_) =>
          verify(() => mockBox.put('notif_push_payment', false)).called(1),
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
            .having((s) => s.prefs['push_payment'], 'push_payment', isTrue)
            .having((s) => s.prefs['push_delivery'], 'push_delivery', isTrue),
      ],
    );

    test('NotificationPrefsState avec mêmes prefs sont égaux', () {
      const prefs = {'push_payment': true, 'sms_payment': false};
      const a = NotificationPrefsState(prefs: prefs);
      const b = NotificationPrefsState(prefs: prefs);
      expect(a, equals(b));
    });

    test('NotifPrefToggled props contient la clé', () {
      const event = NotifPrefToggled('push_payment');
      expect(event.props, contains('push_payment'));
    });
  });
}
