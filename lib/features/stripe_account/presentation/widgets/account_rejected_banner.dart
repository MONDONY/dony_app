import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountRejectedBanner extends StatelessWidget {
  const AccountRejectedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: const Color(0xFFE53935).withOpacity(0.12),
      leading: const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935)),
      content: const Text(
        'Votre compte Stripe a été rejeté',
        style: TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => context.push('/account/rejected'),
          child: const Text('Reconfigurer'),
        ),
      ],
    );
  }
}
