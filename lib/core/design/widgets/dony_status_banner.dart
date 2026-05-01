import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Banner types for [DonyStatusBanner].
enum DonyStatusBannerType { info, success, warning, error }

/// A horizontal status banner used to convey contextual messages (info, warning, error, success).
///
/// Usage:
/// ```dart
/// DonyStatusBanner(
///   type: DonyStatusBannerType.warning,
///   message: 'Votre compte n'est pas encore vérifié.',
///   icon: Icons.warning_amber_rounded,
/// )
/// ```
class DonyStatusBanner extends StatelessWidget {
  const DonyStatusBanner({
    super.key,
    required this.type,
    required this.message,
    this.icon,
  });

  final DonyStatusBannerType type;
  final String message;
  final IconData? icon;

  _BannerStyle get _style => switch (type) {
        DonyStatusBannerType.info => _BannerStyle(
            background: DonyColors.info50,
            border: DonyColors.info500,
            iconColor: DonyColors.info500,
            defaultIcon: Icons.info_outline_rounded,
          ),
        DonyStatusBannerType.success => _BannerStyle(
            background: DonyColors.successLight,
            border: DonyColors.success500,
            iconColor: DonyColors.success500,
            defaultIcon: Icons.check_circle_outline_rounded,
          ),
        DonyStatusBannerType.warning => _BannerStyle(
            background: DonyColors.warningLight,
            border: DonyColors.warning500,
            iconColor: DonyColors.warning500,
            defaultIcon: Icons.warning_amber_rounded,
          ),
        DonyStatusBannerType.error => _BannerStyle(
            background: DonyColors.errorLight,
            border: DonyColors.danger500,
            iconColor: DonyColors.danger500,
            defaultIcon: Icons.error_outline_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final tt = Theme.of(context).textTheme;
    final effectiveIcon = icon ?? style.defaultIcon;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, size: 18, color: style.iconColor),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: DonyColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStyle {
  final Color background;
  final Color border;
  final Color iconColor;
  final IconData defaultIcon;

  const _BannerStyle({
    required this.background,
    required this.border,
    required this.iconColor,
    required this.defaultIcon,
  });
}
