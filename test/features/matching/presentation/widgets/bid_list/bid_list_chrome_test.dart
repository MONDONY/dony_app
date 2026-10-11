import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_list_chrome.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _l = lookupAppLocalizations(AppL10n.fr);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: AppL10n.fr,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('BidListErrorView affiche le message et relance au tap', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(BidListErrorView(message: 'Boom', onRetry: () => retries++)),
    );

    expect(find.text('Boom'), findsOneWidget);
    await tester.tap(find.text(_l.commonRetry));
    expect(retries, 1);
  });

  testWidgets('HiddenBidsBanner affiche le compte et « Voir tout »', (
    tester,
  ) async {
    var shown = 0;
    await tester.pumpWidget(
      _host(HiddenBidsBanner(count: 3, onShowAll: () => shown++)),
    );

    expect(find.text(_l.bidListHiddenOffers(3)), findsOneWidget);
    await tester.tap(find.text(_l.commonSeeAll));
    expect(shown, 1);
  });

  testWidgets('DismissBackground affiche le libellé « Supprimer »', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SizedBox(height: 120, child: DismissBackground())),
    );
    expect(find.text(_l.commonDelete), findsOneWidget);
  });
}
