import 'package:dony/core/currency/supported_currency.dart';

/// Portage Dart du calcul de la commission par paliers du back
/// (`CommissionCalculator`, `CommissionGrid`, `CommissionReductions`, spec
/// 2026-10-18 §4.2 et §4.3). Le back reste la source de vérité : ce calcul ne
/// sert qu'à AFFICHER ce que le serveur facturera, à l'unité mineure près.
///
/// Les deux implémentations sont verrouillées par les mêmes vecteurs
/// (`test/fixtures/commission/vectors.json`, recopiés du back). Le code promo
/// n'est jamais calculé dans l'app : seul le serveur le chiffre.
///
/// Ordre de calcul, un seul arrondi à la fin :
///  1. net arrondi HALF_UP à l'unité mineure de la devise ;
///  2. commission de grille marginale, bornes converties sans arrondi ;
///  3. taux spécial : `min(grille, net × taux spécial)` ;
///  4. commission à 0 : elle reste à 0, ni minimum ni bon ;
///  5. sinon `max(commission, minimum de la devise)` ;
///  6. bon de parrainage multiplié APRÈS le minimum ;
///  7. arrondi HALF_UP à l'unité mineure.
///
/// Toute l'arithmétique passe par un décimal exact (entier `BigInt` + échelle) :
/// aucun `double` n'est jamais multiplié, un `double` d'entrée est relu depuis
/// sa représentation décimale la plus courte (`toString()`), exactement comme le
/// `BigDecimal` du back lit « 0.07 ».

// ── Types publics ──────────────────────────────────────────────────────────

/// Tranche de la grille : taux marginal applicable au-delà de [fromEur].
class CommissionTier {
  const CommissionTier({required this.fromEur, required this.rate});

  /// Borne basse de la tranche, en euros.
  final double fromEur;

  /// Taux marginal (0,07 pour 7 %).
  final double rate;

  /// Accepte un nombre ou une chaîne décimale pour chaque champ.
  factory CommissionTier.fromJson(Map<String, dynamic> json) => CommissionTier(
    fromEur: _jsonDouble(json['fromEur']),
    rate: _jsonDouble(json['rate']),
  );
}

/// Grille de commission marginale datée, la même pour toutes les devises.
class CommissionGrid {
  const CommissionGrid({
    required this.id,
    required this.effectiveFrom,
    required this.tiers,
    required this.minimums,
  });

  /// Identifiant de la grille (`gridId` côté serveur).
  final String id;

  /// Date d'effet, toujours en UTC.
  final DateTime effectiveFrom;

  /// Tranches triées par `fromEur` croissant.
  final List<CommissionTier> tiers;

  /// Commission minimum par devise, indexée par code ISO majuscule.
  final Map<String, double> minimums;

  /// Forme de `GET /config/commission-grid` : `gridId`, `effectiveFrom`,
  /// `tiers`, `minimums`. Une date sans fuseau est lue en UTC (le serveur
  /// l'exprime en `LocalDateTime` UTC), une date avec `Z` ou décalage garde son
  /// instant.
  factory CommissionGrid.fromJson(Map<String, dynamic> json) {
    final tiers = [
      for (final t in (json['tiers'] as List<dynamic>))
        CommissionTier.fromJson(Map<String, dynamic>.from(t as Map)),
    ]..sort((a, b) => a.fromEur.compareTo(b.fromEur));
    final rawMinimums = Map<String, dynamic>.from(json['minimums'] as Map);
    return CommissionGrid(
      id: json['gridId'] as String,
      effectiveFrom: _parseUtc(json['effectiveFrom'] as String),
      tiers: List.unmodifiable(tiers),
      minimums: Map.unmodifiable({
        for (final e in rawMinimums.entries)
          e.key.toUpperCase(): _jsonDouble(e.value),
      }),
    );
  }

  /// Minimum de la devise, `null` si la grille ne le donne pas.
  double? minimumFor(String currencyCode) =>
      minimums[currencyCode.trim().toUpperCase()];
}

/// Réductions personnelles appliquées à la commission de grille.
class CommissionReductions {
  const CommissionReductions({this.overrideRate, this.voucherFactor});

  /// Taux spécial du compte (plus petit des deux overrides), `null` sans.
  final double? overrideRate;

  /// Facteur du bon de parrainage (0,5), appliqué après le minimum.
  final double? voucherFactor;

  /// Aucune réduction : commission de grille, minimum compris.
  static const none = CommissionReductions();
}

/// Devis d'une commission, montants arrondis à l'unité mineure de la devise.
class CommissionResult {
  const CommissionResult({
    required this.net,
    required this.commission,
    required this.gross,
    required this.minimumApplied,
  });

  /// Net du voyageur.
  final double net;

  /// Commission Yadony, arrondie une seule fois (HALF_UP).
  final double commission;

  /// Total payé par l'expéditeur, `net + commission`.
  final double gross;

  /// Vrai quand le minimum de la devise a relevé la commission.
  final bool minimumApplied;
}

/// Le montant ne couvre pas la commission minimum : même une unité mineure de
/// net coûte plus que le brut (422 `budget-below-commission-minimum` côté back).
class BudgetBelowCommissionMinimumException implements Exception {
  const BudgetBelowCommissionMinimumException();

  @override
  String toString() => 'BudgetBelowCommissionMinimumException';
}

// ── Calcul ─────────────────────────────────────────────────────────────────

/// Devis complet pour un net du voyageur. [net] est ramené à l'unité mineure
/// de la devise (HALF_UP).
///
/// Lève [ArgumentError] si le net arrondi est nul ou négatif, [StateError] si la
/// grille n'a pas de minimum pour [currencyCode] ou si la devise est inconnue.
CommissionResult computeCommission(
  double net,
  String currencyCode,
  CommissionGrid grid, {
  CommissionReductions reductions = CommissionReductions.none,
}) {
  final currency = _currencyOf(currencyCode);
  final n = _Dec.fromDouble(net).roundHalfUp(currency.minorUnit);
  if (n.signum <= 0) {
    throw ArgumentError.value(net, 'net', 'Net must be strictly positive');
  }
  final c = _commission(n, currency, grid, reductions);
  return CommissionResult(
    net: n.toDouble(),
    commission: c.amount.toDouble(),
    gross: n.add(c.amount).toDouble(),
    minimumApplied: c.minimumApplied,
  );
}

/// Plus grand net `N`, à l'unité mineure de la devise, tel que
/// `N + C(N) ≤ gross` : budget TTC d'une demande de colis, brut négocié d'un
/// trajet. `N ↦ N + C(N)` est strictement croissante sur les unités mineures,
/// la dichotomie trouve donc la valeur exacte.
///
/// Lève [BudgetBelowCommissionMinimumException] quand même la plus petite unité
/// de net coûte plus que [gross].
double netForGross(
  double gross,
  String currencyCode,
  CommissionGrid grid, {
  CommissionReductions reductions = CommissionReductions.none,
}) {
  final currency = _currencyOf(currencyCode);
  final g = _Dec.fromDouble(gross);
  final minor = currency.minorUnit;

  var lo = 1;
  final hi0 = g.floorToUnits(minor);
  if (hi0 < lo || _grossOf(lo, currency, grid, reductions).compareTo(g) > 0) {
    throw const BudgetBelowCommissionMinimumException();
  }
  var hi = hi0;
  // Invariant : grossOf(lo) ≤ gross ; on cherche le plus grand lo qui le tient.
  while (lo < hi) {
    final mid = lo + (hi - lo + 1) ~/ 2;
    if (_grossOf(mid, currency, grid, reductions).compareTo(g) <= 0) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return _Dec(BigInt.from(lo), minor).toDouble();
}

/// Produit `a × b` en décimal exact, arrondi HALF_UP à [minorUnit] décimales :
/// le net au kilo du back (`pricePerKg × weightKg` en `BigDecimal`,
/// `setScale(minorUnit, HALF_UP)`). Le produit en `double` s'en écarte d'une
/// unité mineure (8,5 × 1,15 vaut 9.774999… et non 9,775).
double exactProductHalfUp(double a, double b, int minorUnit) => _Dec.fromDouble(
  a,
).mul(_Dec.fromDouble(b)).roundHalfUp(minorUnit).toDouble();

// ── Interne ────────────────────────────────────────────────────────────────

SupportedCurrency _currencyOf(String code) {
  final currency = SupportedCurrency.fromCode(code);
  if (currency == null) {
    throw StateError('Unsupported commission currency: $code');
  }
  return currency;
}

_Dec _grossOf(
  int netMinor,
  SupportedCurrency currency,
  CommissionGrid grid,
  CommissionReductions reductions,
) {
  final n = _Dec(BigInt.from(netMinor), currency.minorUnit);
  return n.add(_commission(n, currency, grid, reductions).amount);
}

class _Commission {
  const _Commission(this.amount, this.minimumApplied);
  final _Dec amount;
  final bool minimumApplied;
}

/// Étapes 2 à 7, pour un net déjà à l'unité mineure.
_Commission _commission(
  _Dec n,
  SupportedCurrency currency,
  CommissionGrid grid,
  CommissionReductions r,
) {
  var base = _gridCommission(n, currency, grid);
  final override = r.overrideRate;
  if (override != null) {
    final capped = n.mul(_Dec.fromDouble(override));
    if (capped.compareTo(base) < 0) base = capped;
  }
  if (base.signum == 0) {
    // Taux spécial à 0 : ni minimum, ni bon.
    return _Commission(_Dec.zero.roundHalfUp(currency.minorUnit), false);
  }

  final minimumValue = grid.minimumFor(currency.code);
  if (minimumValue == null) {
    throw StateError(
      'Commission grid ${grid.id} has no minimum for ${currency.code}',
    );
  }
  final minimum = _Dec.fromDouble(minimumValue);
  final minimumApplied = base.compareTo(minimum) < 0;
  var amount = minimumApplied ? minimum : base;
  final voucher = r.voucherFactor;
  if (voucher != null) {
    amount = amount.mul(_Dec.fromDouble(voucher));
  }
  return _Commission(amount.roundHalfUp(currency.minorUnit), minimumApplied);
}

/// `Σ taux_i × max(0, min(net, borne_sup_i) − borne_inf_i)`, NON arrondie. Les
/// bornes (en euros) sont converties par `× unitsPerEur` sans arrondi.
_Dec _gridCommission(
  _Dec net,
  SupportedCurrency currency,
  CommissionGrid grid,
) {
  final tiers = [...grid.tiers]..sort((a, b) => a.fromEur.compareTo(b.fromEur));
  final unitsPerEur = _Dec.fromDouble(currency.unitsPerEur);
  var total = _Dec.zero;
  for (var i = 0; i < tiers.length; i++) {
    final lower = _Dec.fromDouble(tiers[i].fromEur).mul(unitsPerEur);
    if (net.compareTo(lower) <= 0) break;
    var top = net;
    if (i + 1 < tiers.length) {
      final upper = _Dec.fromDouble(tiers[i + 1].fromEur).mul(unitsPerEur);
      if (upper.compareTo(top) < 0) top = upper;
    }
    total = total.add(_Dec.fromDouble(tiers[i].rate).mul(top.sub(lower)));
  }
  return total;
}

// ── Décimal exact ──────────────────────────────────────────────────────────

/// Décimal exact : `unscaled × 10^-scale`. Addition, soustraction et
/// multiplication sont exactes, seul [roundHalfUp] perd de la précision.
class _Dec {
  const _Dec(this.unscaled, this.scale);

  final BigInt unscaled;
  final int scale;

  static final zero = _Dec(BigInt.zero, 0);

  static final _plain = RegExp(
    r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );

  /// Lit un `double` depuis sa représentation décimale la plus courte
  /// (`0.07.toString() == '0.07'`), jamais depuis sa valeur binaire.
  factory _Dec.fromDouble(double value) => _Dec.parse(value.toString());

  /// Lit un texte décimal (`'0.07'`, `'650'`, `'1e-7'`, `'1.0E10'`).
  factory _Dec.parse(String text) {
    final m = _plain.firstMatch(text.trim());
    if (m == null ||
        ((m.group(2) ?? '').isEmpty && (m.group(3) ?? '').isEmpty)) {
      throw FormatException('Invalid decimal number', text);
    }
    final sign = m.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
    final intPart = m.group(2) ?? '';
    final fracPart = m.group(3) ?? '';
    final exponent = int.parse(m.group(4) ?? '0');
    final digits = BigInt.parse('${intPart.isEmpty ? '0' : intPart}$fracPart');
    var scale = fracPart.length - exponent;
    var unscaled = sign * digits;
    if (scale < 0) {
      unscaled *= BigInt.from(10).pow(-scale);
      scale = 0;
    }
    return _Dec(unscaled, scale);
  }

  int get signum => unscaled.sign;

  _Dec _aligned(int to) =>
      to == scale ? this : _Dec(unscaled * BigInt.from(10).pow(to - scale), to);

  _Dec add(_Dec o) {
    final s = scale > o.scale ? scale : o.scale;
    return _Dec(_aligned(s).unscaled + o._aligned(s).unscaled, s);
  }

  _Dec sub(_Dec o) {
    final s = scale > o.scale ? scale : o.scale;
    return _Dec(_aligned(s).unscaled - o._aligned(s).unscaled, s);
  }

  _Dec mul(_Dec o) => _Dec(unscaled * o.unscaled, scale + o.scale);

  int compareTo(_Dec o) {
    final s = scale > o.scale ? scale : o.scale;
    return _aligned(s).unscaled.compareTo(o._aligned(s).unscaled);
  }

  /// Arrondi HALF_UP (demi vers l'infini, valeurs positives ici) à [to] décimales.
  _Dec roundHalfUp(int to) {
    if (scale <= to) return _aligned(to);
    final divisor = BigInt.from(10).pow(scale - to);
    final negative = unscaled.isNegative;
    final abs = unscaled.abs();
    var q = abs ~/ divisor;
    if ((abs - q * divisor) * BigInt.two >= divisor) q += BigInt.one;
    return _Dec(negative ? -q : q, to);
  }

  /// Partie entière, en unités de `10^-minor`, arrondie vers le bas (FLOOR).
  int floorToUnits(int minor) {
    if (scale <= minor) return _aligned(minor).unscaled.toInt();
    final divisor = BigInt.from(10).pow(scale - minor);
    var q = unscaled ~/ divisor;
    if (unscaled.isNegative && q * divisor != unscaled) q -= BigInt.one;
    return q.toInt();
  }

  /// Le `double` le plus proche de la valeur décimale.
  double toDouble() => double.parse(toPlainString());

  String toPlainString() {
    final abs = unscaled.abs().toString().padLeft(scale + 1, '0');
    final intPart = abs.substring(0, abs.length - scale);
    final frac = abs.substring(abs.length - scale);
    final sign = unscaled.isNegative ? '-' : '';
    return scale == 0 ? '$sign$intPart' : '$sign$intPart.$frac';
  }
}

// ── JSON ───────────────────────────────────────────────────────────────────

double _jsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Numeric value expected', value);
}

final _timeZoneSuffix = RegExp(
  r'(Z|[+-]\d{2}(:?\d{2})?)$',
  caseSensitive: false,
);

/// Date ISO-8601 vers un instant UTC : sans fuseau, la valeur est déjà en UTC.
DateTime _parseUtc(String raw) {
  final text = raw.trim();
  final tIndex = text.indexOf('T');
  if (tIndex < 0) return DateTime.parse('${text}T00:00:00Z');
  final hasZone = _timeZoneSuffix.hasMatch(text.substring(tIndex));
  return DateTime.parse(hasZone ? text : '${text}Z').toUtc();
}
