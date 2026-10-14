import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalize : majuscules, format [A-Z0-9-]{4,20}', () {
    expect(PendingReferralCodeStore.normalize(' abou1890 '), 'ABOU1890');
    expect(PendingReferralCodeStore.normalize('MERCI-7K2F'), 'MERCI-7K2F');
    expect(PendingReferralCodeStore.normalize('AB'), isNull);
    expect(PendingReferralCodeStore.normalize('ABC/../X'), isNull);
    expect(PendingReferralCodeStore.normalize('A' * 21), isNull);
    expect(PendingReferralCodeStore.normalize(null), isNull);
  });

  test('save puis relecture par une nouvelle instance', () async {
    final store = PendingReferralCodeStore();
    await store.ready;
    await store.save('abou1890');
    expect(store.current, 'ABOU1890');

    final reloaded = PendingReferralCodeStore();
    await reloaded.ready;
    expect(reloaded.current, 'ABOU1890');
  });

  test('un code invalide n\'est pas gardé', () async {
    final store = PendingReferralCodeStore();
    await store.ready;
    await store.save('x');
    expect(store.current, isNull);
  });

  test('clear efface la mémoire et le disque', () async {
    final store = PendingReferralCodeStore();
    await store.save('ABOU1890');
    await store.clear();
    expect(store.current, isNull);

    final reloaded = PendingReferralCodeStore();
    await reloaded.ready;
    expect(reloaded.current, isNull);
  });

  test('un code de plus de 30 jours est oublié', () async {
    final saved = DateTime(2026);
    SharedPreferences.setMockInitialValues({
      'pending_referral_code': 'ABOU1890',
      'pending_referral_code_saved_at': saved.millisecondsSinceEpoch,
    });

    final store = PendingReferralCodeStore(
      now: () => saved.add(const Duration(days: 31)),
    );
    await store.ready;
    expect(store.current, isNull);
  });

  test('un code récent est relu', () async {
    final saved = DateTime(2026);
    SharedPreferences.setMockInitialValues({
      'pending_referral_code': 'ABOU1890',
      'pending_referral_code_saved_at': saved.millisecondsSinceEpoch,
    });

    final store = PendingReferralCodeStore(
      now: () => saved.add(const Duration(days: 2)),
    );
    await store.ready;
    expect(store.current, 'ABOU1890');
  });
}
