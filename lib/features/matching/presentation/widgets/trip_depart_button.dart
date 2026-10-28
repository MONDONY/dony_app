import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bouton « Je pars » du trajet. Disparaît une fois le départ confirmé depuis
/// cet appareil. Toute la logique vit dans [TripDepartCubit].
class TripDepartButton extends StatelessWidget {
  const TripDepartButton({super.key, required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TripDepartCubit>(
      create: (_) => getIt<TripDepartCubit>(param1: announcementId),
      child: BlocConsumer<TripDepartCubit, TripDepartState>(
        listenWhen: (a, b) =>
            (!a.departed && b.departed) ||
            (a.error != b.error && b.error != null),
        listener: (context, state) {
          if (state.departed) {
            DonySnackbar.show(
              context,
              message: context.l10n.tripDepartConfirmedSnackbar,
              type: DonySnackbarType.success,
            );
          } else {
            final error = state.error;
            if (error != null) {
              ErrorPresenter.show(context, error);
            }
          }
        },
        builder: (context, state) {
          if (state.departed) {
            return const SizedBox.shrink();
          }
          return DonyButton(
            key: const Key('trip-depart-button'),
            label: context.l10n.tripDepartButton,
            isLoading: state.loading,
            onPressed: state.loading
                ? null
                : () => context.read<TripDepartCubit>().depart(context),
          );
        },
      ),
    );
  }
}
