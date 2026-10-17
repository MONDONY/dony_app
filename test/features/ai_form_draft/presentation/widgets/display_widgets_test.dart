import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/chat_bubble.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/draft_summary.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/quick_replies.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/understood_chips.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);

  setUpAll(() => initializeDateFormatting('fr'));

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    localizedApp(Scaffold(body: SingleChildScrollView(child: child))),
  );

  testWidgets('bulles : assistant, utilisateur, transcription en direct', (
    tester,
  ) async {
    await pump(
      tester,
      const Column(
        children: [
          AiChatBubble.assistant(text: 'Le 15 ?'),
          AiChatBubble.user(text: 'Oui'),
          AiChatBubble.live(text: 'Je voyage', label: 'Transcription'),
          AiChatBubble.live(text: '', label: 'Vide'),
        ],
      ),
    );
    expect(find.text('Le 15 ?'), findsOneWidget);
    expect(find.text('Oui'), findsOneWidget);
    expect(find.text('Je voyage'), findsOneWidget);
    expect(find.text('Transcription'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);
  });

  testWidgets('réponses rapides : un toucher envoie la réponse', (
    tester,
  ) async {
    final picked = <String>[];
    await pump(
      tester,
      QuickReplies(
        replies: const ['Oui', 'En voiture'],
        onSelected: picked.add,
      ),
    );
    await tester.tap(find.byKey(const Key('ai-quick-reply-1')));
    expect(picked, ['En voiture']);
  });

  testWidgets('« Déjà compris » : puces, manquants marqués « ? », compteur', (
    tester,
  ) async {
    await pump(
      tester,
      const UnderstoodChips(
        kind: AiFormKind.trip,
        understood: ['route', 'capacity', 'grid'],
        missing: ['departureDate', 'transportMode'],
        draft: {
          'departureCity': 'Paris',
          'arrivalCity': 'Abidjan',
          'availableKg': 23,
        },
      ),
    );
    expect(find.text(fr.aiFormDraftUnderstoodTitle), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.text('23 kg'), findsOneWidget);
    expect(find.text(fr.aiFormDraftMissingDate), findsOneWidget);
    expect(find.byKey(const Key('ai-chip-missing')), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.byKey(const Key('ai-understood-count'))).data,
      '3 / 5',
    );
  });

  testWidgets('résumé trajet : route, lignes, avertissements grille et carte', (
    tester,
  ) async {
    await pump(
      tester,
      const DraftSummary(
        kind: AiFormKind.trip,
        resolved: AiResolvedDraft(
          draft: {
            'departureCity': 'Paris',
            'arrivalCity': 'Abidjan',
            'availableKg': 23,
          },
          warnings: [
            AiDraftWarning.noPriceGrid,
            AiDraftWarning.cardNotConfigured,
          ],
        ),
      ),
    );
    expect(find.text(fr.aiFormDraftReadyTitle), findsOneWidget);
    expect(find.text(fr.aiFormDraftReadyBodyTrip), findsOneWidget);
    expect(find.byKey(const Key('ai-summary-route')), findsOneWidget);
    expect(find.text(fr.aiFormDraftWarningNoGrid), findsOneWidget);
    expect(find.text(fr.aiFormDraftWarningCardNotConfigured), findsOneWidget);
    expect(find.byKey(const Key('ai-summary-warning')), findsNWidgets(2));
    expect(find.text(fr.aiFormDraftSummaryPhotoHint), findsNothing);
  });

  testWidgets('résumé demande d’envoi : rappel des photos ; limite de tours', (
    tester,
  ) async {
    await pump(
      tester,
      const DraftSummary(
        kind: AiFormKind.packageRequest,
        turnLimitReached: true,
        resolved: AiResolvedDraft(draft: {'weightKg': 5}),
      ),
    );
    expect(find.text(fr.aiFormDraftTurnLimit), findsOneWidget);
    expect(find.text(fr.aiFormDraftReadyBodyPackage), findsNothing);
    expect(find.text(fr.aiFormDraftSummaryPhotoHint), findsOneWidget);
    expect(find.byKey(const Key('ai-summary-route')), findsNothing);
  });
}
