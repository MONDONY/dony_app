import 'package:dony/core/design/tokens/color_tokens.dart'; // DonyStatusColors extension
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Banner types for [DonyStatusBanner].
enum DonyStatusBannerType { info, success, warning, error }

/// A horizontal status banner used to convey contextual messages (info, warning, error, success).
///
/// Supports optional [title], [onDismiss] close button, [action] widget, and [messageSpan]
/// for rich text content.
///
/// Usage:
/// ```dart
/// DonyStatusBanner(
///   type: DonyStatusBannerType.warning,
///   message: 'Votre compte n\'est pas encore vérifié.',
///   icon: Icons.warning_amber_rounded,
///   title: 'Attention',
///   onDismiss: () {},
///   action: TextButton(onPressed: () {}, child: Text('Vérifier')),
/// )
/// ```
class DonyStatusBanner extends StatelessWidget {
  const DonyStatusBanner({
    super.key,
    required this.type,
    this.message,
    this.messageSpan,
    this.icon,
    this.iconAsset,
    this.title,
    this.onDismiss,
    this.action,
  }) : assert(
          message != null || messageSpan != null,
          'Either message or messageSpan must be provided.',
        );

  final DonyStatusBannerType type;

  /// Plain-text message. Use [messageSpan] for rich text.
  final String? message;

  /// Rich text content. Takes precedence over [message] when both are provided.
  final TextSpan? messageSpan;

  /// Optional custom icon. Defaults to the type's standard icon.
  final IconData? icon;

  /// Nom d'un SVG Lucide dans `assets/icons/` (sans extension). Prioritaire sur
  /// [icon] — rend un [DonyIcon] teintable à la place d'une icône Material.
  final String? iconAsset;

  /// Optional title displayed above the message in bold.
  final String? title;

  /// When provided, shows a close (×) icon button on the right.
  final VoidCallback? onDismiss;

  /// Optional action widget (e.g. a TextButton) displayed below the message.
  final Widget? action;

  _BannerStyle _resolveStyle(ColorScheme cs) => switch (type) {
        DonyStatusBannerType.info => _BannerStyle(
            background: cs.infoLight,
            border: cs.info,
            iconColor: cs.info,
            defaultIcon: Icons.info_outline_rounded,
          ),
        DonyStatusBannerType.success => _BannerStyle(
            background: cs.successLight,
            border: cs.success,
            iconColor: cs.success,
            defaultIcon: Icons.check_circle_outline_rounded,
          ),
        DonyStatusBannerType.warning => _BannerStyle(
            background: cs.warningLight,
            border: cs.warning,
            iconColor: cs.warning,
            defaultIcon: Icons.warning_amber_rounded,
          ),
        DonyStatusBannerType.error => _BannerStyle(
            background: cs.errorLight,
            border: cs.error,
            iconColor: cs.error,
            defaultIcon: Icons.error_outline_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = _resolveStyle(cs);
    final tt = Theme.of(context).textTheme;
    final effectiveIcon = icon ?? style.defaultIcon;

    final baseTextStyle = tt.bodySmall?.copyWith(color: cs.onSurface);
    Widget messageWidget;
    if (messageSpan != null) {
      // Use Text.rich so find.textContaining works in widget tests.
      // Merge the base style with the provided span so child spans inherit it.
      final mergedSpan = TextSpan(
        style: baseTextStyle,
        children: messageSpan!.children ?? [messageSpan!],
        text: messageSpan!.children == null ? messageSpan!.text : null,
      );
      messageWidget = Text.rich(mergedSpan);
    } else {
      messageWidget = Text(
        message!,
        style: baseTextStyle,
      );
    }

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
          iconAsset != null
              ? DonyIcon(iconAsset!, size: 18, color: style.iconColor)
              : Icon(effectiveIcon, size: 18, color: style.iconColor),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                ],
                messageWidget,
                if (action != null) ...[
                  const SizedBox(height: DonySpacing.xs),
                  action!,
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: DonySpacing.xs),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: style.iconColor),
            ),
          ],
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
