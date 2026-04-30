import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _navSub = getIt<NotificationService>().navigationStream.listen((route) {
      appRouter.go(route);
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        getIt<NotificationService>().uploadCurrentToken();
      }
    });
  }

  @override
  void dispose() {
    _navSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
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
          BlocProvider<NotificationBloc>(
            create: (_) => getIt<NotificationBloc>(),
          ),
        ],
        child: MaterialApp.router(
          title: 'dony',
          theme: AppTheme.light,
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
      );
}
