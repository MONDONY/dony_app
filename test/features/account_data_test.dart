import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_datasource.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/settings/data/connected_devices_datasource.dart';
import 'package:dony/features/settings/data/datasources/blocked_users_datasource.dart';
import 'package:dony/features/settings/data/datasources/business_prefs_remote_datasource.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:dony/features/stripe_account/data/stripe_account_datasource.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:dony/features/trip_templates/data/datasources/trip_recurrence_datasource.dart';
import 'package:dony/features/trip_templates/data/datasources/trip_template_datasource.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_recurrence_repository.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_dio.dart';

const _referralJson = {
  'code': 'AWA123',
  'shareUrl': 'https://yadony.com/r/AWA123',
  'totalInvited': 4,
  'signedUp': 2,
  'rewarded': 1,
  'hasBeenReferred': true,
  'activeVoucherCount': 1,
  'voucherFactor': 0.5,
  'nextVoucherExpiresAt': '2026-12-01T10:00:00Z',
};

const _templateJson = {
  'id': 't1',
  'label': 'Paris-Dakar',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'transportMode': 'PLANE',
  'capacityUnit': 'KG',
  'availableKg': 20,
};

const _recurrenceJson = {
  'id': 'rec1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'transportMode': 'PLANE',
  'capacityUnit': 'KG',
  'availableKg': 20,
  'pricePerKg': 8,
  'pickupAddress': {'label': 'Orly', 'lat': 48.7, 'lng': 2.4},
  'deliveryAddress': {'label': 'AIBD', 'lat': 14.7, 'lng': -17.1},
  'weekdays': 'MON,FRI',
  'horizonDays': 30,
  'active': true,
};

void main() {
  late RecordingApi api;

  setUp(() => api = RecordingApi());

  group('ReferralInfo', () {
    test('fromJson lit tous les champs et calcule le pourcentage', () {
      final info = ReferralInfo.fromJson(_referralJson);
      expect(info.code, 'AWA123');
      expect(info.shareUrl, contains('AWA123'));
      expect(info.totalInvited, 4);
      expect(info.signedUp, 2);
      expect(info.rewarded, 1);
      expect(info.hasBeenReferred, isTrue);
      expect(info.activeVoucherCount, 1);
      expect(info.voucherFactor, 0.5);
      expect(info.voucherPercentOff, 50);
      expect(info.nextVoucherExpiresAt, DateTime.utc(2026, 12, 1, 10));
    });

    test('fromJson : valeurs par défaut sur un back antérieur', () {
      final info = ReferralInfo.fromJson({'code': 'X', 'shareUrl': 'u'});
      expect(info.totalInvited, 0);
      expect(info.signedUp, 0);
      expect(info.rewarded, 0);
      expect(info.hasBeenReferred, isFalse);
      expect(info.activeVoucherCount, 0);
      expect(info.voucherFactor, isNull);
      expect(info.voucherPercentOff, isNull);
      expect(info.nextVoucherExpiresAt, isNull);
    });
  });

  group('Referral datasource / repository', () {
    late ReferralRepository repo;

    setUp(() => repo = ReferralRepository(ReferralDatasource(api.client)));

    test('getMyReferral lit /me/referral', () async {
      api.on('GET', '/me/referral', _referralJson);
      expect((await repo.getMyReferral()).code, 'AWA123');
      expect(api.last.method, 'GET');
    });

    test('regenerateCode poste /me/referral/regenerate', () async {
      api.on('POST', '/me/referral/regenerate', {
        ..._referralJson,
        'code': 'NEW1',
      });
      expect((await repo.regenerateCode()).code, 'NEW1');
    });

    test('redeemCode envoie le code', () async {
      await repo.redeemCode('AWA123');
      expect(api.last.path, '/referral/redeem');
      expect(api.last.data, {'code': 'AWA123'});
    });
  });

  group('Blocked users', () {
    late BlockedUsersRepository repo;

    setUp(() {
      repo = BlockedUsersRepository(BlockedUsersDatasource(api.client));
    });

    test('fetchBlockedUsers lit la liste', () async {
      api.on('GET', '/users/me/blocks', [
        {
          'userId': 'u1',
          'displayName': 'Moussa',
          'blockedAt': '2026-01-02T03:04:05Z',
        },
      ]);
      final list = await repo.fetchBlockedUsers();
      expect(list.single.userId, 'u1');
      expect(list.single.displayName, 'Moussa');
      expect(list.single.blockedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test('blockUser poste blockedUserId', () async {
      await repo.blockUser('u2');
      expect(api.last.method, 'POST');
      expect(api.last.path, '/users/me/blocks');
      expect(api.last.data, {'blockedUserId': 'u2'});
    });

    test('unblockUser appelle DELETE', () async {
      await repo.unblockUser('u2');
      expect(api.last.method, 'DELETE');
      expect(api.last.path, '/users/me/blocks/u2');
    });
  });

  group('ConnectedDevicesDatasource', () {
    late ConnectedDevicesDatasource ds;

    setUp(() => ds = ConnectedDevicesDatasource(api.client));

    test('fetchDevices lit la liste', () async {
      api.on('GET', '/users/me/devices', [
        {
          'deviceId': 'dev1',
          'deviceName': 'iPhone',
          'platform': 'ios',
          'lastSeenAt': '2026-05-01T00:00:00Z',
          'isCurrent': true,
        },
      ]);
      final devices = await ds.fetchDevices();
      expect(devices.single.deviceId, 'dev1');
      expect(devices.single.platform, 'ios');
      expect(devices.single.isCurrent, isTrue);
    });

    test('revokeDevice et revokeOthers appellent DELETE', () async {
      await ds.revokeDevice('dev1');
      await ds.revokeOthers();
      expect(api.requests.map((r) => '${r.method} ${r.path}'), [
        'DELETE /users/me/devices/dev1',
        'DELETE /users/me/devices/others',
      ]);
    });
  });

  group('BusinessPrefsRepository', () {
    test('fetch puis update rendent la réponse du serveur', () async {
      final repo = BusinessPrefsRepository(
        BusinessPrefsRemoteDatasource(api.client),
      );
      api.on('GET', '/users/me/business-preferences', {
        'currencyCode': 'XOF',
        'country': 'SN',
      });
      api.on('PUT', '/users/me/business-preferences', {
        'currencyCode': 'EUR',
        'country': 'FR',
      });

      final prefs = await repo.fetchPrefs();
      expect(prefs.currencyCode, 'XOF');

      final updated = await repo.updatePrefs(
        UserBusinessPrefsDto.fromJson(const {'country': 'FR'}),
      );
      expect(updated.currencyCode, 'EUR');
      expect(api.last.method, 'PUT');
      expect((api.last.data as Map)['country'], 'FR');
    });
  });

  group('ProfileRepository', () {
    late ProfileRepository repo;

    setUp(() => repo = ProfileRepository(api.client));

    test('downgradePro appelle DELETE /auth/me/upgrade-to-pro', () async {
      await repo.downgradePro();
      expect(api.last.method, 'DELETE');
      expect(api.last.path, '/auth/me/upgrade-to-pro');
    });

    test('downgradePro convertit l’erreur en AppException', () async {
      api.on('DELETE', '/auth/me/upgrade-to-pro', {
        'code': 'not-pro-account',
      }, status: 409);
      await expectLater(repo.downgradePro(), throwsA(isA<AppException>()));
    });

    test('getProfilePublic lit le profil public', () async {
      api.on('GET', '/users/u1/profile-public', {
        'userId': 'u1',
        'displayName': 'Awa',
        'averageRating': 4.5,
      });
      final p = await repo.getProfilePublic('u1');
      expect(p.userId, 'u1');
      expect(p.displayName, 'Awa');
      expect(p.averageRating, 4.5);
    });

    test('getProfilePublic convertit une coupure réseau', () async {
      api.adapter.failWith = DioExceptionType.connectionError;
      await expectLater(
        repo.getProfilePublic('u1'),
        throwsA(isA<OfflineException>()),
      );
    });
  });

  group('StripeAccountRepository', () {
    late StripeAccountRepository repo;

    setUp(() {
      repo = StripeAccountRepository(StripeAccountDatasource(api.client));
    });

    test('getAccountStatus lit le statut stocké', () async {
      api.on('GET', '/payments/connect/account', {
        'stripeAccountId': 'acct_1',
        'stripeAccountStatus': 'ACTIVE',
        'country': 'FR',
      });
      final s = await repo.getAccountStatus();
      expect(s.accountId, 'acct_1');
      expect(s.status, 'ACTIVE');
    });

    test('refreshAccountStatus poste /payments/connect/refresh', () async {
      api.on('POST', '/payments/connect/refresh', {
        'stripeAccountStatus': 'PENDING',
      });
      final s = await repo.refreshAccountStatus();
      expect(s.status, 'PENDING');
      expect(api.last.method, 'POST');
    });

    test('les erreurs sont converties en AppException', () async {
      api.on('GET', '/payments/connect/account', null, status: 500);
      api.on('POST', '/payments/connect/refresh', {
        'code': 'stripe-account-required',
      }, status: 409);
      await expectLater(repo.getAccountStatus(), throwsA(isA<AppException>()));
      await expectLater(
        repo.refreshAccountStatus(),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Trip templates / recurrences', () {
    test('TripTemplateRepository : CRUD sur /trip-templates', () async {
      final repo = TripTemplateRepository(TripTemplateDatasource(api.client));
      api.on('GET', '/trip-templates', [_templateJson]);
      api.on('POST', '/trip-templates', _templateJson);
      api.on('PUT', '/trip-templates/t1', {
        ..._templateJson,
        'label': 'Modifié',
      });

      expect((await repo.getAll()).single.label, 'Paris-Dakar');
      expect((await repo.create({'label': 'x'})).id, 't1');
      expect(api.last.data, {'label': 'x'});
      expect((await repo.update('t1', {'label': 'M'})).label, 'Modifié');
      await repo.delete('t1');
      expect(api.requests.map((r) => r.method), [
        'GET',
        'POST',
        'PUT',
        'DELETE',
      ]);
      expect(api.last.path, '/trip-templates/t1');
    });

    test('TripRecurrenceRepository : CRUD sur /trip-recurrences', () async {
      final repo = TripRecurrenceRepository(
        TripRecurrenceDatasource(api.client),
      );
      api.on('GET', '/trip-recurrences', [_recurrenceJson]);
      api.on('POST', '/trip-recurrences', _recurrenceJson);
      api.on('PUT', '/trip-recurrences/rec1', {
        ..._recurrenceJson,
        'active': false,
      });

      final all = await repo.getAll();
      expect(all.single.weekdays, 'MON,FRI');
      expect(all.single.pickupAddress.label, 'Orly');
      expect((await repo.create({'weekdays': 'MON'})).id, 'rec1');
      expect(api.last.data, {'weekdays': 'MON'});
      expect((await repo.update('rec1', {'active': false})).active, isFalse);
      await repo.delete('rec1');
      expect(api.last.method, 'DELETE');
      expect(api.last.path, '/trip-recurrences/rec1');
    });
  });
}
