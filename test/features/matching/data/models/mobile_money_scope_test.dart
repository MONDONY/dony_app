import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '11111111-1111-1111-1111-111111111111';
  test('portée bid : chemins et routes sous /bids', () {
    const s = MobileMoneyScope.bid(id);
    expect(s.statusPath, '/bids/$id/mobile-money/status');
    expect(s.initiatePath, '/bids/$id/mobile-money/initiate');
    expect(s.awaitingRoute, '/bids/$id/mobile-money/awaiting');
    expect(s.fallbackRoute, '/bids/$id');
    expect(s.analyticsName, 'bid');
  });
  test('portée négociation : chemins et routes sous /negotiations', () {
    const s = MobileMoneyScope.negotiation(id);
    expect(s.statusPath, '/negotiations/$id/mobile-money/status');
    expect(s.initiatePath, '/negotiations/$id/mobile-money/initiate');
    expect(s.awaitingRoute, '/negotiations/$id/mobile-money/awaiting');
    expect(s.fallbackRoute, '/negotiations/$id');
    expect(s.analyticsName, 'negotiation');
  });
  test('égalité par type et id', () {
    expect(const MobileMoneyScope.bid(id), const MobileMoneyScope.bid(id));
    expect(
      const MobileMoneyScope.bid(id),
      isNot(const MobileMoneyScope.negotiation(id)),
    );
  });
}
