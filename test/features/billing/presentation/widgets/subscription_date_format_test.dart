import 'package:dony/features/billing/presentation/widgets/subscription_date_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  final date = DateTime(2026, 12, 24);

  test('français par défaut', () {
    expect(formatSubscriptionDate(date), '24 décembre 2026');
  });

  test('anglais quand la langue de l’app est l’anglais', () {
    useEnglish();
    expect(formatSubscriptionDate(date), '24 December 2026');
  });
}
