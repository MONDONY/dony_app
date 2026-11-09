import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/features/app_update/bloc/app_update_prompt_cubit.dart';
import 'package:dony/features/app_update/presentation/widgets/app_update_prompt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Montre le modal de mise à jour recommandée (`recommended_build`) quand
/// [AppUpdatePromptCubit] le demande. Monté dans le shell principal : le modal
/// n'apparaît donc qu'une fois l'utilisateur arrivé dans l'app (ni pendant le
/// splash, la connexion ou l'onboarding, ni sur l'écran bloquant). Ne rend
/// rien lui-même.
class AppUpdatePromptGate extends StatelessWidget {
  const AppUpdatePromptGate({super.key, this.cubit});

  /// Injectable pour les tests. Un Cubit fourni de l'extérieur reste à son
  /// propriétaire : le widget ne le ferme pas.
  final AppUpdatePromptCubit? cubit;

  @override
  Widget build(BuildContext context) {
    const listener = _Listener();
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<AppUpdatePromptCubit>.value(
        value: provided,
        child: listener,
      );
    }
    return BlocProvider<AppUpdatePromptCubit>(
      create: (_) => getIt<AppUpdatePromptCubit>(),
      child: listener,
    );
  }
}

class _Listener extends StatefulWidget {
  const _Listener();

  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lancement : une fois le shell affiché.
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate(false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _evaluate(true);
  }

  /// Un autre écran plein par-dessus le shell : on ne fait rien et on ne
  /// mémorise rien.
  bool get _shellIsCurrent =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  void _evaluate(bool resumed) {
    if (!_shellIsCurrent) return;
    final cubit = context.read<AppUpdatePromptCubit>();
    unawaited(resumed ? cubit.onForeground() : cubit.check());
  }

  Future<void> _show(AppUpdatePromptCubit cubit) async {
    if (!_shellIsCurrent) {
      cubit.skip();
      return;
    }
    final choice = await AppUpdatePromptSheet.show(context);
    if (choice == AppUpdatePromptChoice.update) {
      await cubit.update();
    } else {
      await cubit.later();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppUpdatePromptCubit, bool>(
      listenWhen: (previous, current) => !previous && current,
      listener: (context, _) {
        final cubit = context.read<AppUpdatePromptCubit>();
        WidgetsBinding.instance.addPostFrameCallback((_) => _show(cubit));
      },
      child: const SizedBox.shrink(),
    );
  }
}
