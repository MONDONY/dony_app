import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    const baseUser = UserModel(
      id: 'user-123',
      phoneNumber: '+33612345678',
      email: 'test@dony.app',
      firstName: 'Amadou',
      lastName: 'Diallo',
      roles: ['SENDER'],
      kycStatus: 'PENDING',
      status: 'ACTIVE',
    );

    // ─── displayName ──────────────────────────────────────────────────────────

    group('displayName', () {
      test('prénom + nom → retourne le nom complet', () {
        expect(baseUser.displayName, 'Amadou Diallo');
      });

      test('seulement prénom → retourne le prénom', () {
        const user = UserModel(
          id: 'u1',
          firstName: 'Fatou',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.displayName, 'Fatou');
      });

      test('seulement nom → retourne le nom', () {
        const user = UserModel(
          id: 'u1',
          lastName: 'Sow',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.displayName, 'Sow');
      });

      // Ni le numéro ni l'email ne servent plus de repli : ils affichaient une coordonnée
      // personnelle comme nom, ce que « Masquer mon numéro » interdit. Le serveur garantit
      // un username non vide depuis la migration V183.
      test('pas de nom → retourne le username, pas le numéro', () {
        const user = UserModel(
          id: 'u1',
          username: 'user1785153600',
          phoneNumber: '+33699887766',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.displayName, 'user1785153600');
      });

      test('pas de nom → retourne le username, pas l\'email', () {
        const user = UserModel(
          id: 'u1',
          username: 'user1785153600',
          email: 'user@example.com',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.displayName, 'user1785153600');
      });

      test('numéro et email seuls, sans username → "Utilisateur"', () {
        const user = UserModel(
          id: 'u1',
          phoneNumber: '+33699887766',
          email: 'user@example.com',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.displayName, 'Utilisateur');
      });

      test('rien de disponible → retourne "Utilisateur"', () {
        const user = UserModel(
          id: 'u1',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.displayName, 'Utilisateur');
      });
    });

    // ─── initials ─────────────────────────────────────────────────────────────

    group('initials', () {
      test('prénom + nom → deux initiales majuscules', () {
        expect(baseUser.initials, 'AD');
      });

      test('seulement prénom → première lettre en majuscule', () {
        const user = UserModel(
          id: 'u1',
          firstName: 'Kouamé',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.initials, 'K');
      });

      test('seulement email → ignoré, retourne "?"', () {
        const user = UserModel(
          id: 'u1',
          email: 'amadou@dony.app',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.initials, '?');
      });

      test('seulement téléphone → ignoré, retourne "?"', () {
        const user = UserModel(
          id: 'u1',
          phoneNumber: '+33612345678',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.initials, '?');
      });

      // Deux derniers chiffres du username : le « U » de « user » rendrait tous les
      // comptes sans nom identiques.
      test('sans nom → deux derniers chiffres du username', () {
        const user = UserModel(
          id: 'u1',
          username: 'user1785153600',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.initials, '00');
      });

      test('rien → retourne "?"', () {
        const user = UserModel(
          id: 'u1',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.initials, '?');
      });
    });

    // ─── age ──────────────────────────────────────────────────────────────────

    group('age', () {
      test('pas de birthDate → retourne null', () {
        expect(baseUser.age, isNull);
      });

      test('birthDate il y a 30 ans → retourne 30', () {
        final now = DateTime.now();
        final user = UserModel(
          id: 'u1',
          birthDate: DateTime(now.year - 30, now.month, now.day),
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.age, 30);
      });

      test('anniversaire non encore passé dans l\'année → âge - 1', () {
        final now = DateTime.now();
        // Birthday next month means not yet had this year's birthday
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextMonthYear = now.month == 12
            ? now.year - 30 + 1
            : now.year - 30;
        final user = UserModel(
          id: 'u1',
          birthDate: DateTime(nextMonthYear, nextMonth, 1),
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.age, 29);
      });
    });

    // ─── isProfileComplete ────────────────────────────────────────────────────

    final birthDate = DateTime(1995, 3, 12);
    const fullyComplete = UserModel(
      id: 'u1',
      avatarUrl: 'https://cdn.example.com/avatar.jpg',
      firstName: 'Amadou',
      lastName: 'Diallo',
      email: 'amadou@example.com',
      phoneNumber: '+221701234567',
      city: 'Dakar',
      bio: 'Voyageur régulier Paris-Dakar.',
      roles: [],
      kycStatus: 'PENDING',
      status: 'ACTIVE',
    );

    group('isProfileComplete', () {
      test(
        '8 champs remplis (photo, identité, contact, ville, à propos) → true',
        () {
          final user = fullyComplete.copyWith(birthDate: birthDate);
          expect(user.isProfileComplete(), isTrue);
        },
      );

      test(
        'prénom + nom + email seuls → false (photo/téléphone/etc manquants)',
        () {
          const user = UserModel(
            id: 'u1',
            firstName: 'Amadou',
            lastName: 'Diallo',
            email: 'amadou@example.com',
            roles: [],
            kycStatus: 'PENDING',
            status: 'ACTIVE',
          );
          expect(user.isProfileComplete(), isFalse);
        },
      );

      test('date de naissance manquante → false (requise désormais)', () {
        expect(fullyComplete.birthDate, isNull);
        expect(fullyComplete.isProfileComplete(), isFalse);
      });

      test('photo manquante → false', () {
        final user = UserModel(
          id: 'u1',
          firstName: 'Amadou',
          lastName: 'Diallo',
          email: 'amadou@example.com',
          phoneNumber: '+221701234567',
          birthDate: birthDate,
          city: 'Dakar',
          bio: 'Voyageur régulier Paris-Dakar.',
          roles: const [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.avatarUrl, isNull);
        expect(user.isProfileComplete(), isFalse);
      });

      test('email manquant → false', () {
        final user = UserModel(
          id: 'u1',
          avatarUrl: 'https://cdn.example.com/avatar.jpg',
          firstName: 'Amadou',
          lastName: 'Diallo',
          phoneNumber: '+221701234567',
          birthDate: birthDate,
          city: 'Dakar',
          bio: 'Voyageur régulier Paris-Dakar.',
          roles: const [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.email, isNull);
        expect(user.isProfileComplete(), isFalse);
      });

      // ── countPhone: false (SMS OTP backend non confirmé) ──────────────────
      group('countPhone: false (flag SMS OTP désactivé)', () {
        test('téléphone absent mais les 7 autres champs remplis → true', () {
          final user = fullyComplete.copyWith(birthDate: birthDate);
          final userWithoutPhone = UserModel(
            id: user.id,
            avatarUrl: user.avatarUrl,
            firstName: user.firstName,
            lastName: user.lastName,
            email: user.email,
            city: user.city,
            bio: user.bio,
            birthDate: user.birthDate,
            roles: user.roles,
            kycStatus: user.kycStatus,
            status: user.status,
          );
          expect(userWithoutPhone.phoneNumber, isNull);
          expect(userWithoutPhone.isProfileComplete(countPhone: false), isTrue);
          // Le même utilisateur reste incomplet si le flag est actif (le
          // total redevient 8 et le téléphone manque).
          expect(userWithoutPhone.isProfileComplete(), isFalse);
        });
      });
    });

    // ─── profileCompletionSteps ───────────────────────────────────────────────

    group('profileCompletionSteps', () {
      test('aucun champ → 0 étape sur 8', () {
        const user = UserModel(
          id: 'u1',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.profileCompletionSteps(), 0);
        expect(UserModel.profileTotalSteps(), 8);
      });

      test('countPhone: false → total de 7', () {
        expect(UserModel.profileTotalSteps(countPhone: false), 7);
      });

      test('prénom seulement → 1 étape', () {
        const user = UserModel(
          id: 'u1',
          firstName: 'Amadou',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.profileCompletionSteps(), 1);
      });

      test('prénom + nom + email → 3 étapes', () {
        const user = UserModel(
          id: 'u1',
          firstName: 'Amadou',
          lastName: 'Diallo',
          email: 'amadou@example.com',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.profileCompletionSteps(), 3);
      });

      test('les 8 champs remplis → 8 étapes', () {
        final user = fullyComplete.copyWith(birthDate: birthDate);
        expect(user.profileCompletionSteps(), 8);
      });

      test(
        'téléphone rempli mais countPhone: false → il n\'est pas compté',
        () {
          final user = fullyComplete.copyWith(birthDate: birthDate);
          expect(user.phoneNumber, isNotNull);
          expect(user.profileCompletionSteps(countPhone: false), 7);
        },
      );
    });

    // ─── statuts et rôles ─────────────────────────────────────────────────────

    group('statuts et rôles', () {
      test('kycStatus VERIFIED → isKycVerified = true', () {
        const user = UserModel(
          id: 'u1',
          roles: [],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        );
        expect(user.isKycVerified, isTrue);
      });

      test('kycStatus PENDING → isKycVerified = false', () {
        expect(baseUser.isKycVerified, isFalse);
      });

      test('rôle SENDER → isSender = true', () {
        expect(baseUser.isSender, isTrue);
        expect(baseUser.isTraveler, isFalse);
      });

      test('rôle TRAVELER → isTraveler = true', () {
        const user = UserModel(
          id: 'u1',
          roles: ['TRAVELER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.isTraveler, isTrue);
        expect(user.isSender, isFalse);
      });

      test('rôles SENDER + TRAVELER → isSender et isTraveler = true', () {
        const user = UserModel(
          id: 'u1',
          roles: ['SENDER', 'TRAVELER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user.isSender, isTrue);
        expect(user.isTraveler, isTrue);
      });
    });

    // ─── fromJson ─────────────────────────────────────────────────────────────

    group('fromJson()', () {
      test('JSON complet → UserModel correctement désérialisé', () {
        final json = {
          'id': 'user-abc',
          'phoneNumber': '+33612345678',
          'email': 'test@dony.app',
          'firstName': 'Amadou',
          'lastName': 'Diallo',
          'birthDate': '1990-05-15',
          'city': 'Paris',
          'roles': ['SENDER', 'TRAVELER'],
          'kycStatus': 'VERIFIED',
          'status': 'ACTIVE',
        };

        final user = UserModel.fromJson(json);

        expect(user.id, 'user-abc');
        expect(user.phoneNumber, '+33612345678');
        expect(user.email, 'test@dony.app');
        expect(user.firstName, 'Amadou');
        expect(user.lastName, 'Diallo');
        expect(user.birthDate, DateTime(1990, 5, 15));
        expect(user.city, 'Paris');
        expect(user.roles, containsAll(['SENDER', 'TRAVELER']));
        expect(user.kycStatus, 'VERIFIED');
        expect(user.status, 'ACTIVE');
      });

      test('JSON minimal → valeurs par défaut appliquées', () {
        final json = {'id': 'user-min', 'roles': []};

        final user = UserModel.fromJson(json);

        expect(user.id, 'user-min');
        expect(user.phoneNumber, isNull);
        expect(user.firstName, isNull);
        expect(user.kycStatus, 'NOT_STARTED');
        expect(user.status, 'ACTIVE');
        expect(user.roles, isEmpty);
      });

      test('JSON avec birthDate null → birthDate null', () {
        final json = {
          'id': 'u1',
          'birthDate': null,
          'roles': [],
          'kycStatus': 'PENDING',
          'status': 'ACTIVE',
        };

        final user = UserModel.fromJson(json);
        expect(user.birthDate, isNull);
      });
    });

    // ─── Equatable ────────────────────────────────────────────────────────────

    group('Equatable', () {
      test('deux UserModel avec les mêmes données → égaux', () {
        const user1 = UserModel(
          id: 'u1',
          phoneNumber: '+33612345678',
          roles: ['SENDER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        const user2 = UserModel(
          id: 'u1',
          phoneNumber: '+33612345678',
          roles: ['SENDER'],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user1, equals(user2));
        expect(user1.props, equals(user2.props));
      });

      test('IDs différents → non égaux', () {
        const user1 = UserModel(
          id: 'u1',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        const user2 = UserModel(
          id: 'u2',
          roles: [],
          kycStatus: 'PENDING',
          status: 'ACTIVE',
        );
        expect(user1, isNot(equals(user2)));
      });
    });

    // ─── bio / avatarUrl / languages / transportMode ──────────────────────────

    test('UserModel parse bio/avatarUrl/languages/transportMode', () {
      final u = UserModel.fromJson({
        'id': 'u1',
        'roles': ['SENDER'],
        'bio': 'Hello',
        'avatarUrl': 'https://cdn/a.jpg',
        'languages': ['FR', 'WO'],
        'transportMode': 'AVION',
      });
      expect(u.bio, 'Hello');
      expect(u.avatarUrl, 'https://cdn/a.jpg');
      expect(u.languages, ['FR', 'WO']);
      expect(u.transportMode, 'AVION');
      expect(u.toJson()['bio'], 'Hello');
    });

    // ─── deletionRequestedAt ──────────────────────────────────────────────────

    group('deletionRequestedAt', () {
      test('parses deletionRequestedAt when present', () {
        final json = {
          'id': 'u1',
          'roles': ['SENDER'],
          'kycStatus': 'PENDING',
          'status': 'PENDING_DELETION',
          'deletionRequestedAt': '2026-05-06T10:00:00Z',
        };
        final user = UserModel.fromJson(json);
        expect(user.deletionRequestedAt, isNotNull);
        expect(user.deletionRequestedAt!.year, 2026);
        expect(user.isPendingDeletion, isTrue);
      });

      test('deletionRequestedAt is null when absent', () {
        final json = {
          'id': 'u1',
          'roles': ['SENDER'],
          'kycStatus': 'PENDING',
          'status': 'ACTIVE',
        };
        final user = UserModel.fromJson(json);
        expect(user.deletionRequestedAt, isNull);
        expect(user.isPendingDeletion, isFalse);
      });
    });
  });
}
