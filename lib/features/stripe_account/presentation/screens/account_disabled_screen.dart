import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDisabledScreen extends StatefulWidget {
  const AccountDisabledScreen({super.key});

  @override
  State<AccountDisabledScreen> createState() => _AccountDisabledScreenState();
}

class _AccountDisabledScreenState extends State<AccountDisabledScreen> {
  int _primaryTapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Compte désactivé'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            Text(
              'Compte temporairement désactivé',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre compte Stripe est temporairement désactivé. '
              "La création de nouvelles annonces est bloquée jusqu'à "
              'la réactivation automatique par Stripe.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => _primaryTapCount++);
                  final uri = Uri.parse('https://dashboard.stripe.com/');
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Voir mon compte Stripe'),
              ),
            ),
            if (_primaryTapCount >= 2) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final uri = Uri.parse('mailto:support@dony.app');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: const Text('Contacter le support Dony'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
