import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:dony/features/referral/presentation/referral_format.dart';
import 'package:dony/features/referral/presentation/widgets/redeem_code_bottom_sheet.dart';
import 'package:dony/features/referral/presentation/widgets/referral_reward_sheets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

String _formatLongDate(AppLocalizations l, DateTime date) =>
    DateFormat.yMMMMd(l.localeName).format(date);

const _tabularFigures = [FontFeature.tabularFigures()];

/// Écran Parrainage : le lien à partager, les récompenses à choisir, les
/// filleuls et leur avancement.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key, this.prefillCode, this.pendingCodeStore});

  /// Code venu d'un lien d'invitation (`yadony://referral?code=…`) : si le
  /// compte n'a pas encore de parrain, la saisie du code s'ouvre pré-remplie.
  /// Jamais appliqué sans que la personne valide.
  final String? prefillCode;

  /// Code en attente, effacé une fois utilisé ou devenu sans objet.
  final PendingReferralCodeStore? pendingCodeStore;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  /// Le code du lien n'est proposé qu'une fois par ouverture de l'écran.
  /// Simple garde, jamais lue par le `build`.
  bool _prefillHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReferralBloc>().add(
          const ReferralLoadRequested(includeReferees: true),
        );
      }
    });
  }

  void _maybeOfferPrefill(BuildContext context, ReferralInfo info) {
    final code = widget.prefillCode;
    if (_prefillHandled || code == null) return;
    _prefillHandled = true;
    if (info.hasBeenReferred) {
      // Déjà parrainé : le lien n'a plus d'objet, l'écran s'ouvre simplement.
      unawaited(widget.pendingCodeStore?.clear());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) unawaited(_openRedeem(context, initialCode: code));
    });
  }

  Future<void> _openRedeem(BuildContext context, {String? initialCode}) async {
    final bloc = context.read<ReferralBloc>();
    final redeemed = await RedeemCodeBottomSheet.show(
      context,
      initialCode: initialCode ?? widget.pendingCodeStore?.current,
    );
    if (redeemed ?? false) {
      unawaited(widget.pendingCodeStore?.clear());
      bloc.add(const ReferralLoadRequested(includeReferees: true));
    }
  }

  Widget _buildBody(BuildContext context, ReferralState state) {
    if (state is ReferralError) {
      return _ErrorView(
        message: ErrorPresenter.resolve(
          state.error,
          l10n: context.l10n,
        ).message,
      );
    }
    if (state is ReferralLoaded) {
      return _LoadedBody(state: state, onRedeemTap: () => _openRedeem(context));
    }
    return const DonyDetailSkeleton();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<ReferralBloc, ReferralState>(
      // Le bloc est partagé avec le profil : il peut être déjà chargé à
      // l'ouverture. Le rechargement lancé par `initState` émet de toute
      // façon un nouvel état, à jour de `hasBeenReferred`.
      listenWhen: (_, current) => current is ReferralLoaded && !_prefillHandled,
      listener: (context, state) =>
          _maybeOfferPrefill(context, (state as ReferralLoaded).info),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            actions: const [DonyFeedbackButton()],
            title: Text(
              context.l10n.referralScreenTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            centerTitle: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: cs.onSurface,
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }
}

// ─── Loaded body ─────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state, required this.onRedeemTap});

  final ReferralLoaded state;
  final VoidCallback onRedeemTap;

  @override
  Widget build(BuildContext context) {
    final info = state.info;
    final l = context.l10n;
    final sections = <Widget>[
      _HeroCard(info: info),
      _InviteLinkCard(info: info),
      for (final referee in state.availableRewards)
        _RewardAvailableCard(
          key: ValueKey('reward-${referee.invitationId}'),
          referee: referee,
          info: info,
          loading: state.choosingInvitationId == referee.invitationId,
          enabled: !state.isChoosingReward,
        ),
      _StatsRow(state: state),
      if (info.activeVoucherCount > 0) _LegacyVouchersNote(info: info),
      if (state.refereesStatus != RefereesStatus.idle &&
          state.refereesStatus != RefereesStatus.unavailable)
        _RefereesSection(state: state),
      _HowItWorksSection(info: info),
      if (!info.hasBeenReferred)
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ),
            onPressed: onRedeemTap,
            child: Text(l.referralHaveCodeLink, textAlign: TextAlign.center),
          ),
        ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<ReferralBloc>();
        bloc.add(const ReferralLoadRequested(includeReferees: true));
        // Un rafraîchissement raté garde l'écran tel quel sans émettre :
        // l'indicateur ne doit pas tourner indéfiniment.
        await bloc.stream
            .firstWhere((s) => s is! ReferralLoading)
            .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.base,
          DonySpacing.sm,
          DonySpacing.base,
          DonySpacing.xxl,
        ),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: DonySpacing.base),
        itemBuilder: (context, index) => sections[index]
            .animate()
            .fadeIn(delay: (60 * index.clamp(0, 6)).ms, duration: 300.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }
}

// ─── Hero card ───────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.info});
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    // Couleurs primitives intentionnelles : carte de marque, bleu Yadony et
    // texte blanc dans les deux thèmes (le bleu clair du thème sombre ne
    // porterait pas le blanc à 4.5:1).
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.lg + 2,
        DonySpacing.lg,
        DonySpacing.lg + 2,
      ),
      decoration: BoxDecoration(
        color: DonyColors.blue500,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.referralHeroTitleDefault,
            style: tt.titleSmall?.copyWith(color: DonyColors.blue100),
          ),
          const SizedBox(height: DonySpacing.sm + 2),
          Text(
            l.referralHeroRewardTitle(
              formatRewardWalletAmount(l, info),
              info.effectiveRewardDiscountPercent,
            ),
            style: tt.displayMedium?.copyWith(
              color: DonyColors.textOnBrand,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: DonySpacing.sm + 2),
          Text(
            l.referralHeroRewardBody,
            style: tt.bodyMedium?.copyWith(
              color: DonyColors.blue50,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Invite link ─────────────────────────────────────────────────────────────

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.info});
  final ReferralInfo info;

  /// `https://yadony.com/r/ABCD` → `yadony.com/r/ABCD`.
  static String displayUrl(String url) =>
      url.replaceFirst(RegExp(r'^https?://'), '');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bloc = context.read<ReferralBloc>();
    final message = l.referralShareMessage(info.code, info.shareUrl);
    return _Card(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.referralLinkLabel,
            style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          // Rayons concentriques : 8 (bouton) + 4 (marge) = 12.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayUrl(info.shareUrl),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleLarge?.copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                ReferralCopyButton(
                  semanticsLabel: l.referralCopyLinkSemantics,
                  onTap: () {
                    bloc.add(const ReferralLinkCopied());
                    DonySnackbar.show(
                      context,
                      message: l.referralLinkCopiedMessage,
                      type: DonySnackbarType.success,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Text.rich(
            TextSpan(
              text: '${l.referralCodeInlineLabel} ',
              children: [
                TextSpan(
                  text: info.code,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            style: tt.bodySmall?.copyWith(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('referral-share-whatsapp'),
                  icon: DonyIcon('message-circle', size: 18, color: cs.surface),
                  label: Text(l.travelerContactWhatsApp),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onSurface,
                    foregroundColor: cs.surface,
                    minimumSize: const Size.fromHeight(48),
                    textStyle: tt.titleLarge,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                  ),
                  onPressed: () => bloc.add(
                    ReferralShared(
                      message,
                      channel: ReferralShareChannel.whatsapp,
                      sharePositionOrigin: sharePositionOriginFor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    key: const ValueKey('referral-share-sheet'),
                    icon: DonyIcon('share-2', size: 18, color: cs.primary),
                    label: Text(l.commonShare),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: tt.titleLarge,
                      side: BorderSide(color: cs.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                    ),
                    // Le bon récompense qui invite, pas qui est invité : le
                    // message ne promet rien au filleul.
                    onPressed: () => bloc.add(
                      ReferralShared(
                        message,
                        sharePositionOrigin: sharePositionOriginFor(
                          buttonContext,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reward available ────────────────────────────────────────────────────────

class _RewardAvailableCard extends StatelessWidget {
  const _RewardAvailableCard({
    super.key,
    required this.referee,
    required this.info,
    required this.loading,
    required this.enabled,
  });

  final Referee referee;
  final ReferralInfo info;
  final bool loading;
  final bool enabled;

  Future<void> _choose(BuildContext context) async {
    final bloc = context.read<ReferralBloc>();
    final result = await ReferralRewardChoiceSheet.show(
      context,
      bloc: bloc,
      referee: referee,
      info: info,
    );
    if (result == null || !context.mounted) return;
    await ReferralRewardConfirmationSheet.show(
      context,
      referee: result,
      info: info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = referee.displayName;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: DonyColors.terra500,
                  shape: BoxShape.circle,
                ),
                child: const DonyIcon(
                  'gift',
                  size: 20,
                  color: DonyColors.textOnBrand,
                ),
              ),
              const SizedBox(width: DonySpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.referralRewardAvailableTitle,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name == null
                          ? l.referralRewardAvailableBodyAnonymous
                          : l.referralRewardAvailableBody(name),
                      style: tt.bodySmall?.copyWith(
                        fontSize: 13,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          FilledButton(
            style: FilledButton.styleFrom(
              // Terre foncée dans les deux thèmes : le blanc y tient 4.6:1.
              backgroundColor: DonyColors.terra600,
              foregroundColor: DonyColors.textOnBrand,
              minimumSize: const Size.fromHeight(48),
              textStyle: tt.titleLarge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
            ),
            onPressed: enabled ? () => _choose(context) : null,
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DonyColors.textOnBrand,
                    ),
                  )
                : Text(l.referralChooseRewardButton),
          ),
        ],
      ),
    );
  }
}

// ─── Stats ───────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});
  final ReferralLoaded state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final info = state.info;
    final currency =
        state.referees
            .where((r) => r.earnedWalletAmount > 0)
            .map((r) => r.walletCurrency)
            .firstOrNull ??
        info.effectiveRewardWalletCurrency;
    return Row(
      children: [
        _StatBox(label: l.referralStatSignedUp, value: '${info.signedUp}'),
        const SizedBox(width: DonySpacing.sm),
        _StatBox(
          label: l.referralStatFirstDelivery,
          value: '${info.firstDeliveryCount}',
        ),
        const SizedBox(width: DonySpacing.sm),
        _StatBox(
          label: l.referralStatEarned,
          value: formatReferralAmount(l, state.earnedWalletAmount, currency),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: _Card(
        radius: DonyRadius.lg,
        padding: const EdgeInsets.all(DonySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  fontFeatures: _tabularFigures,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Anciens bons de commission ──────────────────────────────────────────────

class _LegacyVouchersNote extends StatelessWidget {
  const _LegacyVouchersNote({required this.info});
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Bons -50 % attribués avant la récompense au choix : une ligne discrète
    // tant qu'il en reste. Sans pourcentage connu, aucun chiffre inventé.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.voucherPercentOff == null
                ? l.referralVouchersUnknownPercent(info.activeVoucherCount)
                : l.referralVouchers(
                    info.activeVoucherCount,
                    info.voucherPercentOff!,
                  ),
            style: tt.bodySmall?.copyWith(fontSize: 13, color: cs.onSurface),
          ),
          if (info.nextVoucherExpiresAt != null) ...[
            const SizedBox(height: DonySpacing.xxs),
            Text(
              l.referralVoucherExpiresLabel(
                _formatLongDate(l, info.nextVoucherExpiresAt!),
              ),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Referees ────────────────────────────────────────────────────────────────

class _RefereesSection extends StatelessWidget {
  const _RefereesSection({required this.state});
  final ReferralLoaded state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final Widget content = switch (state.refereesStatus) {
      RefereesStatus.loading => const Padding(
        padding: EdgeInsets.all(DonySpacing.base),
        child: Column(
          children: [
            DonySkeletonBox(height: 40),
            SizedBox(height: DonySpacing.md),
            DonySkeletonBox(height: 40),
          ],
        ),
      ),
      RefereesStatus.error => Padding(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.referralRefereesError,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => context.read<ReferralBloc>().add(
                const ReferralRefereesRequested(reset: true),
              ),
              child: Text(l.commonRetry),
            ),
          ],
        ),
      ),
      _ when state.referees.isEmpty => Padding(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Text(
          l.referralRefereesEmpty,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      _ => Column(
        children: [
          for (var i = 0; i < state.referees.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            _RefereeRow(referee: state.referees[i], info: state.info),
          ],
          if (!state.refereesLast) ...[
            Divider(height: 1, color: cs.outlineVariant),
            SizedBox(
              height: 48,
              child: state.loadingMoreReferees
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: () => context.read<ReferralBloc>().add(
                        const ReferralRefereesRequested(),
                      ),
                      child: Text(l.referralRefereesLoadMore),
                    ),
            ),
          ],
        ],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l.referralRefereesSectionTitle),
        const SizedBox(height: DonySpacing.sm + 2),
        _Card(child: content),
      ],
    );
  }
}

class _RefereeRow extends StatelessWidget {
  const _RefereeRow({required this.referee, required this.info});
  final Referee referee;
  final ReferralInfo info;

  bool get _obtained =>
      referee.rewardStatus == RewardStatus.chosen ||
      referee.status == RefereeStatus.rewarded;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final highlighted = referee.isRewardAvailable || _obtained;
    final initials = referee.initials;
    final code = referee.rewardChoice == RewardChoice.discountCode
        ? referee.discountCode
        : null;
    final codeActive = code != null && !code.used && !code.expired;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
            ),
            child: initials == null
                ? DonyIcon(
                    'user',
                    size: 18,
                    color: highlighted
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                  )
                : ExcludeSemantics(
                    child: Text(
                      initials,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: highlighted
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referee.displayName ?? l.referralRefereeAnonymous,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
                ),
                if (_subtitle(l) case final subtitle?) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (codeActive) ...[
                  const SizedBox(height: DonySpacing.xs),
                  _InlineCode(code: code.code),
                ],
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          _badge(l, cs),
        ],
      ),
    );
  }

  String? _subtitle(AppLocalizations l) {
    if (referee.rewardStatus == RewardStatus.chosen) {
      switch (referee.rewardChoice) {
        case RewardChoice.walletCredit:
          return l.referralWalletCredited(
            formatRefereeWalletAmount(l, referee, info),
          );
        case RewardChoice.discountCode:
          final code = referee.discountCode;
          if (code == null) return null;
          if (code.used) return l.referralRefereeCodeUsed;
          if (code.expired) return l.referralRefereeCodeExpired;
          final expiresAt = code.expiresAt;
          return expiresAt == null
              ? null
              : l.referralVoucherExpiresLabel(formatReferralDate(l, expiresAt));
        case RewardChoice.commissionVoucher:
        case null:
          return l.referralRefereeVoucherObtained;
      }
    }
    if (referee.status == RefereeStatus.rewarded) {
      return l.referralRefereeVoucherObtained;
    }
    final signedUpAt = referee.signedUpAt;
    return signedUpAt == null
        ? null
        : l.referralRefereeSignedUp(formatReferralShortDate(l, signedUpAt));
  }

  Widget _badge(AppLocalizations l, ColorScheme cs) {
    final (String label, Color bg, Color fg) = switch (referee) {
      _ when referee.isRewardAvailable => (
        l.referralBadgeToChoose,
        cs.secondaryContainer,
        cs.onSecondaryContainer,
      ),
      _ when _obtained => (
        l.referralBadgeObtained,
        cs.successLight,
        cs.success,
      ),
      _ when referee.status == RefereeStatus.firstDelivery => (
        l.referralStatFirstDelivery,
        cs.primaryContainer,
        cs.onPrimaryContainer,
      ),
      _ => (
        l.referralBadgeNoShipmentYet,
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
    };
    return _Badge(label: label, background: bg, foreground: fg);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Code de réduction obtenu, copiable d'un tap.
class _InlineCode extends StatelessWidget {
  const _InlineCode({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${l.referralCopyCodeAction} $code',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        onTap: () =>
            copyReferralText(context, code, l.referralCodeCopiedMessage),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              DonyIcon('copy', size: 14, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── How it works ────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({required this.info});
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [
      (l.referralStepShareTitle, l.referralStepShareBody),
      (l.referralStepShipTitle, l.referralStepShipBody),
      (
        l.referralStepChooseTitle,
        l.referralStepChooseBody(
          formatRewardWalletAmount(l, info),
          info.effectiveRewardDiscountPercent,
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l.referralHowItWorksTitle),
        const SizedBox(height: DonySpacing.sm + 2),
        _Card(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _Step(number: i + 1, title: steps[i].$1, body: steps[i].$2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});
  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: tt.titleMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w800,
              fontFeatures: _tabularFigures,
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.titleLarge?.copyWith(color: cs.onSurface)),
              const SizedBox(height: 2),
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
      ],
    );
  }
}

// ─── Shared pieces ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: DonySpacing.xs),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = DonyRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outline),
      ),
      child: child,
    );
  }
}

// ─── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyMascotteAnimated(
              type: DonyMascotteType.assis,
              size: DonyMascotteSize.lg,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              l.commonSomethingWentWrong,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: l.commonRetry,
              iconAsset: 'refresh-cw',
              fullWidth: false,
              onPressed: () => context.read<ReferralBloc>().add(
                const ReferralLoadRequested(includeReferees: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
