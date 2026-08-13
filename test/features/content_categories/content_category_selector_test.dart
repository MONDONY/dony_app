import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements IContentCategoryRepository {
  _FakeRepository(this._categories);
  final List<ContentCategory> _categories;

  @override
  Future<List<ContentCategory>> getCategories() async => _categories;
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  late _FakeRepository repository;

  setUp(() {
    repository = _FakeRepository(fallbackCatalog);
  });

  Finder fieldFinder({String prefix = 'content-combo'}) =>
      find.byKey(Key('$prefix-field'));

  testWidgets(
    'focus sur le champ ouvre la liste avec les 11 items du catalogue',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCategorySelector(
            repository: repository,
            selected: const [],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Avant le focus, la liste n'est pas affichée.
      expect(find.byKey(const Key('content-combo-dropdown')), findsNothing);

      await tester.tap(fieldFinder());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('content-combo-dropdown')), findsOneWidget);
      for (final category in fallbackCatalog) {
        expect(
          find.byKey(Key('content-combo-item-${category.label}')),
          findsOneWidget,
          reason: 'Item "${category.label}" doit être présent dans la liste',
        );
      }
    },
  );

  testWidgets(
    'taper « ali » filtre la liste — seul « Alimentation sèche » reste',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCategorySelector(
            repository: repository,
            selected: const [],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(fieldFinder());
      await tester.pumpAndSettle();
      await tester.enterText(fieldFinder(), 'ali');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('content-combo-item-Alimentation sèche')),
        findsOneWidget,
      );
      for (final category in fallbackCatalog) {
        if (category.label == 'Alimentation sèche') continue;
        expect(
          find.byKey(Key('content-combo-item-${category.label}')),
          findsNothing,
          reason:
              '"${category.label}" ne doit plus être visible après filtrage',
        );
      }
    },
  );

  testWidgets(
    'tap sur un item ajoute un tag, coche l\'item et laisse la liste ouverte',
    (tester) async {
      List<String>? emitted;
      await tester.pumpWidget(
        _wrap(
          ContentCategorySelector(
            repository: repository,
            selected: const [],
            onChanged: (value) => emitted = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(fieldFinder());
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('content-combo-item-Livres')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-combo-item-Livres')));
      await tester.pumpAndSettle();

      expect(emitted, ['Livres']);
      expect(find.byKey(const Key('content-combo-tag-Livres')), findsOneWidget);
      // La liste reste ouverte (multi-sélection).
      expect(find.byKey(const Key('content-combo-dropdown')), findsOneWidget);
      final item = tester.widget<Row>(
        find.descendant(
          of: find.byKey(const Key('content-combo-item-Livres')),
          matching: find.byType(Row),
        ),
      );
      // La coche ✓ est le dernier enfant de la Row quand sélectionné.
      expect(item.children.length, 4);
    },
  );

  testWidgets('re-tap sur un item déjà sélectionné le désélectionne', (
    tester,
  ) async {
    List<String>? emitted;
    await tester.pumpWidget(
      _wrap(
        ContentCategorySelector(
          repository: repository,
          selected: const ['Livres'],
          onChanged: (value) => emitted = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('content-combo-tag-Livres')), findsOneWidget);

    await tester.tap(fieldFinder());
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('content-combo-item-Livres')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('content-combo-item-Livres')));
    await tester.pumpAndSettle();

    expect(emitted, isEmpty);
    expect(find.byKey(const Key('content-combo-tag-Livres')), findsNothing);
  });

  testWidgets(
    'texte sans match affiche « Ajouter "Poissons" » — tap ajoute le tag',
    (tester) async {
      List<String>? emitted;
      await tester.pumpWidget(
        _wrap(
          ContentCategorySelector(
            repository: repository,
            selected: const [],
            onChanged: (value) => emitted = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(fieldFinder());
      await tester.pumpAndSettle();
      await tester.enterText(fieldFinder(), 'Poissons');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('content-combo-item-add')), findsOneWidget);
      expect(find.textContaining('Poissons'), findsWidgets);

      await tester.tap(find.byKey(const Key('content-combo-item-add')));
      await tester.pumpAndSettle();

      expect(emitted, contains('Poissons'));
      expect(
        find.byKey(const Key('content-combo-tag-Poissons')),
        findsOneWidget,
      );
    },
  );

  testWidgets('✕ sur un tag le retire', (tester) async {
    List<String>? emitted;
    await tester.pumpWidget(
      _wrap(
        ContentCategorySelector(
          repository: repository,
          selected: const ['Documents & administratif'],
          onChanged: (value) => emitted = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tag = find.byKey(
      const Key('content-combo-tag-Documents & administratif'),
    );
    expect(tag, findsOneWidget);

    await tester.tap(
      find.descendant(of: tag, matching: find.byType(GestureDetector)),
    );
    await tester.pumpAndSettle();

    expect(emitted, isEmpty);
    expect(tag, findsNothing);
  });

  testWidgets(
    'valeurs initiales (dont une hors catalogue) affichées comme tags',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ContentCategorySelector(
            repository: repository,
            selected: const ['Documents & administratif', 'Poissons'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('content-combo-tag-Documents & administratif')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('content-combo-tag-Poissons')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'la liste de labels émise correspond exactement aux tags affichés',
    (tester) async {
      List<String>? emitted;
      await tester.pumpWidget(
        _wrap(
          ContentCategorySelector(
            repository: repository,
            selected: const [],
            onChanged: (value) => emitted = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(fieldFinder());
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('content-combo-item-Livres')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-combo-item-Livres')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('content-combo-item-Documents & administratif')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('content-combo-item-Documents & administratif')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(fieldFinder(), 'Poissons');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-combo-item-add')));
      await tester.pumpAndSettle();

      expect(
        emitted,
        unorderedEquals(['Livres', 'Documents & administratif', 'Poissons']),
      );
      final tagFinder = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('content-combo-tag-'),
      );
      expect(tagFinder, findsNWidgets(3));
    },
  );
}
