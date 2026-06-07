import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

Widget _buildApp({
  required _MockNegotiationBloc bloc,
  bool isTraveler = false,
  bool isCheckout = false,
  double? grossPriceEur,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: BlocProvider.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => ElevatedButton(
            key: const Key('open'),
            onPressed: () => AcceptOfferBottomSheet.show(
              ctx,
              bloc: bloc,
              threadId: 't-1',
              priceEur: 35.0,
              grossPriceEur: grossPriceEur,
              isTraveler: isTraveler,
              isCheckout: isCheckout,
            ),
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
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  tearDown(() => bloc.close());

  testWidgets('shows "Accepter l\'offre" title when not checkout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Accepter l\'offre'), findsOneWidget);
  });

  testWidgets('shows "Payer en escrow" title when isCheckout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isCheckout: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Payer en escrow'), findsOneWidget);
  });

  testWidgets('shows "Tu reçois" label for traveler', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Tu reçois'), findsOneWidget);
  });

  testWidgets('shows "Montant à régler" label for sender', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: false));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Montant à régler'), findsOneWidget);
  });

  testWidgets('shows commission breakdown when sender and grossPriceEur provided',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(bloc: bloc, isTraveler: false, grossPriceEur: 39.20),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('commission Dony'), findsOneWidget);
  });

  testWidgets('does NOT show commission breakdown for traveler',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(bloc: bloc, isTraveler: true, grossPriceEur: 39.20),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('commission Dony'), findsNothing);
  });

  testWidgets('confirms button label uses Confirmer when not checkout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmer'), findsOneWidget);
  });

  testWidgets('confirms button label uses Payer (amount) when isCheckout',
      (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isCheckout: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    // The button text contains the amount, not just "Payer"
    expect(find.textContaining('Payer ('), findsOneWidget);
  });

  testWidgets('no error when NegotiationLoading state',
      (tester) async {
    when(() => bloc.state).thenReturn(const NegotiationLoading());
    when(() => bloc.stream).thenAnswer(
        (_) => Stream.value(const NegotiationLoading()));
    await tester.pumpWidget(_buildApp(bloc: bloc));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump(const Duration(milliseconds: 500));
    // Sheet rendered without error - button is present
    expect(find.byType(ElevatedButton), findsWidgets);
  });

  testWidgets('traveler sees correct info text', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('l\'expéditeur effectuera le paiement'),
        findsOneWidget);
  });

  testWidgets('sender sees escrow info text', (tester) async {
    await tester.pumpWidget(_buildApp(bloc: bloc, isTraveler: false));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('mis en escrow'), findsOneWidget);
  });
}
