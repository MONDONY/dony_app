import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/retry_appointment_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<DeliveryNoShowProcedureState>
    implements DeliveryNoShowProcedureCubit {}

void main() {
  final now = DateTime.now();
  final holdUntil = now.add(const Duration(days: 5));
  final procedure = DeliveryNoShowProcedureModel(
    bidId: 'b1',
    role: 'SENDER',
    bidStatus: 'ARRIVED',
    reported: true,
    holdUntil: holdUntil,
    canSetRetryAppointment: true,
  );
  late _MockCubit cubit;
  late StreamController<DeliveryNoShowProcedureState> states;

  setUp(() {
    cubit = _MockCubit();
    states = StreamController.broadcast();
    final initial = DeliveryNoShowProcedureLoaded(procedure, now: now);
    whenListen(cubit, states.stream, initialState: initial);
    when(
      () => cubit.setRetryAppointment(
        appointmentAt: any(named: 'appointmentAt'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() => states.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => RetryAppointmentSheet.show(
                ctx,
                cubit: cubit,
                holdUntil: holdUntil,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  DonyButton submitButton(WidgetTester tester) => tester.widget<DonyButton>(
    find.byKey(const Key('dnp-appointment-submit')),
  );

  testWidgets('envoi désactivé tant que la date et l heure manquent', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Nouveau rendez-vous'), findsOneWidget);
    expect(find.textContaining('avant la fin de la garde'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets(
    'rendez-vous valide : envoi au cubit avec la note, puis fermeture',
    (tester) async {
      await open(tester);
      final state = tester.state<State<RetryAppointmentSheet>>(
        find.byType(RetryAppointmentSheet),
      );
      final tomorrow = now.add(const Duration(days: 1));
      // ignore: invalid_use_of_visible_for_testing_member
      (state as dynamic).debugSet(
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        const TimeOfDay(hour: 10, minute: 30),
      );
      await tester.enterText(find.byType(TextField), 'Devant la gare');
      await tester.pumpAndSettle();
      expect(submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('dnp-appointment-submit')));
      await tester.pump();
      final at =
          verify(
                () => cubit.setRetryAppointment(
                  appointmentAt: captureAny(named: 'appointmentAt'),
                  note: 'Devant la gare',
                ),
              ).captured.single
              as DateTime;
      expect(at.hour, 10);

      states.add(
        DeliveryNoShowProcedureLoaded(
          procedure,
          now: now,
          appointmentSaved: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RetryAppointmentSheet), findsNothing);
      expect(find.text('Rendez-vous envoyé au voyageur'), findsOneWidget);
    },
  );

  testWidgets('rendez-vous après la fin de garde : envoi refusé', (
    tester,
  ) async {
    await open(tester);
    final state = tester.state<State<RetryAppointmentSheet>>(
      find.byType(RetryAppointmentSheet),
    );
    final late = holdUntil.add(const Duration(days: 1));
    (state as dynamic).debugSet(
      DateTime(late.year, late.month, late.day),
      const TimeOfDay(hour: 10, minute: 0),
    );
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull);
  });
}
