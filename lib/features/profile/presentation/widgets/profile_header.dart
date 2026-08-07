import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.isTraveler,
    required this.isSender,
    required this.isKycVerified,
    required this.isProAccount,
    this.avatarUrl,
    this.phoneNumber,
    this.email,
    this.city,
    this.onEditProfile,
    this.topPadding,
  });

  final String displayName;
  final bool isTraveler;
  final bool isSender;
  final bool isKycVerified;
  final bool isProAccount;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? email;
  final String? city;
  final VoidCallback? onEditProfile;

  /// Padding haut (zone status bar) — passé explicitement pour que la sonde de
  /// mesure et le rendu réel utilisent une valeur identique (les deux vivent
  /// dans des sous-arbres au `MediaQuery` différent). Repli sur le MediaQuery
  /// local si non fourni.
  final double? topPadding;

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
        DonySpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row : avatar + infos + bouton édition ────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyAvatar(
                name: displayName,
                imageUrl: avatarUrl,
                size: DonyAvatarSize.xl,
                verified: isKycVerified,
                pro: isProAccount,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + badge VÉRIFIÉ / PRO
                    Row(
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
                        if (isKycVerified) ...[
                          const SizedBox(width: DonySpacing.xs),
                          _BadgeLabel(isPro: isProAccount),
                        ],
                      ],
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
                      email: email,
                      isKycVerified: isKycVerified,
                    ),
                  ],
                ),
              ),
              // Bouton édition
              Semantics(
                button: true,
                container: true,
                excludeSemantics: true,
                label: 'Modifier le profil',
                child: GestureDetector(
                onTap: onEditProfile,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: DonyIcon(
                    'square-pen',
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Badge label VÉRIFIÉ / PRO ─────────────────────────────────────────────────

class _BadgeLabel extends StatelessWidget {
  const _BadgeLabel({required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isPro ? DonyColors.amberLight : DonyColors.blue50,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        isPro ? 'PRO' : 'VÉRIFIÉ',
        style: tt.labelSmall?.copyWith(
          color: isPro ? DonyColors.amberDark : DonyColors.blue700,
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
    this.email,
    required this.isKycVerified,
  });

  final String? phoneNumber;
  final String? email;
  final bool isKycVerified;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phoneNumber != null && phoneNumber!.isNotEmpty;
    final hasEmail = email != null && email!.isNotEmpty;

    return ValueListenableBuilder<bool>(
      valueListenable: smsAuthEnabledListenable,
      builder: (_, phoneAuthEnabled, __) => Wrap(
        spacing: DonySpacing.xs,
        runSpacing: DonySpacing.xs,
        children: [
          // Tant que le SMS OTP backend n'est pas confirmé, personne ne peut
          // plus ajouter/vérifier de numéro : le chip "manquant" serait une
          // relance permanente pour une action devenue impossible.
          if (phoneAuthEnabled)
            if (hasPhone)
              const _Chip(
                label: 'Tél. ✓',
                iconAsset: 'phone',
                bg: DonyColors.success50,
                fg: DonyColors.success700,
              )
            else
              const _Chip(
                label: 'Tél. manquant',
                iconAsset: 'phone',
                bg: DonyColors.neutral100,
                fg: DonyColors.neutral500,
              ),
          if (hasEmail)
            const _Chip(
              label: 'Email ✓',
              iconAsset: 'mail',
              bg: DonyColors.success50,
              fg: DonyColors.success700,
            )
          else
            const _Chip(
              label: 'Email manquant',
              iconAsset: 'mail',
              bg: DonyColors.warning50,
              fg: DonyColors.warning700,
            ),
          if (isKycVerified)
            const _Chip(
              label: 'Identité ✓',
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
