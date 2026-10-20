import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Comptes de versement mobile money du voyageur. Accessible depuis « Moi »
/// → section ARGENT → « Versement mobile money ».
///
/// Version de transition : liste en lecture seule des comptes lus par
/// `MobileMoneyAccountBloc`. Les écrans d'ajout, de changement de numéro et
/// de retrait arrivent avec la réécriture de cet écran (lot C, tâche 13).
class MobileMoneyAccountScreen extends StatelessWidget {
  const MobileMoneyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: Text(l.mobileMoneyAccountTitle, style: tt.headlineMedium),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<MobileMoneyAccountBloc, MobileMoneyAccountState>(
          builder: (context, state) {
            final data = state.data;
            if (data != null) {
              return ListView(
                children: [
                  for (final account in data.accounts)
                    ListTile(
                      title: Text(account.providerLabel),
                      subtitle: Text(account.msisdnMasked),
                    ),
                ],
              );
            }
            if (state is MobileMoneyAccountError) {
              return DonyEmptyState(
                type: DonyEmptyStateType.error,
                title: l.mobileMoneyAccountLoadError,
                actionLabel: l.commonRetry,
                onAction: () => context.read<MobileMoneyAccountBloc>().add(
                  const MobileMoneyAccountsRequested(),
                ),
              );
            }
            return Center(child: CircularProgressIndicator(color: cs.primary));
          },
        ),
      ),
    );
  }
}
