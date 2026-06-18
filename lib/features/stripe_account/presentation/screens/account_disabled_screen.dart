import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountDisabledScreen extends StatefulWidget {
  const AccountDisabledScreen({super.key});

  @override
  State<AccountDisabledScreen> createState() => _AccountDisabledScreenState();
}

class _AccountDisabledScreenState extends State<AccountDisabledScreen> {
  final _tapCount = ValueNotifier<int>(0);

  @override
  void dispose() {
    _tapCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const DonyIcon('x'),
          onPressed: () => context.pop(),
        ),
        title: const Text('Compte désactivé'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _tapCount,
        builder: (context, count, _) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Texte scrollable, boutons épinglés en bas (anti-overflow
                // petit écran / gros text scale).
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DonyIcon(
                              'triangle-alert',
                              size: 48,
                              color: Color(0xFFF59E0B),
                            ),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      _tapCount.value++;
                      final uri = Uri.parse('https://dashboard.stripe.com/');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: const Text('Voir mon compte Stripe'),
                  ),
                ),
                if (count >= 2) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final uri = Uri.parse('mailto:support@dony.app');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: const Text('Contacter le support Dony'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
