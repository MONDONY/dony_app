import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';

abstract class PriceGridState {}

class PriceGridInitial extends PriceGridState {}

class PriceGridLoading extends PriceGridState {}

class PriceGridLoaded extends PriceGridState {
  final List<PriceGridItemModel> items;
  PriceGridLoaded(this.items);
}

class PriceGridError extends PriceGridState {
  final String message;
  PriceGridError(this.message);
}
