import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:equatable/equatable.dart';

abstract class PriceGridState extends Equatable {
  const PriceGridState();
  @override
  List<Object?> get props => [];
}

class PriceGridInitial extends PriceGridState {
  const PriceGridInitial();
}

class PriceGridLoading extends PriceGridState {
  const PriceGridLoading();
}

class PriceGridLoaded extends PriceGridState {
  final List<PriceGridItemModel> items;
  const PriceGridLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class PriceGridError extends PriceGridState {
  final String message;
  const PriceGridError(this.message);
  @override
  List<Object?> get props => [message];
}
