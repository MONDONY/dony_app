import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/grid_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementFormBloc
    extends MockBloc<AnnouncementFormEvent, AnnouncementFormState>
    implements AnnouncementFormBloc {}

const _items = [
  GridPreviewItem(id: 'a1', label: 'Téléphone', unitPriceDisplay: 12.60),
  GridPreviewItem(id: 'a2', label: 'Vêtement', unitPriceDisplay: 8.40),
  GridPreviewItem(id: 'a3', label: 'Chaussures', unitPriceDisplay: 15.75),
  GridPreviewItem(id: 'a4', label: 'Sac de riz', unitPriceDisplay: 26.25),
  GridPreviewItem(id: 'a5', label: 'Livre', unitPriceDisplay: 5.25),
];

/// Monte la carte derrière un GoRouter réel : « Modifier » pousse la route de
/// la grille, et le retour doit provoquer un rechargement.
Widget _wrap(
  List<GridPreviewItem> items, {
  AnnouncementFormBloc? bloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: GridPreviewCard(items: items)),
      ),
      GoRoute(
        path: '/profile/price-grid',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Retour'),
            ),
          ),
        ),
      ),
    ],
  );

  final app = MaterialApp.router(routerConfig: router);
  if (bloc == null) return app;
  return BlocProvider<AnnouncementFormBloc>.value(value: bloc, child: app);
}

void main() {
  setUpAll(() {
    // mocktail exige une valeur de repli pour capturer les events du BLoC.
    registerFallbackValue(const AnnouncementGridPreviewLoadRequested());
  });

  group('GridPreviewCard — repli de la liste', () {
    testWidgets('trois articles ou moins : tout est visible, pas de bouton', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items.take(3).toList()));
      await tester.pumpAndSettle();

      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('Vêtement'), findsOneWidget);
      expect(find.text('Chaussures'), findsOneWidget);
      expect(find.byKey(const Key('grid-preview-see-all')), findsNothing);
    });

    testWidgets('au-delà de trois : seuls les premiers restent affichés', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('Vêtement'), findsOneWidget);
      expect(find.text('Chaussures'), findsOneWidget);
      // Les deux derniers sont repliés dans la feuille.
      expect(find.text('Sac de riz'), findsNothing);
      expect(find.text('Livre'), findsNothing);
    });

    testWidgets('le bouton annonce le nombre total d\'articles', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      expect(find.text('Voir les 5 articles'), findsOneWidget);
    });

    testWidgets('la feuille montre tous les articles', (tester) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grid-preview-see-all')));
      await tester.pumpAndSettle();

      for (final item in _items) {
        expect(
          find.text(item.label),
          findsWidgets,
          reason: '${item.label} doit apparaître dans la feuille',
        );
      }
    });

    testWidgets('la feuille propose de modifier la grille', (tester) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grid-preview-see-all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('grid-sheet-edit')), findsOneWidget);
    });

    testWidgets('rappelle que le barème vient du profil', (tester) async {
      await tester.pumpWidget(_wrap(_items));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('viennent de votre profil'),
        findsOneWidget,
      );
    });
  });

  group('GridPreviewCard — grille vide', () {
    testWidgets('invite à composer la grille plutôt que de constater le vide', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const []));
      await tester.pumpAndSettle();

      expect(find.text('Votre grille est vide'), findsOneWidget);
      expect(find.byKey(const Key('grid-preview-create')), findsOneWidget);
      expect(find.byKey(const Key('grid-preview-see-all')), findsNothing);
    });
  });

  group('GridPreviewCard — rafraîchissement au retour', () {
    late AnnouncementFormBloc bloc;

    setUp(() {
      bloc = _MockAnnouncementFormBloc();
      whenListen(
        bloc,
        const Stream<AnnouncementFormState>.empty(),
        initialState: const AnnouncementFormState(),
      );
    });

    testWidgets('« Modifier » ouvre l\'écran de grille du profil', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items, bloc: bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grid-preview-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Retour'), findsOneWidget);
    });

    testWidgets('le retour recharge l\'aperçu', (tester) async {
      // Le BLoC n'émet le chargement qu'à la bascule vers le mode grille :
      // sans ce rappel explicite, un prix corrigé resterait invisible ici.
      await tester.pumpWidget(_wrap(_items, bloc: bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grid-preview-edit')));
      await tester.pumpAndSettle();

      verifyNever(
        () => bloc.add(any(that: isA<AnnouncementGridPreviewLoadRequested>())),
      );

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(any(that: isA<AnnouncementGridPreviewLoadRequested>())),
      ).called(1);
    });

    testWidgets('« Modifier ma grille » depuis la feuille recharge aussi', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_items, bloc: bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grid-preview-see-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('grid-sheet-edit')));
      await tester.pumpAndSettle();

      // La feuille se referme avant la navigation : aucune route ne doit
      // rester empilée par-dessus elle.
      expect(find.byKey(const Key('grid-sheet-edit')), findsNothing);
      expect(find.text('Retour'), findsOneWidget);

      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(any(that: isA<AnnouncementGridPreviewLoadRequested>())),
      ).called(1);
    });
  });
}
