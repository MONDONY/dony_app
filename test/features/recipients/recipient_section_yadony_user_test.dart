import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/widgets/designate_yadony_user_sheet.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _MockRepo extends Mock implements RecipientInvitationRepository {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeRecipientEvent()));

  late _MockRecipientBloc bloc;
  late _MockRepo repo;
  late RecipientSectionController controller;
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;

  setUp(() {
    bloc = _MockRecipientBloc();
    when(() => bloc.state).thenReturn(const RecipientState());
    repo = _MockRepo();
    when(() => repo.parcelDesignationOffered).thenReturn(true);
    if (getIt.isRegistered<RecipientInvitationRepository>()) {
      getIt.unregister<RecipientInvitationRepository>();
    }
    getIt.registerSingleton<RecipientInvitationRepository>(repo);
    controller = RecipientSectionController();
    nameCtrl = TextEditingController();
    phoneCtrl = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    getIt.unregister<RecipientInvitationRepository>();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool allow = true,
    Locale locale = AppL10n.fr,
    String? chosen = 'awa.diallo',
  }) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipientSection(
              controller: controller,
              nameCtrl: nameCtrl,
              phoneCtrl: phoneCtrl,
              allowYadonyUser: allow,
              createBloc: () => bloc,
              openDesignateSheet: (_) async =>
                  chosen == null ? null : DesignatedUser(chosen),
              children: const [Text('champs manuels')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder choice() => find.byKey(const Key('recipient-section-yadony-user'));

  testWidgets('hôte sans désignation (demande d\'envoi) : pas de choix', (
    tester,
  ) async {
    await pump(tester, allow: false);
    expect(choice(), findsNothing);
  });

  testWidgets('back sans la route ou sans désignation : pas de choix', (
    tester,
  ) async {
    when(() => repo.parcelDesignationOffered).thenReturn(false);
    await pump(tester);
    expect(choice(), findsNothing);
    expect(find.text('Choisir un destinataire'), findsOneWidget);
  });

  testWidgets('sélection : @identifiant, attente, identifiant exposé', (
    tester,
  ) async {
    nameCtrl.text = 'Ancien nom';
    phoneCtrl.text = '+221771234567';
    await pump(tester);
    expect(find.text('Un utilisateur Yadony'), findsOneWidget);
    await tester.tap(choice());
    await tester.pumpAndSettle();
    expect(controller.username, 'awa.diallo');
    expect(find.text('@awa.diallo'), findsOneWidget);
    expect(find.text('En attente de confirmation'), findsOneWidget);
    expect(find.text('champs manuels'), findsNothing);
    // Nom et numéro sont ignorés à la soumission.
    expect(nameCtrl.text, isEmpty);
    expect(phoneCtrl.text, isEmpty);
  });

  testWidgets('feuille fermée sans choisir : rien ne change', (tester) async {
    await pump(tester, chosen: null);
    await tester.tap(choice());
    await tester.pumpAndSettle();
    expect(controller.username, isNull);
    expect(find.text('champs manuels'), findsOneWidget);
  });

  testWidgets('Changer revient à la saisie manuelle', (tester) async {
    await pump(tester);
    await tester.tap(choice());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Changer'));
    await tester.pumpAndSettle();
    expect(controller.username, isNull);
    expect(find.text('champs manuels'), findsOneWidget);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets('libellés sans débordement à 360 dp (${locale.languageCode})', (
      tester,
    ) async {
      await pump(tester, locale: locale);
      await tester.tap(choice());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final loc in const [AppL10n.fr, AppL10n.en]) {
    testWidgets(
      'libellé du choix Yadony sur une ligne à 360 dp (${loc.languageCode})',
      (tester) async {
        await pump(tester, locale: loc, chosen: null);
        final label = find.descendant(
          of: choice(),
          matching: find.byType(Text),
        );
        final text = tester.widget<Text>(label);
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
        // Une seule ligne : hauteur inférieure à deux lignes du style.
        final lineHeight = (text.style?.fontSize ?? 14) * 1.6;
        expect(tester.getSize(label).height, lessThan(lineHeight * 2));
      },
    );
  }
}
