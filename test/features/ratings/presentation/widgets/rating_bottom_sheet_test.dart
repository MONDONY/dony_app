import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRatingBloc extends Mock implements RatingBloc {}

Widget _wrap(Widget child, RatingBloc bloc) => MaterialApp(
      home: BlocProvider<RatingBloc>.value(value: bloc, child: child),
    );

void main() {
  late RatingBloc bloc;

  setUp(() {
    bloc = _MockRatingBloc();
    when(() => bloc.state).thenReturn(const RatingInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche le sélecteur d\'étoiles et le champ commentaire', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => RatingBottomSheet.show(ctx, bidId: 'bid-1', travelerName: 'Amadou'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Évaluer Amadou'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsWidgets);
    expect(find.text('Commentaire (facultatif)'), findsOneWidget);
  });

  testWidgets('le bouton Envoyer est désactivé si 0 étoile', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => RatingBottomSheet.show(ctx, bidId: 'bid-1', travelerName: 'Amadou'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Envoyer l\'évaluation'), matching: find.byType(FilledButton)),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('le bouton Envoyer est actif après sélection d\'une étoile', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) => TextButton(
        onPressed: () => RatingBottomSheet.show(ctx, bidId: 'bid-1', travelerName: 'Amadou'),
        child: const Text('Ouvrir'),
      )),
      bloc,
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Tape sur la 3ème étoile
    final stars = find.byIcon(Icons.star_outline_rounded);
    await tester.tap(stars.at(2));
    await tester.pumpAndSettle();

    // Le bouton doit maintenant être actif
    final filledBtn = find.byType(FilledButton);
    final btn = tester.widget<FilledButton>(filledBtn.last);
    expect(btn.onPressed, isNotNull);
  });
}
