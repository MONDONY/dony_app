import 'package:dony/features/city/data/city_model.dart';

abstract class CitySearchState {
  const CitySearchState();
}

class CitySearchInitial extends CitySearchState {
  const CitySearchInitial();
}

class CitySearchLoading extends CitySearchState {
  const CitySearchLoading();
}

class CitySearchLoaded extends CitySearchState {
  const CitySearchLoaded(this.cities);
  final List<CityModel> cities;
}

class CitySearchError extends CitySearchState {
  const CitySearchError(this.message);
  final String message;
}
