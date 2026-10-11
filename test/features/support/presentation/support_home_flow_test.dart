import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

const _ticket = SupportTicket(
  id: 'ticket-1',
  category: 'PAYMENT',
  subject: 'Paiement bloque',
  status: SupportTicketStatuses.waitingUser,
);

const _ready = SupportState(homeStatus: SupportViewStatus.ready);

void main() {
  late _MockSupportBloc bloc;
  late StreamController<SupportState> states;

  setUp(() {
    useEnglish();
    DonySnackbar.clearDedup();
    bloc = _MockSupportBloc();
    states = StreamController<SupportState>.broadcast();
  });

  tearDown(() => states.close());

  Future<void> pump(WidgetTester tester, SupportState initial) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    whenListen(bloc, states.stream, initialState: initial);
    final router = GoRouter(
      initialLocation: '/support',
      routes: [
        GoRoute(
          path: '/support',
          builder: (_, _) => BlocProvider<SupportBloc>.value(
            value: bloc,
            child: const SupportHomeScreen(),
          ),
        ),
        GoRoute(
          path: '/support/tickets/:id',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: Text('detail ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, SupportState state) async {
    states.add(state);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('création : catégorie, sujet et message partent au BLoC', (
    tester,
  ) async {
    await pump(tester, _ready);
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();

    DonyButton send() =>
        tester.widget<DonyButton>(find.widgetWithText(DonyButton, 'Send'));
    expect(send().onPressed, isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Payment'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Subject'),
      '  Paiement bloqué ',
    );
    await tester.pump();
    expect(send().onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextField, 'Message'),
      ' Mon paiement ne passe pas. ',
    );
    await tester.pump();
    expect(send().onPressed, isNotNull);

    send().onPressed!();
    await tester.pump();
    verify(
      () => bloc.add(
        const SupportTicketCreateRequested(
          category: 'PAYMENT',
          subject: 'Paiement bloqué',
          message: 'Mon paiement ne passe pas.',
        ),
      ),
    ).called(1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('création en échec : avis d\'erreur', (tester) async {
    await pump(tester, _ready);
    await emit(
      tester,
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        createStatus: SupportActionStatus.failure,
        failure: SupportFailure.generic,
      ),
    );
    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('création en échec sans cause : pas d\'avis', (tester) async {
    await pump(tester, _ready);
    await emit(
      tester,
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        createStatus: SupportActionStatus.failure,
      ),
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('retrait refusé : avis d\'erreur', (tester) async {
    await pump(tester, _ready);
    await emit(
      tester,
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        hideStatus: SupportActionStatus.failure,
      ),
    );
    expect(
      find.text(
        'This ticket could not be removed right now. Please try again later.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('ticket créé : ouvert puis liste rechargée au retour', (
    tester,
  ) async {
    await pump(tester, _ready);
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();

    await emit(
      tester,
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        createStatus: SupportActionStatus.success,
        createdTicketId: 'ticket-7',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail ticket-7'), findsOneWidget);

    await tester.tap(find.text('detail ticket-7'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const SupportHomeRequested())).called(1);
  });

  testWidgets('ticket touché : fil ouvert, liste rechargée au retour', (
    tester,
  ) async {
    await pump(
      tester,
      const SupportState(
        homeStatus: SupportViewStatus.ready,
        tickets: [_ticket],
      ),
    );
    await tester.tap(find.text('Paiement bloque'));
    await tester.pumpAndSettle();
    expect(find.text('detail ticket-1'), findsOneWidget);

    await tester.tap(find.text('detail ticket-1'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const SupportHomeRequested())).called(1);
  });

  testWidgets('chargement en échec : « Try again » relance', (tester) async {
    await pump(
      tester,
      const SupportState(
        homeStatus: SupportViewStatus.failure,
        failure: SupportFailure.generic,
      ),
    );
    expect(find.text('We couldn\'t load support'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    verify(() => bloc.add(const SupportHomeRequested())).called(1);
  });

  test('supportErrorMessage : le détail serveur prime, sinon la cause', () {
    final l = lookupAppLocalizations(AppL10n.en);
    expect(
      supportErrorMessage(l, const SupportState(serverDetail: 'détail')),
      'détail',
    );
    expect(
      supportErrorMessage(
        l,
        const SupportState(failure: SupportFailure.ticketResolved),
      ),
      l.supportTicketResolvedError,
    );
    expect(
      supportErrorMessage(
        l,
        const SupportState(failure: SupportFailure.hideFailed),
      ),
      l.supportTicketHideError,
    );
    expect(supportErrorMessage(l, const SupportState()), isNull);
  });
}
