import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileMoneyDeposit', () {
    group('fromJson', () {
      test('parses tous les champs avec le statut ACCEPTED', () {
        final json = {
          'id': 'deposit-uuid-1',
          'status': 'ACCEPTED',
          'provider': 'ORANGE_SEN',
          'providerLabel': 'Orange Money',
          'msisdnMasked': '+221 •••• 67',
          'authorizationUrl': null,
          'failureCode': null,
          'failureMessage': null,
        };

        final deposit = MobileMoneyDeposit.fromJson(json);

        expect(deposit.id, 'deposit-uuid-1');
        expect(deposit.status, MobileMoneyDepositStatus.accepted);
        expect(deposit.providerLabel, 'Orange Money');
        expect(deposit.msisdnMasked, '+221 •••• 67');
        expect(deposit.authorizationUrl, isNull);
        expect(deposit.failureCode, isNull);
        expect(deposit.failureMessage, isNull);
      });

      test('parses chaque statut connu', () {
        const cases = {
          'CREATED': MobileMoneyDepositStatus.created,
          'ACCEPTED': MobileMoneyDepositStatus.accepted,
          'PROCESSING': MobileMoneyDepositStatus.processing,
          'COMPLETED': MobileMoneyDepositStatus.completed,
          'FAILED': MobileMoneyDepositStatus.failed,
          'SUBMIT_REJECTED': MobileMoneyDepositStatus.submitRejected,
        };

        for (final entry in cases.entries) {
          final deposit = MobileMoneyDeposit.fromJson({
            'id': 'deposit-uuid',
            'status': entry.key,
          });

          expect(deposit.status, entry.value, reason: entry.key);
        }
      });

      test('replie sur unknown pour un statut de depot non reconnu', () {
        final deposit = MobileMoneyDeposit.fromJson(const {
          'id': 'deposit-uuid',
          'status': 'SOMETHING_NEW',
        });

        expect(deposit.status, MobileMoneyDepositStatus.unknown);
      });

      test('replie sur unknown quand le statut est absent', () {
        final deposit = MobileMoneyDeposit.fromJson(const {
          'id': 'deposit-uuid',
        });

        expect(deposit.status, MobileMoneyDepositStatus.unknown);
      });

      test('parses authorizationUrl quand present (redirection Wave)', () {
        final deposit = MobileMoneyDeposit.fromJson(const {
          'id': 'deposit-uuid',
          'status': 'CREATED',
          'authorizationUrl': 'https://wave.test/pay?ref=abc',
        });

        expect(deposit.authorizationUrl, 'https://wave.test/pay?ref=abc');
      });

      test('parses failureCode et failureMessage quand le depot a echoue', () {
        final deposit = MobileMoneyDeposit.fromJson(const {
          'id': 'deposit-uuid',
          'status': 'FAILED',
          'failureCode': 'INSUFFICIENT_BALANCE',
          'failureMessage': 'Solde insuffisant',
        });

        expect(deposit.failureCode, 'INSUFFICIENT_BALANCE');
        expect(deposit.failureMessage, 'Solde insuffisant');
      });
    });

    group('isLive', () {
      test('vrai pour created, accepted et processing', () {
        for (final status in [
          MobileMoneyDepositStatus.created,
          MobileMoneyDepositStatus.accepted,
          MobileMoneyDepositStatus.processing,
        ]) {
          final deposit = MobileMoneyDeposit(id: 'd', status: status);
          expect(deposit.isLive, isTrue, reason: status.name);
        }
      });

      test('faux pour completed, failed, submitRejected et unknown', () {
        for (final status in [
          MobileMoneyDepositStatus.completed,
          MobileMoneyDepositStatus.failed,
          MobileMoneyDepositStatus.submitRejected,
          MobileMoneyDepositStatus.unknown,
        ]) {
          final deposit = MobileMoneyDeposit(id: 'd', status: status);
          expect(deposit.isLive, isFalse, reason: status.name);
        }
      });
    });

    group('isFailed', () {
      test('vrai pour failed et submitRejected', () {
        for (final status in [
          MobileMoneyDepositStatus.failed,
          MobileMoneyDepositStatus.submitRejected,
        ]) {
          final deposit = MobileMoneyDeposit(id: 'd', status: status);
          expect(deposit.isFailed, isTrue, reason: status.name);
        }
      });

      test('faux pour created, accepted, processing, completed et unknown', () {
        for (final status in [
          MobileMoneyDepositStatus.created,
          MobileMoneyDepositStatus.accepted,
          MobileMoneyDepositStatus.processing,
          MobileMoneyDepositStatus.completed,
          MobileMoneyDepositStatus.unknown,
        ]) {
          final deposit = MobileMoneyDeposit(id: 'd', status: status);
          expect(deposit.isFailed, isFalse, reason: status.name);
        }
      });
    });

    group('Equatable', () {
      test('deux depots avec les memes donnees sont egaux', () {
        const a = MobileMoneyDeposit(
          id: 'd',
          status: MobileMoneyDepositStatus.accepted,
          providerLabel: 'Orange Money',
        );
        const b = MobileMoneyDeposit(
          id: 'd',
          status: MobileMoneyDepositStatus.accepted,
          providerLabel: 'Orange Money',
        );

        expect(a, equals(b));
      });

      test('deux depots avec un statut different ne sont pas egaux', () {
        const a = MobileMoneyDeposit(
          id: 'd',
          status: MobileMoneyDepositStatus.accepted,
        );
        const b = MobileMoneyDeposit(
          id: 'd',
          status: MobileMoneyDepositStatus.failed,
        );

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('MobileMoneyPaymentStatus', () {
    group('fromJson', () {
      test('parses l\'exemple complet avec un depot en cours', () {
        final json = {
          'bidId': 'bid-uuid-1',
          'bidStatus': 'AWAITING_PAYMENT',
          'paymentStatus': 'PENDING',
          'deadlineAt': '2026-09-08T07:30:00',
          'amount': 16800,
          'currency': 'XOF',
          'deposit': {
            'id': 'deposit-uuid-1',
            'status': 'ACCEPTED',
            'provider': 'ORANGE_SEN',
            'providerLabel': 'Orange Money',
            'msisdnMasked': '+221 •••• 67',
            'authorizationUrl': null,
            'failureCode': null,
            'failureMessage': null,
          },
        };

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.subjectId, 'bid-uuid-1');
        expect(status.subjectStatus, 'AWAITING_PAYMENT');
        expect(status.paymentStatus, 'PENDING');
        expect(status.amount, 16800.0);
        expect(status.currency, 'XOF');
        expect(status.deposit, isNotNull);
        expect(status.deposit!.id, 'deposit-uuid-1');
        expect(status.deposit!.status, MobileMoneyDepositStatus.accepted);
        expect(status.deposit!.providerLabel, 'Orange Money');
        expect(status.deposit!.msisdnMasked, '+221 •••• 67');
      });

      test('deposit est nul tant qu\'aucun depot n\'a ete tente', () {
        final json = {
          'bidId': 'bid-uuid-1',
          'bidStatus': 'AWAITING_PAYMENT',
          'paymentStatus': 'PENDING',
        };

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.deposit, isNull);
      });

      test('paymentStatus est nul avant toute tentative de paiement', () {
        final json = {'bidId': 'bid-uuid-1', 'bidStatus': 'AWAITING_PAYMENT'};

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.paymentStatus, isNull);
      });

      test(
        'parses deadlineAt sans suffixe de zone comme UTC puis convertit en local',
        () {
          final json = {
            'bidId': 'bid-uuid-1',
            'bidStatus': 'AWAITING_PAYMENT',
            'deadlineAt': '2026-09-08T07:30:00',
          };

          final status = MobileMoneyPaymentStatus.fromJson(json);

          expect(status.deadlineAt, isNotNull);
          expect(status.deadlineAt!.toUtc(), DateTime.utc(2026, 9, 8, 7, 30));
        },
      );

      test('deadlineAt reste correct avec un suffixe Z explicite', () {
        final json = {
          'bidId': 'bid-uuid-1',
          'bidStatus': 'AWAITING_PAYMENT',
          'deadlineAt': '2026-09-08T07:30:00Z',
        };

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.deadlineAt!.toUtc(), DateTime.utc(2026, 9, 8, 7, 30));
      });

      test('deadlineAt est nul quand absent', () {
        final json = {'bidId': 'bid-uuid-1', 'bidStatus': 'AWAITING_PAYMENT'};

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.deadlineAt, isNull);
      });

      test('parses amount entier', () {
        final json = {
          'bidId': 'bid-uuid-1',
          'bidStatus': 'AWAITING_PAYMENT',
          'amount': 16800,
        };

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.amount, 16800.0);
        expect(status.amount, isA<double>());
      });

      test('parses amount decimal', () {
        final json = {
          'bidId': 'bid-uuid-1',
          'bidStatus': 'AWAITING_PAYMENT',
          'amount': 16800.5,
        };

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.amount, 16800.5);
      });

      test('amount est nul quand absent', () {
        final json = {'bidId': 'bid-uuid-1', 'bidStatus': 'AWAITING_PAYMENT'};

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.amount, isNull);
      });

      test('currency vaut XOF par defaut quand absente', () {
        final json = {'bidId': 'bid-uuid-1', 'bidStatus': 'AWAITING_PAYMENT'};

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.currency, 'XOF');
      });

      test('un statut de depot non reconnu replie sur unknown', () {
        final json = {
          'bidId': 'bid-uuid-1',
          'bidStatus': 'AWAITING_PAYMENT',
          'deposit': {'id': 'deposit-uuid', 'status': 'SOMETHING_NEW'},
        };

        final status = MobileMoneyPaymentStatus.fromJson(json);

        expect(status.deposit!.status, MobileMoneyDepositStatus.unknown);
      });

      test(
        'parses une reponse de fil de negociation (threadId, sans bidStatus)',
        () {
          final json = {
            'threadId': 'thread-uuid-1',
            'paymentStatus': 'PENDING',
            'amount': 16800,
            'currency': 'XOF',
          };

          final status = MobileMoneyPaymentStatus.fromJson(json);

          expect(status.subjectId, 'thread-uuid-1');
          expect(status.subjectStatus, isNull);
          expect(status.paymentStatus, 'PENDING');
        },
      );
    });

    group('isEscrowed', () {
      test('vrai quand paymentStatus vaut ESCROW', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          paymentStatus: 'ESCROW',
        );

        expect(status.isEscrowed, isTrue);
      });

      test('vrai quand paymentStatus vaut RELEASED', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'COMPLETED',
          paymentStatus: 'RELEASED',
        );

        expect(status.isEscrowed, isTrue);
      });

      test('faux quand paymentStatus vaut PENDING ou est nul', () {
        const pending = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          paymentStatus: 'PENDING',
        );
        const none = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
        );

        expect(pending.isEscrowed, isFalse);
        expect(none.isEscrowed, isFalse);
      });
    });

    group('isDepositLive / isDepositFailed', () {
      test('refletent le statut du depot imbrique', () {
        const live = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          deposit: MobileMoneyDeposit(
            id: 'd',
            status: MobileMoneyDepositStatus.processing,
          ),
        );
        const failed = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          deposit: MobileMoneyDeposit(
            id: 'd',
            status: MobileMoneyDepositStatus.failed,
          ),
        );

        expect(live.isDepositLive, isTrue);
        expect(live.isDepositFailed, isFalse);
        expect(failed.isDepositLive, isFalse);
        expect(failed.isDepositFailed, isTrue);
      });

      test('sont faux quand il n\'y a pas encore de depot', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
        );

        expect(status.isDepositLive, isFalse);
        expect(status.isDepositFailed, isFalse);
      });
    });

    group('isExpired', () {
      test('vrai quand bidStatus vaut CANCELLED, meme deadline future', () {
        final status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'CANCELLED',
          deadlineAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(status.isExpired(DateTime.now()), isTrue);
      });

      test('vrai quand la deadline est passee et non sequestre', () {
        final deadline = DateTime.now().subtract(const Duration(minutes: 1));
        final status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          paymentStatus: 'PENDING',
          deadlineAt: deadline,
        );

        expect(status.isExpired(DateTime.now()), isTrue);
      });

      test('faux quand la deadline est encore dans le futur', () {
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        final status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          paymentStatus: 'PENDING',
          deadlineAt: deadline,
        );

        expect(status.isExpired(DateTime.now()), isFalse);
      });

      test('jamais expire une fois sequestre, meme deadline passee', () {
        final deadline = DateTime.now().subtract(const Duration(minutes: 1));
        final status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'ACCEPTED',
          paymentStatus: 'ESCROW',
          deadlineAt: deadline,
        );

        expect(status.isExpired(DateTime.now()), isFalse);
      });

      test('faux sans deadline quand le bid n\'est pas annule', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
        );

        expect(status.isExpired(DateTime.now()), isFalse);
      });

      test('vrai quand paymentStatus vaut CANCELLED (fil revenu a payer)', () {
        final status = MobileMoneyPaymentStatus(
          subjectId: 'thread-1',
          paymentStatus: 'CANCELLED',
          deadlineAt: DateTime.now().add(const Duration(hours: 1)),
        );

        expect(status.isExpired(DateTime.now()), isTrue);
      });
    });

    group('isReverted', () {
      test('vrai sur un fil revenu a payer (CANCELLED sans bidStatus)', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'thread-1',
          paymentStatus: 'CANCELLED',
        );

        expect(status.isReverted, isTrue);
      });

      test('faux sur un bid annule (bidStatus CANCELLED)', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'CANCELLED',
          paymentStatus: 'CANCELLED',
        );

        expect(status.isReverted, isFalse);
      });

      test('faux quand le paiement est PENDING ou nul', () {
        const pending = MobileMoneyPaymentStatus(
          subjectId: 'thread-1',
          paymentStatus: 'PENDING',
        );
        const none = MobileMoneyPaymentStatus(subjectId: 'thread-1');

        expect(pending.isReverted, isFalse);
        expect(none.isReverted, isFalse);
      });
    });

    group('isWaveRedirect', () {
      test('vrai quand le depot a une authorizationUrl', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          deposit: MobileMoneyDeposit(
            id: 'd',
            status: MobileMoneyDepositStatus.created,
            authorizationUrl: 'https://wave.test/pay?ref=abc',
          ),
        );

        expect(status.isWaveRedirect, isTrue);
      });

      test('faux quand le depot n\'a pas d\'authorizationUrl', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          deposit: MobileMoneyDeposit(
            id: 'd',
            status: MobileMoneyDepositStatus.created,
          ),
        );

        expect(status.isWaveRedirect, isFalse);
      });

      test('faux quand il n\'y a pas de depot', () {
        const status = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
        );

        expect(status.isWaveRedirect, isFalse);
      });
    });

    group('Equatable', () {
      test('deux statuts avec les memes donnees sont egaux', () {
        const a = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          paymentStatus: 'PENDING',
        );
        const b = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
          paymentStatus: 'PENDING',
        );

        expect(a, equals(b));
      });

      test('deux statuts avec un bidId different ne sont pas egaux', () {
        const a = MobileMoneyPaymentStatus(
          subjectId: 'bid-1',
          subjectStatus: 'AWAITING_PAYMENT',
        );
        const b = MobileMoneyPaymentStatus(
          subjectId: 'bid-2',
          subjectStatus: 'AWAITING_PAYMENT',
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
