import 'package:dony/features/matching/data/grid_item_declaration_matcher.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementGridItemModel _item(String id, String label) =>
    AnnouncementGridItemModel(id: id, label: label, unitPriceDisplay: 20);

final _grid = [
  _item('phone', 'Téléphone'),
  _item('laptop', 'Ordinateur portable'),
  _item('suitcase', 'Valise 23 kg'),
  _item('shoes', 'Paire de chaussures'),
];

List<String> _suggest({
  Set<String> categories = const {},
  String description = '',
  Map<String, int> quantities = const {},
  Set<String> dismissed = const {},
}) => GridItemDeclarationMatcher.suggest(
  items: _grid,
  categories: categories,
  description: description,
  quantities: quantities,
  dismissed: dismissed,
).map((i) => i.id).toList();

void main() {
  test('la catégorie électronique propose téléphone et ordinateur', () {
    expect(_suggest(categories: {'Téléphone & électronique'}), [
      'phone',
      'laptop',
    ]);
  });

  test('un mot-clé de la description suffit, sans catégorie', () {
    expect(_suggest(description: 'Un iPhone 13 dans sa boîte'), [
      'phone',
      'laptop',
    ]);
  });

  test('un mot du libellé écrit dans la description', () {
    expect(_suggest(description: 'Une valise de vêtements'), ['suitcase']);
  });

  test('accents, casse et pluriel ignorés', () {
    expect(_suggest(description: 'Deux TELEPHONES'), contains('phone'));
    expect(_suggest(categories: {'Chaussures'}), ['shoes']);
  });

  test('article déjà choisi ou écarté : plus proposé', () {
    expect(
      _suggest(
        categories: {'Téléphone & électronique'},
        quantities: {'phone': 1},
        dismissed: {'laptop'},
      ),
      isEmpty,
    );
  });

  test('rien de commun : aucune proposition', () {
    expect(
      _suggest(categories: {'Alimentation sèche'}, description: 'Du riz'),
      isEmpty,
    );
    expect(_suggest(description: 'kg de 23'), isEmpty);
  });

  test('« tele » ne prend pas « hotel »', () {
    expect(_suggest(description: "Savon d'hôtel"), isEmpty);
  });

  test('normalize retire accents et ligatures', () {
    expect(
      GridItemDeclarationMatcher.normalize('Œuvre Électronique'),
      'oeuvre electronique',
    );
  });
}
