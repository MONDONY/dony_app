// Section « Votre transport » de la fiche colis voyageur : titre, tuiles de
// `travelerTilesFor`, résumés, ouverture du sheet, FR/EN, 360 dp et grand
// texte.
import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_transport_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

const _handover = AddressData(
  label: '22 Rue du Séminaire, 94550 Chevilly-Larue, France',
  lat: 48.7667,
  lng: 2.3508,
);
const _delivery = AddressData(
  label: 'ACI 2000, Bamako, Mali',
  lat: 12.6362,
  lng: -8.0121,
);

BidModel _bid({
  String status = 'ACCEPTED',
  double? weightKg = 3,
  String? recipientName = 'Awa',
  bool recipientDeclined = false,
  AddressData? handoverAddress = _handover,
  AddressData? deliveryAddress = _delivery,
  String? departureCity = 'Paris',
  String? arrivalCity = 'Bamako',
  String? handoverLocation,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  weightKg: weightKg,
  recipientName: recipientName,
  recipientDeclined: recipientDeclined,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  handoverAddress: handoverAddress,
  deliveryAddress: deliveryAddress,
  handoverLocation: handoverLocation,
);

/// Charge les vraies polices : avec la police de repli des tests, chaque glyphe
/// fait un cadratin et les libellés paraîtraient plus larges que sur appareil.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await _loadAppFonts();
  });

  setUp(() async {
    final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
    await analytics.onConfigured();
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Future<void> pump(
    WidgetTester tester,
    BidModel bid, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: TravelerTransportSection(bid: bid),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder tile(TravelerTile t) => find.byKey(Key('traveler-tile-${t.name}'));

  Finder textIn(TravelerTile t, String text) =>
      find.descendant(of: tile(t), matching: find.text(text));

  testWidgets('titre de section et trois tuiles dans l\'ordre', (tester) async {
    await pump(tester, _bid());

    expect(find.text('Votre transport'), findsOneWidget);
    expect(tile(TravelerTile.lieux), findsOneWidget);
    expect(tile(TravelerTile.colis), findsOneWidget);
    expect(tile(TravelerTile.details), findsOneWidget);
    expect(find.byType(DonyActionTile), findsNWidgets(3));
    // Ordre de la grille : Lieux, Colis puis Détails.
    expect(
      tester.getTopLeft(tile(TravelerTile.lieux)).dx,
      lessThan(tester.getTopLeft(tile(TravelerTile.colis)).dx),
    );
  });

  testWidgets('titres des tuiles (FR)', (tester) async {
    await pump(tester, _bid());

    expect(textIn(TravelerTile.lieux, 'Lieux'), findsOneWidget);
    expect(textIn(TravelerTile.colis, 'Colis et destinataire'), findsOneWidget);
    expect(textIn(TravelerTile.details, 'Plus de détails'), findsOneWidget);
  });

  testWidgets('titres des tuiles et de la section (EN)', (tester) async {
    await pump(tester, _bid(), locale: const Locale('en'));

    expect(find.text('Your trip'), findsOneWidget);
    expect(textIn(TravelerTile.lieux, 'Places'), findsOneWidget);
    expect(textIn(TravelerTile.colis, 'Parcel and recipient'), findsOneWidget);
    expect(textIn(TravelerTile.details, 'More details'), findsOneWidget);
  });

  group('tuile Colis : résumé', () {
    testWidgets('poids et destinataire', (tester) async {
      await pump(tester, _bid());

      expect(textIn(TravelerTile.colis, '3 kg · pour Awa'), findsOneWidget);
    });

    testWidgets('poids et destinataire (EN)', (tester) async {
      await pump(tester, _bid(), locale: const Locale('en'));

      expect(textIn(TravelerTile.colis, '3 kg · for Awa'), findsOneWidget);
    });

    testWidgets('destinataire sans nom : le poids seul', (tester) async {
      await pump(tester, _bid(recipientName: ' '));

      expect(textIn(TravelerTile.colis, '3 kg'), findsOneWidget);
    });

    testWidgets('destinataire refusé : son nom n\'est pas répété', (
      tester,
    ) async {
      await pump(tester, _bid(recipientDeclined: true));

      expect(textIn(TravelerTile.colis, '3 kg'), findsOneWidget);
      expect(find.textContaining('Awa'), findsNothing);
    });

    testWidgets('poids inconnu : pas de résumé', (tester) async {
      await pump(tester, _bid(weightKg: null));

      expect(find.textContaining(' kg'), findsNothing);
    });
  });

  group('tuile Lieux : résumé', () {
    testWidgets('avant la remise : la ville de dépôt', (tester) async {
      await pump(tester, _bid());

      expect(textIn(TravelerTile.lieux, 'Remise à Paris'), findsOneWidget);
    });

    for (final status in [
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
    ]) {
      testWidgets('$status : la ville de récupération', (tester) async {
        await pump(tester, _bid(status: status));

        expect(
          textIn(TravelerTile.lieux, 'Récupération à Bamako'),
          findsOneWidget,
        );
      });
    }

    testWidgets('EN : drop-off puis pickup', (tester) async {
      await pump(tester, _bid(), locale: const Locale('en'));
      expect(textIn(TravelerTile.lieux, 'Drop-off in Paris'), findsOneWidget);

      await pump(
        tester,
        _bid(status: 'IN_TRANSIT'),
        locale: const Locale('en'),
      );
      expect(textIn(TravelerTile.lieux, 'Pickup in Bamako'), findsOneWidget);
    });

    testWidgets('ville inconnue : repli sur le libellé de l\'adresse', (
      tester,
    ) async {
      await pump(tester, _bid(departureCity: null));

      expect(
        textIn(TravelerTile.lieux, 'Remise à ${_handover.label}'),
        findsOneWidget,
      );
    });

    testWidgets('rien de connu pour l\'étape : pas de résumé', (tester) async {
      await pump(
        tester,
        _bid(
          status: 'IN_TRANSIT',
          arrivalCity: null,
          deliveryAddress: null,
          handoverLocation: 'Gare de Lyon',
        ),
      );

      expect(find.textContaining('Récupération à'), findsNothing);
      expect(find.textContaining('Retrait'), findsNothing);
    });
  });

  testWidgets('tuile Détails : résumé de ce que montre le sheet', (
    tester,
  ) async {
    await pump(tester, _bid());

    expect(
      textIn(TravelerTile.details, 'Référence, dépôt, trajet'),
      findsOneWidget,
    );
  });

  testWidgets('statut clos : Lieux disparaît de la grille', (tester) async {
    await pump(tester, _bid(status: 'CANCELLED'));

    expect(tile(TravelerTile.lieux), findsNothing);
    expect(find.byType(DonyActionTile), findsNWidgets(2));
  });

  testWidgets('sans adresse : Lieux disparaît, Colis et Détails restent', (
    tester,
  ) async {
    await pump(tester, _bid(handoverAddress: null, deliveryAddress: null));

    expect(tile(TravelerTile.lieux), findsNothing);
    expect(tile(TravelerTile.colis), findsOneWidget);
    expect(tile(TravelerTile.details), findsOneWidget);
  });

  group('un tap ouvre le sheet de la tuile', () {
    for (final (t, title) in [
      (TravelerTile.lieux, 'Remise du colis'),
      (TravelerTile.colis, 'Awa'),
      (TravelerTile.details, 'DEMANDE'),
    ]) {
      testWidgets(t.name, (tester) async {
        await pump(tester, _bid());

        await tester.tap(tile(t));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(title), findsWidgets);
        expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
      });
    }
  });

  group('sans débordement', () {
    final bids = {
      'noms longs': _bid(
        status: 'IN_TRANSIT',
        recipientName: 'Aminata Diakité-Konaté',
        arrivalCity: 'Ouagadougou-Centre',
      ),
      // Repli du résumé Lieux sur le libellé de l'adresse, bien plus long
      // qu'une ville.
      'sans ville de départ': _bid(departureCity: null),
      'sans ville d\'arrivée': _bid(status: 'IN_TRANSIT', arrivalCity: null),
    };
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final scale in const [1.0, 1.3]) {
        for (final MapEntry(key: name, value: bid) in bids.entries) {
          testWidgets('${locale.languageCode}, 360 dp, ×$scale, $name', (
            tester,
          ) async {
            await pump(
              tester,
              bid,
              locale: locale,
              textScale: scale,
              size: const Size(360, 800),
            );

            expect(tester.takeException(), isNull);
            for (final t in TravelerTile.values) {
              final box = tester.getRect(tile(t));
              expect(box.left, greaterThanOrEqualTo(0), reason: t.name);
              expect(box.right, lessThanOrEqualTo(360), reason: t.name);
            }
          });
        }
      }
    }
  });
}
