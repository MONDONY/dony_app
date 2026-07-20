import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_required_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le wizard de création d'une demande d'envoi, précédé du gate KYC.
///
/// Partagé entre le hub Activités et l'écran Envoyer — les deux points
/// d'entrée doivent appliquer exactement la même règle de vérification.
///
/// Retourne `true` si le wizard a été ouvert (KYC validé).
Future<bool> openPackageRequestWizard(BuildContext context) async {
  final authState = context.read<AuthBloc>().state;
  final user = switch (authState) {
    final AuthAuthenticated s => s.user,
    final AuthProfileUpdated s => s.user,
    _ => null,
  };

  if (user == null || !user.isKycVerified) {
    await KycRequiredBottomSheet.show(
      context,
      kycStatus: user?.kycStatus ?? 'NOT_STARTED',
    );
    return false;
  }

  await PackageRequestCreateWizard.show(context);
  return true;
}
