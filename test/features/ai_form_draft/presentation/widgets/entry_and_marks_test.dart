import 'package:dony/features/ai_form_draft/bloc/ai_filled_fields_cubit.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_entry_card.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_field_mark.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_filled_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/ai_form_draft_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(localizedApp(Scaffold(body: child)));

  testWidgets('carte trajet : texte et bouton', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AiEntryCard(kind: AiFormKind.trip, onPressed: () => taps++),
    );
    expect(find.text(fr.aiFormDraftEntryTitle), findsOneWidget);
    expect(find.text(fr.aiFormDraftEntryBodyTrip), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-entry-cta')));
    expect(taps, 1);
  });

  testWidgets('carte demande d’envoi : son texte', (tester) async {
    await pump(
      tester,
      AiEntryCard(kind: AiFormKind.packageRequest, onPressed: () {}),
    );
    expect(find.text(fr.aiFormDraftEntryBodyPackage), findsOneWidget);
  });

  testWidgets('porte : cachée tant que la sonde n’a pas dit oui', (
    tester,
  ) async {
    final availability = AiFormDraftAvailabilityCubit(
      FakeAiFormDraftRepository(enabled: true),
    );
    addTearDown(availability.close);
    await pump(
      tester,
      AiEntryGate(availability: availability, child: const Text('carte')),
    );
    expect(find.text('carte'), findsNothing);
    await availability.refresh();
    await tester.pump();
    expect(find.text('carte'), findsOneWidget);
  });

  testWidgets('porte : formDraftEnabled faux, carte absente', (tester) async {
    final availability = AiFormDraftAvailabilityCubit(
      FakeAiFormDraftRepository(),
    );
    addTearDown(availability.close);
    await availability.refresh();
    await pump(
      tester,
      AiEntryGate(availability: availability, child: const Text('carte')),
    );
    expect(find.text('carte'), findsNothing);
  });

  testWidgets('bandeau : texte et « Reparler »', (tester) async {
    var taps = 0;
    await pump(tester, AiFilledBanner(onTalkAgain: () => taps++));
    expect(find.text(fr.aiFormDraftFilledBanner), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-talk-again')));
    expect(taps, 1);
  });

  testWidgets('marque : visible seulement pour un champ rempli par l’IA', (
    tester,
  ) async {
    final filled = AiFilledFieldsCubit();
    addTearDown(filled.close);
    await pump(
      tester,
      BlocProvider.value(
        value: filled,
        child: const Column(
          children: [
            AiFieldMark(fields: ['departureDate'], child: Text('Date')),
            AiFieldMark.overlay(
              fields: ['departureCity', 'arrivalCity'],
              child: SizedBox(height: 40, child: Text('Villes')),
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('ai-field-mark')), findsNothing);
    final dateState = tester.element(find.text('Date'));
    filled.markFilled({'arrivalCity'});
    // Deux images : après la première émission du Cubit, la suivante n'est
    // livrée au BlocBuilder qu'après l'image en cours (constaté en test).
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('ai-field-mark')), findsOneWidget);
    expect(find.text(fr.assistantBadge), findsOneWidget);
    filled.markFilled({'departureDate', 'arrivalCity'});
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('ai-field-mark')), findsNWidgets(2));
    // Le champ enveloppé garde son élément : son état n'est pas recréé.
    expect(tester.element(find.text('Date')), same(dateState));
  });

  testWidgets('marque sans cubit au-dessus : l’enfant seul', (tester) async {
    await pump(
      tester,
      const AiFieldMark(fields: ['departureDate'], child: Text('Date')),
    );
    expect(find.text('Date'), findsOneWidget);
    expect(find.byKey(const Key('ai-field-mark')), findsNothing);
  });
}
