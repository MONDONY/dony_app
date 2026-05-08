abstract class CitySearchEvent {
  const CitySearchEvent();
}

class CitySearchQueryChanged extends CitySearchEvent {
  const CitySearchQueryChanged(this.query);
  final String query;
}

class CitySearchCleared extends CitySearchEvent {
  const CitySearchCleared();
}
