// Marqueur des feuilles qui affichent elles-mêmes les erreurs du
// CancellationBloc : l'écran dessous s'en remet à elles tant qu'elles sont
// montées, pour ce bloc seulement.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_errors_shown_above.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

void main() {
  testWidgets('déclaré tant que monté, pour ce bloc seulement', (tester) async {
    final declared = _MockCancellationBloc();
    final other = _MockCancellationBloc();
    expect(CancellationErrorsShownAbove.isClaimed(declared), isFalse);

    await tester.pumpWidget(
      CancellationErrorsShownAbove(bloc: declared, child: const SizedBox()),
    );
    expect(CancellationErrorsShownAbove.isClaimed(declared), isTrue);
    expect(CancellationErrorsShownAbove.isClaimed(other), isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(CancellationErrorsShownAbove.isClaimed(declared), isFalse);
  });

  testWidgets('deux feuilles empilées : déclaré jusqu\'au retrait de la '
      'dernière', (tester) async {
    final bloc = _MockCancellationBloc();
    await tester.pumpWidget(
      CancellationErrorsShownAbove(
        bloc: bloc,
        child: CancellationErrorsShownAbove(
          bloc: bloc,
          child: const SizedBox(),
        ),
      ),
    );
    expect(CancellationErrorsShownAbove.isClaimed(bloc), isTrue);

    await tester.pumpWidget(
      CancellationErrorsShownAbove(bloc: bloc, child: const SizedBox()),
    );
    expect(CancellationErrorsShownAbove.isClaimed(bloc), isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(CancellationErrorsShownAbove.isClaimed(bloc), isFalse);
  });

  testWidgets('changement de bloc : la déclaration suit', (tester) async {
    final first = _MockCancellationBloc();
    final second = _MockCancellationBloc();
    await tester.pumpWidget(
      CancellationErrorsShownAbove(bloc: first, child: const SizedBox()),
    );
    await tester.pumpWidget(
      CancellationErrorsShownAbove(bloc: second, child: const SizedBox()),
    );

    expect(CancellationErrorsShownAbove.isClaimed(first), isFalse);
    expect(CancellationErrorsShownAbove.isClaimed(second), isTrue);
  });
}
