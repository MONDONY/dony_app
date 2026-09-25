import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

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

  testWidgets('affiche le sélecteur d\'étoiles et le champ commentaire', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => RatingBottomSheet.show(
              ctx,
              bidId: 'bid-1',
              travelerName: 'Amadou',
            ),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Évaluer Amadou'), findsOneWidget);
    // Étoiles du sélecteur = DonyIcon('star') taille 44 (rempli/vide par couleur).
    expect(
      find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'star' && w.size == 44,
      ),
      findsWidgets,
    );
    expect(find.text('Commentaire (facultatif)'), findsOneWidget);
  });

  testWidgets('le bouton Envoyer est désactivé si 0 étoile', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => RatingBottomSheet.show(
              ctx,
              bidId: 'bid-1',
              travelerName: 'Amadou',
            ),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final btn = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(DonyButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(btn.onTap, isNull);
  });

  testWidgets('le bouton Envoyer est actif après sélection d\'une étoile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => RatingBottomSheet.show(
              ctx,
              bidId: 'bid-1',
              travelerName: 'Amadou',
            ),
            child: const Text('Ouvrir'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Tape sur la 3ème étoile (DonyIcon('star') taille 44 du sélecteur)
    final stars = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'star' && w.size == 44,
    );
    await tester.tap(stars.at(2));
    await tester.pumpAndSettle();

    // Le bouton doit maintenant être actif
    final btn = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(DonyButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(btn.onTap, isNotNull);
  });

  testWidgets('titre "Rate the sender" en anglais quand isTravelerRating', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => RatingBottomSheet.show(
              ctx,
              bidId: 'bid-1',
              isTravelerRating: true,
            ),
            child: const Text('Open'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Rate the sender'), findsOneWidget);
    expect(find.text('Send rating'), findsOneWidget);
  });

  testWidgets('titre "Rate {name}" en anglais sans isTravelerRating', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => RatingBottomSheet.show(
              ctx,
              bidId: 'bid-1',
              travelerName: 'Amadou',
            ),
            child: const Text('Open'),
          ),
        ),
        bloc,
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Rate Amadou'), findsOneWidget);
  });
}
