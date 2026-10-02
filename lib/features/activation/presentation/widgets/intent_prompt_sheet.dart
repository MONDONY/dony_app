import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/intent_form.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Feuille « Que faites-vous sur Yadony ? » (comptes existants, réglages).
/// Renvoie `true` quand l'intention est enregistrée.
abstract final class IntentPromptSheet {
  static Future<bool?> show(
    BuildContext context, {
    required IntentSource source,
    UserIntent? initialIntent,
    String? initialDestination,
  }) {
    final cubit = getIt<IntentCubit>(
      param1: (intent: initialIntent, destination: initialDestination),
    );
    final l = context.l10n;
    return DonyBottomSheet.show<bool>(
      context,
      title: l.intentSheetTitle,
      wrapper: (content) => BlocProvider<IntentCubit>.value(
        value: cubit,
        child: BlocListener<IntentCubit, IntentFormState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: (ctx, state) {
            if (state.status == IntentFormStatus.saved) {
              ctx.pop(true);
            } else if (state.status == IntentFormStatus.error) {
              DonySnackbar.show(
                ctx,
                message: ctx.l10n.intentSaveError,
                type: DonySnackbarType.error,
              );
            }
          },
          child: content,
        ),
      ),
      // Le cubit n'émet plus rien après le pop (saved est le dernier état) :
      // le fermer à la fin de la feuille est sûr pendant l'animation de sortie.
      stickyBottom: BlocBuilder<IntentCubit, IntentFormState>(
        bloc: cubit,
        builder: (ctx, state) => DonyButton(
          key: const Key('intent-sheet-continue'),
          label: l.intentContinue,
          isLoading: state.status == IntentFormStatus.saving,
          onPressed: state.isValid && state.status != IntentFormStatus.saving
              ? () => cubit.submit(source)
              : null,
        ),
      ),
      child: const IntentForm(),
    ).whenComplete(() => unawaited(cubit.close()));
  }
}
