import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_ring.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Panneau d'attente d'un paiement mobile money, partagé par la recharge du
/// portefeuille et le paiement d'un colis : anneau calé sur l'échéance du
/// serveur, consigne selon la façon dont l'opérateur fait valider (lien par
/// SMS, code secret, ou neutre), récapitulatif libre, et bouton pour ouvrir
/// l'opérateur quand il fournit un lien d'autorisation (Wave).
///
/// Sans type propre à un parcours : l'écran appelant fournit les lignes du
/// récapitulatif déjà formatées ([recap]).
class MobileMoneyAwaitingPanel extends StatelessWidget {
  const MobileMoneyAwaitingPanel({
    super.key,
    required this.expiresAt,
    required this.hint,
    required this.msisdnMasked,
    required this.recap,
    this.authorizationUrl,
    this.providerLabel,
    this.now = DateTime.now,
  }) : assert(
         authorizationUrl == null || providerLabel != null,
         'providerLabel est requis avec authorizationUrl (libellé du bouton)', // i18n-ignore
       );

  /// Échéance de la demande de paiement (instant du serveur).
  final DateTime expiresAt;

  /// Façon dont l'opérateur fait valider : pilote titre et consigne.
  final MobileMoneyValidationHint hint;

  /// Numéro payeur masqué, tel que rendu par le serveur.
  final String msisdnMasked;

  /// Lignes du récapitulatif (libellé, valeur), séparées par un filet.
  final List<({String label, String value})> recap;

  /// Lien d'autorisation de l'opérateur, quand il en fournit un : affiche le
  /// bouton « Ouvrir {opérateur} ».
  final String? authorizationUrl;

  /// Nom de l'opérateur, utilisé par le libellé du bouton d'ouverture :
  /// obligatoire dès que [authorizationUrl] est fourni (assertion en debug ;
  /// en release, un lien sans nom n'affiche simplement pas le bouton).
  final String? providerLabel;

  /// Horloge, injectable pour les tests.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final url = authorizationUrl;
    final label = providerLabel;
    final (title, body) = switch (hint) {
      MobileMoneyValidationHint.smsLink => (
        l.walletTopupMmSmsSentTitle(msisdnMasked),
        l.walletTopupMmSmsSentBody,
      ),
      MobileMoneyValidationHint.pinPrompt => (
        l.walletTopupMmPromptTitle(msisdnMasked),
        l.walletTopupMmPromptBody,
      ),
      MobileMoneyValidationHint.generic => (
        l.walletTopupMmPromptTitle(msisdnMasked),
        l.walletTopupMmGenericBody,
      ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: DonySpacing.md),
          MobileMoneyAwaitingRing(expiresAt: expiresAt, now: now),
          const SizedBox(height: DonySpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyCard(
            child: Column(
              children: [
                for (var i = 0; i < recap.length; i++) ...[
                  if (i > 0) const DonyInfoRow.divider(),
                  DonyInfoRow(label: recap[i].label, value: recap[i].value),
                ],
              ],
            ),
          ),
          if (url != null && label != null) ...[
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              key: const Key('mobile-money-awaiting-open-authorization'),
              label: l.walletTopupMmOpenProvider(label),
              iconAsset: 'external-link',
              onPressed: () =>
                  getIt<ExternalUrlLauncher>().open(Uri.parse(url)),
            ),
          ],
        ],
      ),
    );
  }
}
