import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.activeRole,
    required this.isTraveler,
    required this.isSender,
    required this.isKycVerified,
    required this.isProAccount,
    this.phoneNumber,
    this.email,
    this.city,
    this.profileCompletionPercent = 0.0,
    this.onEditProfile,
    this.onRoleSwitch,
  });

  final String displayName;
  final ActiveRole activeRole;
  final bool isTraveler;
  final bool isSender;
  final bool isKycVerified;
  final bool isProAccount;
  final String? phoneNumber;
  final String? email;
  final String? city;
  final double profileCompletionPercent;
  final VoidCallback? onEditProfile;
  final ValueChanged<ActiveRole>? onRoleSwitch;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top;

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
              GestureDetector(
                onTap: onEditProfile,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DonySpacing.md),

          // ── Toggle rôle (uniquement si double rôle) ───────────────────
          if (isTraveler && isSender) ...[
            _RolePill(activeRole: activeRole, onRoleSwitch: onRoleSwitch),
            const SizedBox(height: DonySpacing.md),
          ],

          // ── Barre de complétion du profil ─────────────────────────────
          _ProgressBar(
            percent: profileCompletionPercent,
            isPro: isProAccount,
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

    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        if (hasPhone)
          const _Chip(
            label: 'Tél.',
            icon: Icons.phone_rounded,
            bg: DonyColors.success50,
            fg: DonyColors.success700,
          )
        else
          const _Chip(
            label: 'Tél. manquant',
            icon: Icons.phone_outlined,
            bg: DonyColors.neutral100,
            fg: DonyColors.neutral500,
          ),
        if (hasEmail)
          const _Chip(
            label: 'Email ✓',
            icon: Icons.email_rounded,
            bg: DonyColors.success50,
            fg: DonyColors.success700,
          )
        else
          const _Chip(
            label: 'Email manquant',
            icon: Icons.email_outlined,
            bg: DonyColors.warning50,
            fg: DonyColors.warning700,
          ),
        if (isKycVerified)
          const _Chip(
            label: 'KYC ✓',
            icon: Icons.verified_user_rounded,
            bg: DonyColors.blue50,
            fg: DonyColors.blue700,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final String label;
  final IconData icon;
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
          Icon(icon, size: 11, color: fg),
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

// ── Toggle rôle ───────────────────────────────────────────────────────────────

class _RolePill extends StatelessWidget {
  const _RolePill({required this.activeRole, this.onRoleSwitch});

  final ActiveRole activeRole;
  final ValueChanged<ActiveRole>? onRoleSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillTab(
            emoji: '📦',
            label: 'Expéditeur',
            isActive: activeRole == ActiveRole.sender,
            onTap: () => onRoleSwitch?.call(ActiveRole.sender),
          ),
          _PillTab(
            emoji: '✈️',
            label: 'Voyageur',
            isActive: activeRole == ActiveRole.traveler,
            onTap: () => onRoleSwitch?.call(ActiveRole.traveler),
          ),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.emoji,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: cs.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre de progression ──────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percent, required this.isPro});

  final double percent;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final pct = percent.clamp(0.0, 1.0);
    final isComplete = pct >= 1.0;
    final barColor = isPro ? DonyColors.starGold : cs.primary;
    final pctLabel = isComplete ? '100% ✓' : '${(pct * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Profil complet',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              pctLabel,
              style: tt.labelSmall?.copyWith(
                color: barColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: cs.outline.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
