import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/ai_form_draft_test_doubles.dart';

void main() {
  test('éteint tant que la sonde n’a pas répondu', () {
    expect(
      AiFormDraftAvailabilityCubit(
        FakeAiFormDraftRepository(enabled: true),
      ).state,
      isFalse,
    );
  });

  blocTest<AiFormDraftAvailabilityCubit, bool>(
    'refresh : la sonde fait foi',
    build: () =>
        AiFormDraftAvailabilityCubit(FakeAiFormDraftRepository(enabled: true)),
    act: (c) => c.refresh(),
    expect: () => [true],
  );

  test('refresh après fermeture : aucune émission', () async {
    final cubit = AiFormDraftAvailabilityCubit(
      FakeAiFormDraftRepository(enabled: true),
    );
    await cubit.close();
    await cubit.refresh();
    expect(cubit.state, isFalse);
  });
}
