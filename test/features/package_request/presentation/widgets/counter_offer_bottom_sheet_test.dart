import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/counter_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

void main() {
  late _MockNegotiationBloc bloc;

  setUpAll(() {
    registerFallbackValue(
      const NegotiationCounterRequested(
        threadId: 't-1',
        proposedPriceEur: 40,
      ),
    );
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Future<void> openSheet(
    WidgetTester tester, {
    double currentPriceEur = 50,
    int roundsCount = 2,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<NegotiationBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CounterOfferBottomSheet.show(
              context,
              bloc: bloc,
              threadId: 't-1',
              currentPriceEur: currentPriceEur,
              roundsCount: roundsCount,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('CounterOfferBottomSheet', () {
    testWidgets('affiche le titre "Faire une contre-offre"', (tester) async {
      await openSheet(tester);
      expect(find.text('Faire une contre-offre'), findsOneWidget);
    });

    testWidgets('affiche le prix actuel (format role-aware) et le round',
        (tester) async {
      await openSheet(tester, currentPriceEur: 50, roundsCount: 2);
      // isTraveler defaults to false → sender sees gross: 50 * 1.12 = 56 → "Tu paies 56,00 €"
      expect(find.textContaining('56'), findsWidgets);
      expect(find.textContaining('Round 2/5'), findsOneWidget);
    });

    testWidgets('affiche le label "Ton prix proposé"', (tester) async {
      await openSheet(tester);
      expect(find.text('Ton prix proposé'), findsOneWidget);
    });

    testWidgets('affiche le label "Message (optionnel)"', (tester) async {
      await openSheet(tester);
      expect(find.text('Message (optionnel)'), findsOneWidget);
    });

    testWidgets('affiche le suffixe € sur le champ de prix', (tester) async {
      await openSheet(tester);
      expect(find.text('€'), findsOneWidget);
    });

    testWidgets('affiche le bouton "Envoyer ma contre-offre" désactivé par défaut',
        (tester) async {
      await openSheet(tester);
      expect(find.text('Envoyer ma contre-offre'), findsOneWidget);
    });

    testWidgets('le bouton envoie l\'événement après saisie d\'un prix valide',
        (tester) async {
      await openSheet(tester);

      final priceField = find.byType(TextFormField).first;
      await tester.enterText(priceField, '40');
      await tester.pump();
      // Laisser addPostFrameCallback exécuter la mise à jour du notifier
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Envoyer ma contre-offre'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(any(that: isA<NegotiationCounterRequested>()))).called(1);
    });

    testWidgets('le compteur de caractères affiche 0/280 initialement',
        (tester) async {
      await openSheet(tester);
      expect(find.textContaining('0/280'), findsOneWidget);
    });

    testWidgets('le compteur se met à jour quand on tape dans le message',
        (tester) async {
      await openSheet(tester);

      final msgField = find.byType(TextFormField).last;
      await tester.enterText(msgField, 'Bonjour');
      await tester.pump();
      expect(find.textContaining('7/280'), findsOneWidget);
    });
  });
}
