import 'dart:async';

import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/phone_verification_badge.dart';
import 'package:dony/core/phone/phone_verification_level.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.isTraveler,
    required this.isSender,
    required this.isKycVerified,
    required this.isProAccount,
    this.gpPro = false,
    this.avatarUrl,
    this.phoneNumber,
    this.declaredPhoneLevel,
    this.email,
    this.city,
    this.username,
    this.topPadding,
    this.trailingInset = 0,
    this.onTap,
  });

  final String displayName;
  final bool isTraveler;
  final bool isSender;
  final bool isKycVerified;
  final bool isProAccount;

  /// GP Pro : coche de l'avatar en argent (l'or du PRO prime).
  final bool gpPro;
  final String? avatarUrl;
  final String? phoneNumber;

  /// Niveau du numéro seulement déclaré (pays sans SMS) ; `null` sans numéro
  /// déclaré. Ignoré dès qu'un [phoneNumber] vérifié par SMS existe.
  final PhoneVerificationLevel? declaredPhoneLevel;
  final String? email;
  final String? city;

  /// Identifiant public (`awa.diallo`), sans arobase : la puce le montre et
  /// un tap le copie. Absent ou vide : pas de puce.
  final String? username;

  /// Padding haut (zone status bar) — passé explicitement pour que la sonde de
  /// mesure et le rendu réel utilisent une valeur identique (les deux vivent
  /// dans des sous-arbres au `MediaQuery` différent). Repli sur le MediaQuery
  /// local si non fourni.
  final double? topPadding;

  /// Largeur, à droite, laissée libre par la ligne nom + badge. Ce header est
  /// le fond d'une `SliverAppBar` : les boutons d'action (scarabée, burger)
  /// se dessinent PAR-DESSUS, en haut à droite. Sans cette réserve, un nom
  /// long ou le badge PRO passe sous les boutons (vu sur le build 72).
  /// L'écran passe la largeur réelle de ses actions.
  final double trailingInset;

  /// Tap sur l'avatar ou le nom (FLUTTER-9X) : ouvre le profil. Le reste du
  /// fond reste inerte, les actions de l'AppBar se dessinent par-dessus.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final topPad = topPadding ?? MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        topPad + DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row : avatar + infos ─────────────────────────────────────
          // Le crayon « Modifier le profil » a quitté ce header : l'édition
          // vit dans la feuille de menu du burger, et derrière un tap sur
          // l'avatar ou le nom (FLUTTER-9X).
          _Tappable(
            onTap: onTap,
            label: context.l10n.profileHeaderOpenSemantics,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyAvatar(
                  name: displayName,
                  imageUrl: avatarUrl,
                  size: DonyAvatarSize.xl,
                  verified: isKycVerified,
                  pro: isProAccount,
                  gpPro: gpPro,
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + badge PRO, à l'écart des actions de
                      // la SliverAppBar (voir [trailingInset]).
                      Padding(
                        padding: EdgeInsets.only(right: trailingInset),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: tt.headlineMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Pas de badge « VÉRIFIÉ » ici : la puce « Identité ✓ »
                            // en dessous le dit déjà. Seul PRO reste à côté du nom.
                            if (isKycVerified && isProAccount) ...[
                              const SizedBox(width: DonySpacing.xs),
                              const _ProBadge(),
                            ],
                          ],
                        ),
                      ),
                      if (city != null && city!.isNotEmpty) ...[
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          city!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: DonySpacing.sm),
                      // Chips tél / email / KYC
                      _ContactChips(
                        phoneNumber: phoneNumber,
                        declaredPhoneLevel: declaredPhoneLevel,
                        email: email,
                        isKycVerified: isKycVerified,
                        username: username,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.onTap,
    required this.label,
    required this.child,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    if (tap == null) return child;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: const Key('profile-header-open'),
        onTap: tap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: child,
      ),
    );
  }
}

// ── Badge PRO ─────────────────────────────────────────────────────────────────

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: DonyColors.kycBadgeGold,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        context.l10n.profileProBadge,
        style: tt.labelSmall?.copyWith(
          color: const Color(0xFF2B1B00),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Chips contact ─────────────────────────────────────────────────────────────

class _ContactChips extends StatelessWidget {
  const _ContactChips({
    this.phoneNumber,
    this.declaredPhoneLevel,
    this.email,
    required this.isKycVerified,
    this.username,
  });

  final String? phoneNumber;
  final PhoneVerificationLevel? declaredPhoneLevel;
  final String? email;
  final bool isKycVerified;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phoneNumber != null && phoneNumber!.isNotEmpty;
    final hasEmail = email != null && email!.isNotEmpty;
    final l = context.l10n;

    return ValueListenableBuilder<bool>(
      valueListenable: smsAuthEnabledListenable,
      builder: (_, phoneAuthEnabled, _) => Wrap(
        spacing: DonySpacing.xs,
        runSpacing: DonySpacing.xs,
        children: [
          if (username != null && username!.isNotEmpty)
            _UsernameChip(username: username!),
          // Tant que le SMS OTP backend n'est pas confirmé, personne ne peut
          // plus ajouter/vérifier de numéro : le chip "manquant" serait une
          // relance permanente pour une action devenue impossible.
          if (phoneAuthEnabled)
            if (hasPhone)
              _Chip(
                label: l.profileChipPhoneVerified,
                iconAsset: 'phone',
                bg: DonyColors.success50,
                fg: DonyColors.success700,
              )
            else if (declaredPhoneLevel != null)
              PhoneVerificationBadge(declaredPhoneLevel!)
            else
              _Chip(
                label: l.profileChipPhoneMissing,
                iconAsset: 'phone',
                bg: DonyColors.neutral100,
                fg: DonyColors.neutral500,
              ),
          if (hasEmail)
            _Chip(
              label: l.profileChipEmailVerified,
              iconAsset: 'mail',
              bg: DonyColors.success50,
              fg: DonyColors.success700,
            )
          else
            _Chip(
              label: l.profileChipEmailMissing,
              iconAsset: 'mail',
              bg: DonyColors.warning50,
              fg: DonyColors.warning700,
            ),
          if (isKycVerified)
            _Chip(
              label: l.profileChipIdentityVerified,
              iconAsset: 'shield-check',
              bg: DonyColors.blue50,
              fg: DonyColors.blue700,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.iconAsset,
    required this.bg,
    required this.fg,
  });

  final String label;
  final String iconAsset;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(iconAsset, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Puce de l'identifiant : un tap le copie dans le presse-papiers.
///
/// Le header est le fond d'une `SliverAppBar` et son avatar/nom ouvrent le
/// profil : la puce a son propre `InkWell`, qui gagne l'arène de gestes sur
/// le toucher et n'appelle donc jamais `onTap` du header.
class _UsernameChip extends StatelessWidget {
  const _UsernameChip({required this.username});

  final String username;

  Future<void> _copy(BuildContext context) async {
    final message = context.l10n.usernameCopied;
    await Clipboard.setData(ClipboardData(text: username));
    if (!context.mounted) return;
    DonySnackbar.show(
      context,
      message: message,
      type: DonySnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    const fg = DonyColors.blue700;
    return Semantics(
      button: true,
      label: context.l10n.usernameCopySemantics(username),
      excludeSemantics: true,
      child: Material(
        color: DonyColors.blue50,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        child: InkWell(
          key: const Key('profile-username-chip'),
          borderRadius: BorderRadius.circular(DonyRadius.full),
          onTap: () => unawaited(_copy(context)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: DonySpacing.xxs + 1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DonyIcon('at-sign', size: 11, color: fg),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    username,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const DonyIcon('copy', size: 11, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
