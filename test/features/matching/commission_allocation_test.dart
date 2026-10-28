import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/commission_allocation_preview.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/commission_allocation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockBidRepository extends Mock implements BidRepository {}

BidModel _bid(BidPaymentMethod method) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 5,
  description: 'Test',
  status: 'PENDING',
  createdAt: DateTime(2026, 10, 28),
  updatedAt: DateTime(2026, 10, 28),
  paymentMethod: method,
);

const _mixed = {
  'bidCurrency': 'eur',
  'commission': 6,
  'covered': true,
  'lines': [
    {'currency': 'USD', 'debitAmount': 4.0, 'coveredInBid': 3.5},
    {
      'currency': 'xof',
      'debitAmount': 1639.9,
      'coveredInBid': 2.5,
      'rateOfTheDay': 655.96,
    },
  ],
};

void main() {
  group('CommissionAllocationPreview', () {
    test('lit les lignes, majuscules et taux du jour', () {
      final p = CommissionAllocationPreview.fromJson(_mixed);

      expect(p.bidCurrency, 'EUR');
      expect(p.lines.map((l) => l.currency), ['USD', 'XOF']);
      expect(p.lines.first.converted, isFalse);
      expect(p.lines.last.rateOfTheDay, 655.96);
      expect(p.needsExplanation, isTrue);
    });

    test('un seul portefeuille sans conversion : rien à expliquer', () {
      final p = CommissionAllocationPreview.fromJson(const {
        'bidCurrency': 'EUR',
        'commission': 6,
        'covered': true,
        'lines': [
          {'currency': 'EUR', 'debitAmount': 6, 'coveredInBid': 6},
        ],
      });
      expect(p.needsExplanation, isFalse);
    });

    test('un seul portefeuille converti : à expliquer', () {
      final p = CommissionAllocationPreview.fromJson(const {
        'bidCurrency': 'EUR',
        'commission': 6,
        'covered': true,
        'lines': [
          {
            'currency': 'XOF',
            'debitAmount': 3935.76,
            'coveredInBid': 6,
            'rateOfTheDay': 655.96,
          },
        ],
      });
      expect(p.needsExplanation, isTrue);
    });

    test(
      'non couvert : rien à expliquer, le solde insuffisant prend le relais',
      () {
        final p = CommissionAllocationPreview.fromJson(const {
          'bidCurrency': 'EUR',
          'commission': 6,
          'covered': false,
          'fundingDetail': {
            'bidCurrency': 'EUR',
            'commission': 6,
            'availableInBid': 2,
            'shortfallInBid': 4,
          },
        });
        expect(p.needsExplanation, isFalse);
        expect(p.fundingDetail?.shortfallInBid, 4);
        expect(p.lines, isEmpty);
      },
    );
  });

  group('confirmCashCommissionAllocation', () {
    late _MockBidRepository repo;
    bool? result;

    Future<void> run(
      WidgetTester tester,
      BidModel bid, {
      Future<void> Function()? interact,
    }) async {
      result = null;
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await confirmCashCommissionAllocation(
                    context,
                    bid,
                    repository: repo,
                  ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (interact != null) await interact();
    }

    setUp(() => repo = _MockBidRepository());

    testWidgets('autre moyen de paiement : poursuit sans appel ni feuille', (
      tester,
    ) async {
      await run(tester, _bid(BidPaymentMethod.stripe));

      expect(result, isTrue);
      verifyNever(() => repo.previewCommissionAllocation(any()));
    });

    testWidgets('aperçu indisponible : poursuit sans feuille', (tester) async {
      when(
        () => repo.previewCommissionAllocation('bid-1'),
      ).thenThrow(Exception('404'));

      await run(tester, _bid(BidPaymentMethod.cash));

      expect(result, isTrue);
      expect(
        find.byKey(const Key('commission-allocation-line-USD')),
        findsNothing,
      );
    });

    testWidgets('un seul portefeuille de la devise du colis : poursuit', (
      tester,
    ) async {
      when(() => repo.previewCommissionAllocation('bid-1')).thenAnswer(
        (_) async => CommissionAllocationPreview.fromJson(const {
          'bidCurrency': 'EUR',
          'commission': 6,
          'covered': true,
          'lines': [
            {'currency': 'EUR', 'debitAmount': 6, 'coveredInBid': 6},
          ],
        }),
      );

      await run(tester, _bid(BidPaymentMethod.cash));

      expect(result, isTrue);
    });

    testWidgets('plusieurs portefeuilles : feuille puis confirmation', (
      tester,
    ) async {
      when(
        () => repo.previewCommissionAllocation('bid-1'),
      ).thenAnswer((_) async => CommissionAllocationPreview.fromJson(_mixed));

      await run(
        tester,
        _bid(BidPaymentMethod.cash),
        interact: () async {
          expect(
            find.byKey(const Key('commission-allocation-line-USD')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('commission-allocation-line-XOF')),
            findsOneWidget,
          );
          expect(find.textContaining('au taux du jour'), findsNWidgets(2));
          expect(result, isNull);
          await tester.tap(find.text('Accepter et régler'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        },
      );

      expect(result, isTrue);
    });

    testWidgets('feuille fermée sans confirmer : on ne poursuit pas', (
      tester,
    ) async {
      when(
        () => repo.previewCommissionAllocation('bid-1'),
      ).thenAnswer((_) async => CommissionAllocationPreview.fromJson(_mixed));

      await run(
        tester,
        _bid(BidPaymentMethod.cash),
        interact: () async {
          await tester.tapAt(const Offset(5, 5));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        },
      );

      expect(result, isFalse);
    });
  });
}
