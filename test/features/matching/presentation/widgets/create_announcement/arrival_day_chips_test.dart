import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/arrival_day_chips.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Jour à [n] jours de [d], en arithmétique de calendrier.
DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Départ le 5 d'un mois futur : +3 à +14 reste dans le même mois, la grille
/// du sélecteur de date les affiche tous.
DateTime _departure() {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 2, 5);
}

Widget _host(
  ValueNotifier<int> notifier, {
  int maxDays = 2,
  DateTime? departureDate,
  String locale = 'fr',
  double width = 360,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ArrivalDayChips(
            notifier: notifier,
            maxDays: maxDays,
            departureDate: departureDate,
          ),
        ),
      ),
    ),
  ),
);

bool _selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

void main() {
  late ValueNotifier<int> notifier;

  setUp(() => notifier = ValueNotifier(0));
  tearDown(() => notifier.dispose());

  testWidgets('maxDays 2 : trois puces, rendu inchangé', (tester) async {
    await tester.pumpWidget(_host(notifier));

    for (final k in ['arrival-day-0', 'arrival-day-1', 'arrival-day-2']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    expect(find.byKey(const Key('arrival-day-other')), findsNothing);
    expect(find.text('Autre date'), findsNothing);
    expect(find.text('Le jour même'), findsOneWidget);
    expect(find.text('Le lendemain'), findsOneWidget);
    expect(find.text('Dans 2 jours'), findsOneWidget);
    expect(_selected(tester, 'arrival-day-0'), isTrue);
    await tester.tap(find.byKey(const Key('arrival-day-2')));
    await tester.pump();
    expect(notifier.value, 2);
  });

  testWidgets('maxDays 14 : Autre date ouvre le sélecteur borné à J+3..J+14', (
    tester,
  ) async {
    final dep = _departure();
    await tester.pumpWidget(_host(notifier, maxDays: 14, departureDate: dep));
    expect(find.text('Autre date'), findsOneWidget);

    await tester.tap(find.byKey(const Key('arrival-day-other')));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, _plusDays(dep, 3));
    expect(picker.lastDate, _plusDays(dep, 14));
    // Rien n'est choisi tant que la date n'est pas validée.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(notifier.value, 0);
  });

  testWidgets('date choisie J+5 : notifier 5, ligne Date d\'arrivée', (
    tester,
  ) async {
    final dep = _departure();
    await tester.pumpWidget(_host(notifier, maxDays: 14, departureDate: dep));
    expect(find.byKey(const Key('arrival-date-row')), findsNothing);

    await tester.tap(find.byKey(const Key('arrival-day-other')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('${_plusDays(dep, 5).day}'),
      ),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(notifier.value, 5);
    expect(_selected(tester, 'arrival-day-other'), isTrue);
    for (final k in ['arrival-day-0', 'arrival-day-1', 'arrival-day-2']) {
      expect(_selected(tester, k), isFalse);
    }
    final row = tester.widget<Text>(find.byKey(const Key('arrival-date-row')));
    final shown = row.textSpan!.toPlainText();
    expect(shown, startsWith('Date d\'arrivée : '));
    expect(shown, endsWith(DateFormat.yMMMEd('fr').format(_plusDays(dep, 5))));
  });

  testWidgets('un décalage de 1 ou 2 jours sélectionne la puce, sans ligne', (
    tester,
  ) async {
    final dep = _departure();
    await tester.pumpWidget(_host(notifier, maxDays: 14, departureDate: dep));
    for (final offset in [1, 2]) {
      notifier.value = offset;
      await tester.pump();
      expect(_selected(tester, 'arrival-day-$offset'), isTrue);
      expect(_selected(tester, 'arrival-day-other'), isFalse);
      expect(find.byKey(const Key('arrival-date-row')), findsNothing);
    }
  });

  testWidgets('retoucher Autre date rouvre le sélecteur sur la date choisie', (
    tester,
  ) async {
    final dep = _departure();
    notifier.value = 9;
    await tester.pumpWidget(_host(notifier, maxDays: 14, departureDate: dep));

    await tester.tap(find.byKey(const Key('arrival-day-other')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      _plusDays(dep, 9),
    );
  });

  group('sans date de départ (modèles et séries, D17)', () {
    testWidgets('Autre date ouvre un choix de décalage de 3 à 14 jours', (
      tester,
    ) async {
      await tester.pumpWidget(_host(notifier, maxDays: 14));

      await tester.tap(find.byKey(const Key('arrival-day-other')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      for (var n = 3; n <= 14; n++) {
        expect(find.byKey(Key('arrival-offset-$n')), findsOneWidget);
      }
      expect(find.byKey(const Key('arrival-offset-2')), findsNothing);
      expect(find.byKey(const Key('arrival-offset-15')), findsNothing);

      await tester.tap(find.byKey(const Key('arrival-offset-7')));
      await tester.pumpAndSettle();

      expect(notifier.value, 7);
      expect(_selected(tester, 'arrival-day-other'), isTrue);
      final row = tester.widget<Text>(
        find.byKey(const Key('arrival-date-row')),
      );
      expect(row.textSpan!.toPlainText(), 'Date d\'arrivée : Dans 7 jours');
    });

    testWidgets('anglais : « Other date », « In 12 days »', (tester) async {
      await tester.pumpWidget(_host(notifier, maxDays: 14, locale: 'en'));
      expect(find.text('Other date'), findsOneWidget);

      await tester.tap(find.byKey(const Key('arrival-day-other')));
      await tester.pumpAndSettle();
      // Liste longue : le 12e jour est sous le pli de la feuille.
      await tester.ensureVisible(find.byKey(const Key('arrival-offset-12')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('arrival-offset-12')));
      await tester.pumpAndSettle();

      expect(notifier.value, 12);
      final row = tester.widget<Text>(
        find.byKey(const Key('arrival-date-row')),
      );
      expect(row.textSpan!.toPlainText(), 'Arrival date : In 12 days');
    });

    testWidgets('fermer le choix sans rien toucher garde le décalage', (
      tester,
    ) async {
      notifier.value = 4;
      await tester.pumpWidget(_host(notifier, maxDays: 14));
      await tester.tap(find.byKey(const Key('arrival-day-other')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(notifier.value, 4);
    });
  });

  group('arrivalChipsMaxDays', () {
    test('route : borne du mode ; ailleurs ou inconnu : 2', () {
      expect(arrivalChipsMaxDays(TransportMode.car), 14);
      expect(arrivalChipsMaxDays(TransportMode.bus), 14);
      expect(arrivalChipsMaxDays(TransportMode.plane), 2);
      expect(arrivalChipsMaxDays(TransportMode.boat), 2);
      expect(arrivalChipsMaxDays(null), 2);
    });
  });

  group('effectiveArrivalOffset', () {
    test('route : le décalage compte sans heure d\'arrivée', () {
      expect(
        effectiveArrivalOffset(
          mode: TransportMode.car,
          hasArrivalTime: false,
          offset: 5,
        ),
        5,
      );
    });
    test('avion : sans heure d\'arrivée, 0 ; avec heure, le décalage', () {
      expect(
        effectiveArrivalOffset(
          mode: TransportMode.plane,
          hasArrivalTime: false,
          offset: 2,
        ),
        0,
      );
      expect(
        effectiveArrivalOffset(
          mode: TransportMode.plane,
          hasArrivalTime: true,
          offset: 2,
        ),
        2,
      );
      expect(
        effectiveArrivalOffset(mode: null, hasArrivalTime: false, offset: 1),
        0,
      );
    });
  });

  for (final locale in ['fr', 'en']) {
    testWidgets('360 dp $locale : quatre puces, libellés sur une ligne', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      notifier.value = 6;
      await tester.pumpWidget(
        _host(
          notifier,
          maxDays: 14,
          departureDate: _departure(),
          locale: locale,
        ),
      );

      expect(tester.takeException(), isNull);
      final keys = [
        'arrival-day-0',
        'arrival-day-1',
        'arrival-day-2',
        'arrival-day-other',
      ];
      final heights = <double>[];
      for (final k in keys) {
        final chip = find.byKey(Key(k));
        expect(chip, findsOneWidget);
        final label = find.descendant(of: chip, matching: find.byType(Text));
        // Une seule ligne : hauteur d'une ligne de texte, jamais deux.
        expect(tester.getSize(label.first).height, lessThan(24));
        heights.add(tester.getSize(chip).height);
        expect(
          tester.getRect(chip).right,
          lessThanOrEqualTo(360 - 16 + 0.5),
          reason: '$k déborde de la largeur',
        );
      }
      expect(heights.toSet().length, 1);
    });
  }
}
