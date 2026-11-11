import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_tax_info_entry.dart';
import 'package:dony/features/tax_info/bloc/tax_info_prompt_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_session.dart';
import 'package:dony/features/tax_info/bloc/tax_info_signal.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../tax_info/tax_info_targeted_fixtures.dart';
import '../../../tax_info/tax_info_test_helpers.dart';

class _MockRepo extends Mock implements TaxInfoRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _user = UserModel(
  id: 'u1',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

const _ask = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.solliciter,
);
const _done = TaxInfo(
  provided: true,
  solicitation: TaxInfoSolicitation.dejaFourni,
  maskedTaxIdentificationNumber: '****1234',
);
const _none = TaxInfo(
  provided: false,
  solicitation: TaxInfoSolicitation.nePasSolliciter,
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(() => repo.fetch()).thenAnswer((_) async => _ask);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<TaxInfoSession>(TaxInfoSession())
      ..registerFactoryParam<TaxInfoPromptCubit, String, void>(
        (userId, _) => TaxInfoPromptCubit(
          repo,
          analytics,
          getIt<TaxInfoSession>(),
          userId,
        ),
      );
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(
    WidgetTester tester, {
    UserModel? user = _user,
    Locale locale = AppL10n.fr,
  }) async {
    useNarrowScreen(tester);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('AVANT'),
                  ProfileTaxInfoEntry(user: user),
                  const Text('APRÈS'),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/tax-info',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: context.pop,
              child: const Text('ÉCRAN FISCAL'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder banner() => find.byKey(const Key('tax-info-banner'));
  Finder row() => find.byKey(const Key('profile-tax-info-row'));

  group('SOLLICITER : bannière', () {
    testWidgets('affichée, sans ligne, une seule lecture', (tester) async {
      await pump(tester);
      expect(banner(), findsOneWidget);
      expect(row(), findsNothing);
      expect(find.text(fr.taxInfoBannerBody), findsOneWidget);
      verify(() => repo.fetch()).called(1);
    });

    testWidgets('« Compléter » ouvre l\'écran et trace l\'appui', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('tax-info-banner-open')));
      await tester.pumpAndSettle();
      expect(find.text('ÉCRAN FISCAL'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          'profile_tax_info_tapped',
          properties: {'variant': 'banner'},
        ),
      ).called(1);
    });

    testWidgets('« Plus tard » la masque, sans rien envoyer, sans trou', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('tax-info-banner-later')));
      await tester.pumpAndSettle();
      expect(banner(), findsNothing);
      verifyNever(
        () => repo.save(
          taxIdentificationNumber: any(named: 'taxIdentificationNumber'),
          taxCountry: any(named: 'taxCountry'),
          vatNumber: any(named: 'vatNumber'),
        ),
      );
      // Rien ne la fait revenir pendant la session : reprise de l'app,
      // signal d'enregistrement, nouveau montage.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      notifyTaxInfoChanged();
      await tester.pumpAndSettle();
      expect(banner(), findsNothing);
      await pump(tester);
      expect(banner(), findsNothing);
    });

    testWidgets('en anglais, à 360 dp : libellés sur une ligne', (
      tester,
    ) async {
      await pump(tester, locale: AppL10n.en);
      expect(find.text(en.taxInfoBannerTitle), findsOneWidget);
      expectOneLineNotShrunk(
        tester,
        find.byKey(const Key('tax-info-banner-open')),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DEJA_FOURNI : ligne discrète', () {
    setUp(() => when(() => repo.fetch()).thenAnswer((_) async => _done));

    testWidgets('ligne seule, jamais de bannière, ouvre l\'écran', (
      tester,
    ) async {
      await pump(tester);
      expect(row(), findsOneWidget);
      expect(banner(), findsNothing);
      expect(find.text(fr.taxInfoRowLabel), findsOneWidget);
      await tester.tap(row());
      await tester.pumpAndSettle();
      expect(find.text('ÉCRAN FISCAL'), findsOneWidget);
      verify(
        () => analytics.logEvent(
          'profile_tax_info_tapped',
          properties: {'variant': 'row'},
        ),
      ).called(1);
    });
  });

  group('collecte ciblée (yadony-back #730)', () {
    testWidgets('INFO_REQUIRED demandé : bannière', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => kFranceDiditNifMissing);
      await pump(tester);
      expect(banner(), findsOneWidget);
      expect(row(), findsNothing);
    });

    testWidgets('INFO_REQUIRED pas encore demandé : ligne « À compléter »', (
      tester,
    ) async {
      when(() => repo.fetch()).thenAnswer((_) async => kAllMissing);
      await pump(tester);
      expect(banner(), findsNothing);
      expect(row(), findsOneWidget);
      expect(find.text(fr.taxInfoRowSubtitleToComplete), findsOneWidget);
    });

    testWidgets('COMPLETE : ligne « Voir ou modifier »', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => kComplete);
      await pump(tester);
      expect(row(), findsOneWidget);
      expect(find.text(fr.taxInfoRowSubtitle), findsOneWidget);
    });

    testWidgets('hors périmètre : aucune entrée visible', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => kOutOfScope);
      await pump(tester);
      expect(banner(), findsNothing);
      expect(row(), findsNothing);
      expect(find.text(fr.taxInfoRowLabel), findsNothing);
    });

    testWidgets('pays inconnu : bannière « pays seul », sans la '
        'notification', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => kResidence);
      await pump(tester);
      expect(banner(), findsOneWidget);
      expect(find.text(fr.taxInfoBannerResidenceBody), findsOneWidget);
      expect(find.text(fr.taxInfoBannerBody), findsNothing);
      await tester.tap(find.byKey(const Key('tax-info-banner-later')));
      await tester.pumpAndSettle();
      expect(banner(), findsNothing);
      expect(row(), findsOneWidget);
      expect(find.text(fr.taxInfoRowSubtitleToComplete), findsOneWidget);
    });

    testWidgets('onglet Profil ouvert : relecture, la bannière apparaît', (
      tester,
    ) async {
      when(() => repo.fetch()).thenAnswer((_) async => kOutOfScope);
      await pump(tester);
      expect(banner(), findsNothing);
      when(() => repo.fetch()).thenAnswer((_) async => kResidence);
      requestTaxInfoRefresh();
      await tester.pumpAndSettle();
      expect(banner(), findsOneWidget);
      verify(() => repo.fetch()).called(2);
    });

    testWidgets('relecture en échec : rien, aucune erreur', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => kResidence);
      await pump(tester);
      when(() => repo.fetch()).thenThrow(const TaxInfoException('network'));
      requestTaxInfoRefresh();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(banner(), findsOneWidget);
    });

    testWidgets('statut inconnu (futur) : ancien comportement, rien pour '
        'un voyageur non sollicité', (tester) async {
      when(() => repo.fetch()).thenAnswer(
        (_) async => TaxInfo.fromJson(const {
          'provided': false,
          'solicitation': 'NE_PAS_SOLLICITER',
          'collectionStatus': 'CLOSURE_PENDING',
          'actionRequired': true,
        }),
      );
      await pump(tester);
      expect(banner(), findsNothing);
      expect(row(), findsNothing);
    });

    testWidgets('en, à 360 dp : « To complete » sans exception', (
      tester,
    ) async {
      when(() => repo.fetch()).thenAnswer((_) async => kAllMissing);
      await pump(tester, locale: AppL10n.en);
      expect(find.text(en.taxInfoRowSubtitleToComplete), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('rien à demander : aucune trace', () {
    Future<void> expectNothing(WidgetTester tester) async {
      await pump(tester);
      expect(banner(), findsNothing);
      expect(row(), findsNothing);
      expect(find.text(fr.taxInfoBannerTitle), findsNothing);
      expect(tester.takeException(), isNull);
      // Aucun vide : « AVANT » et « APRÈS » sont contigus.
      final gap =
          tester.getTopLeft(find.text('APRÈS')).dy -
          tester.getBottomLeft(find.text('AVANT')).dy;
      expect(gap, lessThan(1));
    }

    testWidgets('NE_PAS_SOLLICITER', (tester) async {
      when(() => repo.fetch()).thenAnswer((_) async => _none);
      await expectNothing(tester);
    });

    for (final status in [404, 403, 401]) {
      testWidgets('$status (dac7-disabled, invité, session, ancien back)', (
        tester,
      ) async {
        when(
          () => repo.fetch(),
        ).thenThrow(TaxInfoUnavailableException(status: status));
        await expectNothing(tester);
      });
    }

    testWidgets('réseau en panne : rien, aucune erreur', (tester) async {
      when(() => repo.fetch()).thenThrow(const TaxInfoException('network'));
      await expectNothing(tester);
    });

    testWidgets(
      'expéditeur pur (rôle SENDER) : aucune lecture, rien d\'affiché',
      (tester) async {
        await pump(tester, user: _user.copyWith(roles: const ['SENDER']));
        expect(banner(), findsNothing);
        expect(row(), findsNothing);
        verifyNever(() => repo.fetch());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('pas d\'utilisateur : aucune lecture', (tester) async {
      await pump(tester, user: null);
      expect(banner(), findsNothing);
      verifyNever(() => repo.fetch());
    });

    testWidgets('cubit absent du graphe : rien', (tester) async {
      getIt.unregister<TaxInfoPromptCubit>();
      await pump(tester);
      expect(banner(), findsNothing);
      verifyNever(() => repo.fetch());
      expect(tester.takeException(), isNull);
    });
  });

  group('relecture', () {
    testWidgets('reprise de l\'app : une relecture', (tester) async {
      await pump(tester);
      verify(() => repo.fetch()).called(1);
      when(() => repo.fetch()).thenAnswer((_) async => _done);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      verify(() => repo.fetch()).called(1);
      expect(banner(), findsNothing);
      expect(row(), findsOneWidget);
    });

    testWidgets('informations enregistrées ailleurs : la bannière laisse '
        'place à la ligne', (tester) async {
      await pump(tester);
      expect(banner(), findsOneWidget);
      when(() => repo.fetch()).thenAnswer((_) async => _done);
      notifyTaxInfoChanged();
      await tester.pumpAndSettle();
      expect(banner(), findsNothing);
      expect(row(), findsOneWidget);
    });

    testWidgets('rafale de reprises pendant une lecture : coalescée', (
      tester,
    ) async {
      final gate = Completer<TaxInfo>();
      await pump(tester);
      clearInteractions(repo);
      when(() => repo.fetch()).thenAnswer((_) => gate.future);
      for (var i = 0; i < 5; i++) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        notifyTaxInfoChanged();
      }
      await tester.pump();
      verify(() => repo.fetch()).called(1);
      gate.complete(_ask);
      await tester.pumpAndSettle();
      // Un seul rejeu coalescé, pas dix.
      verify(() => repo.fetch()).called(1);
    });

    testWidgets('widget retiré : plus d\'écouteur, aucune exception', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      notifyTaxInfoChanged();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
