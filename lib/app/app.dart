import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dony/app/announcement_deep_link.dart';
import 'package:dony/app/reduced_motion_priming.dart';
import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/analytics_consent_gate.dart';
import 'package:dony/features/auth/account_reset_guard.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/auth/guest_access_guard.dart';
import 'package:dony/features/connectivity/bloc/connectivity_cubit.dart';
import 'package:dony/features/connectivity/presentation/widgets/connectivity_banner.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/favorites_migration.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/notifications/notification_route_resolver.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class DonyApp extends StatefulWidget {
  const DonyApp({super.key});

  @override
  State<DonyApp> createState() => _DonyAppState();
}

class _DonyAppState extends State<DonyApp> {
  StreamSubscription<String>? _navSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<Uri>? _deepLinkSub;
  AppLifecycleListener? _lifecycleListener;
  final _appLinks = AppLinks();

  /// Le premier verdict de `AuthCheckRequested` a été traité. Le garde-fou
  /// « compte absent côté backend » ne doit jouer qu'à ce moment-là, pas sur
  /// les `AuthInitial` ultérieurs (déconnexion volontaire, changement de
  /// compte) qui ont déjà leur propre navigation.
  bool _startupAuthResolved = false;

  // go() est nécessaire pour activer le bon onglet du shell principal.
  // Toutes les autres routes utilisent push() pour empiler par-dessus l'état
  // courant et permettre au bouton retour de revenir à l'écran précédent.
  void _navigateToRoute(String route) {
    if (isShellTabRoute(route)) {
      appRouter.go(route);
    } else {
      appRouter.push(route);
    }
  }

  @override
  void initState() {
    super.initState();
    _navSub = getIt<NotificationService>().navigationStream.listen((route) {
      _navigateToRoute(route);
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      // `!user.isAnonymous` : l'ouverture d'une session visiteur déclenche
      // aussi cet événement, et un visiteur n'a pas de compte serveur où
      // enregistrer un jeton FCM.
      if (user != null && !user.isAnonymous) {
        unawaited(getIt<NotificationService>().requestPermission());
        getIt<NotificationService>().uploadCurrentToken();
      }
    });
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        unawaited(getIt<NotificationService>().onAppResumed());
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Le splash natif était maintenu depuis `_bootstrap` : on le retire dès
      // que le premier écran réel est peint. C'est le seul splash de l'app.
      FlutterNativeSplash.remove();
      _initDeepLinks();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // À froid, avant le premier `build` : voir la doc de
    // [primeReducedMotionDuration]. `MediaQuery` n'est pas encore fiable
    // dans `initState`, mais l'est ici — c'est ce que `build` exploite déjà
    // plus bas via `MediaQuery.disableAnimationsOf(context)`. Peut être
    // rappelée à chaque nouvelle dépendance héritée (ex. clavier), sans
    // conséquence : voir la doc de la fonction.
    primeReducedMotionDuration(
      getIt<AccessibilityBloc>().state,
      systemReducesMotion: MediaQuery.disableAnimationsOf(context),
    );
  }

  void _initDeepLinks() {
    // Handle cold-start URI (app was terminated)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
    // Handle warm/hot start URIs
    _deepLinkSub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (Object error, StackTrace stack) {
        // On log dans Sentry sans laisser l'erreur tuer l'abonnement (sinon
        // les deep links suivants ne seraient plus reçus).
        unawaited(
          getIt<ErrorReportingService>().report(
            error,
            operation: 'navigation.deep_link_stream',
            stackTrace: stack,
            context: {'feature': 'navigation'},
          ),
        );
      },
    );
  }

  // Allowlist par égalité stricte des chemins FIXES atteignables via yadony://.
  // Empêche un lien forgé (ex. yadony://admin/…) d'atteindre un écran non prévu.
  //
  // Ce n'est plus la seule porte du schéma : les chemins PARAMÉTRÉS, qu'une
  // table d'égalité ne peut pas décrire, sont résolus avant elle dans
  // _handleDeepLink. Auditer la surface deep-link demande donc de lire les deux.
  // Au deuxième chemin paramétré, remplacer l'ensemble par une liste ordonnée de
  // résolveurs plutôt que d'ajouter un troisième bras.
  static const _allowedDeepLinkPaths = {
    '/stripe/onboarding/complete',
    '/stripe/onboarding/refresh',
    '/payment/confirm',
    '/tracking/scan',
  };

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'yadony') {
      return;
    }

    // Chemin paramétré : traité à part de la liste blanche exhaustive, qui
    // fonctionne par égalité stricte et ne peut donc pas porter un identifiant
    // variable. La validation du segment vit dans resolveAnnouncementDeepLink.
    final announcementRoute = resolveAnnouncementDeepLink(uri);
    if (announcementRoute != null) {
      try {
        _navigateToRoute(announcementRoute);
      } catch (_) {
        // Route indisponible — no-op, comme pour les autres liens profonds.
      }
      return;
    }

    final routePath = '/${uri.host}${uri.path}';
    if (!_allowedDeepLinkPaths.contains(routePath)) {
      return;
    }
    try {
      _navigateToRoute(routePath);
    } catch (_) {
      // Unknown deep link path — no-op
    }
  }

  @override
  void dispose() {
    _navSub?.cancel();
    _authSub?.cancel();
    _deepLinkSub?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<AppPreferencesBloc>.value(
        value: getIt<AppPreferencesBloc>(),
      ),
      BlocProvider<AccessibilityBloc>.value(value: getIt<AccessibilityBloc>()),
      BlocProvider<ConnectivityCubit>.value(value: getIt<ConnectivityCubit>()),
    ],
    child: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
      builder: (context, prefsState) {
        final themeMode = switch (prefsState.preferences.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return BlocConsumer<AccessibilityBloc, AccessibilityState>(
          listenWhen: (a, b) => a.reduceMotion != b.reduceMotion,
          listener: (context, a11y) {
            // Statique global de flutter_animate : il ne peut pas être posé
            // dans un build, et doit être remis à sa valeur d'origine dans
            // le tearDown des tests, sinon un test qui active la réduction
            // contamine tous les suivants.
            final reduce = _resolveMotion(context, a11y);
            Animate.defaultDuration = reduce
                ? Duration.zero
                : const Duration(milliseconds: 300);
          },
          builder: (context, a11y) {
            final reduceMotion = _resolveMotion(context, a11y);
            final highContrast = _resolveContrast(context, a11y);
            final themeOptions = A11yThemeOptions(
              highContrast: highContrast,
              reduceMotion: reduceMotion,
              underlineLinks: a11y.underlineLinks,
            );
            // Le `MultiBlocProvider` existant (ActiveRoleCubit, AuthBloc,
            // KycBloc, etc.), son `BlocListener<AuthBloc>` et son
            // `AnnotatedRegion` sont imbriqués ici tels quels, sans aucune
            // modification. Seul le `MaterialApp.router` qu'ils
            // contiennent change, à l'étape suivante.
            return MultiBlocProvider(
              providers: [
                BlocProvider<ActiveRoleCubit>(
                  create: (_) => getIt<ActiveRoleCubit>(),
                ),
                // lazy: false + AuthCheckRequested : le profil serveur est
                // chargé dès le démarrage, EN ARRIÈRE-PLAN. La navigation
                // initiale, elle, ne l'attend pas (cf. resolveInitialLocation)
                // — c'est ce qui supprime l'écran d'attente bloquant qui
                // apparaissait quand le backend mettait du temps à répondre.
                BlocProvider<AuthBloc>(
                  lazy: false,
                  create: (_) {
                    final bloc = getIt<AuthBloc>();
                    final probe = getIt<FirebaseSessionProbe>();
                    // `hasRealSession` : un visiteur porte une session anonyme
                    // sans compte serveur. `GET /auth/me` lui répondrait 404 à
                    // chaque démarrage, pour rien.
                    if (probe.hasRealSession) {
                      bloc.add(const AuthCheckRequested());
                    }
                    // Décision extraite et testée isolément
                    // (`GuestAccessGuard.shouldLoadGuestFavorites`) plutôt
                    // qu'un `else if` inline : c'est le seul endroit qui
                    // décide si un visiteur qui rouvre l'app doit voir ses
                    // favoris rechargés, un `!` inversé ici passerait
                    // silencieusement au vert sans test dédié. Ce provider
                    // n'a pas accès à `FavoriteIdsCubit` via `context`
                    // (déclaré plus loin dans ce même `MultiBlocProvider`) :
                    // on passe par `getIt`, comme pour `AuthBloc` lui-même.
                    if (GuestAccessGuard.shouldLoadGuestFavorites(probe)) {
                      getIt<FavoriteIdsCubit>().load();
                    }
                    return bloc;
                  },
                ),
                BlocProvider<LocalAuthBloc>(
                  create: (_) => getIt<LocalAuthBloc>(),
                ),
                BlocProvider<KycBloc>(create: (_) => getIt<KycBloc>()),
                BlocProvider<AnnouncementBloc>(
                  create: (_) => getIt<AnnouncementBloc>(),
                ),
                BlocProvider<BidBloc>(create: (_) => getIt<BidBloc>()),
                BlocProvider<PaymentBloc>(create: (_) => getIt<PaymentBloc>()),
                BlocProvider<NotificationBloc>(
                  create: (_) => getIt<NotificationBloc>(),
                ),
                BlocProvider<RatingBloc>(create: (_) => getIt<RatingBloc>()),
                BlocProvider<StripeAccountBloc>(
                  create: (_) => getIt<StripeAccountBloc>(),
                ),
                BlocProvider<HelpCenterBloc>(
                  lazy: false,
                  create: (_) =>
                      getIt<HelpCenterBloc>()
                        ..add(const HelpCenterLoadRequested()),
                ),
                // Singletons partagés — alimentent le point d'attention de
                // l'onglet Activités (bottom nav) même hors du hub.
                BlocProvider<TravelerBidsBloc>.value(
                  value: getIt<TravelerBidsBloc>(),
                ),
                BlocProvider<NegotiationListBloc>.value(
                  value: getIt<NegotiationListBloc>(),
                ),
                // Préférences métier (dont la devise active) : singleton exposé
                // une fois ici, pour que toute surface offrant un changement de
                // devise puisse le lire sans re-déclarer un provider.
                BlocProvider<BusinessPrefsBloc>.value(
                  value: getIt<BusinessPrefsBloc>(),
                ),
                // Global FavoriteIdsCubit — provides heart buttons across all screens.
                // load() is triggered after AuthAuthenticated so it only hits the API
                // when the user is logged in. The cubit swallows errors silently.
                BlocProvider<FavoriteIdsCubit>.value(
                  value: getIt<FavoriteIdsCubit>(),
                ),
              ],
              child: BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (AccountResetGuard.shouldResetAccountScopedBlocs(state)) {
                    // `BusinessPrefsBloc`/`StripeAccountBloc` sont des
                    // `lazySingleton` GetIt jamais recréés par `AuthBloc` —
                    // sans ce reset, ils continueraient de porter le pays /
                    // le statut Stripe du compte précédent après une
                    // déconnexion, un changement de compte ou une nouvelle
                    // inscription (régression trouvée en revue finale du lot
                    // 2, voir `AccountResetGuard`).
                    context.read<BusinessPrefsBloc>().add(
                      const BusinessPrefsReset(),
                    );
                    context.read<StripeAccountBloc>().add(
                      const StripeAccountReset(),
                    );
                  }
                  // Garde-fou de démarrage : session Firebase valide mais
                  // compte absent côté backend (404 → AuthInitial). On ne peut
                  // pas rester sur /home avec un compte inexistant. Une erreur
                  // réseau, elle, émet AuthError : on ne déconnecte pas et
                  // l'écran affiche son état d'erreur avec réessai.
                  if (!_startupAuthResolved && state is! AuthLoading) {
                    _startupAuthResolved = true;
                    // Un visiteur reste légitimement en AuthInitial : sa
                    // session anonyme n'a pas de compte serveur, et le
                    // renvoyer sur /auth/method interdirait la navigation
                    // publique que le mode visiteur est censé ouvrir.
                    if (state is AuthInitial &&
                        getIt<FirebaseSessionProbe>().hasRealSession) {
                      appRouter.go('/auth/method');
                      return;
                    }
                  }
                  if (state is AuthAuthenticated) {
                    context.read<ActiveRoleCubit>().syncWithRoles(
                      state.user.roles,
                    );
                    // One-shot migration: push legacy Hive-saved trips to server,
                    // then reload favorites so migrated items appear immediately.
                    // Capture cubit ref before the async gap to avoid
                    // use_build_context_synchronously lint.
                    final favCubit = context.read<FavoriteIdsCubit>();
                    unawaited(
                      getIt<FavoritesMigration>().run().then(
                        (_) => favCubit.load(),
                      ),
                    );
                    // Réconciliation des préférences de confidentialité depuis le
                    // backend vers le cache Hive local (utile après un changement
                    // fait sur un autre appareil).
                    unawaited(
                      getIt<PrivacySettingsRepository>()
                          .fetch()
                          .then((s) {
                            final prefs = getIt<HiveService>().userPrefs;
                            prefs.put(
                              HiveService.kContactKycOnly,
                              s.contactKycOnly,
                            );
                            prefs.put(
                              HiveService.kHidePhoneNumber,
                              s.hidePhoneNumber,
                            );
                          })
                          .catchError((_) {}),
                    );
                  } else if (state is AuthProfileUpdated) {
                    context.read<ActiveRoleCubit>().syncWithRoles(
                      state.user.roles,
                    );
                  } else if (GuestAccessGuard.isFreshGuestSession(state)) {
                    // Session anonyme fraîchement ouverte ("Parcourir sans
                    // compte") : les favoris sont le seul contenu qu'un
                    // visiteur peut conserver, autant les charger tout de
                    // suite (idempotent, erreurs avalées silencieusement).
                    // Prédicat extrait et testé isolément
                    // (`GuestAccessGuard.isFreshGuestSession`) : un mauvais
                    // état dans cette chaîne de `else if` ne doit pas pouvoir
                    // passer inaperçu.
                    context.read<FavoriteIdsCubit>().load();
                  }
                },
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: const SystemUiOverlayStyle(
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarDividerColor: Colors.transparent,
                    systemNavigationBarContrastEnforced: false,
                    statusBarColor: Colors.transparent,
                  ),
                  child: MaterialApp.router(
                    title: 'Yadony',
                    theme: AppTheme.light(a11y: themeOptions),
                    darkTheme: AppTheme.dark(a11y: themeOptions),
                    themeMode: themeMode,
                    locale: Locale(prefsState.preferences.languageCode),
                    routerConfig: appRouter,
                    debugShowCheckedModeBanner: false,
                    builder: (context, child) {
                      final mq = MediaQuery.of(context);
                      return MediaQuery(
                        data: mq.copyWith(
                          textScaler: a11y.followSystemTextScale
                              ? mq.textScaler.clamp(
                                  maxScaleFactor: kA11yMaxTextScale,
                                )
                              : TextScaler.linear(a11y.textScaleFactor),
                          boldText: a11y.boldText,
                          disableAnimations: reduceMotion,
                        ),
                        child: AccessibilityScope(
                          underlineLinks: a11y.underlineLinks,
                          reinforceLabels: a11y.reinforceLabels,
                          persistentMessages: a11y.persistentMessages,
                          confirmImportantActions: a11y.confirmImportantActions,
                          highContrast: highContrast,
                          // Monté sous le Navigator de MaterialApp → peut
                          // présenter le bottom sheet de consentement
                          // analytics + brancher identify/reset sur le
                          // cycle d'authentification.
                          // Tap hors champ = clavier fermé, et barre
                          // « Terminé » au-dessus des claviers sans touche de
                          // validation (pavé numérique, champs multilignes).
                          child: DonyKeyboardScope(
                            child: Column(
                              children: [
                                // Bandeau réseau global : au-dessus de
                                // TOUTE route (shell ou pushée), jamais
                                // seulement les onglets du shell.
                                const ConnectivityBanner(),
                                Expanded(
                                  child: AnalyticsConsentGate(
                                    child: child ?? const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [
                      Locale('fr', 'FR'),
                      Locale('en', 'US'),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  /// Résout le mode tri-état du mouvement contre le réglage système.
  static bool _resolveMotion(BuildContext context, AccessibilityState s) =>
      switch (s.reduceMotion) {
        AccessibilityMode.on => true,
        AccessibilityMode.off => false,
        _ => MediaQuery.disableAnimationsOf(context),
      };

  /// Résout le mode tri-état du contraste contre le réglage système.
  static bool _resolveContrast(BuildContext context, AccessibilityState s) =>
      switch (s.highContrast) {
        AccessibilityMode.on => true,
        AccessibilityMode.off => false,
        _ => MediaQuery.highContrastOf(context),
      };
}
