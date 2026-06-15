import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountRejectedScreen extends StatefulWidget {
  const AccountRejectedScreen({super.key});

  @override
  State<AccountRejectedScreen> createState() => _AccountRejectedScreenState();
}

class _AccountRejectedScreenState extends State<AccountRejectedScreen> {
  final _tapCount = ValueNotifier<int>(0);

  @override
  void dispose() {
    _tapCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stripeState = context.watch<StripeAccountBloc>().state;
    final reason = stripeState is StripeAccountReady
        ? stripeState.accountStatus.reason
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const DonyIcon('x'),
          onPressed: () => context.pop(),
        ),
        title: const Text('Compte rejeté'),
      ),
      body: BlocListener<ConnectOnboardingBloc, ConnectOnboardingState>(
        listener: (context, state) async {
          if (state is ConnectOnboardingUrlReady) {
            final uri = Uri.parse(state.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } else if (state is ConnectOnboardingError) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error.message),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        child: ValueListenableBuilder<int>(
          valueListenable: _tapCount,
          builder: (context, count, _) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DonyIcon('circle-alert', size: 48, color: Color(0xFFE53935)),
                  const SizedBox(height: 16),
                  Text(
                    'Compte rejeté',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Votre compte Stripe a été rejeté. Vous devez '
                    'reconfigurer un nouveau compte pour continuer.',
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Raison : $reason',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _tapCount.value++;
                        context
                            .read<ConnectOnboardingBloc>()
                            .add(const ConnectOnboardingLinkRequested());
                      },
                      child: const Text('Reconfigurer mon compte'),
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
      ),
    );
  }
}
