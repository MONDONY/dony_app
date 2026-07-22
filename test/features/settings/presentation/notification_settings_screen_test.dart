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

MockNotificationPrefsBloc _buildMockBloc([
  Map<String, bool>? customPrefs,
  bool? packageMatchAlert,
]) {
  final mockBloc = MockNotificationPrefsBloc();
  final prefs = customPrefs ?? {
    'push_activity_bids': true,
    'push_activity_negotiations': true,
    'push_messages': true,
    'push_trip_reminder': true,
    'push_promo': false,
    'email_promo': false,
  };
  final state = NotificationPrefsState(
    prefs: prefs,
    packageMatchAlert: packageMatchAlert,
  );
  when(() => mockBloc.state).thenReturn(state);
  whenListen<NotificationPrefsState>(mockBloc, const Stream.empty(),
      initialState: state);
  return mockBloc;
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
      final mockBloc = _buildMockBloc();
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Livraison confirmée'));
      await tester.pump();

      // L'ouverture de l'écran dispatche la lecture de la cloche serveur :
      // c'est le tap sur une tuile verrouillée qui ne doit rien bousculer.
      verifyNever(() => mockBloc.add(any(that: isA<NotifPrefToggled>())));
      verifyNever(
        () => mockBloc.add(any(that: isA<NotifPackageMatchAlertToggled>())),
      );
    });

    testWidgets('affiche la section ACTIVITÉ avec 4 tiles', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('ACTIVITÉ'), findsOneWidget);
      expect(find.text('Matchs & enchères'), findsOneWidget);
      expect(find.text('Discussions de prix'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Rappel trajet J-1'), findsOneWidget);
    });

    testWidgets('tap Matchs & enchères dispatche NotifPrefToggled(push_activity_bids)',
        (tester) async {
      final mockBloc = _buildMockBloc();
      addTearDown(mockBloc.close);

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
      final mockBloc = _buildMockBloc();
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Discussions de prix'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discussions de prix'));
      await tester.pump();

      verify(() => mockBloc.add(
            any(that: isA<NotifPrefToggled>()
                .having((e) => e.key, 'key', 'push_activity_negotiations')),
          )).called(1);
    });

    testWidgets('tap Messages dispatche NotifPrefToggled(push_messages)',
        (tester) async {
      final mockBloc = _buildMockBloc();
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Messages'),
        100,
        scrollable: find.byType(Scrollable).first,
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

      await tester.scrollUntilVisible(
        find.text('ACTUS & PROMOTIONS'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTUS & PROMOTIONS'), findsOneWidget);
      expect(find.text('Actus dony (Push)'), findsOneWidget);
      expect(find.text('Actus dony (E-mail)'), findsOneWidget);
    });
  });

  // ─── Cloche « colis compatibles », rapatriée depuis l'écran supprimé ────────
  group('NotificationSettingsScreen — colis compatibles', () {
    const label = 'Nouveaux colis compatibles';

    testWidgets('la ligne vit dans la section ACTIVITÉ, sous Matchs & enchères',
        (tester) async {
      final mockBloc = _buildMockBloc(null, true);
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget);
      // Juste sous « Matchs & enchères » : c'est la section qu'elle complète.
      final matchs = tester.getTopLeft(find.text('Matchs & enchères')).dy;
      final compat = tester.getTopLeft(find.text(label)).dy;
      final autre = tester.getTopLeft(find.text('Discussions de prix')).dy;
      expect(compat, greaterThan(matchs));
      expect(compat, lessThan(autre));
    });

    testWidgets('l\'écran demande la valeur serveur à l\'ouverture',
        (tester) async {
      final mockBloc = _buildMockBloc();
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(
          any(that: isA<NotifPackageMatchAlertLoadRequested>()),
        ),
      ).called(1);
    });

    testWidgets('tap → bascule vers l\'état inverse', (tester) async {
      final mockBloc = _buildMockBloc(null, true);
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pump();

      verify(
        () => mockBloc.add(
          any(
            that: isA<NotifPackageMatchAlertToggled>().having(
              (e) => e.enabled,
              'enabled',
              isFalse,
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('coupée → tap la rallume', (tester) async {
      final mockBloc = _buildMockBloc(null, false);
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pump();

      verify(
        () => mockBloc.add(
          any(
            that: isA<NotifPackageMatchAlertToggled>().having(
              (e) => e.enabled,
              'enabled',
              isTrue,
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('valeur inconnue → le tap ne bascule rien', (tester) async {
      final mockBloc = _buildMockBloc();
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pump();

      verifyNever(
        () => mockBloc.add(any(that: isA<NotifPackageMatchAlertToggled>())),
      );
    });

    testWidgets('la cible tactile fait au moins 44 points de haut',
        (tester) async {
      final mockBloc = _buildMockBloc(null, true);
      addTearDown(mockBloc.close);

      await tester.pumpWidget(_wrapWithBloc(mockBloc));
      await tester.pumpAndSettle();

      final tuile = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tuile.first).height, greaterThanOrEqualTo(44));
    });
  });
}
