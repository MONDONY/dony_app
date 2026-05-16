import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
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

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'dony') {
      return;
    }
    // Build GoRouter path from host + path segments:
    // dony://stripe/onboarding/complete  →  /stripe/onboarding/complete
    final routePath = '/${uri.host}${uri.path}';
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
        ],
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
            // ignore: avoid_redundant_argument_values
            themeMode: ThemeMode.system,
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
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
      );
}
