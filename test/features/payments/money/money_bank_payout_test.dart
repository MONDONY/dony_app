import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/l10n/generated/app_localizations_en.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'money_fixtures.dart';

Map<String, dynamic> _itemJson({Object? bankPayout, bool withKey = true}) => {
  'bidId': 'bid-paid',
  'role': 'TRAVELER',
  'state': 'RELEASED_RECENTLY',
  'releaseCondition': 'RELEASED',
  'channel': 'CARD',
  'amount': 42,
  'currency': 'EUR',
  'settledAt': '2026-10-18T10:00:00Z',
  if (withKey) 'bankPayout': bankPayout,
};

BankPayoutModel _payout(
  BankPayoutStatus status, {
  DateTime? availableOn,
  DateTime? arrivalDate,
  DateTime? paidAt,
}) => BankPayoutModel(
  status: status,
  availableOn: availableOn,
  arrivalDate: arrivalDate,
  paidAt: paidAt,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('parsing de bankPayout', () {
    test('présent : statut et dates lus', () {
      final item = MoneyItemModel.fromJson(
        _itemJson(
          bankPayout: {
            'status': 'IN_TRANSIT',
            'availableOn': '2026-10-22',
            'arrivalDate': '2026-10-24',
            'paidAt': '2026-10-24T09:12:00Z',
            'failureCode': 'account_closed',
          },
        ),
      );
      final p = item.bankPayout!;
      expect(p.status, BankPayoutStatus.inTransit);
      expect(p.availableOn, DateTime(2026, 10, 22));
      expect(p.arrivalDate, DateTime(2026, 10, 24));
      expect(p.paidAt, DateTime.utc(2026, 10, 24, 9, 12).toLocal());
      expect(p.failureCode, 'account_closed');
      expect(p.isKnown, isTrue);
      expect(item.trackedBankPayout, same(p));
    });

    test('absent (ancien back) : null, comportement inchangé', () {
      final item = MoneyItemModel.fromJson(_itemJson(withKey: false));
      expect(item.bankPayout, isNull);
      expect(item.trackedBankPayout, isNull);
    });

    test('null ou type inattendu : null', () {
      expect(MoneyItemModel.fromJson(_itemJson()).bankPayout, isNull);
      expect(
        MoneyItemModel.fromJson(_itemJson(bankPayout: 'PAID')).bankPayout,
        isNull,
      );
    });

    test('statut inconnu ou manquant : unknown, pas de suivi affiché', () {
      for (final raw in [
        {'status': 'RETURNED'},
        <String, dynamic>{},
        {'status': 3},
      ]) {
        final item = MoneyItemModel.fromJson(_itemJson(bankPayout: raw));
        expect(item.bankPayout!.status, BankPayoutStatus.unknown);
        expect(item.bankPayout!.isKnown, isFalse);
        expect(item.trackedBankPayout, isNull);
      }
    });

    test('dates illisibles et failureCode vide ignorés', () {
      final p = BankPayoutModel.fromJson({
        'status': 'FAILED',
        'availableOn': 'demain',
        'arrivalDate': 12,
        'paidAt': null,
        'failureCode': '',
      })!;
      expect(p.status, BankPayoutStatus.failed);
      expect(p.availableOn, isNull);
      expect(p.arrivalDate, isNull);
      expect(p.paidAt, isNull);
      expect(p.failureCode, isNull);
    });

    test('tous les statuts du contrat', () {
      expect(
        BankPayoutStatus.parse('PENDING_AVAILABILITY'),
        BankPayoutStatus.pendingAvailability,
      );
      expect(BankPayoutStatus.parse('AVAILABLE'), BankPayoutStatus.available);
      expect(BankPayoutStatus.parse('IN_TRANSIT'), BankPayoutStatus.inTransit);
      expect(BankPayoutStatus.parse('PAID'), BankPayoutStatus.paid);
      expect(BankPayoutStatus.parse('FAILED'), BankPayoutStatus.failed);
      expect(BankPayoutStatus.parse(null), BankPayoutStatus.unknown);
    });

    test('arrivedOn : date prévue, sinon instant du paiement', () {
      final paidAt = DateTime(2026, 10, 24, 11);
      expect(
        _payout(
          BankPayoutStatus.paid,
          arrivalDate: DateTime(2026, 10, 23),
          paidAt: paidAt,
        ).arrivedOn,
        DateTime(2026, 10, 23),
      );
      expect(_payout(BankPayoutStatus.paid, paidAt: paidAt).arrivedOn, paidAt);
    });

    test('suivi ignoré hors colis versé voyageur', () {
      final p = _payout(BankPayoutStatus.paid);
      expect(
        item(
          state: MoneyState.releasedRecently,
          role: MoneyRole.sender,
          bankPayout: p,
        ).trackedBankPayout,
        isNull,
      );
      expect(
        item(
          state: MoneyState.payoutInProgress,
          bankPayout: p,
        ).trackedBankPayout,
        isNull,
      );
    });
  });

  group('shortStateFor avec bankPayout', () {
    final fr = AppLocalizationsFr();
    final en = AppLocalizationsEn();

    MoneyItemModel paid(BankPayoutModel? p) => item(
      state: MoneyState.releasedRecently,
      settledAt: DateTime(2026, 10, 18),
      bankPayout: p,
    );

    test('PENDING_AVAILABILITY', () {
      expect(
        shortStateFor(
          paid(
            _payout(
              BankPayoutStatus.pendingAvailability,
              availableOn: DateTime(2026, 10, 22),
            ),
          ),
          fr,
        ),
        (text: 'payé, dispo le 22 oct.', tone: MoneyTone.info),
      );
      expect(
        shortStateFor(
          paid(_payout(BankPayoutStatus.pendingAvailability)),
          fr,
        ).text,
        'payé, bientôt dispo',
      );
    });

    test('AVAILABLE', () {
      expect(shortStateFor(paid(_payout(BankPayoutStatus.available)), fr), (
        text: 'virement bancaire à venir',
        tone: MoneyTone.info,
      ));
    });

    test('IN_TRANSIT', () {
      expect(
        shortStateFor(
          paid(
            _payout(
              BankPayoutStatus.inTransit,
              arrivalDate: DateTime(2026, 10, 24),
            ),
          ),
          fr,
        ),
        (text: 'virement en cours, arrivée le 24 oct.', tone: MoneyTone.info),
      );
      expect(
        shortStateFor(paid(_payout(BankPayoutStatus.inTransit)), fr).text,
        'virement bancaire en cours',
      );
    });

    test('PAID : arrivalDate, sinon paidAt, sinon sans date', () {
      expect(
        shortStateFor(
          paid(
            _payout(BankPayoutStatus.paid, arrivalDate: DateTime(2026, 10, 24)),
          ),
          fr,
        ),
        (text: 'arrivé sur votre banque le 24 oct.', tone: MoneyTone.positive),
      );
      expect(
        shortStateFor(
          paid(
            _payout(BankPayoutStatus.paid, paidAt: DateTime(2026, 10, 25, 9)),
          ),
          fr,
        ).text,
        'arrivé sur votre banque le 25 oct.',
      );
      expect(
        shortStateFor(paid(_payout(BankPayoutStatus.paid)), fr).text,
        'arrivé sur votre banque',
      );
    });

    test('FAILED', () {
      expect(shortStateFor(paid(_payout(BankPayoutStatus.failed)), fr), (
        text: 'virement échoué, vérifiez votre banque',
        tone: MoneyTone.attention,
      ));
    });

    test('statut inconnu ou absent : « versé le … » d\'avant', () {
      expect(shortStateFor(paid(_payout(BankPayoutStatus.unknown)), fr), (
        text: 'versé le 18 oct.',
        tone: MoneyTone.positive,
      ));
      expect(shortStateFor(paid(null), fr).text, 'versé le 18 oct.');
    });

    test('repli direct de bankPayoutShortState sur un statut inconnu', () {
      expect(
        bankPayoutShortState(_payout(BankPayoutStatus.unknown), fr).text,
        'versé',
      );
    });

    test('anglais', () {
      expect(
        shortStateFor(
          paid(
            _payout(
              BankPayoutStatus.pendingAvailability,
              availableOn: DateTime(2026, 10, 22),
            ),
          ),
          en,
        ).text,
        'paid, available Oct 22',
      );
      expect(
        shortStateFor(paid(_payout(BankPayoutStatus.failed)), en).text,
        'transfer failed, check your bank',
      );
    });
  });
}
