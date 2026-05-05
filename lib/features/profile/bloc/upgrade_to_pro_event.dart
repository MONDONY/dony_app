part of 'upgrade_to_pro_bloc.dart';

sealed class UpgradeToProEvent extends Equatable {
  const UpgradeToProEvent();

  @override
  List<Object?> get props => [];
}

class UpgradeToProSubmitted extends UpgradeToProEvent {
  final String companyName;
  final String siret;

  const UpgradeToProSubmitted({
    required this.companyName,
    required this.siret,
  });

  @override
  List<Object?> get props => [companyName, siret];
}
