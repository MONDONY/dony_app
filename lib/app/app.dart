import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dony/app/reduced_motion_priming.dart';
import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/widgets/analytics_consent_gate.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/favorites_migration.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class DonyApp extends StatefulWidget {
  const DonyApp({super.key});

  @override
  State<DonyApp> createState() => _DonyAppState();
}

class _DonyAppState extends State<DonyApp> {
  StreamSubscription<String>? _navSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<Uri>? _deepLinkSub;
  final _appLinks = AppLinks();

  // Onglets du shell principal : go() est nécessaire pour activer le bon onglet.
  // Toutes les autres routes utilisent push() pour empiler par-dessus l'état
  // courant et permettre au bouton retour de revenir à l'écran précédent.
  static const _shellTabs = {
    '/home',
    '/announcements',
    '/tracking',
    '/messages',
    '/profile',
  };

  void _navigateToRoute(String route) {
    if (_shellTabs.contains(route)) {
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
      if (user != null) {
        getIt<NotificationService>().uploadCurrentToken();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeepLinks());
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
        AppLog.error('Deep link stream error', error: error, stackTrace: stack);
      },
    );
  }

  // Exhaustive allowlist — only these paths can be reached via dony:// URIs.
  // Prevents crafted deep-links (e.g. dony://admin/…) from routing to
  // unintended screens.
  static const _allowedDeepLinkPaths = {
    '/stripe/onboarding/complete',
    '/stripe/onboarding/refresh',
    '/payment/confirm',
    '/tracking/scan',
  };

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'dony') {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<AppPreferencesBloc>.value(
            value: getIt<AppPreferencesBloc>(),
          ),
          BlocProvider<AccessibilityBloc>.value(
            value: getIt<AccessibilityBloc>(),
          ),
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
                Animate.defaultDuration =
                    reduce ? Duration.zero : const Duration(milliseconds: 300);
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
                    BlocProvider<AuthBloc>(
                      create: (_) => getIt<AuthBloc>(),
                    ),
                    BlocProvider<LocalAuthBloc>(
                      create: (_) => getIt<LocalAuthBloc>(),
                    ),
                    BlocProvider<KycBloc>(
                      create: (_) => getIt<KycBloc>(),
                    ),
                    BlocProvider<AnnouncementBloc>(
                      create: (_) => getIt<AnnouncementBloc>(),
                    ),
                    BlocProvider<BidBloc>(
                      create: (_) => getIt<BidBloc>(),
                    ),
                    BlocProvider<PaymentBloc>(
                      create: (_) => getIt<PaymentBloc>(),
                    ),
                    BlocProvider<NotificationBloc>(
                      create: (_) => getIt<NotificationBloc>(),
                    ),
                    BlocProvider<RatingBloc>(
                      create: (_) => getIt<RatingBloc>(),
                    ),
                    BlocProvider<StripeAccountBloc>(
                      create: (_) => getIt<StripeAccountBloc>(),
                    ),
                    // Singletons partagés — alimentent le point d'attention de
                    // l'onglet Activités (bottom nav) même hors du hub.
                    BlocProvider<TravelerBidsBloc>.value(
                      value: getIt<TravelerBidsBloc>(),
                    ),
                    BlocProvider<NegotiationListBloc>.value(
                      value: getIt<NegotiationListBloc>(),
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
                      if (state is AuthAuthenticated) {
                        context.read<ActiveRoleCubit>().syncWithRoles(state.user.roles);
                        // One-shot migration: push legacy Hive-saved trips to server,
                        // then reload favorites so migrated items appear immediately.
                        // Capture cubit ref before the async gap to avoid
                        // use_build_context_synchronously lint.
                        final favCubit = context.read<FavoriteIdsCubit>();
                        unawaited(
                          getIt<FavoritesMigration>()
                              .run()
                              .then((_) => favCubit.load()),
                        );
                        // Réconciliation des préférences de confidentialité depuis le
                        // backend vers le cache Hive local (utile après un changement
                        // fait sur un autre appareil).
                        unawaited(
                          getIt<PrivacySettingsRepository>().fetch().then((s) {
                            final prefs = getIt<HiveService>().userPrefs;
                            prefs.put(HiveService.kContactKycOnly, s.contactKycOnly);
                            prefs.put(
                                HiveService.kHidePhoneNumber, s.hidePhoneNumber);
                          }).catchError((_) {}),
                        );
                      } else if (state is AuthProfileUpdated) {
                        context.read<ActiveRoleCubit>().syncWithRoles(state.user.roles);
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
                        title: 'dony',
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
                                  ? mq.textScaler
                                      .clamp(maxScaleFactor: kA11yMaxTextScale)
                                  : TextScaler.linear(a11y.textScaleFactor),
                              boldText: a11y.boldText,
                              disableAnimations: reduceMotion,
                            ),
                            child: AccessibilityScope(
                              underlineLinks: a11y.underlineLinks,
                              reinforceLabels: a11y.reinforceLabels,
                              persistentMessages: a11y.persistentMessages,
                              confirmImportantActions:
                                  a11y.confirmImportantActions,
                              // Monté sous le Navigator de MaterialApp → peut
                              // présenter le bottom sheet de consentement
                              // analytics + brancher identify/reset sur le
                              // cycle d'authentification.
                              child: AnalyticsConsentGate(
                                child: child ?? const SizedBox.shrink(),
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
