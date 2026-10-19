import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/receptions/bloc/receptions_prompt_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Bandeau de l'accueil « Un colis vous attend » (YADONY-FLUTTER-PROD-12) :
/// ouvre le colis, ou l'onglet Suivi sur « Réceptions » s'il y en a
/// plusieurs. Rien quand aucun colis n'attend de confirmation.
class ReceptionsPromptBanner extends StatelessWidget {
  const ReceptionsPromptBanner({super.key, required this.cubit});

  final ReceptionsPromptCubit cubit;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ReceptionsPromptCubit, ReceptionsPromptState>(
        bloc: cubit,
        builder: (context, state) => switch (state) {
          ReceptionsPromptHidden() => const SizedBox.shrink(),
          final ReceptionsPromptVisible visible => _Banner(
            state: visible,
            cubit: cubit,
          ),
        },
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state, required this.cubit});

  final ReceptionsPromptVisible state;
  final ReceptionsPromptCubit cubit;

  void _open(BuildContext context) {
    final route = cubit.tap();
    if (route == null) return;
    if (route.startsWith('/tracking')) {
      context.go(route);
    } else {
      unawaited(context.push(route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = state.senderFirstName;
    final title = name != null
        ? l.receptionsPromptFromSender(name)
        : l.receptionsPromptTitle(state.pending.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.sm,
        DonySpacing.base,
        0,
      ),
      child: DonyCard(
        key: const Key('receptions-prompt'),
        onTap: () => _open(context),
        child: Row(
          children: [
            DonyIconContainer(
              iconAsset: 'inbox',
              iconColor: cs.primary,
              backgroundColor: cs.primaryContainer,
            ),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleSmall),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    l.receptionsPromptSubtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('receptions-prompt-dismiss'),
              tooltip: l.commonClose,
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              onPressed: () => unawaited(cubit.dismiss()),
            ),
          ],
        ),
      ),
    );
  }
}
