/// IATA airport codes for Yadony departure and arrival cities.
///
/// Clés et valeurs = données de catalogue (noms de ville comparés, codes
/// IATA), jamais du texte affiché tel quel.
const kDepartureCityCodes = <String, String>{
  'Paris': 'CDG', // i18n-ignore
  'Lyon': 'LYS', // i18n-ignore
  'Marseille': 'MRS', // i18n-ignore
};

const kArrivalCityCodes = <String, String>{
  'Dakar': 'DSS', // i18n-ignore
  'Abidjan': 'ABJ', // i18n-ignore
  'Bamako': 'BKO', // i18n-ignore
  'Douala': 'DLA', // i18n-ignore
};

String cityAirportCode(String city, {required bool departure}) {
  final map = departure ? kDepartureCityCodes : kArrivalCityCodes;
  return map[city] ??
      (city.length >= 3
          ? city.substring(0, 3).toUpperCase()
          : city.toUpperCase());
}
