import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/username/username_cubit.dart';
import 'package:dony/features/profile/data/models/username_availability.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/profile/presentation/widgets/edit_username_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockRepo extends Mock implements ProfileRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  bool? result;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    result = null;
  });

  Future<void> open(WidgetTester tester, {Locale locale = AppL10n.fr}) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await EditUsernameSheet.show(
                  context,
                  createCubit: () => UsernameCubit(
                    repo,
                    analytics,
                    debounce: const Duration(milliseconds: 10),
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('ouvrir'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Finder field() => find.byKey(const Key('username-field'));
  Finder save() => find.byKey(const Key('username-save'));
  DonyButton saveButton(WidgetTester tester) =>
      tester.widget<DonyButton>(save());

  void stubTaken() {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => const UsernameAvailability(
        available: false,
        reason: UsernameReason.taken,
        suggestions: ['awa1', 'awa.d', 'awa_d'],
      ),
    );
  }

  testWidgets('affiche titre, aide, et le bouton est dans la barre fixe', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Mon identifiant'), findsOneWidget);
    expect(
      find.text(
        '3 à 20 caractères : minuscules, chiffres, point et tiret bas. '
        'Modifiable une fois tous les 30 jours.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: save(),
      ),
      findsOneWidget,
    );
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('texte de la maquette : intro, aide « Disponible »', (
    tester,
  ) async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UsernameAvailability(available: true));
    await open(tester);
    expect(
      find.text(
        'C\'est ce que les autres saisissent pour vous ajouter comme '
        'destinataire. Il ne montre ni votre nom ni votre numéro.',
      ),
      findsOneWidget,
    );
    await tester.enterText(field(), 'awa');
    await settle(tester);
    expect(
      find.text(
        '3 à 20 caractères : minuscules, chiffres, point et tiret bas. '
        'Votre identifiant actuel reste réservé 30 jours.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Modifiable une fois'), findsNothing);
  });

  testWidgets('trop tôt sans date lisible : phrase de repli', (tester) async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UsernameAvailability(available: true));
    when(() => repo.changeUsername(any())).thenThrow(
      const ConflictException(
        'x',
        code: 'username-change-too-soon',
        extensions: {'nextChangeAt': 'pas une date'},
      ),
    );
    await open(tester);
    await tester.enterText(field(), 'awa');
    await settle(tester);
    await tester.tap(save());
    await settle(tester);
    expect(
      find.text(
        'Vous avez déjà changé d\'identifiant récemment. Réessayez plus tard.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('possible le'), findsNothing);
  });

  testWidgets('identifiant pris : message et 3 puces, bouton désactivé', (
    tester,
  ) async {
    stubTaken();
    await open(tester);
    await tester.enterText(field(), 'awa');
    await settle(tester);
    expect(find.text('Cet identifiant est déjà pris.'), findsOneWidget);
    expect(find.text('Essayez plutôt'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(3));
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('toucher une puce remplit le champ, revérifie et active', (
    tester,
  ) async {
    stubTaken();
    await open(tester);
    await tester.enterText(field(), 'awa');
    await settle(tester);
    when(
      () => repo.checkUsername('awa1', cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UsernameAvailability(available: true));
    await tester.tap(find.widgetWithText(ActionChip, '@awa1'));
    await settle(tester);
    expect(find.text('Disponible'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'awa1');
  });

  testWidgets('disponible puis Enregistrer : ferme et rend true', (
    tester,
  ) async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UsernameAvailability(available: true));
    when(() => repo.changeUsername('awa.d')).thenAnswer(
      (_) async => const UserModel(
        id: 'u1',
        username: 'awa.d',
        roles: [],
        kycStatus: 'NOT_STARTED',
        status: 'ACTIVE',
      ),
    );
    await open(tester);
    await tester.enterText(field(), 'Awa.D');
    await settle(tester);
    await tester.tap(save());
    await settle(tester);
    verify(() => repo.changeUsername('awa.d')).called(1);
    expect(find.byType(DonyBottomSheetFooter), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('format invalide : astuce locale, aucune requête', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field(), 'ab');
    await settle(tester);
    verifyNever(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    );
    expect(
      find.text(
        'Utilisez 3 à 20 caractères : minuscules, chiffres, point et tiret '
        'bas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('route absente (404) : texte poli, Enregistrer désactivé', (
    tester,
  ) async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenThrow(const NotFoundException());
    await open(tester);
    await tester.enterText(field(), 'awa');
    await settle(tester);
    expect(find.text('Indisponible pour le moment'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('405 (prod) : texte poli, Enregistrer désactivé', (tester) async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenThrow(const NetworkException('x', code: '405'));
    await open(tester);
    await tester.enterText(field(), 'awa');
    await settle(tester);
    expect(find.text('Indisponible pour le moment'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets('360 dp ${locale.languageCode} : bouton sur une ligne', (
      tester,
    ) async {
      if (locale == AppL10n.en) enableEnglish();
      stubTaken();
      await open(tester, locale: locale);
      await tester.enterText(field(), 'awa');
      await settle(tester);
      expect(tester.takeException(), isNull);
      final label = locale == AppL10n.fr ? 'Enregistrer' : 'Save';
      final text = find.descendant(of: save(), matching: find.text(label));
      expect(text, findsOneWidget);
      final style = tester.widget<Text>(text).style;
      final box = tester.getSize(text);
      // Une ligne : hauteur proche de la hauteur de ligne du thème.
      expect(box.height, lessThan((style?.fontSize ?? 16) * 2));
      final scale = find.ancestor(of: text, matching: find.byType(FittedBox));
      for (final e in scale.evaluate()) {
        final fb = e.widget as FittedBox;
        final inner = tester.getSize(
          find.descendant(of: find.byWidget(fb), matching: find.byType(Text)),
        );
        final outer = tester.getSize(find.byWidget(fb));
        expect(inner.width, lessThanOrEqualTo(outer.width));
      }
    });
  }
}
