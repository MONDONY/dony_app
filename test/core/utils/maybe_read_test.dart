// Lecture optionnelle d'un provider : la valeur quand il est là, null sinon.
import 'package:dony/core/utils/maybe_read.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends Cubit<int> {
  _Counter() : super(0);
}

void main() {
  testWidgets('rend le provider au-dessus du contexte', (tester) async {
    final counter = _Counter();
    addTearDown(counter.close);
    await tester.pumpWidget(
      BlocProvider<_Counter>.value(
        value: counter,
        child: const SizedBox(key: Key('child')),
      ),
    );
    final context = tester.element(find.byKey(const Key('child')));
    expect(maybeRead<_Counter>(context), same(counter));
  });

  testWidgets('rend null sans provider, sans lever', (tester) async {
    await tester.pumpWidget(const SizedBox(key: Key('child')));
    final context = tester.element(find.byKey(const Key('child')));
    expect(maybeRead<_Counter>(context), isNull);
  });
}
