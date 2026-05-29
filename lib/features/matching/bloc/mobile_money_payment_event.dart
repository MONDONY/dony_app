import 'package:equatable/equatable.dart';

sealed class MobileMoneyPaymentEvent extends Equatable {
  const MobileMoneyPaymentEvent();

  @override
  List<Object?> get props => [];
}

class MobileMoneyStatusPolled extends MobileMoneyPaymentEvent {
  const MobileMoneyStatusPolled({required this.bidId});
  final String bidId;

  @override
  List<Object?> get props => [bidId];
}

class MobileMoneyLinkRegenRequested extends MobileMoneyPaymentEvent {
  const MobileMoneyLinkRegenRequested({required this.bidId});
  final String bidId;

  @override
  List<Object?> get props => [bidId];
}
