import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/receptions/bloc/parcel_link_cubit.dart';
import 'package:dony/features/receptions/data/models/parcel_role.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvert par `yadony://colis/{id}` (bouton « Ouvrir dans Yadony » de la page
/// publique du QR colis). Remplace l'écran par la fiche qui correspond au rôle
/// de l'utilisateur sur le colis, ou explique que le colis n'est pas le sien.
class ParcelLinkScreen extends StatelessWidget {
  const ParcelLinkScreen({required this.bidId, super.key});

  final String bidId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: DonyAppBar(title: l.parcelLinkTitle),
      body: BlocConsumer<ParcelLinkCubit, ParcelLinkState>(
        listener: (context, state) {
          if (state is! ParcelLinkResolved) return;
          switch (state.role) {
            case ParcelRole.recipient:
              context.pushReplacement('/receptions/$bidId');
            case ParcelRole.sender:
            case ParcelRole.traveler:
              context.pushReplacement('/bids/$bidId');
            case ParcelRole.none:
              break;
          }
        },
        builder: (context, state) => switch (state) {
          ParcelLinkResolved(role: ParcelRole.none) => _Message(
            title: l.parcelLinkNotLinkedTitle,
            body: l.parcelLinkNotLinkedBody,
            actionLabel: l.profileHelpContactSupport,
            onAction: () => context.pushReplacement('/support'),
          ),
          ParcelLinkError(:final error) => _errorMessage(context, error),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _errorMessage(BuildContext context, Object error) {
    final presentation = ErrorPresenter.resolve(error, l10n: context.l10n);
    return _Message(
      title: presentation.title,
      body: presentation.message,
      actionLabel: context.l10n.parcelLinkRetry,
      onAction: () => context.read<ParcelLinkCubit>().load(bidId),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          DonyButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
