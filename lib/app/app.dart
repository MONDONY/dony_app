import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/analytics_consent_gate.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        // log if Sentry is available, otherwise ignore to keep subscription alive
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
  Widget build(BuildContext context) => BlocProvider<AppPreferencesBloc>.value(
        value: getIt<AppPreferencesBloc>(),
        child: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
          builder: (context, prefsState) {
            final themeMode = switch (prefsState.preferences.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            };
            return MultiBlocProvider(
              providers: [
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
              ],
              child: BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthAuthenticated) {
                    // Réconciliation de la préférence contactKycOnly depuis le backend
                    // vers le cache Hive local (utile en cas de changement sur un autre appareil).
                    unawaited(
                      getIt<PrivacySettingsRepository>()
                          .fetchContactKycOnly()
                          .then((v) => getIt<HiveService>().userPrefs
                              .put(HiveService.kContactKycOnly, v))
                          .catchError((_) {}),
                    );
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
                    theme: AppTheme.light,
                    darkTheme: AppTheme.dark,
                    themeMode: themeMode,
                    locale: Locale(prefsState.preferences.languageCode),
                    routerConfig: appRouter,
                    debugShowCheckedModeBanner: false,
                    // Monté sous le Navigator de MaterialApp → peut présenter
                    // le bottom sheet de consentement analytics + brancher
                    // identify/reset sur le cycle d'authentification.
                    builder: (context, child) => AnalyticsConsentGate(
                      child: child ?? const SizedBox.shrink(),
                    ),
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
        ),
      );
}
