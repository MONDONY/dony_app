import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/data/models/notification_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/notification_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

class MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

class MockNotificationPrefsRepository extends Mock
    implements NotificationPrefsRepository {}

class _FakePrefsDto extends Fake implements NotificationPrefsDto {}

void main() {
  late MockBox mockBox;
  // Les trois dépendances serveur sont REQUISES par le bloc : un câblage
  // d'injection incomplet ne compile plus. Elles sont donc montées pour tous
  // les tests, y compris ceux qui ne s'intéressent qu'aux préférences Hive.
  late MockPackageRequestRepository repo;
  late MockAnalytics analytics;
  late MockNotificationPrefsRepository prefsRepo;

  setUpAll(() {
    registerFallbackValue(_FakePrefsDto());
  });

  setUp(() {
    mockBox = MockBox();
    reset(mockBox);
    when(
      () => mockBox.get(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((inv) => inv.namedArguments[#defaultValue]);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

    repo = MockPackageRequestRepository();
    analytics = MockAnalytics();
    prefsRepo = MockNotificationPrefsRepository();
    when(() => repo.getPackageMatchAlert()).thenAnswer((_) async => true);
    when(() => repo.setPackageMatchAlert(any())).thenAnswer((_) async {});
    when(() => prefsRepo.updatePrefs(any())).thenAnswer((_) async {});
    when(
      () => prefsRepo.fetchPrefs(),
    ).thenAnswer((_) async => const NotificationPrefsDto({}));
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('NotificationPrefsBloc', () {
    test('état initial utilise les 6 nouvelles defaults', () {
      final bloc = NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo);
      expect(bloc.state.prefs['push_activity_bids'], isTrue);
      expect(bloc.state.prefs['push_activity_negotiations'], isTrue);
      expect(bloc.state.prefs['push_messages'], isTrue);
      expect(bloc.state.prefs['push_trip_reminder'], isTrue);
      expect(bloc.state.prefs['push_corridor_alerts'], isTrue);
      expect(bloc.state.prefs['push_promo'], isFalse);
      // Retiré : aucun champ serveur, aucun émetteur, plus aucune ligne à l'écran.
      expect(bloc.state.prefs.containsKey('email_promo'), isFalse);
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

      final bloc = NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo);
      expect(bloc.state.prefs['push_activity_bids'], isFalse);
      bloc.close();
    });

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled inverse push_activity_bids (true → false)',
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
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
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
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
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
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
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      verify: (_) =>
          verify(() => mockBox.put('notif_push_promo', true)).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'Deux toggles successifs restituent la valeur initiale',
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
      act: (bloc) => bloc
        ..add(const NotifPrefToggled('push_promo'))
        ..add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_promo'],
          'push_promo_on',
          isTrue,
        ),
        isA<NotificationPrefsState>().having(
          (s) => s.prefs['push_promo'],
          'push_promo_off',
          isFalse,
        ),
      ],
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'Toggler une clé ne modifie pas les autres clés',
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
      act: (bloc) => bloc.add(const NotifPrefToggled('push_promo')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_promo'], 'push_promo', isTrue)
            .having((s) => s.prefs['push_activity_bids'], 'bids', isTrue)
            .having(
              (s) => s.prefs['push_activity_negotiations'],
              'negs',
              isTrue,
            ),
      ],
    );

    test('NotifPrefToggled props contient la clé', () {
      const event = NotifPrefToggled('push_activity_bids');
      expect(event.props, contains('push_activity_bids'));
    });

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'NotifPrefToggled ignore une clé inconnue',
      build: () => NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo),
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
    NotificationPrefsBloc build() =>
        NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo);

    test(
      'état initial : la valeur est inconnue tant qu\'elle n\'est pas lue',
      () {
        final bloc = build();
        expect(bloc.state.packageMatchAlert, isNull);
        bloc.close();
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'chargement → la valeur serveur arrive dans l\'état',
      build: () {
        when(() => repo.getPackageMatchAlert()).thenAnswer((_) async => false);
        return build();
      },
      act: (bloc) => bloc.add(const NotifPackageMatchAlertLoadRequested()),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.packageMatchAlert,
          'packageMatchAlert',
          isFalse,
        ),
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
        isA<NotificationPrefsState>().having(
          (s) => s.packageMatchAlert,
          'packageMatchAlert',
          isFalse,
        ),
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
        when(
          () => repo.setPackageMatchAlert(any()),
        ).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) async {
        bloc.add(const NotifPackageMatchAlertLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotifPackageMatchAlertToggled(false));
      },
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.packageMatchAlert,
          'chargée',
          isTrue,
        ),
        isA<NotificationPrefsState>().having(
          (s) => s.packageMatchAlert,
          'optimiste',
          isFalse,
        ),
        isA<NotificationPrefsState>().having(
          (s) => s.packageMatchAlert,
          'restaurée',
          isTrue,
        ),
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

    // L'ancien test « sans dépôt injecté, le chargement est un non-événement »
    // verrouillait un comportement dégradé devenu impossible : les deux
    // dépendances sont maintenant requises, un câblage incomplet ne compile
    // plus. À sa place, on vérifie la conséquence observable du câblage : après
    // chargement, la valeur n'est plus inconnue, donc la ligne des réglages
    // devient utilisable au lieu de rester grisée à vie.
    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'câblage : après chargement, la valeur n\'est plus inconnue',
      build: build,
      act: (bloc) => bloc.add(const NotifPackageMatchAlertLoadRequested()),
      verify: (bloc) {
        expect(bloc.state.packageMatchAlert, isNotNull);
        verify(() => repo.getPackageMatchAlert()).called(1);
      },
    );

    test('les events portent leurs props', () {
      expect(const NotifPackageMatchAlertToggled(true).props, contains(true));
      expect(const NotifPackageMatchAlertLoadRequested().props, isEmpty);
    });

    test('packageMatchAlert participe à l\'égalité de l\'état', () {
      const a = NotificationPrefsState(prefs: {}, packageMatchAlert: true);
      const b = NotificationPrefsState(prefs: {}, packageMatchAlert: false);
      expect(a, isNot(equals(b)));
    });
  });

  // ─── Synchronisation serveur ───────────────────────────────────────────────
  //
  // Le filtrage des push est appliqué par le backend. Sans ces échanges,
  // l'écran n'enregistrait qu'un choix décoratif que le serveur ignorait :
  // c'est précisément ce que ces tests verrouillent.
  group('NotificationPrefsBloc — synchronisation serveur', () {
    NotificationPrefsBloc build() =>
        NotificationPrefsBloc(mockBox, repo, analytics, prefsRepo);

    /// Place le compte dans l'état courant : un premier échange avec le serveur
    /// a déjà eu lieu, donc la synchro lit au lieu de remonter le cache.
    void dejaSynchronise() {
      when(
        () => mockBox.get(
          'notif_synced_once',
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
    }

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'la lecture serveur fait autorité sur le cache Hive',
      build: () {
        dejaSynchronise();
        when(() => prefsRepo.fetchPrefs()).thenAnswer(
          (_) async => const NotificationPrefsDto({
            'push_messages': false,
            'push_promo': true,
          }),
        );
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefsSyncRequested()),
      expect: () => [
        isA<NotificationPrefsState>().having(
          (s) => s.isSyncing,
          'en cours',
          isTrue,
        ),
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_messages'], 'messages', isFalse)
            .having((s) => s.prefs['push_promo'], 'promo', isTrue)
            .having((s) => s.isSyncing, 'terminé', isFalse),
      ],
      verify: (_) {
        verify(() => mockBox.put('notif_push_messages', false)).called(1);
        verify(() => mockBox.put('notif_push_promo', true)).called(1);
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'lecture en échec → le cache est conservé, pas de retour aux défauts',
      build: () {
        dejaSynchronise();
        when(
          () => mockBox.get(
            'notif_push_messages',
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(false);
        when(() => prefsRepo.fetchPrefs()).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefsSyncRequested()),
      verify: (bloc) {
        expect(bloc.state.prefs['push_messages'], isFalse);
        expect(bloc.state.isSyncing, isFalse);
      },
    );

    // Première synchro : les réglages Hive sont des choix faits à une époque où
    // l'écran ne les transmettait pas. Lire le serveur d'abord les effacerait au
    // profit de ses défauts — c'est-à-dire perdre le réglage au moment précis où
    // il devient enfin effectif.
    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'première synchro → les choix locaux remontent au lieu d\'être écrasés',
      build: () {
        when(
          () => mockBox.get(
            'notif_push_messages',
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(false);
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefsSyncRequested()),
      verify: (bloc) {
        final dto =
            verify(() => prefsRepo.updatePrefs(captureAny())).captured.single
                as NotificationPrefsDto;
        expect(dto.toJson()['pushMessages'], isFalse);
        verifyNever(() => prefsRepo.fetchPrefs());
        verify(() => mockBox.put('notif_synced_once', true)).called(1);
        expect(bloc.state.prefs['push_messages'], isFalse);
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'première synchro en échec → le drapeau reste absent, reprise au prochain lancement',
      build: () {
        when(() => prefsRepo.updatePrefs(any())).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefsSyncRequested()),
      verify: (bloc) {
        verifyNever(() => mockBox.put('notif_synced_once', any()));
        expect(bloc.state.isSyncing, isFalse);
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'synchros suivantes → lecture serveur, plus de remontée',
      build: () {
        dejaSynchronise();
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefsSyncRequested()),
      verify: (_) {
        verify(() => prefsRepo.fetchPrefs()).called(1);
        verifyNever(() => prefsRepo.updatePrefs(any()));
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'une bascule pousse les six champs au serveur',
      build: build,
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      verify: (_) {
        final dto =
            verify(() => prefsRepo.updatePrefs(captureAny())).captured.single
                as NotificationPrefsDto;
        final json = dto.toJson();
        expect(json.keys, hasLength(6));
        expect(json['pushMessages'], isFalse);
        // Les champs non touchés partent avec leur valeur courante : le PUT est
        // un remplacement complet côté serveur, un champ omis y arriverait à
        // `false` et couperait une catégorie jamais désactivée par l'utilisateur.
        expect(json['pushActivityBids'], isTrue);
        expect(json['pushCorridorAlerts'], isTrue);
      },
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'écriture en échec → interrupteur ET cache Hive reviennent en arrière',
      build: () {
        when(() => prefsRepo.updatePrefs(any())).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      expect: () => [
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_messages'], 'optimiste', isFalse)
            .having((s) => s.errorMessage, 'sans erreur', isNull),
        isA<NotificationPrefsState>()
            .having((s) => s.prefs['push_messages'], 'restauré', isTrue)
            .having((s) => s.errorMessage, 'erreur', isNotNull),
      ],
      verify: (_) {
        // Laisser Hive en avance sur le serveur recréerait le défaut d'origine :
        // un réglage affiché comme appliqué, que le serveur ignore.
        verify(() => mockBox.put('notif_push_messages', false)).called(1);
        verify(() => mockBox.put('notif_push_messages', true)).called(1);
      },
    );

    // email_promo n'existe plus : ni champ serveur, ni émetteur, ni ligne à l'écran.
    // La clé ne doit plus rien déclencher, ni en local ni au serveur.
    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'email_promo a été retiré : la clé n\'est plus reconnue',
      build: build,
      act: (bloc) => bloc.add(const NotifPrefToggled('email_promo')),
      expect: () => [],
      verify: (_) {
        verifyNever(() => prefsRepo.updatePrefs(any()));
        verifyNever(() => mockBox.put('notif_email_promo', any()));
      },
    );

    // Toutes les clés restantes sont synchronisées : il n'existe plus de réglage
    // local-only, donc plus de bascule qui n'atteindrait jamais le serveur.
    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'chaque clé de l\'état est poussée au serveur',
      build: build,
      act: (bloc) {
        for (final key in bloc.state.prefs.keys) {
          bloc.add(NotifPrefToggled(key));
        }
      },
      verify: (bloc) => verify(
        () => prefsRepo.updatePrefs(any()),
      ).called(bloc.state.prefs.length),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'une bascule synchronisée est tracée',
      build: build,
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.notificationPrefToggled,
          properties: {'pref': 'push_messages', 'enabled': false},
        ),
      ).called(1),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'écriture en échec → aucune trace analytics',
      build: () {
        when(() => prefsRepo.updatePrefs(any())).thenThrow(Exception('réseau'));
        return build();
      },
      act: (bloc) => bloc.add(const NotifPrefToggled('push_messages')),
      verify: (_) => verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.notificationPrefToggled,
          properties: any(named: 'properties'),
        ),
      ),
    );

    blocTest<NotificationPrefsBloc, NotificationPrefsState>(
      'une nouvelle bascule efface le message d\'erreur précédent',
      build: () {
        var premier = true;
        when(() => prefsRepo.updatePrefs(any())).thenAnswer((_) async {
          if (premier) {
            premier = false;
            throw Exception('réseau');
          }
        });
        return build();
      },
      act: (bloc) async {
        bloc.add(const NotifPrefToggled('push_messages'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotifPrefToggled('push_messages'));
      },
      verify: (bloc) => expect(bloc.state.errorMessage, isNull),
    );
  });

  // ─── Contrat de sérialisation ──────────────────────────────────────────────
  group('NotificationPrefsDto', () {
    test('toJson émet toujours les six champs, même sur une map vide', () {
      final json = const NotificationPrefsDto({}).toJson();
      expect(json.keys, hasLength(6));
      // Les défauts répliquent `NotificationPrefsDto.defaults()` du backend.
      expect(json['pushActivityBids'], isTrue);
      expect(json['pushPromo'], isFalse);
      expect(json['pushCorridorAlerts'], isTrue);
    });

    test('fromJson ignore les champs absents ou mal typés', () {
      final dto = NotificationPrefsDto.fromJson({
        'pushMessages': false,
        'pushPromo': 'oui', // type inattendu
      });
      expect(dto.values['push_messages'], isFalse);
      expect(dto.values.containsKey('push_promo'), isFalse);
      expect(dto.values.containsKey('push_activity_bids'), isFalse);
    });

    test('aller-retour fromJson → toJson préserve les valeurs', () {
      final dto = NotificationPrefsDto.fromJson({
        'pushActivityBids': false,
        'pushActivityNegotiations': false,
        'pushMessages': false,
        'pushTripReminder': false,
        'pushPromo': true,
        'pushCorridorAlerts': false,
      });
      expect(dto.toJson(), {
        'pushActivityBids': false,
        'pushActivityNegotiations': false,
        'pushMessages': false,
        'pushTripReminder': false,
        'pushPromo': true,
        'pushCorridorAlerts': false,
      });
    });

    test('email_promo n\'est pas un champ synchronisé', () {
      expect(NotificationPrefsDto.isSynced('email_promo'), isFalse);
      expect(NotificationPrefsDto.isSynced('push_messages'), isTrue);
    });
  });
}
