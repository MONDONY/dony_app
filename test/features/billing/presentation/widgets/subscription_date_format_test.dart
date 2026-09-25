import 'package:dony/features/billing/presentation/widgets/subscription_date_format.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);
  final date = DateTime(2026, 12, 24);

  test('français par défaut', () {
    expect(formatSubscriptionDate(fr, date), '24 décembre 2026');
  });

  test('anglais quand la langue de l’app est l’anglais', () {
    expect(formatSubscriptionDate(en, date), 'December 24, 2026');
  });
}
