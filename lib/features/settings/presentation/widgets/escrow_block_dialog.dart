import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EscrowBlockDialog extends StatelessWidget {
  const EscrowBlockDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(
        'Paiement en cours',
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Vous avez un paiement en cours (escrow). La suppression sera possible une fois la livraison confirmée.',
        style: tt.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: () {
            context.pop();
            context.go('/announcements');
          },
          child: const Text('Voir mes envois'),
        ),
      ],
    );
  }
}
