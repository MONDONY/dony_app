import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final stripeState = context.watch<StripeAccountBloc>().state;
    final requirementsDue = stripeState is StripeAccountReady
        ? stripeState.accountStatus.requirementsCurrentlyDue
        : const <String>{};
    final isRefreshing = stripeState is StripeAccountLoading;

    return Scaffold(
      appBar: AppBar(
        leading: const DonyAppBarBackButton(leadingIconAsset: 'x'),
        title: const Text('Compte désactivé'),
        actions: [
          IconButton(
            tooltip: 'Actualiser le statut',
            icon: isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const DonyIcon('refresh-cw'),
            onPressed: isRefreshing
                ? null
                : () => context.read<StripeAccountBloc>().add(
                      const StripeAccountStatusRefreshed(),
                    ),
          ),
        ],
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
              DonySnackbar.show(
                context,
                message: state.error.message,
                type: DonySnackbarType.error,
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
                              if (requirementsDue.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Informations à compléter',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ...requirementsDue.map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('•  $r'),
                                  ),
                                ),
                              ],
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
                      onPressed: () {
                        _tapCount.value++;
                        context.read<ConnectOnboardingBloc>().add(
                              const ConnectOnboardingLinkRequested(),
                            );
                      },
                      child: const Text('Compléter mes informations'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
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
                          final uri = Uri.parse('mailto:support@yadony.com');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: const Text('Contacter le support Yadony'),
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
