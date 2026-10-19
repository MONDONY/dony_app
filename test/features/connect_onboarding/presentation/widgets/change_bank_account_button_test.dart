import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/change_bank_account_button.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/recording_url_launcher.dart';

class _MockRepo extends Mock implements IConnectOnboardingRepository {}

const _url = 'https://connect.stripe.com/express/abc';

void main() {
  late _MockRepo repo;
  late List<String> pushed;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    pushed = [];
  });

  Widget host({VoidCallback? onOnboardingRequired}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: ChangeBankAccountButton(
                source: BankAccountLinkSource.payoutsScreen,
                onOnboardingRequired: onOnboardingRequired,
                createCubit: () => BankAccountLinkCubit(
                  repo,
                  makeEnabledAnalytics(MockAnalyticsBackend()),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: kPayoutsRoute,
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Scaffold(body: Text('payouts'));
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light(),
      locale: AppL10n.fr,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  Future<void> tapButton(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('change-bank-account')));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('bouton visible ; chargement pendant l\'appel ; lien ouvert '
      'dans le navigateur du système', (tester) async {
    final launcher = RecordingUrlLauncher();
    installUrlLauncher(launcher, addTearDown);
    final completer = Completer<String>();
    when(repo.createDashboardLink).thenAnswer((_) => completer.future);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Changer de compte bancaire'), findsOneWidget);

    await tester.tap(find.byKey(const Key('change-bank-account')));
    await tester.pump();
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('change-bank-account')),
    );
    expect(button.isLoading, isTrue);
    expect(button.onPressed, isNull);

    completer.complete(_url);
    await tester.pumpAndSettle();
    expect(launcher.urls, [_url]);
    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
    expect(
      tester
          .widget<DonyButton>(find.byKey(const Key('change-bank-account')))
          .isLoading,
      isFalse,
    );
  });

  testWidgets('navigateur introuvable : message', (tester) async {
    installUrlLauncher(RecordingUrlLauncher(result: false), addTearDown);
    when(repo.createDashboardLink).thenAnswer((_) async => _url);
    await tester.pumpWidget(host());
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Impossible d\'ouvrir'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('lanceur en erreur : message, pas de crash', (tester) async {
    installUrlLauncher(RecordingUrlLauncher(throws: true), addTearDown);
    when(repo.createDashboardLink).thenAnswer((_) async => _url);
    await tester.pumpWidget(host());
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Impossible d\'ouvrir'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('404 compte absent : message clair', (tester) async {
    when(
      repo.createDashboardLink,
    ).thenThrow(const NotFoundException(apiCode: 'stripe-account-missing'));
    await tester.pumpWidget(host());
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Aucun compte de paiement n\'est relié'),
      findsOneWidget,
    );
    expect(pushed, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ancien back : disponible bientôt', (tester) async {
    when(repo.createDashboardLink).thenThrow(const NotFoundException());
    await tester.pumpWidget(host());
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('disponible bientôt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('409 sans rappel : ouvre « Recevoir mes paiements »', (
    tester,
  ) async {
    when(repo.createDashboardLink).thenThrow(
      const ConflictException('x', code: 'stripe-onboarding-incomplete'),
    );
    await tester.pumpWidget(host());
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(pushed, [kPayoutsRoute]);
    expect(find.text('payouts'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('409 avec rappel : rappel appelé, pas de navigation', (
    tester,
  ) async {
    var called = 0;
    when(repo.createDashboardLink).thenThrow(
      const ConflictException('x', code: 'stripe-onboarding-incomplete'),
    );
    await tester.pumpWidget(host(onOnboardingRequired: () => called++));
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(called, 1);
    expect(pushed, isEmpty);
    expect(find.textContaining('Terminez d\'abord'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('erreur réseau : message du catalogue, bouton réactivé', (
    tester,
  ) async {
    when(repo.createDashboardLink).thenThrow(const OfflineException());
    await tester.pumpWidget(host());
    await tapButton(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Vérifiez votre connexion'), findsOneWidget);
    expect(
      tester
          .widget<DonyButton>(find.byKey(const Key('change-bank-account')))
          .onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 5));
  });
}
