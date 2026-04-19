import 'package:dony/app/router.dart';
import 'package:dony/app/theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DonyApp extends StatelessWidget {
  const DonyApp({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) => getIt<AuthBloc>(),
          ),
        ],
        child: MaterialApp.router(
          title: 'dony',
          theme: appTheme,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        ),
      );
}
