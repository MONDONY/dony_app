import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/gallery_save_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/trip_poster_screen.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/l10n_test_helpers.dart';
import '../../helpers/mock_analytics_backend.dart';

AnnouncementModel _announcement({
  double pricePerKg = 6.0,
  double? pricePerKgDisplay = 8.0,
  String pricingMode = 'KG',
  List<Map<String, dynamic>> gridItems = const [],
  String capacityUnit = 'SUITCASE_23KG',
  String? pickupLabel,
  String? deliveryLabel,
  Map<String, dynamic> extra = const {},
}) => AnnouncementModel.fromJson({
  'id': 'a1',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 8, 20).toIso8601String(),
  'availableKg': 12.0,
  'totalKg': 23.0,
  'pricePerKg': pricePerKg,
  'pricePerKgDisplay': pricePerKgDisplay,
  'handoverDeadline': DateTime(2026, 8, 19, 19).toIso8601String(),
  'currency': 'EUR',
  'pricingMode': pricingMode,
  'priceGridItems': gridItems,
  'capacityUnit': capacityUnit,
  if (pickupLabel != null)
    'pickupAddress': {'label': pickupLabel, 'lat': 48.88, 'lng': 2.35},
  if (deliveryLabel != null)
    'deliveryAddress': {'label': deliveryLabel, 'lat': 14.69, 'lng': -17.44},
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
  ...extra,
});

Map<String, dynamic> _gridItem(String label, double display) => {
  'id': 'g-$label',
  'label': label,
  'unitPriceNet': display / 1.05,
  'unitPriceDisplay': display,
};

Future<void> _pump(WidgetTester tester, {AnnouncementModel? announcement}) =>
    tester.pumpWidget(
      MaterialApp(
        home: TripPosterScreen(
          announcement: announcement ?? _announcement(),
          shareBaseUrl: 'https://api.yadony.test/api/v1',
        ),
      ),
    );

/// Les actions vivent sous la ligne de flottaison du viewport de test : sans
/// defilement prealable, le tap tombe hors de la zone testable et n'atteint
/// jamais le bouton.
Future<void> _tapAction(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

const _groupUrl = 'https://www.facebook.com/groups/1051558350756867';

String _configJson({required bool groupActive}) =>
    '{"schemaVersion": 1, "socialLinks": [{"network": "facebook", '
    '"url": "$_groupUrl", "active": $groupActive}], "tutorials": []}';

final class _StaticSource implements HelpCenterConfigSource {
  const _StaticSource(this.activatedJson);

  @override
  final String activatedJson;

  @override
  Future<String?> fetchAndActivate() async => activatedJson;
}

/// Note les ouvertures et leur mode : l'application Facebook est ici absente,
/// la tentative applicative échoue et le navigateur prend le relais.
final class _RecordingLauncher extends UrlLauncherPlatform {
  final opened = <(String, PreferredLaunchMode)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add((url, options.mode));
    return options.mode != PreferredLaunchMode.externalNonBrowserApplication;
  }
}

/// Affiche montée sous un vrai HelpCenterBloc, global dans l'app.
Future<_RecordingLauncher> _pumpWithHelpCenter(
  WidgetTester tester, {
  bool groupActive = true,
}) async {
  final launcher = _RecordingLauncher();
  final json = _configJson(groupActive: groupActive);
  final repository = HelpCenterRepository(
    _StaticSource(json),
    fallbackJsonLoader: () async => json,
    urlLauncher: launcher,
  );
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => HelpCenterBloc(
        repository,
        makeDisabledAnalytics(MockAnalyticsBackend()),
      )..add(const HelpCenterLoadRequested()),
      child: MaterialApp(
        home: TripPosterScreen(
          announcement: _announcement(),
          shareBaseUrl: 'https://api.yadony.test/api/v1',
          captureOverride: () async => Uint8List.fromList([1, 2, 3]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return launcher;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  late List<String> copied;

  setUp(() {
    copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('montre l\'aperçu de l\'affiche', (tester) async {
    await _pump(tester);

    expect(find.byType(TripPosterCard), findsOneWidget);
  });

  testWidgets('propose les quatre actions de publication', (tester) async {
    await _pump(tester);

    expect(find.text('Partager l\'affiche'), findsOneWidget);
    expect(find.text('Copier la légende'), findsOneWidget);
    expect(find.text('Copier le lien'), findsOneWidget);
    expect(find.text('Enregistrer dans la galerie'), findsOneWidget);
  });

  testWidgets('« Partager l\'affiche » est fixé en bas, visible sans défiler', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);

    final share = find.widgetWithText(DonyButton, 'Partager l\'affiche');
    expect(share, findsOneWidget);
    expect(
      find.ancestor(of: share, matching: find.byType(SingleChildScrollView)),
      findsNothing,
      reason: 'le bouton ne défile pas avec l\'affiche',
    );
    expect(tester.getRect(share).bottom, lessThanOrEqualTo(700));
    expect(tester.getRect(share).top, greaterThan(0));
  });

  testWidgets('copie l\'URL publique construite depuis la base fournie', (
    tester,
  ) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier le lien');

    // Le canal voyage dans l'URL dès la première affiche publiée : une affiche
    // postée est irrécupérable, un lien sans dimension ne sera jamais
    // attribuable rétroactivement.
    expect(copied, ['https://api.yadony.test/api/v1/annonce/a1?c=lien']);
  });

  /// Sur Facebook, une URL écrite dans l'image n'est pas cliquable : la légende
  /// est le seul endroit où le lien devient actionnable. Elle doit donc le
  /// contenir, sinon la moitié de la valeur de l'affiche est perdue.
  testWidgets('la légende contient le lien cliquable', (tester) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier la légende');

    expect(copied, hasLength(1));
    expect(
      copied.single,
      contains('https://api.yadony.test/api/v1/annonce/a1?c=post'),
    );
  });

  testWidgets('la légende reprend corridor, dépôt et prix expéditeur', (
    tester,
  ) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier la légende');

    final caption = copied.single;
    expect(caption, contains('Paris vers Dakar'));
    expect(caption, contains('Dernier dépôt'));
    expect(caption, contains(formatPriceIn(8, 'EUR')));
    expect(caption, contains('12 kg'));
  });

  /// Le canal de contact est l'application, jamais le portable du voyageur.
  testWidgets('la légende ne contient aucun numéro de téléphone', (
    tester,
  ) async {
    await _pump(tester);

    await _tapAction(tester, 'Copier la légende');

    expect(RegExp(r'\+\d{6,}').hasMatch(copied.single), isFalse);
  });

  /// L'image et le texte du post doivent annoncer la même chose : une légende
  /// qui promet « 0 € le kilo » sous une affiche vendant à l'article ferait
  /// fuir l'expéditeur avant même le clic.
  testWidgets('la légende annonce la grille et jamais 0 le kilo', (
    tester,
  ) async {
    await _pump(
      tester,
      announcement: _announcement(
        pricingMode: 'MIXED',
        pricePerKg: 0,
        pricePerKgDisplay: 0,
        gridItems: [_gridItem('Carton', 25), _gridItem('Valise', 40)],
      ),
    );

    await _tapAction(tester, 'Copier la légende');

    final caption = copied.single;
    expect(caption, contains("dès ${formatPriceIn(25, 'EUR')} l'article"));
    expect(caption, isNot(contains('le kilo')));
  });

  testWidgets('la légende porte les lieux de remise et de récupération', (
    tester,
  ) async {
    await _pump(
      tester,
      announcement: _announcement(
        pickupLabel: '12 rue de Tombouctou, 75018 Paris',
        deliveryLabel: 'Sacré-Cœur 3, Dakar',
      ),
    );

    await _tapAction(tester, 'Copier la légende');

    final caption = copied.single;
    expect(caption, contains('Remise : 12 rue de Tombouctou, 75018 Paris'));
    expect(caption, contains('Récupération : Sacré-Cœur 3, Dakar'));
  });

  testWidgets('la légende mentionne GP Pro seulement pour un voyageur GP Pro', (
    tester,
  ) async {
    await _pump(
      tester,
      announcement: _announcement(
        extra: {
          'traveler': {'id': 't1', 'displayName': 'Awa', 'gpPro': true},
        },
      ),
    );
    await _tapAction(tester, 'Copier la légende');
    expect(copied.single, contains('GP Pro'));

    copied.clear();
    await _pump(
      tester,
      announcement: _announcement(
        extra: {
          'traveler': {'id': 't1', 'displayName': 'Awa'},
        },
      ),
    );
    await _tapAction(tester, 'Copier la légende');
    expect(copied.single, isNot(contains('GP Pro')));
  });

  testWidgets('la légende dit Kg libre quand la capacité est non bornée', (
    tester,
  ) async {
    await _pump(tester, announcement: _announcement(capacityUnit: 'KG_FREE'));

    await _tapAction(tester, 'Copier la légende');

    expect(copied.single, contains('Kg libre'));
    expect(copied.single, isNot(contains('12 kg')));
  });

  testWidgets('anglais : actions et légende traduites', (tester) async {
    useEnglish();
    await _pump(tester);

    expect(find.text('Share the poster'), findsOneWidget);
    expect(find.text('Copy the caption'), findsOneWidget);
    expect(find.text('Copy the link'), findsOneWidget);
    expect(find.text('Save to gallery'), findsOneWidget);

    await _tapAction(tester, 'Copy the caption');

    final caption = copied.single;
    expect(caption, contains('Paris to Dakar'));
    expect(caption, contains('Last drop-off'));
    expect(caption, contains(formatPriceIn(8, 'EUR')));
  });

  group('« Publier dans le groupe Yadony » (FLUTTER-G4)', () {
    late List<MethodCall> galCalls;
    late bool galAccess;

    setUp(() {
      galCalls = <MethodCall>[];
      galAccess = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('gal'), (call) async {
            galCalls.add(call);
            if (call.method == 'requestAccess') return galAccess;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('gal'), null);
    });

    testWidgets('masqué sans HelpCenterBloc', (tester) async {
      await _pump(tester);
      expect(find.text('Publier dans le groupe Yadony'), findsNothing);
    });

    testWidgets('masqué quand la configuration n\'a pas de groupe actif', (
      tester,
    ) async {
      await _pumpWithHelpCenter(tester, groupActive: false);
      expect(find.byKey(const Key('trip-poster-group')), findsNothing);
    });

    testWidgets(
      'copie la légende, enregistre l\'affiche, explique puis ouvre',
      (tester) async {
        final launcher = await _pumpWithHelpCenter(tester);

        await _tapAction(tester, 'Publier dans le groupe Yadony');

        expect(copied, hasLength(1));
        expect(
          copied.single,
          contains('https://api.yadony.test/api/v1/annonce/a1?c=groupe'),
        );
        expect(galCalls.map((c) => c.method), contains('putImageBytes'));
        expect(find.text('Votre publication est prête'), findsOneWidget);
        expect(find.text('Légende et lien copiés'), findsOneWidget);
        expect(
          find.text('Affiche enregistrée dans votre galerie'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Dans le groupe, créez une publication : collez la légende, '
            "puis ajoutez l'affiche depuis votre galerie.",
          ),
          findsOneWidget,
        );
        expect(launcher.opened, isEmpty);

        await tester.tap(find.byKey(const Key('trip-poster-group-open')));
        await tester.pumpAndSettle();

        // Application Facebook d'abord, navigateur en repli.
        expect(launcher.opened, [
          (_groupUrl, PreferredLaunchMode.externalNonBrowserApplication),
          (_groupUrl, PreferredLaunchMode.externalApplication),
        ]);
        expect(find.text('Votre publication est prête'), findsNothing);
      },
    );

    testWidgets('fermer la feuille n\'ouvre pas le groupe', (tester) async {
      final launcher = await _pumpWithHelpCenter(tester);
      await _tapAction(tester, 'Publier dans le groupe Yadony');
      expect(find.text('Votre publication est prête'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(launcher.opened, isEmpty);
    });

    testWidgets('galerie refusée : message d\'erreur, pas de feuille', (
      tester,
    ) async {
      galAccess = false;
      final launcher = await _pumpWithHelpCenter(tester);

      await _tapAction(tester, 'Publier dans le groupe Yadony');

      // Accès aux photos refusé (YADONY-FLUTTER-PROD-T) : renvoi aux
      // Réglages plutôt que le message générique.
      expect(
        find.text(
          'Autorisez Yadony à ajouter des photos dans Réglages, '
          'puis réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.text('Votre publication est prête'), findsNothing);
      expect(launcher.opened, isEmpty);
    });
  });

  group('« Enregistrer dans la galerie » (YADONY-FLUTTER-PROD-T)', () {
    late List<MethodCall> galCalls;
    late int settingsOpened;

    void mockGal(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('gal'), (call) {
            galCalls.add(call);
            return handler(call);
          });
    }

    setUp(() {
      DonySnackbar.clearDedup();
      galCalls = <MethodCall>[];
      settingsOpened = 0;
      getIt.registerSingleton<GallerySaveService>(
        GallerySaveService(openSettings: () async => settingsOpened++),
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('gal'), null);
      await getIt.unregister<GallerySaveService>();
    });

    Future<void> pumpPoster(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripPosterScreen(
            announcement: _announcement(),
            shareBaseUrl: 'https://api.yadony.test/api/v1',
            captureOverride: () async => Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('accès accordé : affiche enregistrée', (tester) async {
      mockGal((call) async => call.method == 'requestAccess' ? true : null);
      await pumpPoster(tester);

      await _tapAction(tester, 'Enregistrer dans la galerie');

      expect(galCalls.map((c) => c.method), contains('putImageBytes'));
      expect(
        find.text('Affiche enregistrée dans votre galerie'),
        findsOneWidget,
      );
    });

    testWidgets('accès refusé : renvoi aux Réglages, qui s\'ouvrent', (
      tester,
    ) async {
      mockGal((call) async => call.method == 'requestAccess' ? false : null);
      await pumpPoster(tester);

      await _tapAction(tester, 'Enregistrer dans la galerie');

      expect(galCalls.map((c) => c.method), isNot(contains('putImageBytes')));
      expect(
        find.text(
          'Autorisez Yadony à ajouter des photos dans Réglages, '
          'puis réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.text('Impossible d\'enregistrer l\'affiche'), findsNothing);
      await tester.tap(find.text('Ouvrir les Réglages'));
      await tester.pump();
      expect(settingsOpened, 1);
      await tester.pumpAndSettle(const Duration(seconds: 7));
    });

    testWidgets('stockage plein : message dédié', (tester) async {
      mockGal((call) async {
        if (call.method == 'requestAccess') return true;
        throw PlatformException(code: 'NOT_ENOUGH_SPACE');
      });
      await pumpPoster(tester);

      await _tapAction(tester, 'Enregistrer dans la galerie');

      expect(
        find.text(
          "Espace insuffisant sur le téléphone pour enregistrer l'image.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('erreur inattendue : message générique', (tester) async {
      mockGal((call) async {
        if (call.method == 'requestAccess') return true;
        throw PlatformException(code: 'UNEXPECTED');
      });
      await pumpPoster(tester);

      await _tapAction(tester, 'Enregistrer dans la galerie');

      expect(find.text('Impossible d\'enregistrer l\'affiche'), findsOneWidget);
    });
  });
}
