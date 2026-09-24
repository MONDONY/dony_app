import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountRejectedBanner extends StatelessWidget {
  const AccountRejectedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return MaterialBanner(
      backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.12),
      leading: const DonyIcon('circle-alert', color: Color(0xFFE53935)),
      content: Text(
        l.stripeAccountRejectedBannerMessage,
        style: const TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => context.push('/account/rejected'),
          child: Text(l.stripeAccountRejectedBannerCta),
        ),
      ],
    );
  }
}
