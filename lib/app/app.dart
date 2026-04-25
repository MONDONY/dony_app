import 'package:dony/app/router.dart';
import 'package:dony/app/theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/local_auth_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class DonyApp extends StatelessWidget {
  const DonyApp({super.key});

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
        ],
        child: MaterialApp.router(
          title: 'dony',
          theme: appTheme,
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
