// Tests de `VoiceDictationSheet` — jusqu'ici quasi jamais couvert (0,8 %)
// car `stt.SpeechToText()` était considéré comme un canal natif hors de
// portée. En réalité `speech_to_text` délègue TOUT à
// `SpeechToTextPlatform.instance` (`speech_to_text_platform_interface`), un
// singleton `PlatformInterface` — exactement le même mécanisme que
// `GeolocatorPlatform.instance`, déjà mocké ailleurs dans ce dépôt
// (`home_screen_test.dart`, `_MockGeolocatorPlatform`). En substituant ce
// singleton par un faux platform-level, on exerce le VRAI `stt.SpeechToText()`
// de production — aucune injection de dépendance n'est nécessaire dans
// `voice_dictation_sheet.dart`, qui reste inchangé.
//
// `MockPlatformInterfaceMixin` (package `plugin_platform_interface`) fait
// passer la vérification de jeton de `PlatformInterface.instance=` : voir
// son usage identique pour Geolocator.
//
// PIÈGE (découvert en écrivant ce fichier) : `SpeechToText` est lui-même un
// SINGLETON process-wide côté package (`factory SpeechToText() => _instance;`
// dans speech_to_text.dart) — chaque `stt.SpeechToText()` de
// `VoiceDictationSheet.show()` renvoie donc la MÊME instance pour tout le
// fichier de test, jamais réinitialisée entre deux `testWidgets`. Son champ
// interne `_initWorked` ne bascule qu'UNE SEULE FOIS à `true` (au premier
// `initialize()` réussi) puis le reste pour toujours dans ce fichier :
// `initialize()` court-circuite ensuite immédiatement sans jamais rappeler la
// plateforme. Conséquences pour la suite ci-dessous :
//   1. Les deux tests qui doivent observer un ÉCHEC d'`initialize()` (false /
//      exception) DOIVENT s'exécuter avant tout test qui laisse
//      `initialize()` réussir — l'ordre de déclaration fait foi (`test`
//      exécute dans l'ordre du fichier, non randomisé par défaut).
//   2. `SpeechToTextPlatform.instance` est un SEUL et MÊME faux, créé une fois
//      pour tout le fichier (jamais recréé par test) : recréer un nouveau
//      faux par test casserait le branchement `onTextRecognition` fait par
//      le SEUL appel `initialize()` qui aboutit réellement à la plateforme.

import 'dart:convert';

import 'package:dony/features/home/presentation/widgets/voice_dictation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// Faux platform-level pour `speech_to_text`. Champs mutables plutôt que
/// mocktail : ce sont de simples valeurs de retour et compteurs d'appel, pas
/// des interactions à vérifier finement.
class _FakeSpeechToTextPlatform
    with MockPlatformInterfaceMixin
    implements SpeechToTextPlatform {
  bool initializeResult = true;
  bool initializeThrows = false;
  bool listenResult = true;
  bool hasPermissionResult = true;
  int cancelCalls = 0;
  int stopCalls = 0;

  @override
  void Function(String results)? onTextRecognition;
  @override
  void Function(String error)? onError;
  @override
  void Function(String status)? onStatus;
  @override
  void Function(double level)? onSoundLevel;

  @override
  Future<bool> hasPermission() async => hasPermissionResult;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async {
    if (initializeThrows) {
      throw Exception('reconnaissance vocale indisponible');
    }
    return initializeResult;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async => listenResult;

  @override
  Future<List<dynamic>> locales() async => [];
}

/// JSON attendu par `SpeechRecognitionResult.fromJson` — un seul alternate,
/// `resultType` 0 = partiel, 2 = final (voir `ResultType` du package).
String _resultJson(String text, {required bool isFinal}) => jsonEncode({
  'alternates': [
    {'recognizedWords': text, 'recognizedPhrases': null, 'confidence': 0.9},
  ],
  'resultType': isFinal ? 2 : 0,
});

/// Capture le résultat de `VoiceDictationSheet.show`, dont l'appel est
/// asynchrone et enjambe des gestes déclenchés APRÈS l'ouverture.
class _ResultHolder {
  String? value;
  bool completed = false;
}

Future<_ResultHolder> _openSheet(WidgetTester tester) async {
  final holder = _ResultHolder();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              holder.value = await VoiceDictationSheet.show(ctx);
              holder.completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return holder;
}

void main() {
  // Un SEUL faux pour tout le fichier — voir le pavé d'explication en tête
  // de fichier sur le singleton `SpeechToText`.
  final fakePlatform = _FakeSpeechToTextPlatform();
  SpeechToTextPlatform.instance = fakePlatform;

  setUp(() {
    fakePlatform
      ..initializeResult = true
      ..initializeThrows = false
      ..listenResult = true
      ..hasPermissionResult = true
      ..cancelCalls = 0
      ..stopCalls = 0;
  });

  // ── Les deux seuls tests où `initialize()` peut échouer — DOIVENT rester
  // avant tout test qui le laisse réussir (voir pavé d'en-tête). ──────────

  testWidgets(
    'initialize() renvoie false : aucune feuille, show() renvoie null',
    (tester) async {
      fakePlatform.initializeResult = false;
      final holder = await _openSheet(tester);

      expect(holder.completed, isTrue);
      expect(holder.value, isNull);
      expect(find.text('Dicter votre recherche'), findsNothing);
    },
  );

  testWidgets(
    'initialize() lève : aucune feuille, show() renvoie null (catch)',
    (tester) async {
      fakePlatform.initializeThrows = true;
      final holder = await _openSheet(tester);

      expect(holder.completed, isTrue);
      expect(holder.value, isNull);
      expect(find.text('Dicter votre recherche'), findsNothing);
    },
  );

  // ── À partir d'ici, `initialize()` réussit et bascule `_initWorked` à
  // `true` pour le reste du fichier : c'est aussi le SEUL test où l'appel
  // atteint réellement `fakePlatform`, qui reçoit donc le branchement
  // `onTextRecognition`/`onStatus`/`onError` — tous les tests suivants en
  // profitent, à condition de garder le MÊME `fakePlatform`. ─────────────

  testWidgets(
    'initialize() réussi : ouvre la feuille avec titre et bouton micro',
    (tester) async {
      final holder = await _openSheet(tester);

      expect(holder.completed, isFalse);
      expect(find.text('Dicter votre recherche'), findsOneWidget);
      expect(
        find.text('Maintenez le micro appuyé, parlez, relâchez pour valider.'),
        findsOneWidget,
      );
      expect(find.text('Maintenez pour parler'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Referme proprement : une feuille laissée ouverte peut interférer
      // avec le montage du test suivant.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(holder.completed, isTrue);
    },
  );

  testWidgets(
    'appui maintenu puis relâchement : renvoie le texte final reconnu, '
    'trim() appliqué, stop() ET cancel() (filet de whenComplete) appelés',
    (tester) async {
      final holder = await _openSheet(tester);

      final micCenter = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final gesture = await tester.startGesture(micCenter);
      await tester.pump();

      expect(find.text('Je vous écoute…'), findsOneWidget);
      expect(find.text('Relâchez pour valider'), findsOneWidget);

      // Résultat partiel : rendu, mais pas encore ce qui sera renvoyé.
      fakePlatform.onTextRecognition?.call(_resultJson('paris', isFinal: false));
      await tester.pump();
      expect(find.text('paris'), findsOneWidget);

      // Résultat final : remplace le partiel.
      fakePlatform.onTextRecognition?.call(
        _resultJson('  paris dakar  ', isFinal: true),
      );
      await tester.pump();
      expect(find.textContaining('paris dakar'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(holder.completed, isTrue);
      expect(holder.value, 'paris dakar', reason: 'trim() doit être appliqué');
      expect(fakePlatform.stopCalls, greaterThanOrEqualTo(1));
      expect(
        fakePlatform.cancelCalls,
        greaterThanOrEqualTo(1),
        reason: 'whenComplete() annule systématiquement, même après un stop()',
      );
    },
  );

  testWidgets('relâchement sans aucun mot reconnu : renvoie null', (
    tester,
  ) async {
    final holder = await _openSheet(tester);

    final micCenter = tester.getCenter(find.byIcon(Icons.mic_rounded));
    final gesture = await tester.startGesture(micCenter);
    await tester.pump();

    await gesture.up();
    await tester.pumpAndSettle();

    expect(holder.completed, isTrue);
    expect(holder.value, isNull);
  });

  testWidgets(
    'relâchement avec un résultat final ne contenant que des espaces : '
    'renvoie null (trim() vide)',
    (tester) async {
      final holder = await _openSheet(tester);

      final micCenter = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final gesture = await tester.startGesture(micCenter);
      await tester.pump();

      fakePlatform.onTextRecognition?.call(_resultJson('   ', isFinal: true));
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();

      expect(holder.value, isNull);
    },
  );

  testWidgets(
    'interruption du geste (pointer cancel) : annule sans résultat, la '
    'feuille reste ouverte',
    (tester) async {
      final holder = await _openSheet(tester);

      final micCenter = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final gesture = await tester.startGesture(micCenter);
      await tester.pump();
      expect(find.text('Je vous écoute…'), findsOneWidget);

      fakePlatform.onTextRecognition?.call(_resultJson('bam', isFinal: false));
      await tester.pump();
      expect(find.text('bam'), findsOneWidget);

      await gesture.cancel();
      await tester.pump();

      // Retour à l'état de repos : transcript et instruction réinitialisés,
      // la feuille elle-même n'est jamais fermée par un abandon.
      expect(
        find.text('Maintenez le micro appuyé, parlez, relâchez pour valider.'),
        findsOneWidget,
      );
      expect(find.text('bam'), findsNothing);
      expect(
        holder.completed,
        isFalse,
        reason: 'annuler le geste ne doit pas fermer la feuille',
      );
      expect(fakePlatform.cancelCalls, greaterThanOrEqualTo(1));

      // Nettoyage : ferme réellement la feuille pour ne pas laisser de
      // route en vol à la fin du test.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'mouvement réduit (MediaQuery.disableAnimations) : l\'onde reste figée, '
    'aucune exception, le geste fonctionne toujours',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      final holder = await _openSheet(tester);

      final micCenter = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final gesture = await tester.startGesture(micCenter);
      await tester.pump();

      expect(find.text('Je vous écoute…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      fakePlatform.onTextRecognition?.call(_resultJson('lomé', isFinal: true));
      await tester.pump();
      expect(find.text('lomé'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(holder.completed, isTrue);
      expect(holder.value, 'lomé');
    },
  );

  testWidgets(
    'fermeture de la feuille par tap sur le fond (sans relâchement du '
    'micro) : le filet whenComplete annule proprement, show() renvoie null',
    (tester) async {
      final holder = await _openSheet(tester);

      final micCenter = tester.getCenter(find.byIcon(Icons.mic_rounded));
      final gesture = await tester.startGesture(micCenter);
      await tester.pump();
      expect(find.text('Je vous écoute…'), findsOneWidget);

      // Tap en dehors de la feuille : `isDismissible` (par défaut) ferme la
      // route sans jamais passer par `_onUp`/`_onCancelPress` du bouton — le
      // pointeur encore posé sur le micro déclenche ensuite un
      // `PointerCancelEvent` synthétique émis par le framework quand son
      // widget se démonte. C'est exactement le scénario du bug corrigé dans
      // `_DictationController` (garde `_disposed`) : sans le correctif,
      // ceci levait « ValueNotifier used after being disposed ».
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(holder.completed, isTrue);
      expect(holder.value, isNull);
      expect(fakePlatform.cancelCalls, greaterThanOrEqualTo(1));

      // Le geste jamais relâché proprement : on le termine pour ne pas
      // laisser le binding de test avec un pointeur actif.
      await gesture.up();
    },
  );
}
