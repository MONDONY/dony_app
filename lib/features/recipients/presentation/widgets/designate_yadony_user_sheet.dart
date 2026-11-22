import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart'
    show DesignatedUser;

/// Feuille « Un utilisateur Yadony » : l'expéditeur désigne le destinataire
/// d'un colis par son identifiant. Rend le [DesignatedUser] choisi, `null` si
/// la feuille est fermée sans choisir.
///
/// La recherche part à la validation du clavier ou à la perte de focus,
/// jamais à la frappe. « Choisir » reste grisé tant qu'aucun compte n'est
/// trouvé, et un back qui ne sait pas désigner un destinataire de colis
/// (`parcelDesignation` faux) ne permet aucune sélection.
abstract final class DesignateYadonyUserSheet {
  static Future<DesignatedUser?> show(
    BuildContext context, {
    String? excludeUsername,
    @visibleForTesting DesignateYadonyUserCubit Function()? createCubit,
  }) {
    return DonyBottomSheet.show<DesignatedUser>(
      context,
      title: context.l10n.designateYadonyUserTitle,
      // Le cubit vit avec la feuille : BlocProvider le ferme quand la route
      // disparaît, après l'animation de sortie.
      wrapper: (child) => BlocProvider<DesignateYadonyUserCubit>(
        create: (_) =>
            (createCubit ?? () => getIt<DesignateYadonyUserCubit>())()
              ..excludeUsername = excludeUsername,
        child: child,
      ),
      stickyBottom:
          BlocBuilder<DesignateYadonyUserCubit, DesignateYadonyUserState>(
            builder: (ctx, state) => DonyButton(
              key: const Key('designate-yadony-user-choose'),
              label: ctx.l10n.designateYadonyUserChoose,
              onPressed: state.canChoose
                  ? () {
                      final chosen = ctx
                          .read<DesignateYadonyUserCubit>()
                          .choose();
                      if (chosen != null) Navigator.of(ctx).pop(chosen);
                    }
                  : null,
            ),
          ),
      child: const _DesignateContent(),
    );
  }
}

class _DesignateContent extends StatefulWidget {
  const _DesignateContent();

  @override
  State<_DesignateContent> createState() => _DesignateContentState();
}

class _DesignateContentState extends State<_DesignateContent> {
  // Contrôleur possédé par le State du contenu, jamais par `show()` : la
  // feuille reste affichée pendant son animation de sortie.
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _error(DesignateYadonyUserState state) {
    final l = context.l10n;
    switch (state.lookup) {
      case DesignateLookup.notFound:
        return l.recipientInviteUsernameNotFound;
      case DesignateLookup.self:
        return l.recipientInviteUsernameSelf;
      case DesignateLookup.quota:
        return l.recipientInviteUsernameQuota;
      case DesignateLookup.unsupported:
        return l.recipientInviteUsernameUnsupported;
      case DesignateLookup.unavailable:
        return l.designateYadonyUserUnavailable;
      case DesignateLookup.failed:
        return l.usernameCheckFailed;
      case DesignateLookup.sameAsCurrent:
        return l.designateYadonyUserAlreadyRecipient;
      case DesignateLookup.idle:
        return state.showsFormatError ? l.usernameInvalidFormat : null;
      case DesignateLookup.searching:
      case DesignateLookup.found:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<DesignateYadonyUserCubit>();
    return BlocBuilder<DesignateYadonyUserCubit, DesignateYadonyUserState>(
      builder: (context, state) {
        final initial = state.foundInitial.trim();
        final hasInitial = initial.isNotEmpty && initial != '?';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.designateYadonyUserIntro,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            Focus(
              onFocusChange: (focused) {
                if (focused) return;
                cubit.fieldBlurred();
                unawaited(cubit.committed());
              },
              child: DonyTextField(
                key: const Key('designate-yadony-user-field'),
                controller: _ctrl,
                label: l.recipientInviteUsernameLabel,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => unawaited(cubit.committed()),
                prefixWidget: const Padding(
                  padding: EdgeInsetsDirectional.only(start: DonySpacing.base),
                  child: Center(
                    widthFactor: 1,
                    child: Text('@', style: TextStyle(fontSize: 16)),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                  TextInputFormatter.withFunction(
                    (old, value) =>
                        value.copyWith(text: value.text.toLowerCase()),
                  ),
                ],
                onChanged: cubit.inputChanged,
                errorText: _error(state),
                errorMaxLines: 3,
              ),
            ),
            if (state.lookup == DesignateLookup.searching) ...[
              const SizedBox(height: DonySpacing.sm),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  key: Key('designate-yadony-user-searching'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            if (state.lookup == DesignateLookup.found) ...[
              const SizedBox(height: DonySpacing.sm),
              Container(
                key: const Key('designate-yadony-user-preview'),
                padding: const EdgeInsets.all(DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(color: cs.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    DonyIcon('circle-check', size: 20, color: cs.success),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${state.foundTarget}',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            hasInitial
                                ? l.recipientInviteUsernameFound(initial)
                                : l.recipientInviteUsernameFoundNoInitial,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: DonySpacing.sm),
          ],
        );
      },
    );
  }
}
