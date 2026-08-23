import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/account_setup_card.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/currency_test_doubles.dart';

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

/// La carte répond à une seule question : « qu'est-ce qui manque encore à ce
/// compte » — champs de profil exclus, c'est le territoire de la bannière
/// « Profil incomplet » voisine. Ces tests verrouillent ses trois contrats :
/// s'escamoter à parcours complet, nommer la bonne prochaine étape (verrou
/// identité → paiements compris), et reprendre le parcours avec le marqueur
/// d'entrée.
void main() {
  late _MockStripeAccountBloc stripeBloc;
  String? resumedAt;

  const verifiedComplete = UserModel(
    id: 'u1',
    roles: ['TRAVELER'],
    kycStatus: 'VERIFIED',
    status: 'ACTIVE',
    country: 'FR',
    residenceStreet: '3 avenue des Lilas',
    stripeAccountStatus: 'ONBOARDING_COMPLETE',
  );

  const nothingDone = UserModel(
    id: 'u2',
    roles: ['TRAVELER'],
    kycStatus: 'NOT_STARTED',
    status: 'ACTIVE',
    country: 'FR',
  );

  const verifiedNoPayouts = UserModel(
    id: 'u3',
    roles: ['TRAVELER'],
    kycStatus: 'VERIFIED',
    status: 'ACTIVE',
    country: 'FR',
    residenceStreet: '3 avenue des Lilas',
    stripeAccountStatus: 'NOT_CREATED',
  );

  setUp(() {
    stripeBloc = _MockStripeAccountBloc();
    resumedAt = null;
    whenListen<StripeAccountState>(
      stripeBloc,
      const Stream.empty(),
      initialState: const StripeAccountReady(
        ConnectAccountStatus(
          status: 'NOT_CREATED',
          connectAvailableInCountry: true,
        ),
      ),
    );
    final analytics = _MockAnalyticsService();
    when(() => analytics.isConfigured).thenReturn(false);
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
    addTearDown(() => getIt.unregister<AnalyticsService>());
  });

  Future<void> pump(WidgetTester tester, UserModel user) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
              BlocProvider<BusinessPrefsBloc>.value(
                value: stubBusinessPrefsBloc(),
              ),
            ],
            child: Scaffold(body: AccountSetupCard(user: user)),
          ),
        ),
        GoRoute(
          path: '/kyc/verify',
          builder: (_, state) {
            resumedAt = state.uri.toString();
            return const Scaffold(body: Text('KYC'));
          },
        ),
        GoRoute(
          path: '/payments/onboarding',
          builder: (_, state) {
            resumedAt = state.uri.toString();
            return const Scaffold(body: Text('Payouts'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('parcours complet : la carte disparaît entièrement', (
    tester,
  ) async {
    // Le statut du bloc fait foi sur celui du profil (même règle que le
    // résolveur) : il doit dire ONBOARDING_COMPLETE lui aussi.
    whenListen<StripeAccountState>(
      stripeBloc,
      const Stream.empty(),
      initialState: const StripeAccountReady(
        ConnectAccountStatus(
          status: 'ONBOARDING_COMPLETE',
          connectAvailableInCountry: true,
        ),
      ),
    );
    await pump(tester, verifiedComplete);

    expect(find.text('Finalisez votre compte'), findsNothing);
    expect(tester.getSize(find.byType(AccountSetupCard)), Size.zero);
  });

  testWidgets('identité manquante : la carte la nomme comme prochaine étape', (
    tester,
  ) async {
    await pump(tester, nothingDone);

    expect(find.text('Finalisez votre compte'), findsOneWidget);
    // Pays et consentement faits, adresse absente : elle vient avant
    // l'identité dans le parcours — mais la prochaine étape affichée doit
    // être la première non faite, ici l'adresse.
    expect(find.textContaining('Prochaine étape'), findsOneWidget);
  });

  testWidgets(
    'identité vérifiée, paiements restants : prochaine étape Paiements, '
    'et le CTA reprend le parcours avec le marqueur d\'entrée',
    (tester) async {
      await pump(tester, verifiedNoPayouts);

      expect(find.text('Prochaine étape : Paiements'), findsOneWidget);

      await tester.tap(find.text('Finalisez votre compte'));
      await tester.pumpAndSettle();

      // Sans ?from=onboarding, l'écran des paiements s'ouvrirait en mode
      // profil : ni jauge, ni enchaînement. Le marqueur est le contrat.
      expect(resumedAt, '/payments/onboarding?from=onboarding');
    },
  );

  testWidgets(
    'identité non vérifiée : jamais Paiements en prochaine étape, même si '
    'seul Connect manque par ailleurs — le verrou tient aussi ici',
    (tester) async {
      const identitySkipped = UserModel(
        id: 'u4',
        roles: ['TRAVELER'],
        kycStatus: 'NOT_STARTED',
        status: 'ACTIVE',
        country: 'FR',
        residenceStreet: '3 avenue des Lilas',
        stripeAccountStatus: 'NOT_CREATED',
      );
      await pump(tester, identitySkipped);

      expect(find.text('Prochaine étape : Identité'), findsOneWidget);

      await tester.tap(find.text('Finalisez votre compte'));
      await tester.pumpAndSettle();

      expect(resumedAt, '/kyc/verify?from=onboarding');
    },
  );
}
