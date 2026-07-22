import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

class MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    reset(mockBox);
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

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled ignore une clé inconnue',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPrefToggled('cle_inexistante')),
      expect: () => [],
      verify: (_) =>
          verifyNever(() => mockBox.put('notif_cle_inexistante', any())),
    );
  });

  // ─── Cloche « colis compatibles » (ex-écran « Colis sur mes trajets ») ──────
  //
  // Le réglage vit côté serveur, pas dans Hive : c'est une préférence de
  // notification du voyageur, pas un choix d'affichage local.
  group('NotificationPrefsBloc — alerte colis compatibles', () {
    late MockPackageRequestRepository repo;
    late MockAnalytics analytics;

    NotificationPrefsBloc build() =>
        NotificationPrefsBloc(mockBox, repo, analytics);

    setUp(() {
      repo = MockPackageRequestRepository();
      analytics = MockAnalytics();
      when(() => repo.getPackageMatchAlert()).thenAnswer((_) async => true);
      when(() => repo.setPackageMatchAlert(any())).thenAnswer((_) async {});
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
    });

    test('état initial : la valeur est inconnue tant qu\'elle n\'est pas lue',
        () {
      final bloc = build();
      expect(bloc.state.packageMatchAlert, isNull);
      bloc.close();
    });

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'chargement → la valeur serveur arrive dans l\'état',
      build: () {
        when(() => repo.getPackageMatchAlert()).thenAnswer((_) async => false);
        return build();
      },
      act: (bloc) => bloc.add(const NotifPackageMatchAlertLoadRequested()),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.packageMatchAlert, 'packageMatchAlert', isFalse),
      ],
      verify: (_) => verify(() => repo.getPackageMatchAlert()).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'chargement en échec → la valeur reste inconnue, aucun état émis',
      build: () {
        when(() => repo.getPackageMatchAlert()).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) => bloc.add(const NotifPackageMatchAlertLoadRequested()),
      expect: () => [],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'bascule → écrit au serveur et trace package_match_alert_toggled',
      build: build,
      act: (bloc) => bloc.add(const NotifPackageMatchAlertToggled(false)),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.packageMatchAlert, 'packageMatchAlert', isFalse),
      ],
      verify: (_) {
        verify(() => repo.setPackageMatchAlert(false)).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.packageMatchAlertToggled,
            properties: {'enabled': false},
          ),
        ).called(1);
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'bascule en échec → retour à la valeur précédente',
      build: () {
        when(() => repo.setPackageMatchAlert(any()))
            .thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) async {
        bloc.add(const NotifPackageMatchAlertLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotifPackageMatchAlertToggled(false));
      },
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.packageMatchAlert, 'chargée', isTrue),
        isA<NotificationPrefsState>()
            .having((s) => s.packageMatchAlert, 'optimiste', isFalse),
        isA<NotificationPrefsState>()
            .having((s) => s.packageMatchAlert, 'restaurée', isTrue),
      ],
      verify: (_) => verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.packageMatchAlertToggled,
          properties: any(named: 'properties'),
        ),
      ),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'la bascule ne touche pas les préférences Hive',
      build: build,
      act: (bloc) => bloc.add(const NotifPackageMatchAlertToggled(false)),
      verify: (_) =>
          verifyNever(() => mockBox.put(any(that: contains('match')), any())),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'sans dépôt injecté, le chargement est un non-événement',
      build: () => NotificationPrefsBloc(mockBox),
      act: (bloc) => bloc.add(const NotifPackageMatchAlertLoadRequested()),
      expect: () => [],
    );

    test('les events portent leurs props', () {
      expect(
        const NotifPackageMatchAlertToggled(true).props,
        contains(true),
      );
      expect(
        const NotifPackageMatchAlertLoadRequested().props,
        isEmpty,
      );
    });

    test('packageMatchAlert participe à l\'égalité de l\'état', () {
      const a = NotificationPrefsState(prefs: {}, packageMatchAlert: true);
      const b = NotificationPrefsState(prefs: {}, packageMatchAlert: false);
      expect(a, isNot(equals(b)));
    });
  });
}
