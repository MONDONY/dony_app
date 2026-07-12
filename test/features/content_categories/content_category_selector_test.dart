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

  testWidgets('displays the 11 catalog labels', (tester) async {
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

    for (final category in fallbackCatalog) {
      expect(find.textContaining(category.label), findsOneWidget);
    }
  });

  testWidgets('checking two categories emits their labels', (tester) async {
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

    await tester.tap(find.byKey(const Key('content-category-DOCUMENTS')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('content-category-LIVRES')));
    await tester.pumpAndSettle();

    expect(
      emitted,
      unorderedEquals(['Documents & administratif', 'Livres']),
    );
  });

  testWidgets('entering "Poissons" in the free field adds it to selection', (
    tester,
  ) async {
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

    await tester.enterText(
      find.byKey(const Key('content-category-free-text')),
      'Poissons',
    );
    await tester.tap(find.byKey(const Key('content-category-add-btn')));
    await tester.pumpAndSettle();

    expect(emitted, contains('Poissons'));
  });

  testWidgets(
    'pre-checks values passed in, including a free value outside the catalog',
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

      final documentsCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const Key('content-category-DOCUMENTS')),
      );
      expect(documentsCheckbox.value, isTrue);

      final freeCheckbox = tester.widget<CheckboxListTile>(
        find.byKey(const Key('content-category-custom-Poissons')),
      );
      expect(freeCheckbox.value, isTrue);
    },
  );
}
