import 'package:dony/features/payments/cash/data/models/commission_method.dart';

abstract class CommissionMethodState {}

class CommissionMethodInitial extends CommissionMethodState {}

class CommissionMethodLoading extends CommissionMethodState {}

class CommissionMethodLoaded extends CommissionMethodState {
  final CommissionMethod card;
  CommissionMethodLoaded(this.card);
}

class CommissionMethodNotConfigured extends CommissionMethodState {}

class CommissionMethodSetupInProgress extends CommissionMethodState {
  final String clientSecret;
  CommissionMethodSetupInProgress(this.clientSecret);
}

class CommissionMethodError extends CommissionMethodState {
  final String message;
  CommissionMethodError(this.message);
}
