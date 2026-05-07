import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/handover_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends Mock implements BidBloc {}

void main() {
  late BidBloc bloc;

  setUp(() {
    bloc = _MockBidBloc();
    when(() => bloc.state).thenReturn(BidInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche les champs adresse et heures', (tester) async {
    final bid = BidModel.skeleton('bid-1-test-ok');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      home: BlocProvider<BidBloc>.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => HandoverBottomSheet.show(ctx, bid: bid),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse de remise'), findsOneWidget);
    expect(find.text('Heure de début'), findsOneWidget);
    expect(find.text('Heure de fin'), findsOneWidget);
    expect(find.text('Confirmer la remise'), findsOneWidget);
  });

  testWidgets('affiche le titre Lieu de remise dans le sheet header',
      (tester) async {
    final bid = BidModel.skeleton('bid-2-test-ok');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      home: BlocProvider<BidBloc>.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => HandoverBottomSheet.show(ctx, bid: bid),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Lieu de remise'), findsOneWidget);
  });

  testWidgets('affiche un indicateur de chargement pendant BidLoading',
      (tester) async {
    when(() => bloc.state).thenReturn(BidLoading());
    when(() => bloc.stream).thenAnswer(
        (_) => Stream.value(BidLoading()));
    final bid = BidModel.skeleton('bid-3-test-ok');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      home: BlocProvider<BidBloc>.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => HandoverBottomSheet.show(ctx, bid: bid),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    // Use pump instead of pumpAndSettle to avoid timeout with loading animations
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // When BidLoading, DonyButton shows a CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
