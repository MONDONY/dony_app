import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockCancellationBloc extends Mock implements CancellationBloc {}

Widget _wrap(Widget child, CancellationBloc bloc) => MaterialApp(
  home: BlocProvider<CancellationBloc>.value(value: bloc, child: child),
);

void main() {
  late CancellationBloc bloc;

  setUp(() {
    bloc = _MockCancellationBloc();
    when(() => bloc.state).thenReturn(CancellationInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche les 5 options de raison', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Vol annulé'), findsOneWidget);
    expect(find.text('Urgence personnelle'), findsOneWidget);
    expect(find.text('Autre'), findsOneWidget);
  });

  testWidgets('le bouton Confirmer est présent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text("Confirmer l'annulation"), findsOneWidget);
  });

  testWidgets('titre et motifs traduits en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () =>
                CancellationBottomSheet.show(ctx, announcementId: 'ann-1'),
            child: const Text('Open'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this trip?'), findsOneWidget);
    expect(find.text('Flight canceled'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Confirm cancellation'), findsOneWidget);
  });
}
