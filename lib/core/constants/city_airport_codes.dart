/// IATA airport codes for Yadony departure and arrival cities.
const kDepartureCityCodes = <String, String>{
  'Paris': 'CDG',
  'Lyon': 'LYS',
  'Marseille': 'MRS',
};

const kArrivalCityCodes = <String, String>{
  'Dakar': 'DSS',
  'Abidjan': 'ABJ',
  'Bamako': 'BKO',
  'Douala': 'DLA',
};

String cityAirportCode(String city, {required bool departure}) {
  final map = departure ? kDepartureCityCodes : kArrivalCityCodes;
  return map[city] ??
      (city.length >= 3 ? city.substring(0, 3).toUpperCase() : city.toUpperCase());
}
