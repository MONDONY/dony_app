import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/dispute_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<DisputeListEvent, DisputeListState>
    implements DisputeListBloc {}

DisputeModel _dispute({
  String status = 'OPEN',
  bool refundFrozen = true,
  bool isBeneficiary = false,
}) => DisputeModel(
  id: 'd-$status',
  bidId: 'b1',
  type: 'SENDER_NO_SHOW_CONTESTED',
  status: status,
  refundFrozen: refundFrozen,
  createdAt: DateTime(2026, 7, 12),
  myRole: 'SENDER',
  otherPartyName: 'Awa K.',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  departureCountryCode: 'FR',
  arrivalCountryCode: 'CI',
  tripDate: DateTime(2026, 6, 20),
  weightKg: 5,
  resolutionType: status == 'RESOLVED' ? 'GUARANTEE_PAID' : null,
  resolvedAt: status == 'RESOLVED' ? DateTime(2026, 6, 4) : null,
  resolutionNote: status == 'RESOLVED' ? 'No-show confirmé.' : null,
  guaranteeAmountCents: status == 'RESOLVED' ? 4000 : null,
  isBeneficiary: isBeneficiary,
);

late _MockBloc bloc;

Widget _harness({DisputeListState? state}) {
  bloc = _MockBloc();
  whenListen(
    bloc,
    const Stream<DisputeListState>.empty(),
    initialState: state ?? const DisputeListLoading(),
  );
  final router = GoRouter(
    initialLocation: '/disputes',
    routes: [
      GoRoute(
        path: '/disputes',
        builder: (_, __) => BlocProvider<DisputeListBloc>.value(
          value: bloc,
          child: const DisputeListScreen(),
        ),
      ),
      GoRoute(
        path: '/disputes/detail',
        builder: (_, __) => const Scaffold(body: Text('DetailStub')),
      ),
      GoRoute(
        path: '/profile/help/contact',
        builder: (_, __) => const Scaffold(body: Text('SupportStub')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('liste : card avec type, statut, corridor, autre partie', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        state: DisputeListLoaded([_dispute(), _dispute(status: 'RESOLVED')]),
      ),
    );
    await tester.pump();
    // Drain les animations flutter_animate (stagger fadeIn) avant assertions
    // pour éviter un Timer en vol au tearDown du test.
    await tester.pumpAndSettle();

    expect(find.text("Contestation d'absence"), findsNWidgets(2));
    expect(find.text('En instruction'), findsOneWidget);
    expect(find.text('Résolu'), findsOneWidget);
    expect(find.textContaining('Lyon'), findsNWidgets(2));
    expect(find.textContaining('Voyageur : Awa K.'), findsNWidgets(2));
  });

  testWidgets('bandeau gel visible seulement si refundFrozen && OPEN', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        state: DisputeListLoaded([
          _dispute(),
          _dispute(status: 'RESOLVED', refundFrozen: false),
        ]),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Remboursement gelé'), findsOneWidget);
  });

  testWidgets('tap card → push détail', (tester) async {
    await tester.pumpWidget(_harness(state: DisputeListLoaded([_dispute()])));
    await tester.pump();
    await tester.tap(find.text("Contestation d'absence"));
    await tester.pumpAndSettle();
    expect(find.text('DetailStub'), findsOneWidget);
  });

  testWidgets('état vide pédagogique + CTA support', (tester) async {
    await tester.pumpWidget(_harness(state: const DisputeListLoaded([])));
    await tester.pump();
    expect(find.text('Aucun litige'), findsOneWidget);
    await tester.tap(find.text('Un problème avec un envoi ?'));
    await tester.pumpAndSettle();
    expect(find.text('SupportStub'), findsOneWidget);
  });

  testWidgets('erreur → Réessayer redispatch', (tester) async {
    await tester.pumpWidget(
      _harness(
        state: DisputeListError(
          NetworkException('Erreur', code: 'network-error'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(const DisputesLoadRequested())).called(1);
  });
}
