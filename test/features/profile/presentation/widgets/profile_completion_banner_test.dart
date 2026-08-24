import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _empty = UserModel(
  id: 'u1',
  roles: [],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

/// La bannière compte deux étapes de compte en plus des champs de profil :
/// l'identité (toujours) et les paiements (là où Stripe couvre le pays). Le
/// total de référence de ces tests est donc **7 champs + identité +
/// paiements = 9**. La date de naissance n'en fait plus partie : Stripe la
/// demande dans son propre formulaire, l'application ne la stocke plus.
Widget _app(
  UserModel user, {
  VoidCallback? onTap,
  String stripeStatus = 'NOT_CREATED',
  bool connectAvailable = true,
}) {
  final bloc = _MockStripeAccountBloc();
  whenListen<StripeAccountState>(
    bloc,
    const Stream.empty(),
    initialState: StripeAccountReady(
      ConnectAccountStatus(
        status: stripeStatus,
        connectAvailableInCountry: connectAvailable,
      ),
    ),
  );
  _pushedRoute = null;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<StripeAccountBloc>.value(
          value: bloc,
          child: Scaffold(
            body: ProfileCompletionBanner(user: user, onTap: onTap ?? () {}),
          ),
        ),
      ),
      GoRoute(
        path: '/kyc/verify',
        builder: (_, state) {
          _pushedRoute = state.uri.path;
          return const Scaffold(body: Text('KYC'));
        },
      ),
      GoRoute(
        path: '/payments/onboarding',
        builder: (_, state) {
          _pushedRoute = state.uri.path;
          return const Scaffold(body: Text('Payouts'));
        },
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// Dernière route atteinte par une case cliquable.
String? _pushedRoute;

/// Couleur de percent-text/icônes affichée pour un [user] donné — lit
/// directement le thème résolu au lieu de dupliquer la logique de palier
/// (`profileCompletionTierColor`) dans le test.
Color _renderedTierColor(WidgetTester tester) {
  final context = tester.element(find.byType(ProfileCompletionBanner));
  final cs = Theme.of(context).colorScheme;
  final pctText = tester.widget<Text>(find.textContaining('% complété'));
  final color = pctText.style!.color!;
  // Egalité de couleur exacte : le tier retourne toujours l'une de ces 3
  // constantes du thème, jamais une teinte interpolée.
  if (color == cs.error) return cs.error;
  if (color == cs.warning) return cs.warning;
  return cs.info;
}

/// Les 7 champs de profil renseignés.
final _allProfileFields = _empty.copyWith(
  avatarUrl: 'https://cdn.example.com/avatar.jpg',
  firstName: 'Amadou',
  lastName: 'Diallo',
  email: 'amadou@example.com',
  phoneNumber: '+221701234567',
  city: 'Dakar',
  bio: 'Voyageur régulier.',
);

void main() {
  // Le SMS OTP backend confirmé est l'état par défaut de ces tests (7
  // champs, téléphone inclus) : le groupe dédié plus bas couvre le cas
  // désactivé (6 champs) séparément.
  setUp(() => setSmsAuthEnabled(true));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets('0/9 → 0 %, les 7 champs plus la case identité sont affichés', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_empty));
    await tester.pump();

    expect(find.text('0% complété · Compléter maintenant'), findsOneWidget);
    expect(find.text('Vérifier mon identité'), findsOneWidget);
    // Les paiements ne sont jamais proposés avant l'identité : Stripe les
    // refuserait (422 `kyc-required`).
    expect(find.text('Activer les paiements'), findsNothing);
    for (final label in const [
      'Photo',
      'Prénom',
      'Nom',
      'Email',
      'Téléphone',
      'Ville',
      'À propos',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('7/9 : profil rempli mais identité manquante → 78 %, la '
      'bannière reste et réclame l\'identité', (tester) async {
    await tester.pumpWidget(_app(_allProfileFields));
    await tester.pump();

    expect(find.text('78% complété · Compléter maintenant'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Vérifier mon identité'), findsOneWidget);
  });

  testWidgets('8/9 : identité vérifiée → les paiements prennent le relais', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_allProfileFields.copyWith(kycStatus: 'VERIFIED')),
    );
    await tester.pump();

    expect(find.text('89% complété · Compléter maintenant'), findsOneWidget);
    expect(find.text('Vérifier mon identité'), findsNothing);
    expect(find.text('Activer les paiements'), findsOneWidget);
  });

  testWidgets('9/9 : tout est fait → la bannière disparaît entièrement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _allProfileFields.copyWith(kycStatus: 'VERIFIED'),
        stripeStatus: 'ONBOARDING_COMPLETE',
      ),
    );
    await tester.pump();

    expect(find.textContaining('% complété'), findsNothing);
    expect(tester.getSize(find.byType(ProfileCompletionBanner)), Size.zero);
  });

  testWidgets('pays hors couverture Stripe : 8 étapes, pas 9 — les '
      'paiements ne sont jamais réclamés', (tester) async {
    await tester.pumpWidget(
      _app(
        _allProfileFields.copyWith(kycStatus: 'VERIFIED'),
        connectAvailable: false,
      ),
    );
    await tester.pump();

    // 8 sur 8 : la bannière s'efface sans jamais avoir parlé de paiements.
    expect(find.textContaining('% complété'), findsNothing);
  });

  testWidgets('tap sur l\'en-tête déclenche le callback onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_app(_empty, onTap: () => tapped = true));
    await tester.tap(find.text('Complétez votre compte'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('la case identité mène à la vérification, pas à l\'édition du '
      'profil', (tester) async {
    // Régression constatée sur device : un GestureDetector autour de la carte
    // entière gagnait l'arène de gestes contre les cases, et « Vérifier mon
    // identité » ouvrait l'édition du profil.
    var editTapped = false;
    await tester.pumpWidget(_app(_empty, onTap: () => editTapped = true));
    await tester.pump();

    await tester.tap(find.text('Vérifier mon identité'));
    await tester.pumpAndSettle();

    expect(editTapped, isFalse, reason: 'la carte a vole le tap');
    expect(_pushedRoute, '/kyc/verify');
  });

  testWidgets('une case de champ de profil mène bien à l\'édition', (
    tester,
  ) async {
    var editTapped = false;
    await tester.pumpWidget(_app(_empty, onTap: () => editTapped = true));
    await tester.pump();

    await tester.tap(find.text('Photo'));
    await tester.pump();

    expect(editTapped, isTrue);
  });

  group('palier de couleur selon le pourcentage', () {
    testWidgets('0/9 (0 %, < 1/3) → rouge (cs.error)', (tester) async {
      await tester.pumpWidget(_app(_empty));
      await tester.pump();

      final context = tester.element(find.byType(ProfileCompletionBanner));
      final cs = Theme.of(context).colorScheme;
      expect(_renderedTierColor(tester), cs.error);
    });

    testWidgets('4/9 (44 %, entre 1/3 et 2/3) → orange (cs.warning)', (
      tester,
    ) async {
      final user = _empty.copyWith(
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'amadou@example.com',
        city: 'Dakar',
      );
      await tester.pumpWidget(_app(user));
      await tester.pump();

      final context = tester.element(find.byType(ProfileCompletionBanner));
      final cs = Theme.of(context).colorScheme;
      expect(find.text('44% complété · Compléter maintenant'), findsOneWidget);
      expect(_renderedTierColor(tester), cs.warning);
    });

    testWidgets('7/9 (78 %, >= 2/3) → bleu (cs.info)', (tester) async {
      final user = _empty.copyWith(
        avatarUrl: 'https://cdn.example.com/avatar.jpg',
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'amadou@example.com',
        phoneNumber: '+221701234567',
        city: 'Dakar',
        bio: 'Voyageur régulier.',
      );
      await tester.pumpWidget(_app(user));
      await tester.pump();

      final context = tester.element(find.byType(ProfileCompletionBanner));
      final cs = Theme.of(context).colorScheme;
      expect(find.text('78% complété · Compléter maintenant'), findsOneWidget);
      expect(_renderedTierColor(tester), cs.info);
    });
  });

  group('SMS OTP backend non confirmé (kSmsAuthEnabledDefault)', () {
    setUp(() => setSmsAuthEnabled(false));

    testWidgets(
      '0/6 champs → 0 %, la croix Téléphone est absente (rien à réclamer)',
      (tester) async {
        await tester.pumpWidget(_app(_empty));
        await tester.pump();

        expect(find.text('0% complété · Compléter maintenant'), findsOneWidget);
        expect(find.text('Téléphone'), findsNothing);
        for (final label in const [
          'Photo',
          'Prénom',
          'Nom',
          'Email',
          'Ville',
          'À propos',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
      },
    );

    testWidgets(
      '6 champs sur 6 (sans téléphone) mais identité et paiements à faire → '
      'la bannière reste : `isProfileComplete` ne connaît pas ces étapes',
      (tester) async {
        final user = _empty.copyWith(
          avatarUrl: 'https://cdn.example.com/avatar.jpg',
          firstName: 'Amadou',
          lastName: 'Diallo',
          email: 'amadou@example.com',
          city: 'Dakar',
          bio: 'Voyageur régulier.',
        );
        await tester.pumpWidget(_app(user));
        await tester.pump();

        expect(user.phoneNumber, isNull);
        expect(user.isProfileComplete(countPhone: false), isTrue);
        // 6 champs sur 6 + identité + paiements = 6 sur 8.
        expect(
          find.text('75% complété · Compléter maintenant'),
          findsOneWidget,
        );
        expect(find.text('Vérifier mon identité'), findsOneWidget);
      },
    );
  });
}
