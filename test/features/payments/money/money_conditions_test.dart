import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_conditions.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'money_fixtures.dart';

const d = TimelineSegment.done;
const c = TimelineSegment.current;
const a = TimelineSegment.attention;
const t = TimelineSegment.todo;

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    fr = await AppLocalizations.delegate.load(AppL10n.fr);
    en = await AppLocalizations.delegate.load(AppL10n.en);
  });

  group('frise', () {
    test('séquestre avant remise : Payé en cours', () {
      expect(timelineFor(item()), [c, t, t, t]);
    });

    test('remis ou en route : Remis en cours ; arrivé : Livré en cours', () {
      for (final s in ['HANDED_OVER', 'IN_TRANSIT']) {
        expect(
          timelineFor(
            item(state: MoneyState.awaitingDeliveryConfirmation, bidStatus: s),
          ),
          [d, c, t, t],
        );
      }
      expect(
        timelineFor(
          item(
            state: MoneyState.awaitingDeliveryConfirmation,
            bidStatus: 'ARRIVED',
          ),
        ),
        [d, d, c, t],
      );
      // Statut inattendu : jamais avant « Remis » dans cet état.
      expect(
        timelineFor(item(state: MoneyState.awaitingDeliveryConfirmation)),
        [d, c, t, t],
      );
    });

    test('garde datée : trois étapes franchies, Versé à venir', () {
      expect(timelineFor(item(state: MoneyState.releaseScheduled)), [
        d,
        d,
        d,
        t,
      ]);
    });

    test('litige et retenue : étape du colis en orange', () {
      expect(
        timelineFor(item(state: MoneyState.inDispute, bidStatus: 'ARRIVED')),
        [d, d, a, t],
      );
      expect(
        timelineFor(item(state: MoneyState.onHold, bidStatus: 'COMPLETED')),
        [d, d, d, a],
      );
      expect(timelineFor(item(state: MoneyState.onHold)), [a, t, t, t]);
    });

    test('versement en cours puis versé', () {
      expect(timelineFor(item(state: MoneyState.payoutInProgress)), [
        d,
        d,
        d,
        c,
      ]);
      expect(timelineFor(item(state: MoneyState.releasedRecently)), [
        d,
        d,
        d,
        d,
      ]);
    });

    test('pas de frise pour espèces, remboursements, état inconnu', () {
      for (final s in [
        MoneyState.cash,
        MoneyState.refundPending,
        MoneyState.refundedRecently,
        MoneyState.unknown,
      ]) {
        expect(timelineFor(item(state: s)), isNull, reason: s.name);
      }
    });

    test('libellés dans l\'ordre', () {
      expect(timelineLabels(fr), ['Payé', 'Remis', 'Livré', 'Versé']);
    });
  });

  group('phrases voyageur', () {
    String text(MoneyItemModel i) => conditionFor(i, fr).text;

    test('séquestre : à la confirmation de livraison', () {
      expect(text(item()), 'Versé quand le destinataire confirme la livraison');
      expect(
        text(item(state: MoneyState.awaitingDeliveryConfirmation)),
        'Versé quand le destinataire confirme la livraison',
      );
    });

    test('garde : date de versement automatique', () {
      final r = conditionFor(
        item(
          state: MoneyState.releaseScheduled,
          releaseAt: DateTime(2026, 10, 11, 10),
        ),
        fr,
      );
      expect(r.text, 'Versé automatiquement le 11 oct. si aucun litige');
      expect(r.tone, ConditionTone.positive);
      // Sans date (ne devrait pas arriver) : la condition seule.
      expect(
        text(item(state: MoneyState.releaseScheduled)),
        'Versé quand le destinataire confirme la livraison',
      );
    });

    test('litige, retenue, versement, versé, remboursement', () {
      final dispute = conditionFor(item(state: MoneyState.inDispute), fr);
      expect(dispute.tone, ConditionTone.attention);
      expect(dispute.text, contains('litige'));
      expect(text(item(state: MoneyState.onHold)), contains('vérification'));
      expect(
        text(item(state: MoneyState.payoutInProgress)),
        'Livré : versement en cours',
      );
      expect(
        text(
          item(
            state: MoneyState.releasedRecently,
            settledAt: DateTime(2026, 10, 5),
          ),
        ),
        'Versé le 5 oct.',
      );
      expect(text(item(state: MoneyState.releasedRecently)), 'Versé');
      expect(
        text(item(state: MoneyState.refundPending)),
        'Annulé : remboursement en cours à l\'expéditeur',
      );
      expect(text(item(state: MoneyState.unknown)), contains('mise à jour'));
    });

    test('espèces : statut de la commission', () {
      expect(
        text(item(state: MoneyState.cash, cashCommissionStatus: 'CHARGED')),
        'Payé en espèces à la remise · commission réglée',
      );
      expect(
        text(item(state: MoneyState.cash, cashCommissionStatus: 'PENDING')),
        'Payé en espèces à la remise · commission en attente',
      );
      expect(
        text(item(state: MoneyState.cash, cashCommissionStatus: 'REFUNDED')),
        'Payé en espèces à la remise · commission remboursée',
      );
      expect(text(item(state: MoneyState.cash)), 'Payé en espèces à la remise');
    });
  });

  group('phrases expéditeur', () {
    String text(MoneyState s, {DateTime? at, DateTime? settled}) =>
        conditionFor(
          item(
            state: s,
            role: MoneyRole.sender,
            releaseAt: at,
            settledAt: settled,
            cashCommissionStatus: 'CHARGED',
          ),
          fr,
        ).text;

    test('toutes les conditions', () {
      expect(
        text(MoneyState.escrowed),
        'Bloqué jusqu\'à la livraison, puis versé au voyageur',
      );
      expect(
        text(MoneyState.releaseScheduled, at: DateTime(2026, 10, 11)),
        'Versé au voyageur le 11 oct. si aucun litige',
      );
      expect(text(MoneyState.inDispute), 'En litige : l\'équipe Yadony décide');
      expect(text(MoneyState.onHold), contains('vérification'));
      expect(
        text(MoneyState.payoutInProgress),
        'Livré : versement au voyageur en cours',
      );
      expect(text(MoneyState.refundPending), 'Remboursement en cours');
      expect(
        text(MoneyState.refundedRecently, settled: DateTime(2026, 10, 2)),
        'Remboursé le 2 oct.',
      );
      expect(text(MoneyState.refundedRecently), 'Remboursé');
      // La commission espèces ne concerne pas l'expéditeur.
      expect(text(MoneyState.cash), 'À régler en espèces à la remise');
    });
  });

  test('anglais', () {
    expect(
      conditionFor(
        item(
          state: MoneyState.releaseScheduled,
          releaseAt: DateTime(2026, 10, 11),
        ),
        en,
      ).text,
      'Paid out automatically on Oct 11 if there is no dispute',
    );
  });

  test('formatMoney : devise et absence de décimales inutiles', () {
    expect(formatMoney(7950, 'XOF'), contains('7'));
    expect(formatMoney(7950, 'XOF'), isNot(contains(',00')));
    expect(formatMoney(26.4, 'EUR'), contains('26,40'));
  });
}
