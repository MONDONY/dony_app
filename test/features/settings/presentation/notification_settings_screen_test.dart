import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationPrefsBloc
    extends MockBloc<NotificationPrefsEvent, NotificationPrefsState>
    implements NotificationPrefsBloc {}

const _defaultPrefs = {
  'push_activity_bids': true,
  'push_activity_negotiations': true,
  'push_messages': true,
  'push_trip_reminder': true,
  'push_promo': false,
  'email_promo': false,
};

Widget _wrap({
  required MockNotificationPrefsBloc mockBloc,
  Map<String, bool>? prefs,
}) {
  when(() => mockBloc.state).thenReturn(
    NotificationPrefsState(prefs: prefs ?? _defaultPrefs),
  );
  return MaterialApp(
    home: BlocProvider<NotificationPrefsBloc>.value(
      value: mockBloc,
      child: const NotificationSettingsScreen(),
    ),
  );
}

void main() {
  late MockNotificationPrefsBloc mockBloc;

  setUp(() {
    mockBloc = MockNotificationPrefsBloc();
    registerFallbackValue(const NotifPrefToggled('push_promo'));
  });

  group('NotificationSettingsScreen', () {
    testWidgets('affiche la section PROTECTIONS CRITIQUES', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('PROTECTIONS CRITIQUES'), findsOneWidget);
    });

    testWidgets('affiche les 3 tiles critiques verrouillées', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Livraison confirmée'), findsOneWidget);
      expect(find.text('Paiement reçu'), findsOneWidget);
      expect(find.text('Litige ouvert'), findsOneWidget);
    });

    testWidgets('affiche le bandeau de protection', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ces notifications protègent vos transactions'),
        findsOneWidget,
      );
    });

    testWidgets('tap sur une tile critique ne dispatche aucun event',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Livraison confirmée'));
      await tester.pump();

      verifyNever(() => mockBloc.add(any()));
    });

    testWidgets('affiche la section ACTIVITÉ avec 4 tiles', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVITÉ'), findsOneWidget);
      expect(find.text('Matchs & enchères'), findsOneWidget);
      expect(find.text('Négociations'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Rappel trajet J-1'), findsOneWidget);
    });

    testWidgets('tap "Matchs & enchères" dispatche NotifPrefToggled(push_activity_bids)',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Matchs & enchères'));
      await tester.pump();

      verify(
        () => mockBloc.add(const NotifPrefToggled('push_activity_bids')),
      ).called(1);
    });

    testWidgets(
        'tap "Négociations" dispatche NotifPrefToggled(push_activity_negotiations)',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Négociations'));
      await tester.pump();

      verify(
        () => mockBloc
            .add(const NotifPrefToggled('push_activity_negotiations')),
      ).called(1);
    });

    testWidgets('tap "Messages" dispatche NotifPrefToggled(push_messages)',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Messages'));
      await tester.pump();

      verify(
        () => mockBloc.add(const NotifPrefToggled('push_messages')),
      ).called(1);
    });

    testWidgets('affiche la section ACTUS & PROMOTIONS avec 2 tiles',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('ACTUS & PROMOTIONS'), findsOneWidget);
      expect(find.text('Actus dony (Push)'), findsOneWidget);
      expect(find.text('Actus dony (E-mail)'), findsOneWidget);
    });
  });
}
