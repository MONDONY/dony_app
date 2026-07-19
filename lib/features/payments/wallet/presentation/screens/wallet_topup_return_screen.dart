import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran de retour après le checkout GeniusPay (Wave/Orange/MTN Money).
///
/// Atteint via le deep link `dony://wallet/topup-return/{status}`, lui-même
/// ouvert par la page de rebond HTTPS `GeniusPayReturnController` côté
/// backend (GeniusPay n'accepte que des URLs http(s) comme success_url/
/// error_url, jamais un schéma custom).
///
/// Le crédit réel du wallet est asynchrone (webhook GeniusPay) — cet écran
/// ne fait donc JAMAIS l'hypothèse que le solde est déjà à jour. Le message
/// "success" annonce que le paiement a été confirmé côté GeniusPay, pas que
/// le wallet est déjà crédité ; le retour au wallet déclenche un rechargement
/// du solde qui reflétera le crédit dès que le webhook aura été traité.
class WalletTopupReturnScreen extends StatelessWidget {
  const WalletTopupReturnScreen({super.key, required this.status});

  final String status;

  bool get _isSuccess => status == 'success';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.huge,
            DonySpacing.lg,
            DonySpacing.xl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSuccess ? cs.successLight : cs.errorLight,
                ),
                child: Icon(
                  _isSuccess ? Icons.check_rounded : Icons.close_rounded,
                  size: 44,
                  color: _isSuccess ? cs.success : cs.error,
                ),
              ),
              const SizedBox(height: DonySpacing.xl),
              Text(
                _isSuccess ? 'Paiement confirmé' : 'Paiement non abouti',
                style: tt.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DonySpacing.md),
              Text(
                _isSuccess
                    ? 'Ton solde sera crédité dans un instant.'
                    : 'Le paiement a échoué ou a été annulé. Ton solde n\'a '
                        'pas été modifié.',
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DonySpacing.xxl),
              DonyButton(
                label: 'Retour au portefeuille',
                onPressed: () => context.go('/payments/wallet'),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(
              begin: 0.04,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}
