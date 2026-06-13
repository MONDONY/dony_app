import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/return_code_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

BidModel _bid({
  String status = 'CANCELLED',
  String? returnCode,
  DateTime? returnDeadline,
  DateTime? returnedAt,
}) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'a-1',
      senderId: 's-1',
      status: status,
      weightKg: 5,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
      returnCode: returnCode,
      returnDeadline: returnDeadline,
      returnedAt: returnedAt,
    );

/// Hôte avec un bouton qui ouvre le sheet demandé en injectant [bloc].
Widget _host(
  void Function(BuildContext) onTap,
) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => onTap(ctx),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockCancellationBloc bloc;

  setUpAll(() {
    registerFallbackValue(ReturnCodeRequested('x'));
    registerFallbackValue(ReturnConfirmRequested('x', '000000'));
  });

  setUp(() {
    bloc = _MockCancellationBloc();
    when(() => bloc.state).thenReturn(CancellationInitial());
  });

  // ── ReturnCodeSheet (expéditeur) ────────────────────────────────────────────

  testWidgets('ReturnCodeSheet affiche le code + dispatch ReturnCodeRequested',
      (tester) async {
    await tester.pumpWidget(_host((ctx) => ReturnCodeSheet.show(
          ctx,
          bid: _bid(
            returnCode: '654321',
            returnDeadline: DateTime(2026, 6, 4),
          ),
          cancellationBloc: bloc,
        )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Code de retour'), findsWidgets);
    expect(find.text('Copier le code'), findsOneWidget);
    // Les 6 chiffres sont rendus en boxes individuelles.
    for (final d in '654321'.split('')) {
      expect(find.text(d), findsOneWidget);
    }
    verify(() => bloc.add(any(that: isA<ReturnCodeRequested>()))).called(1);
  });

  testWidgets('ReturnCodeSheet : tap "Copier le code" → snackbar "Code copié"',
      (tester) async {
    await tester.pumpWidget(_host((ctx) => ReturnCodeSheet.show(
          ctx,
          bid: _bid(
            returnCode: '654321',
            returnDeadline: DateTime(2026, 6, 4),
          ),
          cancellationBloc: bloc,
        )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copier le code'));
    await tester.pump();
    expect(find.text('Code copié'), findsOneWidget);
  });

  testWidgets('ReturnCodeSheet : colis restitué → confirmation', (tester) async {
    await tester.pumpWidget(_host((ctx) => ReturnCodeSheet.show(
          ctx,
          bid: _bid(
            returnDeadline: DateTime(2026, 6, 4),
            returnedAt: DateTime(2026, 6, 2),
          ),
          cancellationBloc: bloc,
        )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Colis restitué'), findsOneWidget);
  });

  // ── ReturnEntrySheet (voyageur) ─────────────────────────────────────────────

  testWidgets(
      'ReturnEntrySheet : saisie 6 chiffres → ReturnConfirmRequested dispatché',
      (tester) async {
    await tester.pumpWidget(_host((ctx) => ReturnEntrySheet.show(
          ctx,
          bid: _bid(returnDeadline: DateTime(2026, 6, 4)),
          cancellationBloc: bloc,
        )));
    await tester.tap(find.text('Open'));
    // Pas de pumpAndSettle : le curseur clignotant du Pinput (autofocus) ne
    // « settle » jamais. On laisse l'animation d'ouverture du sheet se jouer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Bouton désactivé tant que le code n'est pas complet.
    expect(find.text('Confirmer la restitution'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '123456');
    await tester.pump();

    await tester.tap(find.text('Confirmer la restitution'));
    await tester.pump();

    verify(() => bloc.add(any(
        that: isA<ReturnConfirmRequested>()
            .having((e) => e.code, 'code', '123456')
            .having((e) => e.bidId, 'bidId', 'bid-1')))).called(1);
  });

  testWidgets('ReturnEntrySheet : ReturnConfirmed → ferme le sheet',
      (tester) async {
    whenListen(
      bloc,
      Stream<CancellationState>.fromIterable([
        ReturnConfirmed(ReturnCodeModel(returnedAt: DateTime(2026, 6, 2))),
      ]),
      initialState: CancellationInitial(),
    );

    await tester.pumpWidget(_host((ctx) => ReturnEntrySheet.show(
          ctx,
          bid: _bid(returnDeadline: DateTime(2026, 6, 4)),
          cancellationBloc: bloc,
        )));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Le sheet a été refermé par le listener (titre absent).
    expect(find.text('Confirmer la restitution'), findsNothing);
  });

  testWidgets('ReturnEntrySheet : CancellationError → sheet reste ouvert',
      (tester) async {
    whenListen(
      bloc,
      Stream<CancellationState>.fromIterable([
        CancellationError(const NetworkException('Échec réseau')),
      ]),
      initialState: CancellationInitial(),
    );

    await tester.pumpWidget(_host((ctx) => ReturnEntrySheet.show(
          ctx,
          bid: _bid(returnDeadline: DateTime(2026, 6, 4)),
          cancellationBloc: bloc,
        )));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // L'erreur n'a pas refermé le sheet (contrairement à ReturnConfirmed).
    expect(find.text('Confirmer la restitution'), findsOneWidget);
  });
}
