abstract class CommissionMethodEvent {}

class CommissionMethodLoadRequested extends CommissionMethodEvent {}

class CommissionMethodSetupRequested extends CommissionMethodEvent {}

class CommissionMethodSetupCompleted extends CommissionMethodEvent {}

class CommissionMethodSetupCancelled extends CommissionMethodEvent {}

class CommissionMethodDeleteRequested extends CommissionMethodEvent {}
