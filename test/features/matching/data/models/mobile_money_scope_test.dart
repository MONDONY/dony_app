import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '11111111-1111-1111-1111-111111111111';
  const supplementId = '22222222-2222-2222-2222-222222222222';
  test('portée bid : chemins et routes sous /bids', () {
    const s = MobileMoneyScope.bid(id);
    expect(s.statusPath, '/bids/$id/mobile-money/status');
    expect(s.initiatePath, '/bids/$id/mobile-money/initiate');
    expect(s.awaitingRoute, '/bids/$id/mobile-money/awaiting');
    expect(s.fallbackRoute, '/bids/$id');
    expect(s.cancelledIsFinal, isFalse);
    expect(s.analyticsName, 'bid');
  });
  test('portée négociation : chemins et routes sous /negotiations', () {
    const s = MobileMoneyScope.negotiation(id);
    expect(s.statusPath, '/negotiations/$id/mobile-money/status');
    expect(s.initiatePath, '/negotiations/$id/mobile-money/initiate');
    expect(s.awaitingRoute, '/negotiations/$id/mobile-money/awaiting');
    expect(s.fallbackRoute, '/negotiations/$id');
    expect(s.cancelledIsFinal, isFalse);
    expect(s.analyticsName, 'negotiation');
  });
  test('portée supplément : chemins du supplément, repli sur le colis', () {
    const s = MobileMoneyScope.supplement(
      bidId: id,
      supplementId: supplementId,
    );
    const base = '/bids/$id/supplements/$supplementId';
    expect(s, isA<SupplementMobileMoneyScope>());
    expect((s as SupplementMobileMoneyScope).bidId, id);
    expect(s.supplementId, supplementId);
    expect(s.statusPath, '$base/mobile-money/status');
    expect(s.initiatePath, '$base/mobile-money/initiate');
    expect(s.awaitingRoute, '$base/mobile-money/awaiting');
    expect(s.fallbackRoute, '/bids/$id');
    expect(s.cancelledIsFinal, isTrue);
    expect(s.analyticsName, 'bid_supplement');
  });
  test(
    'amendmentScope_paths : chemins de la modification, repli sur le colis',
    () {
      const amendmentId = '33333333-3333-3333-3333-333333333333';
      const s = MobileMoneyScope.amendment(bidId: id, amendmentId: amendmentId);
      const base = '/bids/$id/amendments/$amendmentId';
      expect(s, isA<AmendmentMobileMoneyScope>());
      expect((s as AmendmentMobileMoneyScope).bidId, id);
      expect(s.amendmentId, amendmentId);
      expect(s.statusPath, '$base/mobile-money/status');
      expect(s.initiatePath, '$base/mobile-money/initiate');
      expect(s.awaitingRoute, '$base/mobile-money/awaiting');
      // Les opérateurs acceptés sont ceux du colis, comme pour le supplément.
      expect(
        s.acceptedOperatorsPath,
        '/bids/$id/mobile-money/accepted-operators',
      );
      expect(s.fallbackRoute, '/bids/$id');
      expect(s.cancelledIsFinal, isTrue);
      expect(s.analyticsName, 'bid_amendment');
    },
  );
  test('amendmentScope_equality : colis et modification, distincte du bid', () {
    const amendmentId = '33333333-3333-3333-3333-333333333333';
    expect(
      const MobileMoneyScope.amendment(bidId: id, amendmentId: amendmentId),
      const MobileMoneyScope.amendment(bidId: id, amendmentId: amendmentId),
    );
    expect(
      const MobileMoneyScope.amendment(bidId: id, amendmentId: amendmentId),
      isNot(
        const MobileMoneyScope.amendment(
          bidId: supplementId,
          amendmentId: amendmentId,
        ),
      ),
    );
    expect(
      const MobileMoneyScope.amendment(bidId: id, amendmentId: amendmentId),
      isNot(
        const MobileMoneyScope.supplement(bidId: id, supplementId: amendmentId),
      ),
    );
  });
  test('scope_acceptedOperatorsPath_perScope', () {
    expect(
      const MobileMoneyScope.bid(id).acceptedOperatorsPath,
      '/bids/$id/mobile-money/accepted-operators',
    );
    expect(
      const MobileMoneyScope.negotiation(id).acceptedOperatorsPath,
      '/negotiations/$id/mobile-money/accepted-operators',
    );
    // Le supplément se paie sur le colis : mêmes opérateurs acceptés que
    // le colis (route du bid), pas de route propre au supplément.
    expect(
      const MobileMoneyScope.supplement(
        bidId: id,
        supplementId: supplementId,
      ).acceptedOperatorsPath,
      '/bids/$id/mobile-money/accepted-operators',
    );
  });
  test('égalité par type et id', () {
    expect(const MobileMoneyScope.bid(id), const MobileMoneyScope.bid(id));
    expect(
      const MobileMoneyScope.bid(id),
      isNot(const MobileMoneyScope.negotiation(id)),
    );
  });
  test('égalité d\'un supplément : colis et supplément', () {
    expect(
      const MobileMoneyScope.supplement(bidId: id, supplementId: supplementId),
      const MobileMoneyScope.supplement(bidId: id, supplementId: supplementId),
    );
    expect(
      const MobileMoneyScope.supplement(bidId: id, supplementId: supplementId),
      isNot(
        const MobileMoneyScope.supplement(
          bidId: supplementId,
          supplementId: supplementId,
        ),
      ),
    );
    expect(
      const MobileMoneyScope.supplement(bidId: id, supplementId: id),
      isNot(const MobileMoneyScope.bid(id)),
    );
  });
}
