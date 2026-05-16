import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart';
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
      const NegotiationRefuseTripRequested(threadId: 't-1'),
    );
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<NegotiationBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => RefuseTripBottomSheet.show(
              context,
              bloc: bloc,
              threadId: 't-1',
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('RefuseTripBottomSheet', () {
    testWidgets('affiche le titre "Refuser ce trajet"', (tester) async {
      await openSheet(tester);
      expect(find.text('Refuser ce trajet'), findsOneWidget);
    });

    testWidgets('bouton désactivé tant que la raison est vide',
        (tester) async {
      await openSheet(tester);
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('bouton activé une fois la raison saisie', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'Date trop tardive');
      await tester.pumpAndSettle();
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('confirmer dispatch NegotiationRefuseTripRequested',
        (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'Date trop tardive');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer le refus'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const NegotiationRefuseTripRequested(
            threadId: 't-1',
            reason: 'Date trop tardive',
          ))).called(1);
    });
  });
}
