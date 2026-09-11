import 'package:dony/core/services/app_log.dart';

/// Devise utilisable pour un paiement Stripe côté client.
///
/// Le backend reste la source de vérité : ce catalogue sert à parser sa
/// réponse et à formater les montants déjà résolus côté serveur.
class SupportedCurrency {
  final String code;
  final String symbol;
  final int minorUnit;
  final String locale;
  final String displayName;
  final double unitsPerEur;

  const SupportedCurrency._({
    required this.code,
    required this.symbol,
    required this.minorUnit,
    required this.locale,
    required this.displayName,
    required this.unitsPerEur,
  });

  static const eur = SupportedCurrency._(
    code: 'EUR',
    symbol: '€',
    minorUnit: 2,
    locale: 'fr_FR',
    displayName: 'Euro',
    unitsPerEur: 1,
  );
  static const usd = SupportedCurrency._(
    code: 'USD',
    symbol: '\$',
    minorUnit: 2,
    locale: 'en_US',
    displayName: 'Dollar américain',
    unitsPerEur: 1.08,
  );
  static const cad = SupportedCurrency._(
    code: 'CAD',
    symbol: 'CA\$',
    minorUnit: 2,
    locale: 'fr_CA',
    displayName: 'Dollar canadien',
    unitsPerEur: 1.47,
  );
  static const gbp = SupportedCurrency._(
    code: 'GBP',
    symbol: '£',
    minorUnit: 2,
    locale: 'en_GB',
    displayName: 'Livre sterling',
    unitsPerEur: 0.86,
  );
  static const chf = SupportedCurrency._(
    code: 'CHF',
    symbol: 'CHF',
    minorUnit: 2,
    locale: 'fr_CH',
    displayName: 'Franc suisse',
    unitsPerEur: 0.95,
  );
  static const xof = SupportedCurrency._(
    code: 'XOF',
    symbol: 'F CFA',
    minorUnit: 0,
    locale: 'fr_SN',
    displayName: 'Franc CFA Ouest',
    unitsPerEur: 655.957,
  );
  static const xaf = SupportedCurrency._(
    code: 'XAF',
    symbol: 'FCFA',
    minorUnit: 0,
    locale: 'fr_CM',
    displayName: 'Franc CFA Centre',
    unitsPerEur: 655.957,
  );

  static const values = <SupportedCurrency>[eur, usd, cad, gbp, chf, xof, xaf];

  /// Devises pour lesquelles Stripe peut traiter un paiement carte, verbatim
  /// depuis les contraintes globales du plan devise-par-annonce (2026-08-20) :
  /// « Rails carte : EUR, USD, CAD, GBP, CHF ». XOF et XAF en sont exclues :
  /// pas de rail carte. Leur rail non liquide est le mobile money, cf.
  /// [isMobileMoneyEligible].
  ///
  /// Le serveur reste seul décideur au moment du paiement réel
  /// (`AnnouncementPaymentRails.availableFor`) : ce champ ne sert qu'à
  /// prévisualiser côté client, avant qu'aucune requête n'ait de raison
  /// d'exister (choix de devise à la création d'une annonce).
  static const _stripeEligibleCodes = {'EUR', 'USD', 'CAD', 'GBP', 'CHF'};

  bool get isStripeEligible => _stripeEligibleCodes.contains(code);

  /// Devises pour lesquelles le rail mobile money (pawaPay — Orange Money,
  /// Wave, MTN) est proposé : zone CFA uniquement, XOF (Afrique de l'Ouest)
  /// et XAF (Afrique Centrale). Même logique de prévisualisation client que
  /// [isStripeEligible] — le serveur reste seul décideur au paiement réel.
  static const _mobileMoneyEligibleCodes = {'XOF', 'XAF'};

  bool get isMobileMoneyEligible => _mobileMoneyEligibleCodes.contains(code);

  static SupportedCurrency? fromCode(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toUpperCase();
    for (final currency in values) {
      if (currency.code == normalized) {
        return currency;
      }
    }
    return null;
  }

  /// Codes hors catalogue déjà signalés : un seul avertissement par code et par
  /// lancement, ce repli étant sur le chemin de chaque prix affiché.
  static final Set<String> _reportedUnknownCodes = <String>{};

  /// Repli EUR quand le code est absent ou hors catalogue. Politique de repli
  /// unique : ne jamais réécrire `fromCode(x) ?? eur` sur les sites d'appel.
  ///
  /// Un code absent reste muet (réglage pas encore synchronisé, ancien payload
  /// sans devise). Un code présent mais inconnu est signalé, une fois par code :
  /// sans ce signal, une devise ajoutée côté backend s'afficherait en euros
  /// partout sans que personne ne le voie (audit des rails du 2026-09-10,
  /// « repli euro silencieux »). Le montant reste affiché en euros faute de
  /// mieux : le backend est seul décideur au paiement, l'app ne fait qu'afficher.
  static SupportedCurrency fromCodeOrDefault(String? value) {
    final known = fromCode(value);
    if (known != null) return known;
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.isNotEmpty && _reportedUnknownCodes.add(normalized)) {
      AppLog.warn(
        'Devise hors catalogue affichée en euros',
        data: {'code': normalized},
      );
    }
    return eur;
  }

  /// Réservé aux tests : oublie les codes déjà signalés.
  static void resetUnknownCodeReportsForTest() => _reportedUnknownCodes.clear();

  /// Symbole d'un code ISO, repli EUR — pour les libellés courts (suffixe de
  /// champ, message de validation) où formater un montant complet n'a pas
  /// de sens.
  static String symbolOf(String? value) => fromCodeOrDefault(value).symbol;

  @override
  bool operator ==(Object other) =>
      other is SupportedCurrency && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
