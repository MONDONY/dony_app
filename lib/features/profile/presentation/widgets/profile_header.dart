import 'dart:ui';

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
    required this.totalTrips,
    required this.totalShipments,
    this.isLoadingStats = false,
    this.onNotificationTap,
    this.onRoleSwitch,
  });

  final String displayName;
  final ActiveRole activeRole;
  final bool isTraveler;
  final bool isSender;
  final bool isKycVerified;
  final bool isProAccount;
  final int totalTrips;
  final int totalShipments;
  final bool isLoadingStats;
  final VoidCallback? onNotificationTap;
  final ValueChanged<ActiveRole>? onRoleSwitch;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        topPad + DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.md,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DonyColors.primary, DonyColors.blue900],
        ),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Avatar + ring ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: activeRole == ActiveRole.traveler
                        ? DonyColors.warning
                        : DonyColors.surface,
                    width: 3,
                  ),
                ),
                child: DonyAvatar(
                  name: displayName,
                  size: DonyAvatarSize.xl,
                  verified: isKycVerified,
                  pro: isProAccount,
                ),
              ),
              const SizedBox(height: DonySpacing.md),

              // ── Nom ───────────────────────────────────────────────────
              Text(
                displayName,
                style: tt.headlineMedium?.copyWith(
                  color: DonyColors.textOnBrand,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              // ── Badge KYC ─────────────────────────────────────────────
              if (isKycVerified) ...[
                const SizedBox(height: DonySpacing.xs),
                _KycBadge(isPro: isProAccount),
              ],

              const SizedBox(height: DonySpacing.md),

              // ── Pill switcher style B ─────────────────────────────────
              if (isTraveler && isSender)
                _RolePillB(
                  activeRole: activeRole,
                  onRoleSwitch: onRoleSwitch,
                ),

              const SizedBox(height: DonySpacing.lg),

              // ── Stats glassmorphisme ───────────────────────────────────
              _GlassStats(
                activeRole: activeRole,
                totalTrips: totalTrips,
                totalShipments: totalShipments,
                isLoading: isLoadingStats,
              ),
            ],
          ),

          // ── Notification bell (uniquement si callback fourni) ─────────
          if (onNotificationTap != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: DonyColors.textOnBrand,
                ),
                onPressed: onNotificationTap,
                tooltip: 'Notifications',
              ),
            ),
        ],
      ),
    );
  }
}

// ── KYC Badge ─────────────────────────────────────────────────────────────────

const Color _kKycBadgeBlue = Color(0xFF6FA8FF);
const Color _kKycBadgeGold = Color(0xFFF0B829);

class _KycBadge extends StatelessWidget {
  const _KycBadge({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final accent = isPro ? _kKycBadgeGold : _kKycBadgeBlue;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DonyColors.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: accent, size: 13),
          const SizedBox(width: DonySpacing.xs),
          Text(
            isPro ? 'Profil pro vérifié' : 'Identité vérifiée',
            style: tt.labelSmall?.copyWith(
              color: DonyColors.textOnBrand,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role Pill Style B ─────────────────────────────────────────────────────────

class _RolePillB extends StatelessWidget {
  const _RolePillB({required this.activeRole, this.onRoleSwitch});

  final ActiveRole activeRole;
  final ValueChanged<ActiveRole>? onRoleSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DonyColors.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: DonyColors.surface.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillBTab(
            emoji: '🧭',
            label: 'Voyageur',
            isActive: activeRole == ActiveRole.traveler,
            onTap: () => onRoleSwitch?.call(ActiveRole.traveler),
          ),
          _PillBTab(
            emoji: '📦',
            label: 'Expéditeur',
            isActive: activeRole == ActiveRole.sender,
            onTap: () => onRoleSwitch?.call(ActiveRole.sender),
          ),
        ],
      ),
    );
  }
}

class _PillBTab extends StatelessWidget {
  const _PillBTab({
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
          color: isActive ? DonyColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive
                    ? DonyColors.primary
                    : DonyColors.textOnBrand.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass Stats ───────────────────────────────────────────────────────────────

class _GlassStats extends StatelessWidget {
  const _GlassStats({
    required this.activeRole,
    required this.totalTrips,
    required this.totalShipments,
    required this.isLoading,
  });

  final ActiveRole activeRole;
  final int totalTrips;
  final int totalShipments;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isTraveler = activeRole == ActiveRole.traveler;
    final stat1Value = isLoading ? '—' : '${isTraveler ? totalTrips : totalShipments}';
    final stat1Label = isTraveler ? 'Trajets' : 'Envois';
    final stat3Value = isTraveler ? '98%' : '0€';
    final stat3Label = isTraveler ? 'Livraison' : 'Économisés';

    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          decoration: BoxDecoration(
            color: DonyColors.surface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: DonyColors.surface.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(child: _GlassStat(value: stat1Value, label: stat1Label)),
              _GlassStatDivider(),
              const Expanded(child: _GlassStat(value: '4.9', label: 'Ma note')),
              _GlassStatDivider(),
              Expanded(child: _GlassStat(value: stat3Value, label: stat3Label)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: tt.titleLarge?.copyWith(
            color: DonyColors.textOnBrand,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: DonyColors.textOnBrand.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _GlassStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: DonyColors.textOnBrand.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
    );
  }
}
