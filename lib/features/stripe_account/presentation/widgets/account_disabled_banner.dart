import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountDisabledBanner extends StatelessWidget {
  const AccountDisabledBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: const Color(0xFFF59E0B).withOpacity(0.12),
      leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
      content: const Text(
        'Votre compte Stripe est temporairement désactivé',
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => context.push('/account/disabled'),
          child: const Text('En savoir plus'),
        ),
      ],
    );
  }
}
