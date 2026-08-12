import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentState extends Equatable {
  const MobileMoneyPaymentState();

  @override
  List<Object?> get props => [];
}

class MobileMoneyPaymentInitial extends MobileMoneyPaymentState {
  const MobileMoneyPaymentInitial();
}

class MobileMoneyPaymentLoading extends MobileMoneyPaymentState {
  const MobileMoneyPaymentLoading();
}

class MobileMoneyPaymentPending extends MobileMoneyPaymentState {
  const MobileMoneyPaymentPending({
    required this.paymentLink,
    this.expiresAt,
  });
  final String paymentLink;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [paymentLink, expiresAt];
}

class MobileMoneyPaymentConfirmed extends MobileMoneyPaymentState {
  const MobileMoneyPaymentConfirmed();
}

class MobileMoneyPaymentExpired extends MobileMoneyPaymentState {
  const MobileMoneyPaymentExpired();
}

class MobileMoneyPaymentError extends MobileMoneyPaymentState {
  const MobileMoneyPaymentError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
