import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_bloc.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_event.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_state.dart';
import 'package:dony/features/rebooking/presentation/widgets/past_booking_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PastBookingsScreen extends StatefulWidget {
  const PastBookingsScreen({super.key});

  @override
  State<PastBookingsScreen> createState() => _PastBookingsScreenState();
}

class _PastBookingsScreenState extends State<PastBookingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PastBookingsBloc>().add(const LoadPastBookings());
  }

  void _showNoTripSheet(BuildContext context, String travelerId) {
    final bloc = context.read<PastBookingsBloc>();
    DonyBottomSheet.show(
      context,
      title: 'Aucun voyage disponible',
      stickyBottom: DonyButton(
        label: 'Me notifier à la prochaine annonce',
        icon: Icons.notifications_active_rounded,
        onPressed: () {
          bloc.add(SubscribeToTraveler(travelerId));
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flight_takeoff_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            "Ce voyageur n'a pas encore publié de prochain départ. "
            'Sois prévenu dès qu\'il en publie un.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes voyageurs')),
      body: BlocConsumer<PastBookingsBloc, PastBookingsState>(
        listener: (context, state) {
          if (state is RebookSuccess) {
            DonySnackbar.show(
              context,
              message: 'Réservation créée avec succès !',
              type: DonySnackbarType.success,
            );
            context.go('/profile/shipments/history');
          }
          if (state is NoTripAvailable) {
            _showNoTripSheet(context, state.travelerId);
          }
          if (state is TravelerSubscribed) {
            DonySnackbar.show(
              context,
              message: 'Tu seras notifié dès sa prochaine annonce.',
              type: DonySnackbarType.success,
            );
          }
          if (state is PastBookingsError) {
            DonySnackbar.show(
              context,
              message: state.message,
              type: DonySnackbarType.error,
            );
          }
        },
        builder: (context, state) {
          if (state is PastBookingsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PastBookingsLoaded) {
            if (state.bookings.isEmpty) {
              return const DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: 'Pas encore de voyages complétés',
                description:
                    'Tes voyageurs apparaîtront ici après ton premier envoi livré. '
                    'Tu pourras les re-réserver en un geste.',
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
                MediaQuery.paddingOf(context).bottom + DonySpacing.base,
              ),
              itemCount: state.bookings.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: DonySpacing.md),
              itemBuilder: (context, i) {
                final item = state.bookings[i];
                return PastBookingCard(
                  booking: item,
                  onRebook: () => context
                      .read<PastBookingsBloc>()
                      .add(RebookTraveler(item.bidId)),
                );
              },
            );
          }

          if (state is RebookingInProgress) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: DonySpacing.base),
                  Text('Vérification de la disponibilité…'),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
