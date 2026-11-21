import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/profile/bloc/username/username_cubit.dart';
import 'package:dony/features/profile/data/models/username_availability.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Feuille « Mon identifiant » : l'utilisateur choisit son identifiant public
/// (celui que ses proches saisissent pour l'inviter comme destinataire).
///
/// Rend `true` quand l'identifiant a été changé : l'appelant rafraîchit alors
/// le profil et annonce `usernameSaved`.
abstract final class EditUsernameSheet {
  static Future<bool> show(
    BuildContext context, {
    @visibleForTesting UsernameCubit Function()? createCubit,
  }) async {
    final saved = await DonyBottomSheet.show<bool>(
      context,
      title: context.l10n.usernameSheetTitle,
      analyticsName: 'edit_username',
      // Le cubit vit avec la feuille : BlocProvider le ferme quand la route
      // disparaît, après l'animation de sortie.
      wrapper: (child) => BlocProvider<UsernameCubit>(
        create: (_) =>
            (createCubit ?? () => UsernameCubit(getIt<ProfileRepository>()))(),
        child: child,
      ),
      stickyBottom: BlocBuilder<UsernameCubit, UsernameState>(
        builder: (ctx, state) => DonyButton(
          key: const Key('username-save'),
          label: ctx.l10n.commonSave,
          isLoading: state.status == UsernameStatus.saving,
          onPressed: state.canSave
              ? () => ctx.read<UsernameCubit>().submit()
              : null,
        ),
      ),
      child: const _EditUsernameContent(),
    );
    return saved ?? false;
  }
}

class _EditUsernameContent extends StatefulWidget {
  const _EditUsernameContent();

  @override
  State<_EditUsernameContent> createState() => _EditUsernameContentState();
}

class _EditUsernameContentState extends State<_EditUsernameContent> {
  // Contrôleur possédé par le State du contenu, jamais par `show()` : la
  // feuille reste affichée pendant son animation de sortie.
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Message d'erreur du champ pour l'état courant, `null` sinon.
  String? _errorText(UsernameState state) {
    final l = context.l10n;
    switch (state.status) {
      case UsernameStatus.unavailable:
        return switch (state.reason) {
          UsernameReason.taken => l.usernameTaken,
          UsernameReason.recentlyReleased => l.usernameRecentlyReleased,
          UsernameReason.reserved => l.usernameReserved,
          UsernameReason.looksLikePhone => l.usernameLooksLikePhone,
          UsernameReason.unchanged => l.usernameUnchanged,
          _ => l.usernameInvalidFormat,
        };
      case UsernameStatus.tooSoon:
        final at = state.nextChangeAt;
        final date = at == null
            ? ''
            : DateFormat.yMMMMd(
                Localizations.localeOf(context).toString(),
              ).format(at.toLocal());
        return l.usernameChangeTooSoon(date);
      case UsernameStatus.quota:
        return l.usernameQuota;
      case UsernameStatus.error:
        return l.usernameCheckFailed;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<UsernameCubit>();

    return BlocConsumer<UsernameCubit, UsernameState>(
      listenWhen: (p, c) => p.input != c.input || p.status != c.status,
      listener: (context, state) {
        // Une puce touchée remplit le champ.
        if (_ctrl.text.trim().toLowerCase() != state.input) {
          _ctrl.value = TextEditingValue(
            text: state.input,
            selection: TextSelection.collapsed(offset: state.input.length),
          );
        }
        if (state.status == UsernameStatus.saved) {
          // Même schéma qu'InviteRecipientSheet : le pop se fait ici, dans le listener.
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final suggestions = state.status == UsernameStatus.unavailable
            ? state.suggestions
            : const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.usernameSheetIntro,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyTextField(
              key: const Key('username-field'),
              controller: _ctrl,
              label: l.usernameFieldLabel,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              enabled: state.status != UsernameStatus.saving,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
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
              errorText: _errorText(state),
              errorMaxLines: 3,
            ),
            if (state.status == UsernameStatus.available) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                l.usernameAvailable,
                style: tt.bodySmall?.copyWith(
                  color: cs.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (state.showsFormatHint) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                l.usernameInvalidFormat,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.base),
              Text(
                l.usernameTrySuggestions,
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      key: Key('username-suggestion-$s'),
                      label: Text('@$s'),
                      onPressed: () => cubit.suggestionTapped(s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: DonySpacing.base),
            Text(
              l.usernameHelp,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
