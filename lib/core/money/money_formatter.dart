import 'package:dony/core/money/currency_registry.dart';

const String _nbsp = ' ';

String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buf.write(_nbsp);
    }
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Formate un montant EUR : « 12 € », « 1 234,56 € ». Virgule française,
/// décimales seulement si non rond (aligné sur `formatKgPrice` de
/// `dony_pricing.dart`).
String formatEur(double amount) {
  final isRound = amount % 1 == 0;
  final fixed = amount.toStringAsFixed(isRound ? 0 : 2);
  final parts = fixed.split('.');
  final intPart = _group(parts[0]);
  return parts.length > 1 ? '$intPart,${parts[1]}$_nbsp€' : '$intPart$_nbsp€';
}

/// Affichage dual INDICATIF (spec §6.2) : « 12 € (7 871 F CFA) ». Parité
/// inconnue (devise absente du registre ou `pegRateToEur` non renseigné) ou
/// devise locale = EUR → EUR seul, jamais d'estimation inventée (règle R1).
String formatDual(double eurAmount, {required String localeCurrency}) {
  final eur = formatEur(eurAmount);
  if (localeCurrency == 'EUR') {
    return eur;
  }
  final info = CurrencyRegistry.instance[localeCurrency];
  final peg = info?.pegRateToEur;
  if (info == null || peg == null) {
    return eur;
  }
  // Arrondi INDICATIF à l'unité la plus proche (spec §5.6) — affichage
  // uniquement, jamais utilisé pour un montant transactionnel réel.
  final local = (eurAmount * peg).round();
  final symbol = info.symbol.replaceAll(' ', _nbsp);
  return '$eur (${_group(local.toString())}$_nbsp$symbol)';
}

/// Affichage TRANSACTIONNEL (spec §6.2 règle 4) : montant en unité mineure
/// venu du SERVEUR, affiché tel quel + code ISO (le symbole « F CFA » est
/// ambigu entre XOF/XAF). AUCUNE conversion locale ici — règle R1.
String formatLocalTransactional(int minorAmount, String currency) {
  final info = CurrencyRegistry.instance[currency];
  final minorUnit = info?.minorUnit ?? 2;
  final symbol = (info?.symbol ?? currency).replaceAll(' ', _nbsp);
  String value;
  if (minorUnit == 0) {
    value = _group(minorAmount.toString());
  } else {
    final s = minorAmount.toString().padLeft(minorUnit + 1, '0');
    final intPart = _group(s.substring(0, s.length - minorUnit));
    value = '$intPart,${s.substring(s.length - minorUnit)}';
  }
  return '$value$_nbsp$symbol ($currency)';
}
