import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationPrefsBloc
    extends MockBloc<NotificationPrefsEvent, NotificationPrefsState>
    implements NotificationPrefsBloc {}

class MockBox extends Mock implements Box<dynamic> {}

class _FakeNotifEvent extends Fake implements NotificationPrefsEvent {}

Widget _wrap({Map<String, bool>? prefs}) {
  final mockBloc = MockNotificationPrefsBloc();
  final state = NotificationPrefsState(
    prefs: prefs ??
        {
          'push_activity_bids': true,
          'push_activity_negotiations': true,
          'push_messages': true,
          'push_trip_reminder': true,
          'push_promo': false,
          'email_promo': false,
        },
  );
  when(() => mockBloc.state).thenReturn(state);
  whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
      initialState: state);

  return MaterialApp(
    home: BlocProvider<NotificationPrefsBloc>.value(
      value: mockBloc,
      child: const NotificationSettingsScreen(),
    ),
  );
}

Widget _wrapWithBloc(MockNotificationPrefsBloc mockBloc) {
  return MaterialApp(
    home: BlocProvider<NotificationPrefsBloc>.value(
      value: mockBloc,
      child: const NotificationSettingsScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeNotifEvent());
  });

  group('NotificationSettingsScreen', () {
    testWidgets('affiche la section PROTECTIONS CRITIQUES', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('PROTECTIONS CRITIQUES'), findsOneWidget);
    });

    testWidgets('affiche les 3 tiles critiques', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Livraison confirmée'), findsOneWidget);
      expect(find.text('Paiement reçu'), findsOneWidget);
      expect(find.text('Litige ouvert'), findsOneWidget);
    });

    testWidgets('affiche le bandeau explicatif des critiques', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ces notifications protègent vos transactions'),
        findsOneWidget,
      );
    });

    testWidgets('tap sur tile critique ne dispatche aucun event', (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Livraison confirmée'));
      await tester.pump();

      verifyNever(() => mockBloc.add(any()));
    });

    testWidgets('affiche la section ACTIVITÉ avec 4 tiles', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('ACTIVITÉ'), findsOneWidget);
      expect(find.text('Matchs & enchères'), findsOneWidget);
      expect(find.text('Négociations'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Rappel trajet J-1'), findsOneWidget);
    });

    testWidgets('tap Matchs & enchères dispatche NotifPrefToggled(push_activity_bids)',
        (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Matchs & enchères'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_activity_bids')),
          )).called(1);
    });

    testWidgets('tap Négociations dispatche NotifPrefToggled(push_activity_negotiations)',
        (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Négociations'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_activity_negotiations')),
          )).called(1);
    });

    testWidgets('tap Messages dispatche NotifPrefToggled(push_messages)',
        (tester) async {
      final mockBloc = MockNotificationPrefsBloc();
      final state = NotificationPrefsState(prefs: {
        'push_activity_bids': true,
        'push_activity_negotiations': true,
        'push_messages': true,
        'push_trip_reminder': true,
        'push_promo': false,
        'email_promo': false,
      });
      when(() => mockBloc.state).thenReturn(state);
      whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
          initialState: state);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Messages'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Messages'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_messages')),
          )).called(1);
    });

    testWidgets('affiche la section ACTUS & PROMOTIONS', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('ACTUS & PROMOTIONS'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTUS & PROMOTIONS'), findsOneWidget);
      expect(find.text('Actus dony (Push)'), findsOneWidget);
      expect(find.text('Actus dony (E-mail)'), findsOneWidget);
    });
  });
}
