// Recette du 14/11 : tirer la liste de l'accueil vers le bas ne relançait pas
// la recherche (un trajet publié entre-temps restait absent).
import 'package:dony/features/home/presentation/home_sheet_pull_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HomeSheetPullRefresh pull;

  setUp(() => pull = HomeSheetPullRefresh());

  test('liste tirée puis revenue sur la liste : relance', () {
    pull.onSizeChanged(0.9, settledOnList: true);
    pull.onSizeChanged(1, settledOnList: true);
    expect(pull.onSettled(onList: true, wasOnList: true), isTrue);
    // Une seule relance par geste.
    expect(pull.onSettled(onList: true, wasOnList: true), isFalse);
  });

  test('liste tirée jusqu\'à la carte : pas de relance', () {
    pull.onSizeChanged(0.4, settledOnList: true);
    pull.onSizeChanged(0, settledOnList: true);
    expect(pull.onSettled(onList: false, wasOnList: true), isFalse);
  });

  test('liste ouverte depuis la carte : pas de relance', () {
    pull.onSizeChanged(0.5, settledOnList: false);
    pull.onSizeChanged(1, settledOnList: false);
    expect(pull.onSettled(onList: true, wasOnList: false), isFalse);
  });

  test('liste posée sans geste : pas de relance', () {
    pull.onSizeChanged(1, settledOnList: true);
    expect(pull.onSettled(onList: true, wasOnList: true), isFalse);
  });
}
