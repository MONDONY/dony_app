import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/maintenance/bloc/maintenance_cubit.dart';
import 'package:dony/features/maintenance/bloc/maintenance_state.dart';
import 'package:dony/features/maintenance/presentation/maintenance_gate.dart';
import 'package:dony/features/maintenance/presentation/maintenance_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/l10n_test_helpers.dart';

class _MockMaintenanceCubit extends MockCubit<MaintenanceState>
    implements MaintenanceCubit {}

void main() {
  late _MockMaintenanceCubit cubit;
  var taps = 0;

  setUp(() {
    cubit = _MockMaintenanceCubit();
    taps = 0;
    when(() => cubit.retry()).thenAnswer((_) async {});
  });

  Widget app({Locale locale = AppL10n.fr}) => localizedApp(
    MaintenanceGate(
      cubit: cubit,
      child: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Accueil'),
            ),
            const TextField(key: Key('field')),
          ],
        ),
      ),
    ),
    locale: locale,
  );

  testWidgets('hors maintenance : l’app est utilisable', (tester) async {
    when(() => cubit.state).thenReturn(const MaintenanceState());
    await tester.pumpWidget(app());

    await tester.tap(find.text('Accueil'));
    expect(taps, 1);
    expect(find.byType(MaintenanceScreen), findsNothing);
  });

  testWidgets('en maintenance : seul l’écran de maintenance répond', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(const MaintenanceState(active: true));
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Yadony est en maintenance'), findsOneWidget);
    expect(find.textContaining('Nous améliorons l'), findsOneWidget);
    expect(find.byKey(const Key('maintenance-estimated-end')), findsNothing);

    await tester.tap(find.text('Accueil'), warnIfMissed: false);
    expect(taps, 0, reason: 'l’app dessous est gelée');

    await tester.tap(find.text('Réessayer'));
    verify(() => cubit.retry()).called(1);
  });

  testWidgets('message de l’admin et heure de retour', (tester) async {
    final end = DateTime.utc(2026, 10, 16, 14, 30);
    when(() => cubit.state).thenReturn(
      MaintenanceState(
        active: true,
        message: 'Mise à jour du paiement',
        estimatedEndAt: end,
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mise à jour du paiement'), findsOneWidget);
    expect(
      find.text(
        'Retour prévu vers ${DateFormat.Hm('fr').format(end.toLocal())}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('vérification en cours : bouton désactivé', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const MaintenanceState(active: true, checking: true));
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Réessayer'),
      findsNothing,
      reason: 'remplacé par l’indicateur',
    );
    verifyNever(() => cubit.retry());
  });

  testWidgets('activation : le clavier se referme', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable([const MaintenanceState(active: true)]),
      initialState: const MaintenanceState(),
    );
    await tester.pumpWidget(app());
    await tester.showKeyboard(find.byKey(const Key('field')));
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
  });

  testWidgets('anglais', (tester) async {
    enableEnglish();
    when(() => cubit.state).thenReturn(const MaintenanceState(active: true));
    await tester.pumpWidget(app(locale: AppL10n.en));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Yadony is under maintenance'), findsOneWidget);
  });
}
