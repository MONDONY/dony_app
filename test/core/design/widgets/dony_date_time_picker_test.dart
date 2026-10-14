import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jour du mois courant dont la veille et le surlendemain restent dans la
/// même grille du calendrier.
DateTime _pivot() {
  var d = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 3));
  while (d.day > 25 || d.day < 3) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

void main() {
  final pivot = _pivot();

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Téléphone en 24 h, comme en France : la saisie « 18 » n'est valide
    // qu'à cette condition dans le sélecteur d'heure.
    await tester.pumpWidget(
      MaterialApp(
        locale: AppL10n.fr,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            captured = c;
            return const Scaffold();
          },
        ),
      ),
    );
    return captured;
  }

  Finder inDialog<T>(Finder f) =>
      find.descendant(of: find.byType(T), matching: f);

  testWidgets('jour puis heure saisie : instant complet rendu', (tester) async {
    final ctx = await pumpHost(tester);
    final future = _Capture(
      pickDateThenTime(
        ctx,
        first: DateTime.now(),
        last: pivot.add(const Duration(days: 2)),
        initial: pivot,
        primary: Colors.teal,
      ),
    );
    await tester.pumpAndSettle();

    // Calendrier d'abord.
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(inDialog<DatePickerDialog>(find.text('${pivot.day + 1}')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Puis aussitôt l'heure, à 20:00 par défaut.
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = inDialog<TimePickerDialog>(find.byType(TextField));
    await tester.enterText(fields.at(0), '18');
    await tester.enterText(fields.at(1), '45');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final result = future.result;
    expect(future.done, isTrue);
    final next = pivot.add(const Duration(days: 1));
    expect(result!.day, next);
    expect(result.time, const TimeOfDay(hour: 18, minute: 45));
    expect(result.instant, DateTime(next.year, next.month, next.day, 18, 45));
    expect(
      result.resolve((d) => throw StateError('pas de repli')),
      result.instant,
    );
  });

  testWidgets('heure proposée selon le jour choisi', (tester) async {
    final ctx = await pumpHost(tester);
    DateTime? askedFor;
    final future = _Capture(
      pickDateThenTime(
        ctx,
        first: DateTime.now(),
        last: pivot,
        initial: pivot,
        initialTimeFor: (day) {
          askedFor = day;
          return const TimeOfDay(hour: 7, minute: 15);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final result = future.result;
    expect(future.done, isTrue);
    expect(askedFor, pivot);
    expect(result!.time, const TimeOfDay(hour: 7, minute: 15));
  });

  testWidgets('heure annulée : jour seul, repli de l\'appelant', (
    tester,
  ) async {
    final ctx = await pumpHost(tester);
    final future = _Capture(
      pickDateThenTime(ctx, first: DateTime.now(), last: pivot, initial: pivot),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    final result = future.result;
    expect(future.done, isTrue);
    expect(result!.day, pivot);
    expect(result.time, isNull);
    expect(result.instant, isNull);
    expect(
      result.resolve((d) => DateTime(d.year, d.month, d.day, 23, 59)),
      DateTime(pivot.year, pivot.month, pivot.day, 23, 59),
    );
  });

  testWidgets('calendrier annulé : null, aucun sélecteur d\'heure', (
    tester,
  ) async {
    final ctx = await pumpHost(tester);
    final future = _Capture(
      pickDateThenTime(
        ctx,
        first: DateTime.now(),
        // Borne haute avant la borne basse : ramenée au premier jour.
        last: DateTime.now().subtract(const Duration(days: 3)),
        initial: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(future.done, isTrue);
    expect(future.result, isNull);
    expect(find.byType(TimePickerDialog), findsNothing);
  });
}

/// Résultat d'un sélecteur, lu après les `pump` : attendre le `Future`
/// directement bloquerait le test pour toujours si un dialogue restait ouvert.
class _Capture {
  _Capture(Future<DonyDateTimePick?> future) {
    future.then((r) {
      result = r;
      done = true;
    });
  }

  DonyDateTimePick? result;
  bool done = false;
}
