import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class RoleGuidanceBanner extends StatefulWidget {
  const RoleGuidanceBanner({
    super.key,
    required this.role,
    required this.hiveService,
    this.onCtaTap,
    this.forceHide = false,
  });

  final ActiveRole role;
  final HiveService hiveService;
  final VoidCallback? onCtaTap;
  final bool forceHide;

  // Pour l'expéditeur, le banner se masque automatiquement après cette durée
  // à compter de la première vue (timestamp persisté dans Hive).
  static const Duration senderBannerLifetime = Duration(minutes: 5);

  @override
  State<RoleGuidanceBanner> createState() => _RoleGuidanceBannerState();
}

class _RoleGuidanceBannerState extends State<RoleGuidanceBanner> {
  Timer? _expirationTimer;

  String get _publishKey => widget.role == ActiveRole.traveler
      ? HiveService.kHasPublishedAsTraveler
      : HiveService.kHasPublishedAsSender;

  String get _dismissKey => widget.role == ActiveRole.traveler
      ? HiveService.kTravelerBannerDismissed
      : HiveService.kSenderBannerDismissed;

  List<String> get _watchedKeys => [_publishKey, _dismissKey];

  @override
  void initState() {
    super.initState();
    if (widget.role == ActiveRole.sender) {
      _scheduleSenderExpiration();
    }
  }

  void _scheduleSenderExpiration() {
    final box = widget.hiveService.userPrefs;
    final firstSeenMs =
        box.get(HiveService.kSenderBannerFirstSeenAt) as int?;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (firstSeenMs == null) {
      box.put(HiveService.kSenderBannerFirstSeenAt, nowMs);
      _expirationTimer = Timer(
        RoleGuidanceBanner.senderBannerLifetime,
        _onExpire,
      );
      return;
    }

    final elapsed = Duration(milliseconds: nowMs - firstSeenMs);
    final remaining = RoleGuidanceBanner.senderBannerLifetime - elapsed;
    if (remaining > Duration.zero) {
      _expirationTimer = Timer(remaining, _onExpire);
    }
  }

  void _onExpire() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  bool get _isSenderBannerExpired {
    if (widget.role != ActiveRole.sender) return false;
    final firstSeenMs = widget.hiveService.userPrefs
        .get(HiveService.kSenderBannerFirstSeenAt) as int?;
    if (firstSeenMs == null) return false;
    final elapsed = Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - firstSeenMs,
    );
    return elapsed >= RoleGuidanceBanner.senderBannerLifetime;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forceHide || _isSenderBannerExpired) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Box>(
      valueListenable: widget.hiveService.listenUserPrefs(keys: _watchedKeys),
      builder: (context, box, _) {
        final hasPublished = box.get(_publishKey, defaultValue: false) as bool;
        final dismissed = box.get(_dismissKey, defaultValue: false) as bool;
        if (hasPublished || dismissed) {
          return const SizedBox.shrink();
        }
        return _buildBanner(context);
      },
    );
  }

  void _onDismiss() {
    widget.hiveService.userPrefs.put(_dismissKey, true);
  }

  Widget _buildBanner(BuildContext context) {
    final isSender = widget.role == ActiveRole.sender;
    final title =
        isSender ? 'Envoyer ton premier colis' : 'Publier ton premier trajet';
    final emoji = isSender ? '📦' : '🧭';
    final ctaLabel =
        isSender ? "Publier ma demande d'envoi" : 'Publier mon trajet';
    final steps = isSender
        ? [
            'Compte créé ✓',
            'Cherche un voyageur sur la carte ou publie une demande',
            'Vérifie ton identité (KYC) — requis pour payer',
          ]
        : [
            'Compte créé ✓',
            'Vérifie ton identité (KYC) — obligatoire pour voyager',
            'Publie les détails de ton trajet (date, corridor, kg dispo)',
          ];

    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.md,
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.primarySoft,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    color: DonyColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  key: const Key('role-guidance-banner-dismiss'),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const DonyIcon('x'),
                  color: DonyColors.primary,
                  onPressed: _onDismiss,
                  tooltip: 'Masquer ce conseil',
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          ...steps.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFirst ? '✓' : '${e.key + 1}.',
                    style: tt.bodySmall?.copyWith(
                      color: isFirst ? DonyColors.success : DonyColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      e.value,
                      style: tt.bodySmall?.copyWith(
                        color: isFirst ? DonyColors.textMuted : DonyColors.ink900,
                        decoration: isFirst ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: DonySpacing.md),
          GestureDetector(
            onTap: widget.onCtaTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: DonyColors.primary,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DonyIcon('plus', size: 16, color: Colors.white),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    ctaLabel,
                    style: tt.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
