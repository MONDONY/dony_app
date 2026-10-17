import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_filled_fields_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vide au départ', () {
    final cubit = AiFilledFieldsCubit();
    expect(cubit.state, isEmpty);
    expect(cubit.isFromAi, isFalse);
  });

  blocTest<AiFilledFieldsCubit, Set<String>>(
    'markFilled puis clear',
    build: AiFilledFieldsCubit.new,
    act: (c) {
      c.markFilled({'departureCity', 'availableKg'});
      c.clear();
    },
    expect: () => [
      {'departureCity', 'availableKg'},
      <String>{},
    ],
  );

  test('isFromAi suit les clés', () {
    final cubit = AiFilledFieldsCubit()..markFilled({'departureCity'});
    expect(cubit.isFromAi, isTrue);
  });
}
