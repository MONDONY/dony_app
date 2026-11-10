import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget subject({
    TravelerStatus? status,
    String? registrationNumber,
    Locale locale = AppL10n.fr,
    double width = 360,
  }) => localizedApp(
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Wrap(
            children: [
              TravelerStatusChip(
                status: status,
                registrationNumber: registrationNumber,
              ),
            ],
          ),
        ),
      ),
    ),
    locale: locale,
  );

  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  testWidgets('particulier : pastille « Particulier »', (tester) async {
    await tester.pumpWidget(subject(status: TravelerStatus.individual));
    expect(find.text(fr.travelerStatusChipIndividual), findsOneWidget);
    expect(find.text(fr.travelerStatusChipProfessional), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('professionnel sans numéro : « Professionnel » seul', (
    tester,
  ) async {
    await tester.pumpWidget(subject(status: TravelerStatus.professional));
    expect(find.text(fr.travelerStatusChipProfessional), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('professionnel avec numéro : le numéro est affiché', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        status: TravelerStatus.professional,
        registrationNumber: 'CI-ABJ-2021-B-12345',
      ),
    );
    expect(
      find.text(
        fr.travelerStatusChipProfessionalWithNumber('CI-ABJ-2021-B-12345'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('particulier : le numéro éventuel n\'est jamais affiché', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        status: TravelerStatus.individual,
        registrationNumber: '123456789',
      ),
    );
    expect(find.textContaining('123456789'), findsNothing);
    expect(find.text(fr.travelerStatusChipIndividual), findsOneWidget);
  });

  testWidgets('statut null : rien du tout (ancien back)', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(TravelerStatusChip)), Size.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('numéro vide ou blanc : traité comme absent', (tester) async {
    await tester.pumpWidget(
      subject(status: TravelerStatus.professional, registrationNumber: '   '),
    );
    expect(find.text(fr.travelerStatusChipProfessional), findsOneWidget);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets(
      'une seule ligne dans 200 dp avec un très long numéro (${locale.languageCode})',
      (tester) async {
        await tester.pumpWidget(
          subject(
            status: TravelerStatus.professional,
            registrationNumber: 'CI-ABJ-2021-B-1234567890-LONG-NUMBER-0001',
            locale: locale,
            width: 200,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(find.byType(Text));
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
        final chipRect = tester.getRect(find.byType(TravelerStatusChip));
        expect(chipRect.width, lessThanOrEqualTo(200));
        // Hauteur d'une seule ligne de libellé small.
        expect(chipRect.height, lessThan(32));
      },
    );
  }

  testWidgets('anglais : libellés traduits', (tester) async {
    await tester.pumpWidget(
      subject(status: TravelerStatus.individual, locale: AppL10n.en),
    );
    expect(find.text(en.travelerStatusChipIndividual), findsOneWidget);
    expect(
      en.travelerStatusChipIndividual,
      isNot(fr.travelerStatusChipIndividual),
    );
  });

  testWidgets('sémantique : un seul libellé lisible', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(subject(status: TravelerStatus.individual));
    expect(
      find.bySemanticsLabel(fr.travelerStatusChipIndividual),
      findsOneWidget,
    );
    handle.dispose();
  });
}
