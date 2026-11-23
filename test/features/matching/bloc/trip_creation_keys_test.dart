import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/trip_creation_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int counter;
  late TripCreationKeys keys;

  setUp(() {
    counter = 0;
    keys = TripCreationKeys(generate: () => 'cle-${++counter}-abcdef');
  });

  String publish() => keys.keyFor(saveAsDraft: false, multiLeg: false);

  group('conservation de la clé', () {
    test('la même intention rend la même clé', () {
      expect(publish(), publish());
      expect(counter, 1);
    });

    test('brouillon et publication ont chacun leur clé', () {
      final published = publish();
      final draft = keys.keyFor(saveAsDraft: true, multiLeg: false);

      expect(draft, isNot(published));
      // Chacune reste stable quand on alterne.
      expect(publish(), published);
      expect(keys.keyFor(saveAsDraft: true, multiLeg: false), draft);
    });

    test('trajet simple et voyage à étapes ont chacun leur clé', () {
      final single = publish();
      final trip = keys.keyFor(saveAsDraft: false, multiLeg: true);

      expect(trip, isNot(single));
      expect(keys.keyFor(saveAsDraft: false, multiLeg: true), trip);
    });

    test('la clé par défaut respecte le contrat du back', () {
      final key = TripCreationKeys().keyFor(
        saveAsDraft: false,
        multiLeg: false,
      );

      expect(RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(key), isTrue);
    });
  });

  group('échec où le serveur a pu créer le trajet : même clé', () {
    final errors = <String, AppException>{
      'délai dépassé': const TimeoutException(),
      'pas de connexion': const OfflineException(),
      'API injoignable (502, 503, 504)': const ServiceUnavailableException(),
      '5xx': const ServerException(),
      'erreur réseau non classée': const NetworkException('boom'),
      'requête annulée': const NetworkException('x', code: 'CANCELLED'),
    };

    for (final entry in errors.entries) {
      test(entry.key, () {
        final before = publish();

        keys.onFailure(entry.value);

        expect(publish(), before);
        expect(TripCreationKeys.mayHaveBeenCreated(entry.value), isTrue);
      });
    }
  });

  group('refus définitif du serveur (4xx) : nouvelle clé', () {
    final errors = <String, AppException>{
      '400/422 validation': const ValidationException('x'),
      '401': const UnauthorizedException(),
      '403 limite de brouillons, limite mensuelle': const ForbiddenException(
        'x',
        'draft-limit-reached',
      ),
      '404': const NotFoundException(),
      '409': const ConflictException('x'),
      '429': const RateLimitException(),
      '405 non classé': const NetworkException('x', code: '405'),
    };

    for (final entry in errors.entries) {
      test(entry.key, () {
        final before = publish();

        keys.onFailure(entry.value);

        expect(publish(), isNot(before));
        expect(TripCreationKeys.mayHaveBeenCreated(entry.value), isFalse);
      });
    }

    test('seule l\'intention qui vient d\'échouer est renouvelée', () {
      final draft = keys.keyFor(saveAsDraft: true, multiLeg: false);
      final published = publish();

      keys.onFailure(const ValidationException('x'));

      expect(publish(), isNot(published));
      expect(keys.keyFor(saveAsDraft: true, multiLeg: false), draft);
    });

    test('renewLast renouvelle la dernière intention (route absente)', () {
      final before = publish();

      keys.renewLast();

      expect(publish(), isNot(before));
    });

    test('renewLast et onFailure sans envoi préalable ne font rien', () {
      keys.renewLast();
      keys.onFailure(const ValidationException('x'));

      expect(counter, 0);
    });
  });

  test('un échec puis un refus : la clé change une seule fois', () {
    final first = publish();
    keys.onFailure(const TimeoutException());
    expect(publish(), first);

    keys.onFailure(const ValidationException('x'));
    final second = publish();

    expect(second, isNot(first));
    expect(publish(), second);
  });
}
