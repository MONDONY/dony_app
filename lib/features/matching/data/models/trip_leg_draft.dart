import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:equatable/equatable.dart';

/// Étape ajoutée au formulaire de publication (FLUTTER-4D), au-delà de la
/// première qui est le trajet saisi dans le formulaire.
///
/// La ville de départ n'est pas stockée : c'est toujours la ville d'arrivée de
/// l'étape précédente, relue à la publication. Le chaînage des villes est donc
/// juste par construction ; seule la date peut devenir incohérente si
/// l'étape précédente change, ce que [TripLegChain] signale.
class TripLegDraft extends Equatable {
  const TripLegDraft({
    required this.arrivalCity,
    this.arrivalCountryCode,
    required this.departureDate,
    required this.departureTime,
    required this.deliveryAddress,
    required this.availableKg,
    this.pricePerKg,
    this.stops,
    this.currency,
    this.acceptedPaymentMethods,
  });

  final String arrivalCity;
  final String? arrivalCountryCode;

  /// Jour du départ (sans heure).
  final DateTime departureDate;

  /// Heure du départ, `HH:mm`.
  final String departureTime;

  /// Point de récupération des colis dans la ville d'arrivée.
  final AddressData deliveryAddress;
  final double availableKg;

  /// Prix au kilo propre à l'étape. `null` en mode grille seule.
  final double? pricePerKg;

  /// Escales propres à l'étape (FLUTTER-GE), en avion seulement. `null` = non
  /// renseigné. Préremplies avec celles de l'étape précédente, modifiables.
  final TripStops? stops;

  /// Devise propre à l'étape (code ISO, FLUTTER-HP) : par défaut celle du pays
  /// de départ de l'étape, modifiable dans sa feuille. `null` (étape saisie par
  /// un ancien écran) = devise du premier trajet.
  final String? currency;

  /// Moyens de paiement de l'étape, posés à la publication selon sa devise
  /// (pas de carte en zone CFA, pas de mobile money ailleurs). `null` = ceux du
  /// premier trajet, filtrés par la devise de l'étape.
  final List<String>? acceptedPaymentMethods;

  /// Copie avec les moyens de paiement résolus pour la devise de l'étape.
  TripLegDraft withPaymentMethods(List<String> methods) => TripLegDraft(
    arrivalCity: arrivalCity,
    arrivalCountryCode: arrivalCountryCode,
    departureDate: departureDate,
    departureTime: departureTime,
    deliveryAddress: deliveryAddress,
    availableKg: availableKg,
    pricePerKg: pricePerKg,
    stops: stops,
    currency: currency,
    acceptedPaymentMethods: methods,
  );

  /// Instant du départ, en heure locale.
  DateTime get departureAt {
    final parts = departureTime.split(':');
    return DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  @override
  List<Object?> get props => [
    arrivalCity,
    arrivalCountryCode,
    departureDate,
    departureTime,
    deliveryAddress,
    availableKg,
    pricePerKg,
    stops,
    currency,
    acceptedPaymentMethods,
  ];
}

/// Devise d'une étape (FLUTTER-HP). Le serveur n'impose aucune devise commune
/// aux étapes d'un voyage : chacune est une annonce avec sa propre devise.
abstract final class TripLegCurrency {
  /// Devise par défaut d'une étape partant de [countryCode] : celle du pays
  /// (miroir de `CountryCatalog`), sinon [fallback] (pays inconnu ou hors
  /// catalogue).
  static SupportedCurrency defaultFor(
    String? countryCode, {
    required SupportedCurrency fallback,
  }) => CountryCatalog.byCode(countryCode)?.currency ?? fallback;

  /// Devise de [leg], [fallback] (devise du premier trajet) si elle n'en porte
  /// pas.
  static SupportedCurrency of(TripLegDraft leg, SupportedCurrency fallback) =>
      SupportedCurrency.fromCode(leg.currency) ?? fallback;

  /// Retire de [methods] les moyens que [currency] n'autorise pas, miroir de
  /// `AnnouncementPaymentRails.restrictToCurrency` : jamais vide, les espèces
  /// restent toujours possibles.
  static List<String> restrictPaymentMethods(
    List<String> methods,
    SupportedCurrency currency,
  ) {
    final kept = [
      for (final m in methods)
        if (m == 'CASH' ||
            (m == 'STRIPE' && currency.isStripeEligible) ||
            (m == 'MOBILE_MONEY' && currency.isMobileMoneyEligible))
          m,
    ];
    return kept.isEmpty ? const ['CASH'] : kept;
  }

  /// Moyens de paiement d'une étape dans [currency], d'après les choix faits
  /// sur le premier trajet (dans [firstCurrency]).
  ///
  /// Mêmes choix, bornés par la devise de l'étape : la carte seulement hors
  /// zone CFA (et Stripe Connect prêt), le mobile money seulement en zone CFA.
  /// Les espèces partent dès que la carte ne part pas, comme pour le premier
  /// trajet. Quand la devise du premier trajet ne permettait pas le mobile
  /// money (bascule grisée, le voyageur n'a pas pu le refuser), une étape en
  /// franc CFA l'accepte si le compte de versement est actif dans sa devise.
  /// Le serveur refiltre par devise (`AnnouncementPaymentRails`).
  static List<String> paymentMethodsFor(
    SupportedCurrency currency, {
    required SupportedCurrency firstCurrency,
    required bool stripeConfigured,
    required bool cardEnabled,
    required bool cashEnabled,
    required bool mobileMoneyEnabled,
    required bool mobileMoneyAccountActive,
    SupportedCurrency? mobileMoneyAccountCurrency,
  }) {
    final cardOn = stripeConfigured && currency.isStripeEligible && cardEnabled;
    final mobileMoneyOn =
        currency.isMobileMoneyEligible &&
        (firstCurrency.isMobileMoneyEligible
            ? mobileMoneyEnabled
            : mobileMoneyAccountActive &&
                  mobileMoneyAccountCurrency == currency);
    return [
      if (cardOn) 'STRIPE',
      if (cashEnabled || !cardOn) 'CASH',
      if (mobileMoneyOn) 'MOBILE_MONEY',
    ];
  }
}

/// Point d'arrivée d'une étape, d'où part la suivante.
class TripLegOrigin extends Equatable {
  const TripLegOrigin({
    required this.city,
    this.countryCode,
    required this.arrivalDay,
    this.address,
  });

  final String city;
  final String? countryCode;

  /// Jour d'arrivée de l'étape : la suivante ne peut pas partir avant.
  final DateTime arrivalDay;

  /// Adresse de récupération de l'étape, reprise comme point de remise de la
  /// suivante (même ville).
  final AddressData? address;

  @override
  List<Object?> get props => [city, countryCode, arrivalDay, address];
}

/// Règles de chaînage, alignées sur `TripLegRules` côté serveur.
abstract final class TripLegChain {
  /// Nombre maximal d'étapes d'un voyage, première comprise.
  static const int maxLegs = 5;

  /// Origine de l'étape d'indice [index] dans [legs] (0 = première étape
  /// ajoutée), la première partant de [first].
  static TripLegOrigin originOf(
    TripLegOrigin first,
    List<TripLegDraft> legs,
    int index,
  ) {
    if (index == 0) return first;
    final previous = legs[index - 1];
    return TripLegOrigin(
      city: previous.arrivalCity,
      countryCode: previous.arrivalCountryCode,
      arrivalDay: previous.departureDate,
      address: previous.deliveryAddress,
    );
  }

  /// Comparaison de villes alignée sur `TripLegRules.sameCity` côté serveur :
  /// casse, espaces et accents ignorés.
  static bool sameCity(String? a, String? b) {
    if (a == null || b == null) return false;
    return _normalize(a) == _normalize(b);
  }

  static String _normalize(String s) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ'; // i18n-ignore
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    final buf = StringBuffer();
    for (final ch in s.trim().toLowerCase().split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Vrai si [leg] part avant le jour d'arrivée de [origin].
  static bool departsTooEarly(TripLegOrigin origin, TripLegDraft leg) {
    final day = DateTime(
      origin.arrivalDay.year,
      origin.arrivalDay.month,
      origin.arrivalDay.day,
    );
    return leg.departureDate.isBefore(day);
  }

  /// Indices (0-based) des étapes ajoutées dont la date ne suit plus.
  static Set<int> invalidIndexes(TripLegOrigin first, List<TripLegDraft> legs) {
    final out = <int>{};
    for (var i = 0; i < legs.length; i++) {
      if (departsTooEarly(originOf(first, legs, i), legs[i])) out.add(i);
    }
    return out;
  }
}
