import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/referral/presentation/widgets/redeem_code_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockReferralRepository extends Mock implements ReferralRepository {}

const _fakeInfo = ReferralInfo(
  code: 'TEST0001',
  shareUrl: 'https://dony.app/r/TEST0001',
  totalInvited: 0,
  signedUp: 0,
  rewarded: 0,
  hasBeenReferred: false,
  activeVoucherCount: 0,
  voucherFactor: 0.5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockReferralRepository mockRepo;
  late MockAnalyticsBackend analyticsBackend;

  setUp(() {
    mockRepo = _MockReferralRepository();
    analyticsBackend = MockAnalyticsBackend();
    when(() => mockRepo.getMyReferral()).thenAnswer((_) async => _fakeInfo);

    if (getIt.isRegistered<ReferralRepository>()) {
      getIt.unregister<ReferralRepository>();
    }
    getIt.registerSingleton<ReferralRepository>(mockRepo);

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(analyticsBackend),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<ReferralRepository>()) {
      getIt.unregister<ReferralRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Widget testApp() => MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () => RedeemCodeBottomSheet.show(ctx),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  // ── 1. Affichage ─────────────────────────────────────────────────────────────

  testWidgets('affiche titre et champ de saisie à l\'ouverture', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Entrer un code parrain'), findsOneWidget);
    expect(find.text('Code parrain'), findsOneWidget);
    expect(find.text('Appliquer'), findsOneWidget);
  });

  testWidgets('affiche le texte d\'aide parrain', (tester) async {
    await openSheet(tester);

    expect(find.textContaining('invité par un ami'), findsOneWidget);
  });

  // ── 2. Validation du bouton ───────────────────────────────────────────────────

  testWidgets('bouton désactivé quand le champ est vide — aucun appel repo', (
    tester,
  ) async {
    await openSheet(tester);

    // Tapper "Appliquer" sans rien saisir ne doit pas déclencher redeemCode
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.redeemCode(any()));
    // La sheet est encore ouverte
    expect(find.text('Entrer un code parrain'), findsOneWidget);
  });

  testWidgets('bouton activé après saisie d\'un code', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'JEAN1234');
    await tester.pump();

    // Après saisie, le tap doit atteindre le repo (même si la suite échoue)
    when(() => mockRepo.redeemCode(any())).thenAnswer((_) async {});
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.redeemCode(any())).called(1);
  });

  // ── 3. Conversion en majuscules ──────────────────────────────────────────────

  testWidgets('le code est envoyé en majuscules même si saisi en minuscules', (
    tester,
  ) async {
    when(() => mockRepo.redeemCode(any())).thenAnswer((_) async {});

    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'jean1234');
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.redeemCode('JEAN1234')).called(1);
  });

  // ── 4. Succès ────────────────────────────────────────────────────────────────

  testWidgets('succès : la sheet se ferme quand redeemCode réussit', (
    tester,
  ) async {
    when(() => mockRepo.redeemCode(any())).thenAnswer((_) async {});

    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'VALID42');
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    // Sheet fermée — le titre ne doit plus être visible
    expect(find.text('Entrer un code parrain'), findsNothing);
    // Vérifier que le code correct a été soumis
    verify(() => mockRepo.redeemCode('VALID42')).called(1);
  });

  // ── 5. Erreur ────────────────────────────────────────────────────────────────

  testWidgets('erreur : la sheet reste ouverte si redeemCode échoue', (
    tester,
  ) async {
    when(
      () => mockRepo.redeemCode(any()),
    ).thenThrow(Exception('already-referred'));

    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'USEDCODE');
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    // La sheet reste ouverte (pas de ReferralRedeemed émis)
    expect(find.text('Entrer un code parrain'), findsOneWidget);
    verify(() => mockRepo.redeemCode('USEDCODE')).called(1);
  });

  testWidgets('erreur : redeemCode appelé une seule fois par tap', (
    tester,
  ) async {
    when(
      () => mockRepo.redeemCode(any()),
    ).thenThrow(Exception('network error'));

    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'CODE99');
    await tester.pump();

    // Un seul tap
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.redeemCode('CODE99')).called(1);
  });

  // ── 6. Champ vide après effacement ───────────────────────────────────────────

  testWidgets('effacer le champ redésactive le bouton', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'JEAN1234');
    await tester.pump();
    // Effacer le champ
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // Tapper ne doit pas appeler redeemCode
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.redeemCode(any()));
  });
}
