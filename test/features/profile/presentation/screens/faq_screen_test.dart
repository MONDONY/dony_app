import 'package:dony/core/config/cancellation_fee_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_config/cancellation_fee_config_cubit.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/commission_grid_test_doubles.dart';
import '../../../../helpers/currency_test_doubles.dart';
import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/support_contact_test_helpers.dart';
import '../../../cancellation/cancellation_fee_test_support.dart';

const _emptyConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _hubConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [
    {
      "network": "whatsapp",
      "url": "https://community.example/whatsapp",
      "active": true
    }
  ],
  "tutorials": [
    {
      "id": "payment",
      "title": "Accepter une offre et payer",
      "description": "Sécuriser le règlement dans Yadony.",
      "youtubeVideoId": "M7lc1UVf-VE",
      "order": 2,
      "active": true,
      "contexts": ["payment"]
    },
    {
      "id": "search_intro",
      "title": "Découvrir Yadony",
      "description": "Comprendre la recherche en quelques minutes.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"],
      "durationLabel": "2:30"
    }
  ]
}
''';

Widget _wrap({
  String configJson = _emptyConfigJson,
  AnalyticsService? analytics,
  MockAnalyticsBackend? backend,
  TextScaler textScaler = TextScaler.noScaling,
  bool failRefresh = false,
}) {
  final effectiveAnalytics =
      analytics ?? makeDisabledAnalytics(backend ?? MockAnalyticsBackend());
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => FaqBloc(effectiveAnalytics)),
      BlocProvider(
        create: (_) => HelpCenterBloc(
          HelpCenterRepository(
            _StaticHelpCenterSource(configJson, failRefresh: failRefresh),
            fallbackJsonLoader: () async => _emptyConfigJson,
          ),
          effectiveAnalytics,
        )..add(const HelpCenterLoadRequested()),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FaqScreen()),
          GoRoute(
            path: '/support',
            builder: (_, _) => const Scaffold(body: Text('SupportContactStub')),
          ),
          GoRoute(
            path: '/profile/help/tutorial/:tutorialId',
            builder: (_, state) => Scaffold(
              body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUp(registerSupportContactCubit);
  tearDown(() => setDonyReimbursementCap(kDonyReimbursementCapDefault));

  testWidgets('carte WhatsApp en tête, avant la recherche et les questions', (
    tester,
  ) async {
    registerSupportContactCubit(number: '+33612345678');
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Besoin d\'un humain ?'), findsOneWidget);
    final whatsapp = tester.getTopLeft(find.text('Écrire sur WhatsApp'));
    final search = tester.getTopLeft(find.byKey(const Key('faq-search-field')));
    final section = tester.getTopLeft(find.text('Compte & identité'));
    expect(whatsapp.dy, lessThan(search.dy));
    expect(whatsapp.dy, lessThan(section.dy));
  });

  testWidgets('sans numéro réglé : pas de carte WhatsApp dans le FAQ', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Écrire sur WhatsApp'), findsNothing);
  });

  testWidgets('renders title and all section headers', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('FAQ & aide'), findsOneWidget);
    expect(find.text('Compte & identité'), findsOneWidget);
    expect(find.text('Annonces & demandes'), findsOneWidget);
    expect(find.text('Paiements & remboursements'), findsOneWidget);
    expect(find.text('Suivi & livraison'), findsOneWidget);
    expect(find.text('Sécurité & données'), findsOneWidget);
  });

  testWidgets('first section questions are visible as collapsed items', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Pourquoi la vérification d\'identité est-elle obligatoire ?'),
      findsOneWidget,
    );
  });

  testWidgets('tapping on a question expands its answer', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final question = find.text(
      'Pourquoi la vérification d\'identité est-elle obligatoire ?',
    );
    expect(question, findsOneWidget);

    await tester.tap(question);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('lutter contre la fraude'), findsOneWidget);
  });

  testWidgets('subtitle is rendered', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Recherchez une réponse ou parcourez les catégories.'),
      findsOneWidget,
    );
  });

  testWidgets('rebuilds a visible reimbursement answer when the cap changes', (
    tester,
  ) async {
    setDonyReimbursementCap(50);
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final question = find.text('Que se passe-t-il si mon colis est perdu ?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('jusqu\'à 50 €'), findsOneWidget);

    setDonyReimbursementCap(75);
    await tester.pump();

    expect(find.textContaining('jusqu\'à 75 €'), findsOneWidget);
    expect(find.textContaining('jusqu\'à 50 €'), findsNothing);
  });

  testWidgets('filters questions and answers from the search field', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byKey(const Key('faq-search-field')),
      'remboursement',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Comment se passe le remboursement en cas d\'annulation ?'),
      findsOneWidget,
    );
    expect(
      find.text('Pourquoi la vérification d\'identité est-elle obligatoire ?'),
      findsNothing,
    );
  });

  testWidgets(
    'search ignores accents and restores all categories when cleared',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 600));

      final searchField = find.byKey(const Key('faq-search-field'));
      await tester.enterText(searchField, 'identite');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Pourquoi la vérification d\'identité est-elle obligatoire ?',
        ),
        findsOneWidget,
      );
      expect(find.text('Paiements & remboursements'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Compte & identité'), findsOneWidget);
      expect(find.text('Paiements & remboursements'), findsOneWidget);
      expect(find.text('Sécurité & données'), findsOneWidget);
    },
  );

  // FLUTTER-R6 : la question ne cite plus le taux de commission.
  testWidgets('question commission sans taux', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byKey(const Key('faq-search-field')),
      'frais de service',
    );
    await tester.pumpAndSettle();

    expect(find.text('Pourquoi des frais de service ?'), findsOneWidget);
    expect(find.textContaining('% ?'), findsNothing);
  });

  group('réponse sur les frais de service', () {
    Future<void> openCommissionAnswer(WidgetTester tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 600));
      final question = find.text('Pourquoi des frais de service ?');
      await tester.ensureVisible(question);
      await tester.tap(question);
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('sous grille, la réponse dit qui paie, sans minimum', (
      tester,
    ) async {
      useTestCommissionGrid();
      registerCurrencyPreference('XOF');
      await openCommissionAnswer(tester);

      expect(
        find.text(
          'Les frais de service couvrent les frais de paiement, le support, '
          'la prévention de la fraude et le développement de la plateforme. '
          'Ils dépendent du prix du transport et sont payés par l\'expéditeur. '
          'En espèces, le voyageur les avance sur son solde Yadony et '
          'l\'expéditeur les lui rembourse dans le paiement. Le montant exact '
          'est affiché avant de confirmer.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('minimum'), findsNothing);
      expect(find.textContaining('650'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('sans grille, réponse actuelle', (tester) async {
      await openCommissionAnswer(tester);

      expect(
        find.text(
          'Les frais de service couvrent les frais de paiement, le support, la '
          'prévention de la fraude et le développement de la plateforme.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('minimum de'), findsNothing);
    });
  });

  // I : réponse sur le remboursement. Frais d'annulation allumés : elle dit
  // aussi qu'un colis accepté puis annulé peut porter des frais. Éteints, back
  // antérieur ou configuration pas encore lue : la réponse d'aujourd'hui.
  group('réponse sur le remboursement selon les frais d\'annulation', () {
    tearDown(() async {
      resetCancellationFeeFlagForTest();
      await getIt.reset();
    });

    for (final english in [false, true]) {
      final l = lookupAppLocalizations(english ? AppL10n.en : AppL10n.fr);
      final lang = english ? 'en' : 'fr';

      Future<void> openRefundAnswer(WidgetTester tester) async {
        if (english) {
          enableEnglish();
          useEnglish();
        }
        await tester.pumpWidget(_wrap());
        await tester.pump(const Duration(milliseconds: 600));
        final question = find.text(l.faqPaymentsRefundQ);
        await tester.ensureVisible(question);
        await tester.tap(question);
        await tester.pump(const Duration(milliseconds: 500));
      }

      testWidgets('[$lang] frais éteints : réponse d\'aujourd\'hui', (
        tester,
      ) async {
        await openRefundAnswer(tester);
        expect(find.text(l.faqPaymentsRefundA), findsOneWidget);
        expect(find.text(l.faqPaymentsRefundAWithFee), findsNothing);
      });

      testWidgets('[$lang] frais allumés : la réponse ajoute les frais', (
        tester,
      ) async {
        setCancellationFeeActive(true);
        await openRefundAnswer(tester);
        expect(find.text(l.faqPaymentsRefundAWithFee), findsOneWidget);
        expect(find.text(l.faqPaymentsRefundA), findsNothing);
      });

      testWidgets('[$lang] configuration arrivée après l\'ouverture : la '
          'réponse bascule', (tester) async {
        await openRefundAnswer(tester);
        expect(find.text(l.faqPaymentsRefundA), findsOneWidget);

        setCancellationFeeActive(true);
        await tester.pump();

        expect(find.text(l.faqPaymentsRefundAWithFee), findsOneWidget);
      });
    }

    testWidgets('ouverture du Centre d\'aide : la configuration est lue', (
      tester,
    ) async {
      final repository = MockFeeConfigRepository();
      when(repository.getFeeConfig).thenAnswer((_) async => kActiveFeeConfig);
      final cubit = CancellationFeeConfigCubit(
        repository,
        MockFeeConfigAnalytics(),
      );
      getIt.registerSingleton<CancellationFeeConfigCubit>(cubit);
      addTearDown(cubit.close);

      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 600));

      verify(repository.getFeeConfig).called(1);
      expect(cancellationFeeActive, isTrue);
    });

    testWidgets('back antérieur (404) : réponse d\'aujourd\'hui', (
      tester,
    ) async {
      final l = lookupAppLocalizations(AppL10n.fr);
      await registerFeeConfig();
      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 600));
      final question = find.text(l.faqPaymentsRefundQ);
      await tester.ensureVisible(question);
      await tester.tap(question);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l.faqPaymentsRefundA), findsOneWidget);
    });
  });

  testWidgets('shows an empty state for a search without result', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byKey(const Key('faq-search-field')),
      'question inexistante xyz',
    );
    await tester.pump();

    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(
      find.text('Essayez avec d\'autres mots-clés ou contactez notre équipe.'),
      findsOneWidget,
    );
  });

  testWidgets('opens support from the contact card', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    final contact = find.text('Contacter le support');
    await tester.ensureVisible(contact);
    await tester.tap(contact);
    await tester.pumpAndSettle();

    expect(find.text('SupportContactStub'), findsOneWidget);
  });

  testWidgets(
    'ne montre jamais tutoriels ni communauté (déplacés vers Réseaux sociaux et tutoriels)',
    (tester) async {
      await tester.pumpWidget(_wrap(configJson: _hubConfigJson));
      await tester.pumpAndSettle();

      expect(find.text('Trouver une réponse'), findsOneWidget);
      expect(find.text('Tutoriels vidéo'), findsNothing);
      expect(find.text('Rejoindre la communauté'), findsNothing);
    },
  );

  testWidgets(
    'anglais : titre, section et question traduits, id inchangés pour '
    "l'analytics",
    (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('FAQ & help'), findsOneWidget);
      expect(find.text('Account & identity'), findsOneWidget);
      expect(
        find.text('Why is identity verification required?'),
        findsOneWidget,
      );
      expect(find.text('Find an answer'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
    },
  );

  testWidgets('reste sans overflow avec un facteur de texte 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

final class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json, {this.failRefresh = false});

  final String json;
  final bool failRefresh;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => failRefresh ? null : json;
}
