import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellés traduits d'une période de statistiques du hub Activités.
extension StatsPeriodL10n on StatsPeriod {
  String label(AppLocalizations l) => switch (this) {
    StatsPeriod.sevenDays => l.activityPeriod7Days,
    StatsPeriod.thirtyDays => l.activityPeriod30Days,
    StatsPeriod.twelveMonths => l.activityPeriod12Months,
  };

  /// Sous-titre des feuilles de détail : la fenêtre, nommée comme une durée.
  String detailLabel(AppLocalizations l) => switch (this) {
    StatsPeriod.sevenDays => l.activityPeriodLast7Days,
    StatsPeriod.thirtyDays => l.activityPeriodLast30Days,
    StatsPeriod.twelveMonths => l.activityPeriodLast12Months,
  };
}

/// Libellé traduit d'un rail de paiement de revenu.
extension RevenueRailL10n on RevenueRail {
  String label(AppLocalizations l) => switch (this) {
    RevenueRail.card => l.activityRevenueCard,
    RevenueRail.mobileMoney => l.activityRevenueMobileMoney,
    RevenueRail.cash => l.activityRevenueCash,
    RevenueRail.unknown => l.activityRevenueOther,
  };
}

/// Libellés traduits d'un outil (spec § 4.5). Seule déclaration des textes :
/// la route reste un getter dans [ToolKeyPresentation].
extension ToolKeyL10n on ToolKey {
  /// Groupe nominal au singulier avec article, pour la phrase des manquants.
  String missingPhrase(AppLocalizations l) => switch (this) {
    ToolKey.addresses => l.activityToolMissingAddress,
    ToolKey.recipients => l.activityToolMissingRecipient,
    ToolKey.alerts => l.activityToolMissingAlert,
    ToolKey.tripTemplates => l.activityToolMissingTemplate,
    ToolKey.priceGrid => l.activityToolMissingPriceGrid,
  };

  String ctaLabel(AppLocalizations l) => switch (this) {
    ToolKey.addresses => l.activityToolCtaAddresses,
    ToolKey.recipients => l.activityToolCtaRecipients,
    ToolKey.alerts => l.activityToolCtaAlerts,
    ToolKey.tripTemplates => l.activityToolCtaTemplates,
    ToolKey.priceGrid => l.activityToolCtaPriceGrid,
  };

  /// Texte du badge « prêt ». La grille ne compte pas ses lignes : une grille
  /// à une ligne est aussi configurée qu'une grille à douze.
  String badgeLabel(AppLocalizations l, int count) => switch (this) {
    ToolKey.addresses => l.activityToolBadgeAddresses(count),
    ToolKey.recipients => l.activityToolBadgeRecipients(count),
    ToolKey.alerts => l.activityToolBadgeAlerts(count),
    ToolKey.tripTemplates => l.activityToolBadgeTemplates(count),
    ToolKey.priceGrid => l.activityToolBadgePriceGridReady,
  };
}

/// « Il vous manque un destinataire et une alerte. » Vide si rien ne manque.
String missingSentence(AppLocalizations l, List<ToolKey> missing) {
  if (missing.isEmpty) return '';
  return l.activityToolsMissing(
    joinList(l, missing.map((k) => k.missingPhrase(l)).toList()),
  );
}
