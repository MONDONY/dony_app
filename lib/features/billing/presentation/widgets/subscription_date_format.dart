import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Formate une date dans la langue de l'app, ex. « 24 décembre 2026 ».
///
/// Partagée par [SubscriptionStatusBanner] et [SubscriptionStatusCard] pour
/// que les deux widgets affichent une même date exactement de la même façon.
String formatSubscriptionDate(AppLocalizations l, DateTime local) =>
    DateFormat.yMMMMd(l.localeName).format(local);
