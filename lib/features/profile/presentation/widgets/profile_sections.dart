import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/profile/presentation/widgets/activate_card_payments_cta_card.dart';
import 'package:dony/features/profile/presentation/widgets/add_contact_sheets.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: 'MON COMPTE', cs: cs),
        ProfileListSection(tiles: [kycTile(context, user)]),
        const SizedBox(height: DonySpacing.sm),
        _ContactSecuritySection(
          phoneNumber: user?.phoneNumber,
          email: user?.email,
          onPhoneTap: () => AddPhoneSheet.show(context),
          onEmailTap: () => AddEmailSheet.show(context),
        ),
      ],
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
        ProfileListSection(
          tiles: [
            DonyListTile(
              iconAsset: 'wallet',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Mon portefeuille',
              subtitle: 'Solde & recharges',
              onTap: () => context.push('/payments/wallet'),
            ),
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
              label: 'Carte commission cash',
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

    // « FAQ & aide » n'est plus ici : le hub Activités la porte dans sa
    // section Outils. Préférences et Support ne pesaient qu'une ligne
    // chacune, elles fusionnent.
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
              iconAsset: 'headset',
              iconColor: cs.primary,
              iconBgColor: cs.primaryContainer,
              label: 'Contacter le support',
              subtitle: 'On répond sous 24 h',
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
    required this.phoneNumber,
    required this.email,
    required this.onPhoneTap,
    required this.onEmailTap,
  });

  final String? phoneNumber;
  final String? email;
  final VoidCallback onPhoneTap;
  final VoidCallback onEmailTap;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phoneNumber != null && phoneNumber!.isNotEmpty;
    final hasEmail = email != null && email!.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ContactRow(
            iconAsset: 'phone',
            iconBg: cs.primaryContainer,
            iconColor: cs.primary,
            typeLabel: 'TÉLÉPHONE',
            value: hasPhone ? phoneNumber! : 'Non ajouté',
            isEmpty: !hasPhone,
            isVerified: hasPhone,
            showDivider: true,
            onTap: onPhoneTap,
          ),
          _ContactRow(
            iconAsset: 'at-sign',
            iconBg: cs.successLight,
            iconColor: cs.success,
            typeLabel: 'E-MAIL',
            value: hasEmail ? email! : 'Non ajouté',
            isEmpty: !hasEmail,
            isVerified: hasEmail,
            showDivider: false,
            onTap: onEmailTap,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.iconAsset,
    required this.iconBg,
    required this.iconColor,
    required this.typeLabel,
    required this.value,
    required this.isEmpty,
    required this.isVerified,
    required this.showDivider,
    required this.onTap,
  });

  final String iconAsset;
  final Color iconBg;
  final Color iconColor;
  final String typeLabel;
  final String value;
  final bool isEmpty;
  final bool isVerified;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: showDivider
              ? const BorderRadius.vertical(
                  top: Radius.circular(DonyRadius.card),
                )
              : const BorderRadius.vertical(
                  bottom: Radius.circular(DonyRadius.card),
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
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                          fontWeight: isEmpty
                              ? FontWeight.w400
                              : FontWeight.w600,
                          fontStyle: isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                _StatusBadge(isVerified: isVerified),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: DonySpacing.lg + 32),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isVerified});
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isVerified ? cs.successLight : cs.primaryContainer;
    final fg = isVerified ? cs.success : cs.primary;
    final label = isVerified ? '✓ Vérifié' : '+ Ajouter';

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
    label: 'Documents KYC',
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

    final missing = <String>[];
    if (!(user.firstName?.isNotEmpty ?? false) &&
        !(user.lastName?.isNotEmpty ?? false)) {
      missing.add('Votre nom');
    }
    if (user.birthDate == null) missing.add('Date de naissance');
    if (!(user.city?.isNotEmpty ?? false)) missing.add("Lieu d'habitation");

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.warningLight,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon('notebook-pen', color: cs.warning, size: 18),
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
                        '${(completed / total * 100).round()}% complété · Compléter maintenant',
                        style: tt.bodySmall?.copyWith(
                          color: cs.warning,
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
                value: completed / total,
                backgroundColor: cs.outline,
                valueColor: AlwaysStoppedAnimation<Color>(cs.warning),
                minHeight: 5,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.md),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: missing.map((m) => _MissingChip(label: m)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('plus', color: cs.warning, size: 12),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.warning,
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
