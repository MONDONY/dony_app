abstract class CommissionMethodEvent {}

class CommissionMethodLoadRequested extends CommissionMethodEvent {}

class CommissionMethodSetupRequested extends CommissionMethodEvent {}

class CommissionMethodSetupCompleted extends CommissionMethodEvent {
  final String paymentMethodId;
  CommissionMethodSetupCompleted(this.paymentMethodId);
}

class CommissionMethodSetupCancelled extends CommissionMethodEvent {}

class CommissionMethodDeleteRequested extends CommissionMethodEvent {}
