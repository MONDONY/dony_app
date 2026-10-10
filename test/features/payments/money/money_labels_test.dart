import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'money_fixtures.dart';

void main() {
  final l = AppLocalizationsFr();

  setUpAll(() => initializeDateFormatting('fr'));

  ({String text, MoneyTone tone}) short(MoneyItemModel i) =>
      shortStateFor(i, l);

  test('états courts et tons', () {
    expect(short(item()).text, 'à la livraison');
    expect(
      short(item(state: MoneyState.awaitingDeliveryConfirmation)).text,
      'à la livraison',
    );
    expect(
      short(item(state: MoneyState.releaseScheduled)).text,
      'à la livraison',
    );
    final auto = short(
      item(
        state: MoneyState.releaseScheduled,
        releaseAt: DateTime(2026, 10, 11),
      ),
    );
    expect(auto.text, 'versement auto le 11 oct.');
    expect(auto.tone, MoneyTone.info);
    expect(short(item(state: MoneyState.inDispute)).tone, MoneyTone.attention);
    expect(short(item(state: MoneyState.onHold)).text, 'en vérification');
    expect(
      short(item(state: MoneyState.payoutInProgress)).text,
      'livré · versement en cours',
    );
    expect(
      short(
        item(
          state: MoneyState.releasedRecently,
          settledAt: DateTime(2026, 10, 5),
        ),
      ),
      (text: 'versé le 5 oct.', tone: MoneyTone.positive),
    );
    expect(short(item(state: MoneyState.releasedRecently)).text, 'versé');
    expect(
      short(item(state: MoneyState.refundPending)).text,
      'remboursement en cours',
    );
    expect(
      short(
        item(
          state: MoneyState.refundedRecently,
          settledAt: DateTime(2026, 10, 2),
        ),
      ).text,
      'remboursé le 2 oct.',
    );
    expect(short(item(state: MoneyState.refundedRecently)).text, 'remboursé');
    expect(short(item(state: MoneyState.unknown)).text, 'mise à jour en cours');
  });

  test('espèces : commission pour le voyageur seulement', () {
    String cash(String? status, {MoneyRole role = MoneyRole.traveler}) => short(
      item(state: MoneyState.cash, cashCommissionStatus: status, role: role),
    ).text;
    expect(cash(null), 'en espèces');
    expect(cash('CHARGED'), 'en espèces · commission réglée');
    expect(cash('REFUNDED'), 'en espèces · commission remboursée');
    expect(cash('PENDING'), 'en espèces · commission en attente');
    expect(cash('CHARGED', role: MoneyRole.sender), 'en espèces');
  });

  test('trajet, dates et montants par devise', () {
    expect(routeOf('Paris', 'Abidjan'), 'Paris → Abidjan');
    expect(routeOf(null, 'Abidjan'), 'Abidjan');
    expect(routeOf(null, null), isNull);
    expect(dayDate(DateTime(2026, 10, 11), l), 'dim. 11 oct.');
    expect(
      formatAmounts(const [MoneyAmount('EUR', 12), MoneyAmount('XOF', 9000)]),
      contains(' · '),
    );
  });
}
