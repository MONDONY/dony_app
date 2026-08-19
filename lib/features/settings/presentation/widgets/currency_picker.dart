import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Sélecteur de devise partagé — Réglages › Préférences, carte Solde du
/// profil et déverrouillage d'un solde verrouillé dans Mon portefeuille.
///
/// Source unique de vérité : [BusinessPrefsBloc] (singleton), qui persiste
/// backend → Hive. Le [BuildContext] appelant doit pouvoir résoudre ce BLoC
/// (`context.read<BusinessPrefsBloc>()`), donc être sous un `BlocProvider`
/// qui l'expose.
abstract final class CurrencyPicker {
  /// Ouvre la liste complète et attend la bascule effective (dialogue de
  /// confirmation inclus) avant de se résoudre. Renvoie `true` uniquement si
  /// la devise a réellement changé — l'appelant peut ainsi ne recharger ce
  /// qui en dépend que lorsque c'est utile.
  static Future<bool> show(BuildContext context) async {
    final bloc = context.read<BusinessPrefsBloc>();
    final current = bloc.state.currencyCode;
    final rateFormatter = NumberFormat.decimalPattern('fr_FR');
    final tapped = await DonyBottomSheet.show<SupportedCurrency>(
      context,
      title: 'Devise d\'affichage',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final currency in SupportedCurrency.values)
            ListTile(
              leading: _CurrencyBadge(currency: currency),
              title: Text('${currency.displayName} (${currency.code})'),
              subtitle: Text(
                '1 EUR ≈ ${rateFormatter.format(currency.unitsPerEur)} ${currency.code}',
              ),
              trailing: current == currency.code
                  ? DonyIcon(
                      'check',
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => context.pop(currency),
            ),
        ],
      ),
    );
    if (tapped == null || !context.mounted) {
      return false;
    }
    return switchTo(context, tapped);
  }

  /// Bascule directement vers [target] après confirmation, sans repasser par
  /// la liste complète — utilisé pour déverrouiller un solde verrouillé
  /// (l'intention de l'utilisateur est déjà connue : cette devise précise).
  /// Renvoie `true` si la bascule a été confirmée et synchronisée.
  static Future<bool> switchTo(
    BuildContext context,
    SupportedCurrency target,
  ) async {
    final bloc = context.read<BusinessPrefsBloc>();
    final current = bloc.state.currencyCode;
    if (current == target.code) {
      return false;
    }
    if (bloc.state.currencyLocked) {
      // Lot 2 (2026-08-19) : gel au premier mouvement d'argent. S'applique
      // aussi au déverrouillage d'un solde secondaire — le serveur refuserait
      // de toute façon (422 currency-locked), autant l'annoncer ici plutôt
      // que de laisser échouer silencieusement en "Impossible de synchroniser".
      await DonyDialog.show(
        context,
        title: 'Devise verrouillée',
        message:
            'Un envoi est en cours ou ton portefeuille n\'est pas vide : la '
            'devise ne peut plus être changée pour l\'instant.',
        confirmLabel: 'Compris',
      );
      return false;
    }
    final confirmed = await DonyDialog.show(
      context,
      title: 'Changer de devise',
      message:
          'Tes trajets/colis en $current resteront visibles pour toi mais '
          'plus pour les autres. Ton solde $current reste récupérable en '
          'revenant sur cette devise plus tard.',
      confirmLabel: 'Changer pour ${target.code}',
    );
    if (confirmed != true) {
      return false;
    }
    return bloc.changeCurrency(target.code);
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.currency});

  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        currency.code,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
