import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiFormKind', () {
    test('chemin d’endpoint et nom analytics', () {
      expect(AiFormKind.trip.path, 'trip');
      expect(AiFormKind.packageRequest.path, 'package-request');
      expect(AiFormKind.trip.analyticsName, 'trip');
      expect(AiFormKind.packageRequest.analyticsName, 'package_request');
    });
  });

  test('AiChatMessage.toJson donne le rôle et le texte', () {
    expect(const AiChatMessage.user('bonjour').toJson(), {
      'role': 'user',
      'text': 'bonjour',
    });
    expect(const AiChatMessage.assistant('Le 15 ?').toJson(), {
      'role': 'assistant',
      'text': 'Le 15 ?',
    });
  });

  group('AiFormDraftReply.fromJson', () {
    test('lit une réponse complète', () {
      final reply = AiFormDraftReply.fromJson({
        'draft': {'departureCity': 'Paris', 'availableKg': 23},
        'understood': ['route', 'capacity'],
        'missing': ['departureDate'],
        'question': ' Le 15, c’est bien le samedi 15 novembre ? ',
        'quickReplies': ['Oui', '15 décembre'],
        'done': false,
        'degraded': false,
        'remainingToday': 27,
      });
      expect(reply.draft, {'departureCity': 'Paris', 'availableKg': 23});
      expect(reply.understood, ['route', 'capacity']);
      expect(reply.missing, ['departureDate']);
      expect(reply.question, 'Le 15, c’est bien le samedi 15 novembre ?');
      expect(reply.quickReplies, ['Oui', '15 décembre']);
      expect(reply.done, isFalse);
      expect(reply.degraded, isFalse);
      expect(reply.remainingToday, 27);
    });

    test('valeurs absentes ou de mauvais type : défauts sûrs', () {
      final reply = AiFormDraftReply.fromJson({
        'draft': 'pas un objet',
        'understood': 'route',
        'question': '   ',
      });
      expect(reply.draft, isEmpty);
      expect(reply.understood, isEmpty);
      expect(reply.missing, isEmpty);
      expect(reply.question, isNull);
      expect(reply.quickReplies, isEmpty);
      expect(reply.done, isFalse);
      expect(reply.degraded, isFalse);
      expect(reply.remainingToday, 0);
    });

    test('réponses rapides : 3 au plus, 40 caractères au plus, non vides', () {
      final reply = AiFormDraftReply.fromJson({
        'quickReplies': [
          'Oui',
          '',
          'x' * 41,
          'En voiture',
          42,
          '15 décembre',
          'De trop',
        ],
      });
      expect(reply.quickReplies, ['Oui', 'En voiture', '15 décembre']);
    });

    test(
      'remainingToday non numérique : TypeError (le dépôt la convertit)',
      () {
        expect(
          () => AiFormDraftReply.fromJson({'remainingToday': 'beaucoup'}),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });

  test('isFilledDraftValue', () {
    expect(isFilledDraftValue(null), isFalse);
    expect(isFilledDraftValue('  '), isFalse);
    expect(isFilledDraftValue(const <String>[]), isFalse);
    expect(isFilledDraftValue('Paris'), isTrue);
    expect(isFilledDraftValue(0), isTrue);
    expect(isFilledDraftValue(false), isTrue);
    expect(isFilledDraftValue(['Vêtements']), isTrue);
  });

  test('AiResolvedDraft.filledFields ignore les valeurs vides', () {
    const resolved = AiResolvedDraft(
      draft: {
        'departureCity': 'Paris',
        'arrivalCity': null,
        'cashEnabled': false,
        'categories': <String>[],
        'description': '',
      },
    );
    expect(resolved.filledFields, {'departureCity', 'cashEnabled'});
    expect(resolved.warnings, isEmpty);
  });

  test('isoDate', () {
    expect(isoDate(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('utcOffsetId', () {
    expect(utcOffsetId(const Duration(hours: 2)), '+02:00');
    expect(utcOffsetId(const Duration(hours: -5, minutes: -30)), '-05:30');
    expect(utcOffsetId(Duration.zero), '+00:00');
  });

  test('parseIsoDate', () {
    expect(parseIsoDate('2026-11-15'), DateTime(2026, 11, 15));
    expect(parseIsoDate('15/11/2026'), isNull);
    expect(parseIsoDate('2026-11-15T10:00:00'), isNull);
    expect(parseIsoDate(20261115), isNull);
    expect(parseIsoDate(null), isNull);
  });

  test('exceptions typées', () {
    const quota = AiFormDraftQuotaExceededException(
      retryAfter: Duration(hours: 3),
    );
    expect(quota.retryAfter, const Duration(hours: 3));
    expect(const AiFormDraftDisabledException(), isA<AiFormDraftException>());
    expect(
      const AiFormDraftTooManyTurnsException(),
      isA<AiFormDraftException>(),
    );
    expect(const AiFormDraftNetworkException(), isA<AiFormDraftException>());
  });
}
