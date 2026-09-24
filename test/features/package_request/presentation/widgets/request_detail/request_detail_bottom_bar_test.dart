import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_bottom_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  test('primaryButtonFor', () {
    expect(primaryButtonFor(fr, RequestPrimaryAction.publish).label, 'Publier');
    expect(primaryButtonFor(fr, RequestPrimaryAction.share).icon, 'share-2');
    expect(
      primaryButtonFor(fr, RequestPrimaryAction.pay, amount: '28,00 €').label,
      'Payer 28,00 €',
    );
    final wait = primaryButtonFor(
      fr,
      RequestPrimaryAction.waitTrip,
      travelerName: 'Awa K.',
    );
    expect(wait.label, 'Awa K. ajoute son trajet');
    expect(wait.enabled, isFalse);
    expect(
      primaryButtonFor(
        fr,
        RequestPrimaryAction.rate,
        travelerName: 'Awa K.',
      ).label,
      'Noter Awa K.',
    );
    expect(
      primaryButtonFor(fr, RequestPrimaryAction.republish).label,
      'Republier avec de nouvelles dates',
    );
    expect(
      primaryButtonFor(fr, RequestPrimaryAction.publishSimilar).label,
      'Publier une demande similaire',
    );
    expect(
      primaryButtonFor(fr, RequestPrimaryAction.trackParcel).label,
      'Suivre mon colis',
    );
    expect(
      primaryButtonFor(fr, RequestPrimaryAction.openThread).label,
      'Ouvrir la discussion',
    );
    for (final a in RequestPrimaryAction.values) {
      expect(
        primaryButtonFor(
          fr,
          a,
          travelerName: 'A',
          amount: '1 €',
        ).label.contains('—'),
        isFalse,
      );
    }
  });

  test('primaryButtonFor en anglais', () {
    expect(primaryButtonFor(en, RequestPrimaryAction.publish).label, 'Post');
    expect(
      primaryButtonFor(en, RequestPrimaryAction.pay, amount: '€28.00').label,
      'Pay €28.00',
    );
    expect(
      primaryButtonFor(en, RequestPrimaryAction.waitTrip).label,
      'the traveler is adding their trip',
    );
    expect(
      primaryButtonFor(en, RequestPrimaryAction.trackParcel).label,
      'Track my parcel',
    );
  });

  testWidgets('Modifier + principal ; taps', (tester) async {
    var primary = 0, edit = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: RequestDetailBottomBar(
            actions: const RequestScreenActions(
              primary: RequestPrimaryAction.share,
              showEdit: true,
            ),
            busy: false,
            onPrimary: () => primary++,
            onEdit: () => edit++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Partager'));
    await tester.tap(find.text('Modifier'));
    expect((primary, edit), (1, 1));
  });

  testWidgets('Message affiché quand demandé ; occupé = boutons désactivés', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: RequestDetailBottomBar(
            actions: const RequestScreenActions(
              primary: RequestPrimaryAction.trackParcel,
              showMessage: true,
            ),
            busy: true,
            onPrimary: () {},
            onMessage: () {},
          ),
        ),
      ),
    );
    expect(find.text('Message'), findsOneWidget);
    for (final button in tester.widgetList<DonyButton>(
      find.byType(DonyButton),
    )) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('attente du trajet : principal désactivé même hors chargement', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: RequestDetailBottomBar(
            actions: const RequestScreenActions(
              primary: RequestPrimaryAction.waitTrip,
            ),
            busy: false,
            travelerName: 'Awa K.',
            onPrimary: () {},
          ),
        ),
      ),
    );
    expect(find.text('Awa K. ajoute son trajet'), findsOneWidget);
    expect(
      tester.widget<DonyButton>(find.byType(DonyButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'primaryEnabled: false désactive le bouton malgré une action normalement active',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            bottomNavigationBar: RequestDetailBottomBar(
              actions: const RequestScreenActions(
                primary: RequestPrimaryAction.trackParcel,
              ),
              busy: false,
              primaryEnabled: false,
              onPrimary: () {},
            ),
          ),
        ),
      );
      expect(find.text('Suivre mon colis'), findsOneWidget);
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets('écran traduit en anglais : bouton principal et Modifier', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: RequestDetailBottomBar(
            actions: const RequestScreenActions(
              primary: RequestPrimaryAction.trackParcel,
              showEdit: true,
            ),
            busy: false,
            onPrimary: () {},
            onEdit: () {},
          ),
        ),
      ),
    );
    expect(find.text('Track my parcel'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Suivre mon colis'), findsNothing);
  });
}
