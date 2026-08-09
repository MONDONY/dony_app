import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/profile/presentation/widgets/activate_card_payments_cta_card.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
import 'package:dony/features/profile/presentation/widgets/wallet_balance_card.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/presentation/widgets/redeem_code_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Sections de l'écran Profil.
///
/// L'écran est une page unique : les onglets Activité / Compte / Réglages ont
/// été retirés (chacun ne portait plus que trois ou quatre lignes une fois
/// « Mes trajets et colis » parti vers le hub Activités). Les sections sont
/// donc découpées par sujet et ordonnées par fréquence d'usage — compte et
/// argent d'abord, réglages en bas.
///
/// Aucune section n'est conditionnée au rôle : depuis le modèle double rôle,
/// tout utilisateur est à la fois voyageur et expéditeur dès l'inscription.
/// Chacun peut donc activer les paiements par carte et passer en compte PRO.

// ── MON COMPTE ────────────────────────────────────────────────────────────────

class ProfileAccountSection extends StatelessWidget {
  const ProfileAccountSection({super.key, required this.user});

  final UserModel? user;

  static bool _computeVisible(UserModel? user, bool phoneAuthEnabled) {
    final showKyc = user?.kycStatus != 'VERIFIED';
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;
    final hasPhone = user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;
    final showPhoneRow = phoneAuthEnabled && !hasPhone;
    final showEmailRow = !hasEmail;
    return showKyc || showPhoneRow || showEmailRow;
  }

  /// Lecture non réactive du flag SMS, pour que `_sections()` sache s'il
  /// doit réserver un espacement autour de cette section avant même son
  /// premier `build()` — sans ça, une section qui se réduit à rien (compte
  /// entièrement vérifié) laisse ses deux espacements voisins s'empiler.
  static bool isVisible(UserModel? user) =>
      _computeVisible(user, smsAuthEnabledListenable.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Une fois vérifié ou renseigné, chaque élément quitte « Mon compte » —
    // rien à vérifier deux fois, la section ne sert qu'aux actions restantes.
    return ValueListenableBuilder<bool>(
      valueListenable: smsAuthEnabledListenable,
      builder: (_, phoneEnabled, _) {
        final showKyc = user?.kycStatus != 'VERIFIED';
        final hasEmail = user?.email != null && user!.email!.isNotEmpty;
        final hasPhone = user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty;
        final showPhoneRow = phoneEnabled && !hasPhone;
        final showEmailRow = !hasEmail;

        if (!showKyc && !showPhoneRow && !showEmailRow) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileSectionLabel(label: 'MON COMPTE', cs: cs),
            if (showKyc) ...[
              ProfileListSection(tiles: [kycTile(context, user)]),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (showPhoneRow || showEmailRow)
              _ContactSecuritySection(
                showPhoneRow: showPhoneRow,
                showEmailRow: showEmailRow,
                onPhoneTap: () => AddPhoneSheet.show(context),
                onEmailTap: () => AddEmailSheet.show(context),
              ),
          ],
        );
      },
    );
  }
}

// ── ARGENT ────────────────────────────────────────────────────────────────────

class ProfileMoneySection extends StatelessWidget {
  const ProfileMoneySection({super.key, required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: 'ARGENT', cs: cs),
        // Le CTA d'activation Stripe vit au-dessus de la section qu'il
        // concerne, et non en tête de page : il y est contextuel, et trois
        // bannières empilées en haut d'écran noyaient le reste.
        ActivateCardPaymentsCtaCard(stripeStatus: user?.stripeAccountStatus),
        if (user?.stripeAccountStatus != 'ONBOARDING_COMPLETE')
          const SizedBox(height: DonySpacing.sm),
        const WalletBalanceCard(),
        const SizedBox(height: DonySpacing.sm),
        ProfileListSection(
          tiles: [
            DonyListTile(
              iconAsset: 'piggy-bank',
              iconColor: cs.success,
              iconBgColor: cs.successLight,
              label: 'Recevoir mes paiements',
              onTap: () => context.push('/payments/onboarding'),
            ),
            DonyListTile(
              iconAsset: 'credit-card',
              iconColor: DonyColors.purple,
              iconBgColor: DonyColors.violetLight,
              label: 'Carte commission espèces',
              onTap: () => context.push('/payments/commission-method'),
            ),
            DonyListTile(
              iconAsset: 'layout-grid',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Ma grille de prix',
              subtitle: 'Tarifs par article pour vos trajets',
              showDivider: false,
              onTap: () => context.push('/profile/price-grid'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── MA RÉPUTATION ─────────────────────────────────────────────────────────────

class ProfileReputationSection extends StatelessWidget {
  const ProfileReputationSection({super.key, required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: 'MA RÉPUTATION', cs: cs),
        ProfileListSection(
          tiles: [
            DonyListTile(
              iconAsset: 'user',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Mon profil public',
              subtitle: 'Ce que voient les autres',
              onTap: () => context.push(
                '/profile/public',
                extra: ProfilePublicArgs(
                  userId: user?.id,
                  showSubscribe: false,
                ),
              ),
            ),
            DonyListTile(
              iconAsset: 'star',
              iconColor: cs.secondary,
              iconBgColor: cs.secondaryContainer,
              label: 'Mes avis reçus',
              showDivider: false,
              onTap: () => context.push('/profile/reviews'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── MES AVANTAGES ─────────────────────────────────────────────────────────────

class ProfileAdvantagesSection extends StatelessWidget {
  const ProfileAdvantagesSection({
    super.key,
    required this.user,
    required this.isProAccount,
  });

  final UserModel? user;
  final bool isProAccount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: 'MES AVANTAGES', cs: cs),
        ProfileListSection(
          tiles: [
            DonyListTile(
              iconAsset: 'award',
              iconColor: isProAccount ? cs.success : cs.warning,
              iconBgColor: isProAccount ? cs.successLight : cs.warningLight,
              label: isProAccount ? 'Mon profil PRO' : 'Passer en compte PRO',
              trailing: isProAccount
                  ? DonyIcon('badge-check', color: cs.success, size: 18)
                  : null,
              onTap: user != null
                  ? () => context.push('/profile/upgrade-to-pro')
                  : null,
            ),
            DonyListTile(
              iconAsset: 'user-plus',
              iconColor: cs.success,
              iconBgColor: cs.successLight,
              label: 'Parrainages',
              trailing: Text(
                '0 invité',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              onTap: () => context.push('/profile/referral'),
            ),
            BlocBuilder<ReferralBloc, ReferralState>(
              builder: (context, referralState) {
                final alreadyReferred =
                    referralState is ReferralLoaded &&
                    referralState.info.hasBeenReferred;
                if (alreadyReferred) return const SizedBox.shrink();
                return DonyListTile(
                  iconAsset: 'gift',
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'J\'ai un code parrain',
                  showDivider: false,
                  onTap: () async {
                    final redeemed = await RedeemCodeBottomSheet.show(context);
                    if ((redeemed ?? false) && context.mounted) {
                      context.read<ReferralBloc>().add(
                        const ReferralLoadRequested(),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── SUIVI ─────────────────────────────────────────────────────────────────────

class ProfileFollowUpSection extends StatelessWidget {
  const ProfileFollowUpSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: 'SUIVI', cs: cs),
        ProfileListSection(
          tiles: [
            DonyListTile(
              iconAsset: 'scale',
              iconColor: cs.error,
              iconBgColor: cs.errorContainer.withValues(alpha: 0.5),
              label: 'Mes litiges',
              subtitle: 'Suivi de vos litiges',
              onTap: () => context.push('/disputes'),
            ),
            DonyListTile(
              iconAsset: 'bell',
              iconColor: cs.tertiary,
              iconBgColor: cs.tertiaryContainer.withValues(alpha: 0.5),
              label: 'Mes abonnements',
              subtitle: 'Alertes corridors et voyageurs',
              showDivider: false,
              onTap: () => context.push('/profile/subscriptions'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── AIDE & RÉGLAGES ───────────────────────────────────────────────────────────

class ProfileHelpSection extends StatelessWidget {
  const ProfileHelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: 'AIDE & RÉGLAGES', cs: cs),
        ProfileListSection(
          tiles: [
            DonyListTile(
              iconAsset: 'sliders-horizontal',
              label: 'Paramètres',
              subtitle: 'Thème, langue, notifications, sécurité',
              onTap: () => context.push('/settings'),
            ),
            DonyListTile(
              iconAsset: 'circle-help',
              iconColor: cs.tertiary,
              iconBgColor: cs.tertiaryContainer,
              label: 'FAQ & aide',
              subtitle: 'Réponses aux questions fréquentes',
              onTap: () => context.push('/profile/help/faq'),
            ),
            DonyListTile(
              iconAsset: 'globe',
              iconColor: cs.secondary,
              iconBgColor: cs.secondaryContainer,
              label: 'Réseaux sociaux et tutoriels',
              subtitle: 'Vidéos et communauté Yadony',
              onTap: () => context.push('/profile/community'),
            ),
            DonyListTile(
              iconAsset: 'headset',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Contacter le support',
              subtitle: 'Réponse généralement sous 24 h',
              showDivider: false,
              onTap: () => context.push('/profile/help/contact'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Section Contact & Sécurité ────────────────────────────────────────────────

class _ContactSecuritySection extends StatelessWidget {
  const _ContactSecuritySection({
    required this.showPhoneRow,
    required this.showEmailRow,
    required this.onPhoneTap,
    required this.onEmailTap,
  });

  final bool showPhoneRow;
  final bool showEmailRow;
  final VoidCallback onPhoneTap;
  final VoidCallback onEmailTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (showPhoneRow)
            _ContactRow(
              iconAsset: 'phone',
              iconBg: cs.primaryContainer,
              iconColor: cs.primary,
              typeLabel: 'TÉLÉPHONE',
              isFirst: true,
              isLast: !showEmailRow,
              onTap: onPhoneTap,
            ),
          if (showEmailRow)
            _ContactRow(
              iconAsset: 'at-sign',
              iconBg: cs.successLight,
              iconColor: cs.success,
              typeLabel: 'E-MAIL',
              isFirst: !showPhoneRow,
              isLast: true,
              onTap: onEmailTap,
            ),
        ],
      ),
    );
  }
}

/// Ligne « à renseigner » — n'apparaît que pour un contact encore absent ou
/// non vérifié : une fois rempli, la ligne quitte « Mon compte » entièrement,
/// donc son seul état possible ici est « Non ajouté ».
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.iconAsset,
    required this.iconBg,
    required this.iconColor,
    required this.typeLabel,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String iconAsset;
  final Color iconBg;
  final Color iconColor;
  final String typeLabel;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isFirst
                ? const Radius.circular(DonyRadius.card)
                : Radius.zero,
            bottom: isLast
                ? const Radius.circular(DonyRadius.card)
                : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                DonyIconContainer(
                  iconAsset: iconAsset,
                  backgroundColor: iconBg,
                  iconColor: iconColor,
                  borderRadius: DonyRadius.sm,
                  size: DonyIconContainerSize.sm,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        'Non ajouté',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                const _StatusBadge(),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: DonySpacing.lg + 32),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primaryContainer;
    final fg = cs.primary;
    const label = '+ Ajouter';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel({super.key, required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.xs,
        0,
        DonySpacing.xs,
        DonySpacing.sm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── KYC tile partagée ─────────────────────────────────────────────────────────

DonyListTile kycTile(BuildContext context, UserModel? user) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return DonyListTile(
    iconAsset: 'shield',
    iconColor: cs.primary,
    iconBgColor: cs.primaryContainer,
    label: 'Documents d\'identité',
    showDivider: false,
    trailing: switch (user?.kycStatus) {
      'VERIFIED' => Text(
        'Vérifié',
        style: tt.labelMedium?.copyWith(
          color: cs.success,
          fontWeight: FontWeight.w600,
        ),
      ),
      'REJECTED' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('triangle-alert', color: cs.warning, size: 16),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'Réessayer',
            style: tt.labelMedium?.copyWith(
              color: cs.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      'PENDING' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: cs.warning,
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'En cours',
            style: tt.labelMedium?.copyWith(
              color: cs.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      _ => Text(
        'Vérifier',
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    },
    onTap: user?.kycStatus == 'VERIFIED'
        ? () => KycStatusBottomSheet.show(context)
        : () => KycOnboardingBottomSheet.show(context),
  );
}

// ── Profile completion banner ─────────────────────────────────────────────────

/// Couleur de la jauge/bannière de complétion selon l'avancement : rouge en
/// dessous d'1/3 (urgent), orange jusqu'aux 2/3 (comportement historique),
/// bleu au-delà (presque fini). Jamais vert : à 100% la bannière disparaît
/// entièrement (`ProfileScreen._sections` la conditionne sur
/// `!user.isProfileComplete`), donc ce palier n'est jamais visuellement
/// atteint. Partagé avec `_CompletionGauge` (edit_profile_screen.dart) pour
/// que les deux jauges du même profil affichent toujours la même couleur.
({Color base, Color light}) profileCompletionTierColor(
  ColorScheme cs,
  double pct,
) {
  if (pct < 1 / 3) return (base: cs.error, light: cs.errorLight);
  if (pct < 2 / 3) return (base: cs.warning, light: cs.warningLight);
  return (base: cs.info, light: cs.infoLight);
}

class ProfileCompletionBanner extends StatelessWidget {
  const ProfileCompletionBanner({
    super.key,
    required this.user,
    required this.onTap,
  });

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final completed = user.profileCompletionSteps;
    const total = UserModel.profileTotalSteps;
    final pct = completed / total;
    final tier = profileCompletionTierColor(cs, pct);

    final missing = <String>[];
    if (!(user.avatarUrl?.isNotEmpty ?? false)) missing.add('Photo');
    if (!(user.firstName?.isNotEmpty ?? false)) missing.add('Prénom');
    if (!(user.lastName?.isNotEmpty ?? false)) missing.add('Nom');
    if (!(user.email?.isNotEmpty ?? false)) missing.add('Email');
    if (!(user.phoneNumber?.isNotEmpty ?? false)) missing.add('Téléphone');
    if (user.birthDate == null) missing.add('Date de naissance');
    if (!(user.city?.isNotEmpty ?? false)) missing.add('Ville');
    if (!(user.bio?.isNotEmpty ?? false)) missing.add('À propos');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: tier.light,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: tier.base.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: tier.base.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon('notebook-pen', color: tier.base, size: 18),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil incomplet',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${(pct * 100).round()}% complété · Compléter maintenant',
                        style: tt.bodySmall?.copyWith(
                          color: tier.base,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                DonyIcon('chevron-right', color: cs.onSurfaceVariant, size: 18),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(DonyRadius.xs),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: cs.outline,
                valueColor: AlwaysStoppedAnimation<Color>(tier.base),
                minHeight: 5,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.md),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: missing
                    .map((m) => _MissingChip(label: m, color: tier.base))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('plus', color: color, size: 12),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── List Section wrapper ──────────────────────────────────────────────────────

/// Variante locale de `DonyListSection` acceptant n'importe quel widget : la
/// section Avantages insère un `BlocBuilder` parmi ses lignes, ce que la
/// version du design system (typée `List<DonyListTile>`) refuse.
class ProfileListSection extends StatelessWidget {
  const ProfileListSection({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(children: tiles),
    );
  }
}
