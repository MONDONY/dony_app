import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/ai_consent_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/ai_consent_sheet.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_consent_test_helpers.dart';
import '../../helpers/l10n_test_helpers.dart';
import '../../helpers/recording_url_launcher.dart';

void main() {
  bool? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await AiConsentSheet.ensure(
                  context,
                  entry: AiConsentEntry.assistant,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('accord déjà donné : aucune feuille, rend vrai', (tester) async {
    useAiConsent();
    await open(tester);

    expect(find.byKey(const Key('ai-consent-accept')), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('la feuille nomme le fournisseur et ce qui est envoyé', (
    tester,
  ) async {
    useAiConsent(granted: false);
    await open(tester);

    final l = await AppLocalizations.delegate.load(const Locale('fr'));
    expect(find.text(l.aiConsentTitle), findsOneWidget);
    expect(find.text(l.aiConsentPointProvider), findsOneWidget);
    expect(find.text(l.aiConsentPointNotSent), findsOneWidget);
    expect(l.aiConsentPointProvider, contains('Anthropic'));
  });

  testWidgets('accepter rend vrai et mémorise l’accord', (tester) async {
    final stored = useAiConsent(granted: false);
    await open(tester);

    await tester.tap(find.byKey(const Key('ai-consent-accept')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(stored[HiveService.kAiConsentGranted], isTrue);
  });

  testWidgets('refuser rend faux sans rien mémoriser', (tester) async {
    final stored = useAiConsent(granted: false);
    await open(tester);

    await tester.tap(find.byKey(const Key('ai-consent-decline')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(stored.containsKey(HiveService.kAiConsentGranted), isFalse);
  });

  testWidgets('fermer la feuille par geste vaut refus', (tester) async {
    useAiConsent(granted: false);
    await open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('le lien ouvre la politique de confidentialité', (tester) async {
    useAiConsent(granted: false);
    final launcher = RecordingUrlLauncher();
    installUrlLauncher(launcher, addTearDown);
    getIt.registerSingleton<ExternalUrlLauncher>(ExternalUrlLauncher());
    addTearDown(() => getIt.unregister<ExternalUrlLauncher>());
    await open(tester);

    await tester.ensureVisible(find.byKey(const Key('ai-consent-privacy')));
    await tester.tap(find.byKey(const Key('ai-consent-privacy')));
    await tester.pumpAndSettle();

    expect(launcher.urls, [AiConsentSheet.privacyUrl]);
  });
}
