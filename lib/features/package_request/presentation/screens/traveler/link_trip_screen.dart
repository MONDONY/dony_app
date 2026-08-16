import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart';
import 'package:dony/features/package_request/presentation/widgets/trip_picker_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// TODO(lot2): migrate loading state to LinkTripCubit (BLoC pattern)

export 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart'
    show PaymentCapabilityBlock;

/// Screen shown to the traveler after sender accepted the offer.
/// They must pick one of their existing trips matching the corridor + date,
/// or create a new one which will be auto-linked.
class LinkTripScreen extends StatefulWidget {
  const LinkTripScreen({
    required this.thread,
    this.autoCreateDedicated = false,
    super.key,
  });
  final NegotiationThread thread;

  /// Si `true`, after loading, navigates directly to the trip creation form
  /// without the user having to tap "Créer un nouveau trajet".
  /// Used when navigating from the "Créer un trajet dédié" button.
  final bool autoCreateDedicated;

  @override
  State<LinkTripScreen> createState() => _LinkTripScreenState();
}

class _LinkTripScreenState extends State<LinkTripScreen> {
  // Loading state — ValueNotifiers used instead of setState (BLoC rule compliance).
  final _loadingNotifier = ValueNotifier<bool>(true);
  final _errorNotifier = ValueNotifier<String?>(null);
  final _requestNotifier = ValueNotifier<PackageRequest?>(null);
  final _selectedTripNotifier = ValueNotifier<AnnouncementModel?>(null);
  final _tripPickerKey = GlobalKey<TripPickerSectionState>();

  /// True while `/trips/create` (dedicated-trip creation) is on top of this
  /// screen. That screen owns error handling for the SAME shared
  /// `NegotiationBloc` while it's active (cf. `create_trip_screen.dart`'s
  /// `_isLocked` `BlocListener`) — without this guard, this screen's
  /// `BlocListener` (still subscribed underneath, merely not visible) would
  /// ALSO react to the same `NegotiationError`/`NegotiationLoaded` and stack
  /// duplicate feedback (double sheets/snackbar for a single 422).
  final _creatingDedicatedTripNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.autoCreateDedicated &&
          mounted &&
          _errorNotifier.value == null) {
        _createNewTrip();
      }
    });
  }

  @override
  void dispose() {
    _loadingNotifier.dispose();
    _errorNotifier.dispose();
    _requestNotifier.dispose();
    _selectedTripNotifier.dispose();
    _creatingDedicatedTripNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loadingNotifier.value = true;
    _errorNotifier.value = null;
    _selectedTripNotifier.value = null;

    try {
      // Fetch the request to know its corridor + date window. Matching-trip
      // loading/filtering is owned by TripPickerSection (see below).
      final request = await getIt<PackageRequestRepository>().getById(
        widget.thread.packageRequestId,
      );

      // The traveler no longer declares a payment method or gets preemptively
      // blocked client-side: the back-end computes the actual capability SET
      // at submit time and returns a specific 422 reason when it's empty
      // (handled reactively in the BlocListener below).
      if (mounted) {
        _requestNotifier.value = request;
        _loadingNotifier.value = false;
      }
    } catch (e) {
      if (mounted) {
        // Passe par ErrorPresenter : sans ça l'exception brute (en anglais,
        // ex. « Connection refused… ») remonte telle quelle à l'utilisateur.
        _errorNotifier.value = ErrorPresenter.resolve(e).message;
        _loadingNotifier.value = false;
      }
    }
  }

  void _selectTrip(AnnouncementModel ann) {
    _selectedTripNotifier.value = ann;
  }

  Future<void> _confirmTrip() async {
    final ann = _selectedTripNotifier.value;
    final request = _requestNotifier.value;
    if (ann == null || request == null) return;
    if (widget.thread.status == NegotiationThreadStatus.awaitingTrip) {
      // Legacy `refuseTrip` recovery loop: the back-end still requires
      // submitTrip (with a paymentMethod) for this specific status.
      context.read<NegotiationBloc>().add(
        NegotiationSubmitTripRequested(
          threadId: widget.thread.id,
          travelerAnnouncementId: ann.id,
          // The back-end no longer decides capability from this field — it
          // only requires a non-null accepted method to satisfy the DTO. The
          // actual payment method is chosen by the sender at checkout, from
          // the SET the back-end computes server-side. Falls back to stripe
          // on an empty set (shouldn't happen — a request always has at
          // least one accepted method — but `.first` on an empty Set throws
          // StateError).
          paymentMethod: request.acceptedPaymentMethods.isEmpty
              ? PaymentMethod.stripe
              : request.acceptedPaymentMethods.first,
        ),
      );
    } else {
      // New flow: the thread already has a linked trip (status OPEN) — this
      // screen is reached via a "change trip" entry point rather than the
      // post-acceptance auto-navigation.
      context.read<NegotiationBloc>().add(
        NegotiationChangeTripRequested(
          threadId: widget.thread.id,
          travelerAnnouncementId: ann.id,
        ),
      );
    }
    // Navigation handled by BlocListener on NegotiationLoaded
    // (awaitingPayment or open).
  }

  /// Retry after the cash-insufficient / no-payment-method sheet. Always
  /// dispatches the legacy `submitTrip` event — **not** branched on
  /// `widget.thread.status` like [_confirmTrip], and intentionally so:
  /// `NegotiationChangeTripRequested` / `NegotiationRepository.changeTrip`
  /// (`PATCH /negotiations/{id}/trip`) carries no `paymentMethod` or
  /// `useCardForCommission` field at all — by design, per the
  /// task-13-brief.md contract for the OPEN "change trip" flow. Server-side,
  /// `cash-funds-required` is only ever thrown from `submitTrip`'s
  /// `computeAvailableMethods`/`assertNonEmptyOrThrow` path
  /// (`NegotiationService`), which `changeTrip` does not call — swapping the
  /// linked trip on an already-OPEN thread does not re-negotiate payment
  /// capability. So the cash-insufficient/no-payment-method sheets are
  /// structurally unreachable from an OPEN-status thread today, and
  /// `_resubmitCash` correctly has only the one (legacy AWAITING_TRIP) path
  /// to retry. If a future backend change makes `changeTrip` recompute
  /// capability, this method (and `NegotiationChangeTripRequested`, which
  /// would need a `useCardForCommission` field) must be revisited together.
  void _resubmitCash(String announcementId, {required bool useCard}) {
    if (!mounted) return;
    context.read<NegotiationBloc>().add(
      NegotiationSubmitTripRequested(
        threadId: widget.thread.id,
        travelerAnnouncementId: announcementId,
        paymentMethod: PaymentMethod.cash,
        useCardForCommission: useCard,
      ),
    );
  }

  Future<void> _createNewTrip() async {
    final r = _requestNotifier.value;
    if (r == null) return;
    final lockContext = LockedTripContext(
      threadId: widget.thread.id,
      packageRequestId: r.id,
      departureCity: r.departureCity,
      arrivalCity: r.arrivalCity,
      desiredDate: r.desiredDate,
      dateToleranceDays: r.dateToleranceDays,
      weightKg: r.weightKg,
      transportMode: r.transportMode,
      agreedPriceEur: widget.thread.currentPriceEur,
      paymentMethod: r.acceptedPaymentMethods.isEmpty
          ? PaymentMethod.stripe
          : r.acceptedPaymentMethods.first,
      currency: widget.thread.currency,
    );
    // While /trips/create is on top, IT owns error handling for the shared
    // NegotiationBloc (cf. `_creatingDedicatedTripNotifier` doc above) — this
    // screen's BlocListener must stand down for the duration of the push.
    _creatingDedicatedTripNotifier.value = true;
    try {
      await context.push<bool>(
        '/trips/create',
        extra: CreateTripArgs(
          lockContext: lockContext,
          negotiationBloc: context.read<NegotiationBloc>(),
        ),
      );
    } finally {
      if (mounted) _creatingDedicatedTripNotifier.value = false;
    }
    // The sheet's BlocListener pops itself on success and the screen-level
    // listener below will pop us back. If the user cancelled, we still
    // refresh the matching list.
    if (mounted) await _tripPickerKey.currentState?.reload();
  }

  /// Un trajet n'est modifiable que si ses adresses sont complètes
  /// (requises par AnnouncementUpdateRequested, remplacement complet).
  bool _canModify(AnnouncementModel ann) =>
      ann.pickupAddress != null && ann.deliveryAddress != null;

  Future<void> _openModifySheet(AnnouncementModel ann) async {
    // Même wizard 3 étapes que la création, en mode édition : champs préremplis,
    // corridor + date verrouillés (le trajet doit rester compatible avec la
    // demande), tout le reste éditable.
    await context.push<bool>(
      '/trips/create',
      extra: CreateTripArgs(announcement: ann, lockCorridorAndDate: true),
    );
    if (mounted) {
      await _tripPickerKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<NegotiationBloc, NegotiationState>(
      listenWhen: (prev, curr) =>
          curr is NegotiationLoaded || curr is NegotiationError,
      listener: (context, state) {
        if (state is NegotiationLoaded &&
            (state.thread.status == NegotiationThreadStatus.awaitingPayment ||
                state.thread.status == NegotiationThreadStatus.open)) {
          // Trip linked (legacy AWAITING_TRIP -> AWAITING_PAYMENT) or changed
          // (new flow: OPEN -> OPEN) successfully: leave this screen.
          if (context.canPop()) context.pop();
        } else if (state is NegotiationError) {
          // `/trips/create` is on top and already owns error handling for
          // this SAME shared bloc (cf. `_creatingDedicatedTripNotifier` doc):
          // reacting here too would stack duplicate feedback.
          if (_creatingDedicatedTripNotifier.value) return;
          // Le voyageur ne choisit plus de mode de paiement : le back-end
          // calcule la SET qu'il peut réellement fournir et ne rejette (422)
          // que si elle est vide. Chaque reason route vers son CTA dédié,
          // jamais un message d'erreur sans issue.
          final block = PaymentCapabilityBlock.fromErrorCode(state.error.code);
          final announcementId = _selectedTripNotifier.value?.id;
          if (block == PaymentCapabilityBlock.cardCapabilityRequired) {
            showCardCapabilityRequiredSheet(context);
          } else if (block == PaymentCapabilityBlock.cashFundsRequired &&
              announcementId != null) {
            showCashInsufficientSheet(
              context,
              netPriceEur: widget.thread.currentPriceEur,
              grossPriceEur: widget.thread.grossPriceEur,
              currency: widget.thread.currency,
              onResubmit: ({required useCard}) =>
                  _resubmitCash(announcementId, useCard: useCard),
            );
          } else if (block == PaymentCapabilityBlock.noneAvailable &&
              announcementId != null) {
            showNoPaymentMethodAvailableSheet(
              context,
              netPriceEur: widget.thread.currentPriceEur,
              grossPriceEur: widget.thread.grossPriceEur,
              currency: widget.thread.currency,
              onResubmit: ({required useCard}) =>
                  _resubmitCash(announcementId, useCard: useCard),
            );
          } else {
            DonySnackbar.show(
              context,
              message: state.error.message,
              type: DonySnackbarType.error,
            );
          }
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: _loadingNotifier,
        builder: (context, loading, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: _errorNotifier,
            builder: (context, error, _) {
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: const DonyAppBar(title: 'Lier un trajet'),
                body: loading
                    ? Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      )
                    : error != null
                    ? _ErrorView(message: error, onRetry: _load)
                    : _buildBody(),
                bottomNavigationBar: (loading || error != null)
                    ? const SizedBox.shrink()
                    : ValueListenableBuilder<AnnouncementModel?>(
                        valueListenable: _selectedTripNotifier,
                        builder: (context, selectedTrip, _) {
                          return SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                DonySpacing.lg,
                                DonySpacing.sm,
                                DonySpacing.lg,
                                DonySpacing.base,
                              ),
                              child: DonySelectBar(
                                defaultLabel: 'Sélectionner un trajet',
                                confirmedLabel: 'Confirmer ce trajet',
                                selectedSummary: selectedTrip != null
                                    ? (selectedTrip.isKgFree
                                          ? '${DateFormat('EEE d MMM', 'fr').format(selectedTrip.departureDate)} · Kg libre'
                                          : '${DateFormat('EEE d MMM', 'fr').format(selectedTrip.departureDate)} · ${selectedTrip.availableKg} kg dispo')
                                    : null,
                                selectedCount: selectedTrip != null
                                    ? '1 trajet'
                                    : null,
                                onConfirm: selectedTrip != null
                                    ? _confirmTrip
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final r = _requestNotifier.value!;
    return ValueListenableBuilder<AnnouncementModel?>(
      valueListenable: _selectedTripNotifier,
      builder: (context, selectedTrip, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.lg,
            MediaQuery.paddingOf(context).bottom +
                100, // room for DonySelectBar + safe area
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [DonyColors.blue500, DonyColors.blue700],
                  ),
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demande acceptée à ${formatPriceIn(widget.thread.currentPriceEur, widget.thread.currency)}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.departureCity} → ${r.arrivalCity}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Date de voyage : ${DateFormat('d MMM yyyy', 'fr').format(widget.thread.travelerTravelDate)}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.xl),
              _AvailablePaymentMethodsPreview(
                // Après un premier submitTrip réussi, la réponse du back-end
                // porte la SET calculée serveur ; avant soumission on affiche
                // les méthodes acceptées par la demande, en aperçu.
                methods:
                    widget.thread.availablePaymentMethods ??
                    r.acceptedPaymentMethods,
              ),
              const SizedBox(height: DonySpacing.xl),
              TripPickerSection(
                key: _tripPickerKey,
                departureCity: r.departureCity,
                arrivalCity: r.arrivalCity,
                desiredDate: r.desiredDate,
                dateToleranceDays: r.dateToleranceDays,
                weightKg: r.weightKg,
                selected: selectedTrip,
                onSelected: _selectTrip,
                onCreateDedicated: _createNewTrip,
                onModify: _openModifySheet,
                canModify: _canModify,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bloc lecture seule affiché au trip-linking : le voyageur ne choisit plus
/// de mode de paiement, il ne fait que déclarer sa capacité (au submit). Cet
/// affichage montre les méthodes que l'expéditeur pourra choisir au checkout
/// : un aperçu (`request.acceptedPaymentMethods`) avant soumission, ou la SET
/// calculée par le back-end (`thread.availablePaymentMethods`) une fois le
/// trajet lié.
class _AvailablePaymentMethodsPreview extends StatelessWidget {
  const _AvailablePaymentMethodsPreview({required this.methods});

  final Set<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (methods.isEmpty) return const SizedBox.shrink();

    // Canonical order: STRIPE first, then CASH, then others
    final ordered = PaymentMethod.canonicalOrder
        .where(methods.contains)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'L\'expéditeur choisira parmi',
          style: tt.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: ordered.map((method) {
            return Container(
              key: Key(
                'payment-method-preview-${method.wireName.toLowerCase()}',
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(method.icon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    method.displayLabel,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DonyIcon('circle-alert', size: 48, color: kError),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
