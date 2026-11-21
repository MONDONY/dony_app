import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/contact_picker_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/recipients/bloc/invite_recipient_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Ajouter un destinataire Yadony » : l'expéditeur invite par numéro
/// ou par e-mail. Rend `true` quand l'invitation est partie : l'appelant
/// affiche alors le message, identique que le compte existe ou non.
///
/// [userCountry] (code ISO du pays de l'utilisateur) sert à mettre au format
/// international un numéro repris du carnet du téléphone (`07…`).
///
/// [onSent] est appelé dès que le serveur a accepté l'invitation, avant la
/// fermeture de la feuille : l'appelant y rafraîchit ses invitations envoyées
/// sans attendre la fin de l'animation de sortie (FLUTTER-88).
abstract final class InviteRecipientSheet {
  static Future<bool> show(
    BuildContext context, {
    String? userCountry,
    VoidCallback? onSent,
    @visibleForTesting InviteRecipientCubit Function()? createCubit,
  }) async {
    final sent = await DonyBottomSheet.show<bool>(
      context,
      title: context.l10n.recipientInviteAction,
      // Le cubit vit avec la feuille : BlocProvider le ferme quand la route
      // disparaît, après l'animation de sortie.
      wrapper: (child) => BlocProvider<InviteRecipientCubit>(
        create: (_) => (createCubit ?? () => getIt<InviteRecipientCubit>())(),
        child: child,
      ),
      stickyBottom: BlocBuilder<InviteRecipientCubit, InviteRecipientState>(
        builder: (ctx, state) {
          final submitting = state.status == InviteRecipientStatus.submitting;
          return DonyButton(
            key: const Key('invite-recipient-submit'),
            label: ctx.l10n.recipientInviteSubmit,
            iconAsset: 'send',
            isLoading: submitting,
            onPressed: state.isValid && !submitting
                ? () => ctx.read<InviteRecipientCubit>().submit()
                : null,
          );
        },
      ),
      child: _InviteRecipientContent(userCountry: userCountry, onSent: onSent),
    );
    return sent ?? false;
  }
}

class _InviteRecipientContent extends StatefulWidget {
  const _InviteRecipientContent({this.userCountry, this.onSent});

  final String? userCountry;
  final VoidCallback? onSent;

  @override
  State<_InviteRecipientContent> createState() =>
      _InviteRecipientContentState();
}

class _InviteRecipientContentState extends State<_InviteRecipientContent> {
  // Contrôleurs possédés par le State du contenu, jamais par `show()` : la
  // feuille reste affichée pendant son animation de sortie.
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// « Choisir dans mes contacts » : le numéro et le nom du contact
  /// remplissent le formulaire, le numéro mis au format international.
  Future<void> _pickContact(InviteRecipientCubit cubit) async {
    final contact = await getIt<ContactPickerService>().pick();
    if (!mounted || contact == null || cubit.isClosed) return;
    cubit.contactPicked(contact, countryCode: widget.userCountry);
    _phoneCtrl.text = cubit.state.input;
    _nameCtrl.text = cubit.state.name;
  }

  void _onChannel(InviteRecipientCubit cubit, InvitationChannel channel) {
    cubit.selectChannel(channel);
    cubit.inputChanged(_controllerFor(channel).text);
  }

  TextEditingController _controllerFor(InvitationChannel channel) =>
      switch (channel) {
        InvitationChannel.phone => _phoneCtrl,
        InvitationChannel.email => _emailCtrl,
        InvitationChannel.username => _usernameCtrl,
      };

  /// Message d'erreur du champ identifiant pour l'état courant.
  String? _usernameError(InviteRecipientState state) {
    final l = context.l10n;
    switch (state.lookup) {
      case UsernameLookupStatus.notFound:
        return l.recipientInviteUsernameNotFound;
      case UsernameLookupStatus.self:
        return l.recipientInviteUsernameSelf;
      case UsernameLookupStatus.quota:
        return l.recipientInviteUsernameQuota;
      case UsernameLookupStatus.failed:
        return l.usernameCheckFailed;
      case UsernameLookupStatus.idle:
        return state.showsError ? l.usernameInvalidFormat : null;
      case UsernameLookupStatus.searching:
      case UsernameLookupStatus.found:
      case UsernameLookupStatus.unsupported:
        return null;
    }
  }

  Widget _usernameField(
    InviteRecipientState state,
    InviteRecipientCubit cubit,
  ) {
    return DonyTextField(
      key: const Key('invite-recipient-username'),
      controller: _usernameCtrl,
      label: context.l10n.recipientInviteUsernameLabel,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      // La recherche part à la validation du clavier ou à la perte de focus,
      // jamais à la frappe : le seau serveur est de 30 par heure.
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => unawaited(cubit.usernameCommitted()),
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
          (old, value) => value.copyWith(text: value.text.toLowerCase()),
        ),
      ],
      onChanged: cubit.inputChanged,
      errorText: _usernameError(state),
      errorMaxLines: 3,
    );
  }

  /// Sous le champ identifiant : recherche en cours, compte trouvé, lien vers
  /// le numéro quand l'identifiant n'existe pas, sinon l'aide.
  List<Widget> _usernameStatus(
    InviteRecipientState state,
    InviteRecipientCubit cubit,
  ) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    switch (state.lookup) {
      case UsernameLookupStatus.searching:
        return [
          const SizedBox(height: DonySpacing.sm),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              key: Key('invite-recipient-username-searching'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ];
      case UsernameLookupStatus.found:
        return [
          const SizedBox(height: DonySpacing.sm),
          Container(
            key: const Key('invite-recipient-username-preview'),
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
                        l.recipientInviteUsernameFound(state.foundInitial),
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
        ];
      case UsernameLookupStatus.notFound:
        return [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('invite-recipient-username-by-phone'),
              onPressed: () => _onChannel(cubit, InvitationChannel.phone),
              child: Text(
                l.recipientInviteUsernameAddByPhone,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ];
      case UsernameLookupStatus.idle:
        if (state.showsError) return const [];
        return [
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.recipientInviteUsernameHelper,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ];
      case UsernameLookupStatus.self:
      case UsernameLookupStatus.quota:
      case UsernameLookupStatus.unsupported:
      case UsernameLookupStatus.failed:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<InviteRecipientCubit>();

    return BlocConsumer<InviteRecipientCubit, InviteRecipientState>(
      listenWhen: (p, c) =>
          p.status != c.status ||
          (!p.usernameUnsupported && c.usernameUnsupported),
      listener: (context, state) {
        // Back sans la recherche d'identifiant : l'onglet disparaît, la
        // feuille revient au numéro.
        if (state.usernameUnsupported &&
            state.channel == InvitationChannel.username) {
          _onChannel(cubit, InvitationChannel.phone);
        }
        if (state.status == InviteRecipientStatus.sent) {
          widget.onSent?.call();
          Navigator.of(context).pop(true);
        } else if (state.status == InviteRecipientStatus.failed) {
          if (state.isQuotaExceeded) {
            DonySnackbar.show(
              context,
              message: l.recipientInviteQuota,
              type: DonySnackbarType.error,
            );
          } else {
            unawaited(ErrorPresenter.show(context, state.error));
          }
        }
      },
      builder: (context, state) {
        final isPhone = state.channel == InvitationChannel.phone;
        final isUsername = state.channel == InvitationChannel.username;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.recipientInviteSheetIntro,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            SegmentedButton<InvitationChannel>(
              key: const Key('invite-recipient-channel'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: InvitationChannel.phone,
                  label: Text(l.recipientInviteChannelPhone),
                ),
                ButtonSegment(
                  value: InvitationChannel.email,
                  label: Text(l.recipientInviteChannelEmail),
                ),
                if (!state.usernameUnsupported)
                  ButtonSegment(
                    value: InvitationChannel.username,
                    label: Text(l.recipientInviteChannelUsername),
                  ),
              ],
              selected: {state.channel},
              onSelectionChanged: (s) => _onChannel(cubit, s.first),
            ),
            const SizedBox(height: DonySpacing.base),
            if (isPhone) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('invite-recipient-pick-contact'),
                  onPressed: () => _pickContact(cubit),
                  icon: DonyIcon('contact', size: 18, color: cs.primary),
                  label: Text(l.recipientImportContactsAction),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            Focus(
              onFocusChange: (focused) {
                if (focused) return;
                cubit.fieldBlurred();
                if (isUsername) unawaited(cubit.usernameCommitted());
              },
              child: isUsername
                  ? _usernameField(state, cubit)
                  : isPhone
                  ? DonyTextField(
                      key: const Key('invite-recipient-phone'),
                      controller: _phoneCtrl,
                      label: l.recipientInvitePhoneLabel,
                      hint: l.recipientInvitePhoneHint,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      onChanged: cubit.inputChanged,
                      errorText: state.showsError
                          ? l.recipientInvitePhoneInvalid
                          : null,
                    )
                  : DonyTextField(
                      key: const Key('invite-recipient-email'),
                      controller: _emailCtrl,
                      label: l.recipientInviteEmailLabel,
                      hint: l.recipientInviteEmailHint,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      onChanged: cubit.inputChanged,
                      errorText: state.showsError
                          ? l.recipientInviteEmailInvalid
                          : null,
                    ),
            ),
            if (isUsername) ..._usernameStatus(state, cubit),
            const SizedBox(height: DonySpacing.base),
            DonyTextField(
              key: const Key('invite-recipient-name'),
              controller: _nameCtrl,
              label: l.recipientInviteNameLabel,
              hint: l.recipientInviteNameHint,
              keyboardType: TextInputType.name,
              onChanged: cubit.nameChanged,
              errorText: state.nameTooLong
                  ? l.recipientInviteNameTooLong
                  : null,
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
        );
      },
    );
  }
}
