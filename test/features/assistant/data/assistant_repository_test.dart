import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';
import 'package:dony/features/assistant/data/assistant_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient api;
  late MockDio dio;
  late AssistantRepository repository;

  setUp(() {
    api = MockApiClient();
    dio = MockDio();
    when(() => api.dio).thenReturn(dio);
    repository = AssistantRepository(api);
  });

  DioException error(int status, {Object? data}) => DioException(
    requestOptions: RequestOptions(path: '/assistant/ask'),
    response: Response(
      requestOptions: RequestOptions(path: '/assistant/ask'),
      statusCode: status,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );

  /// Fait répondre le dio mocké avec [data] en HTTP 200.
  void respondWith(Object? data) {
    when(() => dio.post('/assistant/ask', data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/assistant/ask'),
        data: data,
      ),
    );
  }

  Future<AssistantAnswer> ask() =>
      repository.ask(question: 'q', locale: 'fr', history: const []);

  test(
    'envoie la question, la langue et l’historique, puis lit la réponse',
    () async {
      respondWith({
        'answer': 'Allez dans Moi.',
        'answered': true,
        'actions': [
          {'route': '/profile/edit/phone', 'label': 'Changer mon numéro'},
        ],
        'sources': ['changer-numero'],
        'provider': 'groq',
        'remainingToday': 17,
      });
      final answer = await repository.ask(
        question: 'Où ?',
        locale: 'fr',
        history: const [AssistantHistoryTurn(role: 'user', text: 'bonjour')],
      );
      expect(answer.answer, 'Allez dans Moi.');
      expect(answer.answered, isTrue);
      expect(answer.provider, 'groq');
      expect(
        answer.actions.single,
        const AssistantAction(
          route: '/profile/edit/phone',
          label: 'Changer mon numéro',
        ),
      );
      expect(answer.remainingToday, 17);
      final data =
          verify(
                () =>
                    dio.post('/assistant/ask', data: captureAny(named: 'data')),
              ).captured.single
              as Map;
      expect(data['question'], 'Où ?');
      expect(data['locale'], 'fr');
      expect(data['history'], [
        {'role': 'user', 'text': 'bonjour'},
      ]);
      // Sans colis choisi, le champ n'est pas envoyé (back antérieur).
      expect(data.containsKey('parcelId'), isFalse);
      // L'app sait afficher le texte riche (YADONY-FLUTTER-PROD-13).
      expect(data['format'], 'rich');
      // Back d'avant PROD-13 : pas de `answerRich`, affichage du texte brut.
      expect(answer.answerRich, isNull);
      expect(answer.displayText, 'Allez dans Moi.');
      expect(answer.parcelId, isNull);
      expect(answer.parcels, isEmpty);
    },
  );

  group('texte riche (YADONY-FLUTTER-PROD-13)', () {
    Map<String, Object?> body(Object? rich) => {
      'answer': 'Allez dans Moi.\n• Touchez Profil',
      'answered': true,
      'actions': [],
      'provider': 'claude',
      'remainingToday': 3,
      'answerRich': rich,
    };

    test('answerRich affiché, answer garde le texte brut', () async {
      respondWith(body('Allez dans **Moi**.\n- Touchez **Profil**'));
      final answer = await repository.ask(
        question: 'Où ?',
        locale: 'fr',
        history: const [],
      );
      expect(answer.displayText, 'Allez dans **Moi**.\n- Touchez **Profil**');
      expect(answer.answer, 'Allez dans Moi.\n• Touchez Profil');
    });

    for (final rich in [null, '', '   ', 42]) {
      test('answerRich $rich : repli sur answer', () async {
        respondWith(body(rich));
        final answer = await repository.ask(
          question: 'Où ?',
          locale: 'fr',
          history: const [],
        );
        expect(answer.answerRich, isNull);
        expect(answer.displayText, 'Allez dans Moi.\n• Touchez Profil');
      });
    }
  });

  test('envoie le colis choisi et lit les colis proposés', () async {
    respondWith({
      'answer': 'Choisissez le colis concerné.',
      'answered': true,
      'actions': [],
      'provider': 'claude',
      'remainingToday': 3,
      'parcelId': 'b9',
      'parcels': [
        {
          'parcelId': 'b1',
          'trackingNumber': 'DON-7K3M9QXA',
          'departureCity': 'Paris',
          'arrivalCity': 'Dakar',
          'departureDate': '2026-10-20',
          'status': 'IN_TRANSIT',
          'role': 'SENDER',
          'active': true,
        },
        {'parcelId': 'b2', 'status': 'COMPLETED', 'role': 'TRAVELER'},
        {'parcelId': 'b3', 'role': 'SENDER'},
        'pas un objet',
      ],
    });
    final answer = await repository.ask(
      question: 'Où est mon colis ?',
      locale: 'fr',
      history: const [],
      parcelId: 'b9',
    );
    final data =
        verify(
              () => dio.post('/assistant/ask', data: captureAny(named: 'data')),
            ).captured.single
            as Map;
    expect(data['parcelId'], 'b9');
    expect(answer.parcelId, 'b9');
    expect(answer.parcels, const [
      AssistantParcelChoice(
        parcelId: 'b1',
        status: 'IN_TRANSIT',
        role: 'SENDER',
        active: true,
        trackingNumber: 'DON-7K3M9QXA',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
      ),
      AssistantParcelChoice(
        parcelId: 'b2',
        status: 'COMPLETED',
        role: 'TRAVELER',
        active: false,
      ),
    ]);
  });

  test('colis proposés absents ou d’un mauvais type : aucun choix', () {
    final answer = AssistantAnswer.fromJson(const {
      'answer': 'ok',
      'answered': true,
      'actions': <Object>[],
      'parcels': 'x',
    });
    expect(answer.parcels, isEmpty);
  });

  test('champs manquants tolérés', () {
    final a = AssistantAnswer.fromJson(const {'answer': 'x'});
    expect(a.answered, isFalse);
    expect(a.actions, isEmpty);
    expect(a.provider, 'none');
    expect(a.remainingToday, 0);
  });

  test('remainingToday numérique non entier (17.0) lu comme 17', () {
    final a = AssistantAnswer.fromJson(const {
      'answer': 'x',
      'remainingToday': 17.0,
    });
    expect(a.remainingToday, 17);
  });

  test('actions incomplètes ignorées, les autres et le texte gardés', () {
    final a = AssistantAnswer.fromJson(const {
      'answer': 'x',
      'actions': [
        'pas une map',
        {'label': 'Sans route'},
        {'route': '/sans-libelle'},
        {'route': '', 'label': 'Route vide'},
        {'route': '/vide', 'label': '   '},
        {'route': 42, 'label': 'Route non textuelle'},
        {'route': '/home', 'label': 'Accueil'},
      ],
    });
    expect(a.answer, 'x');
    expect(a.actions, const [
      AssistantAction(route: '/home', label: 'Accueil'),
    ]);
  });

  test('modèle d’historique sérialisé en JSON', () {
    const turn = AssistantHistoryTurn(role: 'assistant', text: 'Bonjour');
    expect(turn.toJson(), {'role': 'assistant', 'text': 'Bonjour'});
  });

  test('égalité par valeur des modèles (instances non const)', () {
    // Valeurs calculées à l'exécution : les instances ne sont pas const, donc
    // Equatable compare réellement les props au lieu de court-circuiter sur
    // l'identité canonique des const.
    final role = 'USER'.toLowerCase();
    final salut = 'SALUT'.toLowerCase();
    final autre = 'AUTRE'.toLowerCase();
    final turnA = AssistantHistoryTurn(role: role, text: salut);
    final turnB = AssistantHistoryTurn(role: role, text: salut);
    final turnC = AssistantHistoryTurn(role: role, text: autre);
    expect(turnA, turnB);
    expect(turnA == turnC, isFalse);

    final json = {
      'answer': 'x',
      'answered': true,
      'actions': [
        {'route': '/home', 'label': 'Accueil'},
      ],
      'provider': 'groq',
      'remainingToday': 3,
    };
    final answerA = AssistantAnswer.fromJson(json);
    final answerB = AssistantAnswer.fromJson(json);
    final answerC = AssistantAnswer.fromJson({...json, 'remainingToday': 2});
    expect(answerA, answerB);
    expect(answerA == answerC, isFalse);
  });

  test('réponse malformée (corps texte HTML) = réseau, pas de TypeError', () {
    respondWith('<html>502 Bad Gateway</html>');
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('réponse malformée (actions = 3) = réseau, pas de TypeError', () {
    respondWith({'answer': 'x', 'actions': 3});
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('réponse malformée (answer absent) = réseau, pas de TypeError', () {
    respondWith({'answered': true});
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('réponse vide (answer blanc) = réseau, pas de bulle vide', () {
    for (final blank in ['', '   ', '\n\t ']) {
      respondWith({'answer': blank, 'answered': true});
      expect(
        ask(),
        throwsA(isA<AssistantNetworkException>()),
        reason: 'answer=${blank.codeUnits}',
      );
    }
  });

  test('modèle : answer blanc refusé, texte entouré d’espaces gardé', () {
    expect(
      () => AssistantAnswer.fromJson(const {'answer': '  '}),
      throwsFormatException,
    );
    expect(AssistantAnswer.fromJson(const {'answer': ' ok '}).answer, ' ok ');
  });

  test('404 = assistant désactivé', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(error(404));
    expect(ask(), throwsA(isA<AssistantDisabledException>()));
  });

  test(
    '403 (invité ou compte sans identifiant) = assistant désactivé',
    () async {
      when(
        () => dio.post(any(), data: any(named: 'data')),
      ).thenThrow(error(403));
      expect(ask(), throwsA(isA<AssistantDisabledException>()));
    },
  );

  test('429 avec code assistant-quota-exceeded = quota', () async {
    when(
      () => dio.post(any(), data: any(named: 'data')),
    ).thenThrow(error(429, data: {'code': 'assistant-quota-exceeded'}));
    expect(ask(), throwsA(isA<AssistantQuotaExceededException>()));
  });

  test('429 sans code (limitation Nginx, corps HTML) = réseau', () async {
    when(
      () => dio.post(any(), data: any(named: 'data')),
    ).thenThrow(error(429, data: '<html>429 Too Many Requests</html>'));
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('429 avec un autre code = réseau', () async {
    when(
      () => dio.post(any(), data: any(named: 'data')),
    ).thenThrow(error(429, data: {'code': 'rate-limited'}));
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('422 (validation) = réseau', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(error(422));
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('autre erreur = réseau', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(error(500));
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('erreur sans réponse (hors ligne) = réseau', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/assistant/ask'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('délai de réception dépassé = réseau', () async {
    when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/assistant/ask'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(ask(), throwsA(isA<AssistantNetworkException>()));
  });

  test('les exceptions partagent la hiérarchie AssistantException', () {
    const AssistantException disabled = AssistantDisabledException();
    const AssistantException quota = AssistantQuotaExceededException();
    const AssistantException network = AssistantNetworkException();
    expect(disabled, isA<AssistantException>());
    expect(quota, isA<AssistantException>());
    expect(network, isA<AssistantException>());
  });

  group('status (sonde de disponibilité)', () {
    void statusAnswers(Object? data) =>
        when(() => dio.get('/assistant/status')).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/assistant/status'),
            data: data,
          ),
        );

    void statusFails(DioException e) =>
        when(() => dio.get('/assistant/status')).thenThrow(e);

    test('200 enabled true : disponible', () async {
      statusAnswers({'enabled': true});
      expect(await repository.status(), isTrue);
    });

    test('200 enabled false : indisponible', () async {
      statusAnswers({'enabled': false});
      expect(await repository.status(), isFalse);
    });

    test('403 (invité) : indisponible, sans exception', () async {
      statusFails(error(403));
      expect(await repository.status(), isFalse);
    });

    test('404 (back ancien) : indisponible, sans exception', () async {
      statusFails(error(404));
      expect(await repository.status(), isFalse);
    });

    test('500 : inconnu (ni oui ni non), sans exception', () async {
      statusFails(error(500));
      expect(await repository.status(), isNull);
    });

    test('délai dépassé ou hors ligne : inconnu, sans exception', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        statusFails(
          DioException(
            requestOptions: RequestOptions(path: '/assistant/status'),
            type: type,
          ),
        );
        expect(await repository.status(), isNull, reason: '$type');
      }
    });

    test('erreur inattendue : inconnu', () async {
      when(() => dio.get('/assistant/status')).thenThrow(StateError('boum'));
      expect(await repository.status(), isNull);
    });

    test('corps illisible : inconnu', () async {
      for (final body in <Object?>[
        'oups',
        null,
        <String, dynamic>{},
        {'enabled': 'true'},
        {'enabled': 1},
        [true],
      ]) {
        statusAnswers(body);
        expect(await repository.status(), isNull, reason: '$body');
      }
    });
  });

  group('screen (explication de l’écran)', () {
    void screenResponds(int status, Object? data) {
      when(
        () => dio.get(
          '/assistant/screen',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/assistant/screen'),
          statusCode: status,
          data: data,
        ),
      );
    }

    test('200 : explication, questions et actions', () async {
      screenResponds(200, {
        'id': 'ecran-mes-colis',
        'title': 'L’écran Mes colis',
        'explanation': 'Vous êtes sur Mes colis.',
        'questions': ['Comment annuler ?', '', 3],
        'actions': [
          {'route': '/tracking', 'label': 'Ouvrir le suivi'},
        ],
      });
      final intro = await repository.screen('/envois', 'fr');
      expect(intro!.explanation, 'Vous êtes sur Mes colis.');
      expect(intro.questions, ['Comment annuler ?']);
      expect(intro.actions.single.route, '/tracking');
      final query =
          verify(
                () => dio.get(
                  '/assistant/screen',
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map;
      expect(query, {'path': '/envois', 'locale': 'fr', 'format': 'rich'});
      expect(intro.explanationRich, isNull);
    });

    test('explanationRich lu quand le back le fournit (PROD-13)', () async {
      screenResponds(200, {
        'explanation': 'Ligne une.\nLigne deux.',
        'explanationRich': 'Ligne une.\n- Ligne **deux**.',
      });
      final intro = await repository.screen('/envois', 'fr');
      expect(intro!.explanationRich, 'Ligne une.\n- Ligne **deux**.');
      expect(intro.explanation, 'Ligne une.\nLigne deux.');
    });

    test('204, corps vide ou malformé : rien à expliquer', () async {
      screenResponds(204, '');
      expect(await repository.screen('/x', 'fr'), isNull);
      screenResponds(200, {'explanation': '  '});
      expect(await repository.screen('/x', 'fr'), isNull);
      screenResponds(200, {'questions': []});
      expect(await repository.screen('/x', 'fr'), isNull);
    });

    test('404 (back ancien) ou hors ligne : rien, sans lever', () async {
      when(
        () => dio.get(
          '/assistant/screen',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(error(404));
      expect(await repository.screen('/x', 'fr'), isNull);
    });
  });
}
