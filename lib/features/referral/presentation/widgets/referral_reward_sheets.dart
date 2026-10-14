import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/presentation/referral_format.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille « Choisissez votre récompense » : crédit sur le solde ou code de
/// réduction personnel. Rend le filleul mis à jour une fois le choix accepté
/// par le serveur, `null` si la feuille est fermée sans choix.
///
/// Partage le [ReferralBloc] de l'écran Parrainage (pattern C : l'écran se
/// met à jour tout seul).
abstract final class ReferralRewardChoiceSheet {
  static Future<Referee?> show(
    BuildContext context, {
    required ReferralBloc bloc,
    required Referee referee,
    required ReferralInfo info,
  }) {
    final l = context.l10n;
    // Seuls les taps sur les options écrivent dans ce notifier : il peut
    // être libéré au `whenComplete`.
    final selected = ValueNotifier<RewardChoice>(RewardChoice.walletCredit);
    final name = referee.displayName;
    return DonyBottomSheet.show<Referee>(
      context,
      title: l.referralChoiceTitle,
      // « Awa D. » finit déjà par un point : la phrase n'en ajoute pas un
      // second.
      subtitle: name == null
          ? l.referralChoiceSubtitleAnonymous
          : l.referralChoiceSubtitle(
              name.endsWith('.') ? name.substring(0, name.length - 1) : name,
            ),
      wrapper: (child) =>
          BlocProvider<ReferralBloc>.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<RewardChoice>(
        valueListenable: selected,
        builder: (context, choice, _) =>
            BlocBuilder<ReferralBloc, ReferralState>(
              builder: (context, state) {
                final loading =
                    state is ReferralLoaded &&
                    state.choosingInvitationId == referee.invitationId;
                return DonyButton(
                  label: choice == RewardChoice.discountCode
                      ? l.referralChoiceCodeCta(
                          info.effectiveRewardDiscountPercent,
                        )
                      : l.referralChoiceWalletCta(
                          formatRewardWalletAmount(l, info),
                        ),
                  isLoading: loading,
                  onPressed: loading
                      ? null
                      : () => context.read<ReferralBloc>().add(
                          ReferralRewardChosen(referee.invitationId, choice),
                        ),
                );
              },
            ),
      ),
      child: BlocListener<ReferralBloc, ReferralState>(
        listenWhen: (_, current) =>
            current is ReferralLoaded &&
            (current.rewardError != null ||
                current.rewardResult?.invitationId == referee.invitationId),
        listener: (context, state) {
          final loaded = state as ReferralLoaded;
          final result = loaded.rewardResult;
          if (result != null) {
            Navigator.of(context, rootNavigator: true).pop(result);
            return;
          }
          final error = loaded.rewardError!;
          ErrorPresenter.show(context, error);
          // Déjà choisie ou disparue : rien à choisir ici, la feuille se
          // ferme et l'écran relit la liste.
          if (error is ConflictException || error is NotFoundException) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        },
        child: _ChoiceOptions(selected: selected, info: info),
      ),
    ).whenComplete(selected.dispose);
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.selected, required this.info});

  final ValueNotifier<RewardChoice> selected;
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final amount = formatRewardWalletAmount(l, info);
    final percent = info.effectiveRewardDiscountPercent;
    return ValueListenableBuilder<RewardChoice>(
      valueListenable: selected,
      builder: (context, choice, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceOption(
            key: const ValueKey('referral-choice-wallet'),
            badge: amount,
            title: l.referralChoiceWalletTitle(amount),
            body: l.referralChoiceWalletBody,
            selected: choice == RewardChoice.walletCredit,
            onTap: () => selected.value = RewardChoice.walletCredit,
          ),
          const SizedBox(height: DonySpacing.sm + 2),
          _ChoiceOption(
            key: const ValueKey('referral-choice-code'),
            badge: l.referralPercentBadge(percent),
            title: l.referralChoiceCodeTitle(percent),
            body: l.referralChoiceCodeBody,
            selected: choice == RewardChoice.discountCode,
            onTap: () => selected.value = RewardChoice.discountCode,
          ),
          const SizedBox(height: DonySpacing.md + 2),
          Text(
            l.referralChoiceWalletNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
      ),
    );
  }
}

/// Option de la feuille de choix : un vrai bouton (rôle, état sélectionné),
/// jamais une simple zone tactile.
class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    super.key,
    required this.badge,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: DonyPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(selected ? DonySpacing.base - 1 : 16),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: _duration,
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
                child: Text(
                  badge,
                  maxLines: 1,
                  style: tt.titleLarge?.copyWith(
                    color: selected ? cs.onPrimary : cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              AnimatedContainer(
                duration: _duration,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                    width: selected ? 7 : 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation après le choix : le code de réduction à copier, ou le
/// crédit ajouté au solde.
abstract final class ReferralRewardConfirmationSheet {
  static Future<void> show(
    BuildContext context, {
    required Referee referee,
    required ReferralInfo info,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<void>(
      context,
      stickyBottom: Builder(
        builder: (context) => DonyButton(
          label: l.commonDone,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
      child: ReferralRewardConfirmation(referee: referee, info: info),
    );
  }
}

/// Contenu de la confirmation, public pour les tests.
class ReferralRewardConfirmation extends StatelessWidget {
  const ReferralRewardConfirmation({
    super.key,
    required this.referee,
    required this.info,
  });

  final Referee referee;
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isCode = referee.rewardChoice == RewardChoice.discountCode;
    final code = referee.discountCode;
    final percent = code?.percent ?? info.effectiveRewardDiscountPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DonySpacing.xs),
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.successLight,
              shape: BoxShape.circle,
            ),
            child: DonyIcon('check', size: 30, color: cs.success),
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          isCode
              ? l.referralCodeReadyTitle(percent)
              : l.referralWalletCredited(
                  formatRefereeWalletAmount(l, referee, info),
                ),
          textAlign: TextAlign.center,
          style: tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: DonySpacing.sm + 2),
        Text(
          isCode ? l.referralCodeReadyBody : l.referralWalletCreditedBody,
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            height: 1.45,
            color: cs.onSurfaceVariant,
          ),
        ),
        if (isCode && code != null) ...[
          const SizedBox(height: DonySpacing.lg - 2),
          Container(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.sm,
              DonySpacing.sm,
              DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: cs.primary, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code.code,
                    maxLines: 1,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                ReferralCopyButton(
                  semanticsLabel: l.referralCopyCodeAction,
                  onTap: () => copyReferralText(
                    context,
                    code.code,
                    l.referralCodeCopiedMessage,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.sm + 2),
          Row(
            children: [
              if (code.expiresAt != null)
                Expanded(
                  child: Text(
                    l.referralVoucherExpiresLabel(
                      formatReferralDate(l, code.expiresAt!),
                    ),
                    style: tt.bodySmall?.copyWith(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const Spacer(),
              Text(
                l.referralCodeSingleUse,
                style: tt.bodySmall?.copyWith(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// Copie [text] et confirme par un snackbar.
Future<void> copyReferralText(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    DonySnackbar.show(
      context,
      message: message,
      type: DonySnackbarType.success,
    );
  }
}

/// Bouton « Copier » blanc posé sur un fond teinté (lien d'invitation, code
/// de réduction). 44 pt de haut : la cible tactile minimale.
class ReferralCopyButton extends StatelessWidget {
  const ReferralCopyButton({
    super.key,
    required this.onTap,
    required this.semanticsLabel,
  });

  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: DonyPressable(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md + 2),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon('copy', size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                context.l10n.commonCopy,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
