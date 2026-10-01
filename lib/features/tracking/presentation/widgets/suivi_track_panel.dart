import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:dony/features/receptions/presentation/widgets/receptions_section.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_invitations_banner.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/presentation/widgets/parcel_not_linked_notice.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/shipment_progress_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Contenu du mode « Suivre un colis » : numéro de suivi, lecteur QR plein
/// écran (utilisateur sans caméra dans l'onglet), « Colis à recevoir » et
/// « Mes envois ».
/// Rien n'y est validé : chaque entrée ouvre le parcours en lecture seule.
class SuiviTrackPanel extends StatelessWidget {
  const SuiviTrackPanel({super.key, this.onScanQr});

  /// Bouton « Scanner un QR code » ; `null` le masque (la caméra de l'onglet
  /// est déjà ouverte au-dessus).
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final scan = onScanQr;

    return BlocBuilder<SuiviCubit, SuiviState>(
      builder: (context, state) {
        final error = state.searchStatus == SuiviLoadStatus.error
            ? state.searchError
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TrackNumberField(
              loading: state.searchStatus == SuiviLoadStatus.loading,
            ),
            if (error is ForbiddenException) ...[
              const SizedBox(height: DonySpacing.md),
              const ParcelNotLinkedNotice(),
            ] else if (error != null) ...[
              const SizedBox(height: DonySpacing.sm),
              Text(
                ErrorPresenter.resolve(error, l10n: l).message,
                key: const Key('suivi-search-error'),
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            if (scan != null) ...[
              const SizedBox(height: DonySpacing.md),
              DonyButton(
                key: const Key('suivi-scan-qr'),
                label: l.suiviScanQr,
                iconAsset: 'scan-line',
                variant: DonyButtonVariant.secondary,
                onPressed: scan,
              ),
            ],
            const SizedBox(height: DonySpacing.xl),
            // Colis à recevoir : masquée tant qu'elle est vide.
            // Demandes d'expéditeurs en attente (lot 4), en tête de la
            // section.
            const RecipientInvitationsBanner(),
            const ReceptionsSection(),
            _MyShipments(state: state),
          ],
        );
      },
    );
  }
}

class _TrackNumberField extends StatefulWidget {
  const _TrackNumberField({required this.loading});

  final bool loading;

  @override
  State<_TrackNumberField> createState() => _TrackNumberFieldState();
}

class _TrackNumberFieldState extends State<_TrackNumberField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    _focusNode.unfocus();
    context.read<SuiviCubit>().trackNumber(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    // Bouton à la hauteur du champ : IntrinsicHeight + stretch.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              key: const Key('suivi-number-field'),
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              // L'erreur d'une recherche précédente ne survit pas à la saisie.
              onChanged: (_) => context.read<SuiviCubit>().clearSearchError(),
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: l.trackingSearchNumberLabel,
                hintText: 'DON-XXXXXX', // i18n-ignore — format de numéro
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(DonySpacing.md),
                  child: DonyIcon('qr-code', size: 18, color: cs.primary),
                ),
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          FilledButton(
            key: const Key('suivi-number-submit'),
            onPressed: widget.loading ? null : _submit,
            // Couleurs du bouton primaire du thème (libellé contrasté en clair
            // comme en sombre). Largeur minimale bornée : celle du thème est
            // infinie et cassait la Row.
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DonyRadius.lg),
              ),
            ),
            // Pas de `style` sur le Text : celui du textTheme porte la couleur
            // du texte courant et masquait le libellé (bleu nuit sur bleu nuit).
            child: widget.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(l.suiviTrackSubmit),
          ),
        ],
      ),
    );
  }
}

class _MyShipments extends StatelessWidget {
  const _MyShipments({required this.state});

  final SuiviState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final loaded = state.shipmentsStatus == SuiviLoadStatus.loaded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: l.suiviMyShipments,
            children: [
              if (loaded && state.shipments.isNotEmpty)
                TextSpan(
                  text: '  ${state.shipments.length}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          style: tt.headlineMedium,
        ),
        const SizedBox(height: DonySpacing.sm),
        switch (state.shipmentsStatus) {
          SuiviLoadStatus.idle || SuiviLoadStatus.loading => Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
            child: Center(child: CircularProgressIndicator(color: cs.primary)),
          ),
          SuiviLoadStatus.error => Row(
            children: [
              Expanded(
                child: Text(
                  l.suiviShipmentsError,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () => context.read<SuiviCubit>().loadShipments(),
                child: Text(l.commonRetry),
              ),
            ],
          ),
          SuiviLoadStatus.loaded when state.shipments.isEmpty => Text(
            l.suiviNoShipments,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          SuiviLoadStatus.loaded => Column(
            children: [
              for (final bid in state.shipments)
                Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                  child: _ShipmentRow(bid: bid),
                ),
            ],
          ),
        },
      ],
    );
  }
}

class _ShipmentRow extends StatelessWidget {
  const _ShipmentRow({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final from = bid.departureCity;
    final to = bid.arrivalCity;
    final titleStyle = tt.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final step = shipmentStepFor(bid.status) ?? 1;
    final moving = bid.status == 'IN_TRANSIT'; // i18n-ignore — statut back

    return DonyPressable(
      key: Key('suivi-shipment-${bid.id}'),
      onTap: () => context.read<SuiviCubit>().trackShipment(bid),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: from != null && to != null
                      ? RouteLabel(from: from, to: to, style: titleStyle)
                      : Text(
                          bid.trackingNumber ?? bid.recipientName ?? '',
                          style: titleStyle,
                        ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  l.suiviShipmentStatus(bid.status),
                  style: tt.labelLarge?.copyWith(
                    color: moving ? DonyColors.terra700 : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (bid.trackingNumber != null) ...[
              const SizedBox(height: DonySpacing.xxs),
              Text(
                bid.trackingNumber!,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(height: DonySpacing.md),
            ShipmentProgressBar(step: step),
          ],
        ),
      ),
    );
  }
}
