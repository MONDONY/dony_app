import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/my_negotiation_summary.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/my_negotiation_chip.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_carousel_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _app(Widget home, {Locale locale = AppL10n.fr}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

PackageRequestSearchItem _item({MyNegotiationSummary? negotiation}) =>
    PackageRequestSearchItem(
      id: 'pr-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 10, 6),
      dateToleranceDays: 0,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      categories: const ['Vêtements'],
      targetPriceEur: 35,
      myNegotiation: negotiation,
      sender: const SenderPublicProfile(
        id: 's-1',
        displayName: 'Amina',
        averageRating: 4.9,
        totalRatings: 12,
        kycVerified: true,
      ),
    );

const _myTurn = MyNegotiationSummary(
  threadId: 'th-1',
  status: 'OPEN',
  myTurn: true,
);
const _pending = MyNegotiationSummary(
  threadId: 'th-2',
  status: 'OPEN',
  myTurn: false,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  Widget listCard(PackageRequestSearchItem item, {bool own = false}) => _app(
    Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: PackageRequestListCard(item: item, isOwnRequest: own),
        ),
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group('carte liste (FLUTTER-NZ)', () {
    testWidgets('sans négociation → aucune puce', (tester) async {
      await tester.pumpWidget(listCard(_item()));
      await settle(tester);
      expect(find.byType(MyNegotiationChip), findsNothing);
    });

    testWidgets('à mon tour → « Votre tour »', (tester) async {
      await tester.pumpWidget(listCard(_item(negotiation: _myTurn)));
      await settle(tester);
      expect(find.text('Votre tour'), findsOneWidget);
      expect(find.text('Proposition en attente'), findsNothing);
    });

    testWidgets('en attente de l\'expéditeur → « Proposition en attente »', (
      tester,
    ) async {
      await tester.pumpWidget(listCard(_item(negotiation: _pending)));
      await settle(tester);
      expect(find.text('Proposition en attente'), findsOneWidget);
    });

    testWidgets('ma propre demande → jamais de puce', (tester) async {
      await tester.pumpWidget(listCard(_item(negotiation: _myTurn), own: true));
      await settle(tester);
      expect(find.byType(MyNegotiationChip), findsNothing);
    });
  });

  testWidgets('carrousel : puce posée sur la photo', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SizedBox(
            width: 260,
            height: 320,
            child: PackageRequestCarouselCard(
              item: _item(negotiation: _pending),
              index: 0,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Proposition en attente'), findsOneWidget);
  });

  testWidgets('en anglais → « Your turn »', (tester) async {
    enableEnglish();
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: Center(child: MyNegotiationChip(negotiation: _myTurn)),
        ),
        locale: AppL10n.en,
      ),
    );
    expect(find.text('Your turn'), findsOneWidget);
  });

  testWidgets('un appui ouvre le fil de négociation', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Center(child: MyNegotiationChip(negotiation: _myTurn)),
          ),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (_, state) => Text('fil ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: AppL10n.fr,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-negotiation-chip')));
    await tester.pumpAndSettle();
    expect(find.text('fil th-1'), findsOneWidget);
  });

  testWidgets('onTap fourni → remplace la navigation', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: MyNegotiationChip(
              negotiation: _pending,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MyNegotiationChip));
    expect(tapped, isTrue);
  });
}
