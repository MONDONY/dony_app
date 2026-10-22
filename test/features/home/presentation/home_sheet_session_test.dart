import 'package:dony/features/home/presentation/home_sheet_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(HomeSheetSession.reset);

  test('l\'ouverture à 100 % n\'est donnée qu\'une fois par processus', () {
    HomeSheetSession.reset();

    expect(HomeSheetSession.takeFullOpening(), isTrue);
    expect(HomeSheetSession.takeFullOpening(), isFalse);
    expect(HomeSheetSession.takeFullOpening(), isFalse);
  });

  test('éteinte, elle n\'est jamais donnée et ne se consomme pas', () {
    HomeSheetSession.reset(enabled: false);

    expect(HomeSheetSession.takeFullOpening(), isFalse);

    // Rallumée : la première arrivée est encore disponible.
    HomeSheetSession.fullOpeningEnabled = true;
    expect(HomeSheetSession.takeFullOpening(), isTrue);
  });

  test('reset rend la première arrivée', () {
    HomeSheetSession.reset();
    expect(HomeSheetSession.takeFullOpening(), isTrue);

    HomeSheetSession.reset();
    expect(HomeSheetSession.takeFullOpening(), isTrue);
  });
}
