import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AuthRequiredReason { explore, offer, report }

abstract final class AuthRequiredSheet {
  static Future<void> show(
    BuildContext context, {
    AuthRequiredReason reason = AuthRequiredReason.explore,
  }) {
    final l10n = context.l10n;
    final copy = _copyFor(reason, l10n);
    return DonyBottomSheet.show<void>(
      context,
      title: l10n.authRequiredTitle,
      subtitle: copy.subtitle,
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: l10n.authRequiredSignIn,
            iconAsset: 'key-round',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go('/auth/method');
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: l10n.authRequiredKeepExploring,
            variant: DonyButtonVariant.ghost,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReassuranceRow(
            iconAsset: 'search',
            title: l10n.authRequiredFreeSearchTitle,
            subtitle: l10n.authRequiredFreeSearchBody,
          ),
          const SizedBox(height: DonySpacing.md),
          _ReassuranceRow(
            iconAsset: 'shield-check',
            title: l10n.authRequiredProtectedTitle,
            subtitle: copy.body,
          ),
        ],
      ),
    );
  }

  static _AuthRequiredCopy _copyFor(
    AuthRequiredReason reason,
    AppLocalizations l10n,
  ) {
    return switch (reason) {
      AuthRequiredReason.offer => _AuthRequiredCopy(
        subtitle: l10n.authRequiredOfferSubtitle,
        body: l10n.authRequiredOfferBody,
      ),
      AuthRequiredReason.report => _AuthRequiredCopy(
        subtitle: l10n.authRequiredReportSubtitle,
        body: l10n.authRequiredReportBody,
      ),
      AuthRequiredReason.explore => _AuthRequiredCopy(
        subtitle: l10n.authRequiredExploreSubtitle,
        body: l10n.authRequiredExploreBody,
      ),
    };
  }
}

class _AuthRequiredCopy {
  const _AuthRequiredCopy({required this.subtitle, required this.body});

  final String subtitle;
  final String body;
}

class _ReassuranceRow extends StatelessWidget {
  const _ReassuranceRow({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
  });

  final String iconAsset;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: Center(
            child: DonyIcon(iconAsset, size: 20, color: cs.primary),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
