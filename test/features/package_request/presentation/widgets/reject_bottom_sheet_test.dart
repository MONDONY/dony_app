import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/reject_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

Widget _buildApp(_MockNegotiationBloc bloc) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open'),
            onPressed: () =>
                RejectBottomSheet.show(ctx, bloc: bloc, threadId: 't-1'),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockNegotiationBloc bloc;

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  tearDown(() => bloc.close());

  testWidgets('shows title "Rejeter la négociation"', (tester) async {
    await tester.pumpWidget(_buildApp(bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Rejeter la négociation'), findsOneWidget);
  });

  testWidgets('shows TextField for reason', (tester) async {
    await tester.pumpWidget(_buildApp(bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('shows Confirmer le rejet button', (tester) async {
    await tester.pumpWidget(_buildApp(bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmer le rejet'), findsOneWidget);
  });

  testWidgets('tapping Confirmer dispatches NegotiationRejectRequested', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer le rejet'));
    await tester.pump();
    verify(
      () => bloc.add(NegotiationRejectRequested(threadId: 't-1', reason: null)),
    ).called(1);
  });

  testWidgets('typing a reason sends it in the event', (tester) async {
    await tester.pumpWidget(_buildApp(bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Trop cher');
    await tester.tap(find.text('Confirmer le rejet'));
    await tester.pump();
    verify(
      () => bloc.add(
        NegotiationRejectRequested(threadId: 't-1', reason: 'Trop cher'),
      ),
    ).called(1);
  });

  testWidgets('Confirmer le rejet button is present in the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    // The destructive confirm button should always be present
    expect(find.text('Confirmer le rejet'), findsOneWidget);
  });
}
