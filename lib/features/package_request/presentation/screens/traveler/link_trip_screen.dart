import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/traveler/trip_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// TODO(lot2): migrate loading state to LinkTripCubit (BLoC pattern)

/// Maps the 422 reasons the back-end returns from `submitTrip` /
/// `createDedicatedTrip` when the traveler cannot honor any payment method
/// the sender accepted, to the block-specific UX the screen must show.
///
/// The traveler no longer picks a payment method at trip-linking: the
/// back-end computes the SET of methods it can actually provide, and only
/// rejects (422) when that set is empty. Each reason maps to exactly one
/// contextual CTA — never a dead-end error message.
enum PaymentCapabilityBlock {
  /// Colis is card-only; the traveler has no Stripe Connect onboarding.
  cardCapabilityRequired,

  /// Colis is cash-only; the traveler lacks wallet funds AND card consent.
  cashFundsRequired,

  /// Both methods are accepted by the sender, neither is possible for the
  /// traveler.
  noneAvailable;

  static const Map<String, PaymentCapabilityBlock> _byCode = {
    'payment-method/card-capability-required':
        PaymentCapabilityBlock.cardCapabilityRequired,
    'payment-method/cash-funds-required':
        PaymentCapabilityBlock.cashFundsRequired,
    'payment-method/none-available': PaymentCapabilityBlock.noneAvailable,
  };

  /// Returns `null` when [code] isn't one of the trip-linking capability
  /// block reasons above (e.g. a network error, or an unrelated business
  /// error) — the caller must fall back to a generic error message.
  static PaymentCapabilityBlock? fromErrorCode(String? code) =>
      code == null ? null : _byCode[code];
}

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
  final _matchingTripsNotifier = ValueNotifier<List<AnnouncementModel>>(const []);
  final _selectedTripNotifier = ValueNotifier<AnnouncementModel?>(null);

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.autoCreateDedicated && mounted && _errorNotifier.value == null) {
        _createNewTrip();
      }
    });
  }

  @override
  void dispose() {
    _loadingNotifier.dispose();
    _errorNotifier.dispose();
    _requestNotifier.dispose();
    _matchingTripsNotifier.dispose();
    _selectedTripNotifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loadingNotifier.value = true;
    _errorNotifier.value = null;
    _selectedTripNotifier.value = null;

    try {
      // Fetch the request to know its corridor + date window
      final request = await getIt<PackageRequestRepository>()
          .getById(widget.thread.packageRequestId);

      // Fetch all the traveler's announcements (paginated, just first page for now)
      final myTrips =
          await getIt<AnnouncementRepository>().getMyAnnouncements();

      // Filter by corridor + date window.
      //
      // City comparison normalizes both sides to just the city name before the
      // first comma: "Paris, France" and "Paris" both normalize to "paris".
      // This handles legacy announcements stored with country suffix.
      //
      // Date window: we use desiredDate ± dateToleranceDays, which is exactly
      // the range the backend accepts in submitTrip. This ensures every trip
      // shown here will be accepted by the server (no silent 422s).
      String cityKey(String city) => city.split(',').first.toLowerCase().trim();

      final dateFrom = request.desiredDate
          .subtract(Duration(days: request.dateToleranceDays));
      final dateTo = request.desiredDate
          .add(Duration(days: request.dateToleranceDays));
      final matching = myTrips.announcements.where((ann) {
        // Seuls les trajets encore ACTIFS avec assez de capacité disponible
        // peuvent porter ce colis. Un trajet COMPLETED / IN_PROGRESS / CANCELLED
        // ou sans place ne doit jamais être proposé : une fois lié, il resterait
        // bloqué hors de l'onglet « À venir » (qui ne montre que ACTIVE/FULL).
        final linkable =
            ann.status == 'ACTIVE' && ann.availableKg >= request.weightKg;
        final corridorMatch =
            cityKey(ann.departureCity) == cityKey(request.departureCity) &&
            cityKey(ann.arrivalCity) == cityKey(request.arrivalCity);
        final d = ann.departureDate;
        final dateMatch = !DateTime(d.year, d.month, d.day)
                .isBefore(DateTime(dateFrom.year, dateFrom.month, dateFrom.day)) &&
            !DateTime(d.year, d.month, d.day)
                .isAfter(DateTime(dateTo.year, dateTo.month, dateTo.day));
        return linkable && corridorMatch && dateMatch;
      }).toList();

      // The traveler no longer declares a payment method or gets preemptively
      // blocked client-side: the back-end computes the actual capability SET
      // at submit time and returns a specific 422 reason when it's empty
      // (handled reactively in the BlocListener below).
      if (mounted) {
        _requestNotifier.value = request;
        _matchingTripsNotifier.value = matching;
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
    context.read<NegotiationBloc>().add(NegotiationSubmitTripRequested(
      threadId: widget.thread.id,
      travelerAnnouncementId: ann.id,
      // The back-end no longer decides capability from this field — it only
      // requires a non-null accepted method to satisfy the DTO. The actual
      // payment method is chosen by the sender at checkout, from the SET the
      // back-end computes server-side.
      paymentMethod: request.acceptedPaymentMethods.first,
    ));
    // Navigation handled by BlocListener on NegotiationLoaded(awaitingPayment).
  }

  void _resubmitCash(String announcementId, {required bool useCard}) {
    if (!mounted) return;
    context.read<NegotiationBloc>().add(NegotiationSubmitTripRequested(
          threadId: widget.thread.id,
          travelerAnnouncementId: announcementId,
          paymentMethod: PaymentMethod.cash,
          useCardForCommission: useCard,
        ));
  }

  /// Commission cash « wallet d'abord » : si le solde est insuffisant, on propose
  /// de recharger le wallet OU de consentir au prélèvement sur la carte (effectué
  /// au finalize, wallet puis carte). Reprend le pattern de l'acceptation de bid.
  Future<void> _showCashInsufficientSheet(BuildContext context) async {
    final announcementId = _selectedTripNotifier.value?.id;
    if (announcementId == null) return;

    final net = widget.thread.currentPriceEur;
    final gross = widget.thread.grossPriceEur ?? PriceDisplay.grossFromNet(net);
    final commission = gross - net;

    double balance = 0;
    bool hasCard = false;
    try {
      balance = (await getIt<WalletRepository>().getBalance()).balance;
    } catch (_) {}
    try {
      hasCard = (await getIt<CommissionMethodRepository>().load()) != null;
    } catch (_) {}
    if (!context.mounted) return;

    final cs = Theme.of(context).colorScheme;
    await DonyBottomSheet.show<void>(
      context,
      title: 'Solde insuffisant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission à régler : ${commission.toStringAsFixed(2)} €',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Solde wallet : ${balance.toStringAsFixed(2)} €',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Recharge ton wallet, ou accepte que la commission soit prélevée sur '
            'ta carte à la remise du colis.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Recharger mon wallet',
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              final recharged =
                  await context.push<bool>('/payments/wallet/topup/method');
              if ((recharged ?? false) && mounted) {
                _resubmitCash(announcementId, useCard: false);
              }
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          if (hasCard)
            DonyButton(
              label: 'Payer la commission par carte',
              variant: DonyButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _resubmitCash(announcementId, useCard: true);
              },
            )
          else
            DonyButton(
              label: 'Ajouter une carte',
              variant: DonyButtonVariant.secondary,
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await context.push('/payments/commission-method');
                if (mounted) _resubmitCash(announcementId, useCard: true);
              },
            ),
        ],
      ),
    );
  }

  /// `payment-method/card-capability-required` : le colis n'accepte que la
  /// carte et le voyageur n'a pas encore activé les paiements par carte
  /// (onboarding Stripe Connect). Réutilise le flux d'onboarding existant
  /// (`/connect/onboarding/intro`, cf. `announcement_detail_body.dart`).
  Future<void> _showCardCapabilityRequiredSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    await DonyBottomSheet.show<void>(
      context,
      title: 'Paiement carte requis',
      child: Text(
        'L\'expéditeur n\'accepte que le paiement par carte pour ce colis. '
        'Active les paiements par carte pour pouvoir lier ce trajet.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: cs.onSurface),
      ),
      stickyBottom: DonyButton(
        key: const Key('activate-card-payment-cta'),
        label: 'Activer le paiement carte',
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          context.push('/connect/onboarding/intro');
        },
      ),
    );
  }

  /// `payment-method/none-available` : le colis accepte carte ET espèces,
  /// mais le voyageur ne peut honorer ni l'une ni l'autre. On propose les
  /// deux chemins de déblocage.
  Future<void> _showNoPaymentMethodAvailableSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    await DonyBottomSheet.show<void>(
      context,
      title: 'Aucun moyen de paiement disponible',
      child: Text(
        'Tu ne peux pas encore honorer la carte ni les espèces pour ce colis. '
        'Active le paiement carte, ou débloque le paiement en espèces.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: cs.onSurface),
      ),
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            key: const Key('activate-card-payment-cta'),
            label: 'Activer le paiement carte',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.push('/connect/onboarding/intro');
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            key: const Key('unlock-cash-payment-cta'),
            label: 'Débloquer le paiement en espèces',
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _showCashInsufficientSheet(context);
            },
          ),
        ],
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
      paymentMethod: r.acceptedPaymentMethods.first,
    );
    await context.push<bool>(
      '/trips/create',
      extra: CreateTripArgs(
        lockContext: lockContext,
        negotiationBloc: context.read<NegotiationBloc>(),
      ),
    );
    // The sheet's BlocListener pops itself on success and the screen-level
    // listener below will pop us back. If the user cancelled, we still
    // refresh the matching list.
    if (mounted) await _load();
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
      extra: CreateTripArgs(
        announcement: ann,
        lockCorridorAndDate: true,
      ),
    );
    if (mounted) {
      await _load();
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
            state.thread.status == NegotiationThreadStatus.awaitingPayment) {
          // Trip linked successfully: leave this screen.
          if (context.canPop()) context.pop();
        } else if (state is NegotiationError) {
          // Le voyageur ne choisit plus de mode de paiement : le back-end
          // calcule la SET qu'il peut réellement fournir et ne rejette (422)
          // que si elle est vide. Chaque reason route vers son CTA dédié,
          // jamais un message d'erreur sans issue.
          final block = PaymentCapabilityBlock.fromErrorCode(state.error.code);
          if (block == PaymentCapabilityBlock.cardCapabilityRequired) {
            _showCardCapabilityRequiredSheet(context);
          } else if (block == PaymentCapabilityBlock.cashFundsRequired) {
            _showCashInsufficientSheet(context);
          } else if (block == PaymentCapabilityBlock.noneAvailable) {
            _showNoPaymentMethodAvailableSheet(context);
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
                    ? Center(child: CircularProgressIndicator(color: cs.primary))
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
                                selectedCount: selectedTrip != null ? '1 trajet' : null,
                                onConfirm: selectedTrip != null ? _confirmTrip : null,
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
    final cs = Theme.of(context).colorScheme;
    final r = _requestNotifier.value!;
    return ValueListenableBuilder<AnnouncementModel?>(
      valueListenable: _selectedTripNotifier,
      builder: (context, selectedTrip, _) {
        return ValueListenableBuilder<List<AnnouncementModel>>(
          valueListenable: _matchingTripsNotifier,
          builder: (context, matchingTrips, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
                MediaQuery.paddingOf(context).bottom + 100, // room for DonySelectBar + safe area
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
                        Text('Demande acceptée à ${widget.thread.currentPriceEur.toStringAsFixed(0)} €',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            )),
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
                    methods: widget.thread.availablePaymentMethods ??
                        r.acceptedPaymentMethods,
                  ),
                  const SizedBox(height: DonySpacing.xl),
                  Text(
                    matchingTrips.isEmpty
                        ? 'Aucun de tes trajets ne match'
                        : 'Tes trajets compatibles',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.md),
                  if (matchingTrips.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(DonySpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Column(
                        children: [
                          const DonyIcon('plane',
                              size: 36, color: kTextHint),
                          const SizedBox(height: DonySpacing.sm),
                          Text(
                            'Crée un trajet correspondant à cette demande',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontSize: 14,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...matchingTrips
                        .asMap()
                        .entries
                        .map((e) => TripTile(
                              key: Key('trip-tile-${e.key}'),
                              announcement: e.value,
                              index: e.key,
                              isSelected: selectedTrip?.id == e.value.id,
                              onTap: () => _selectTrip(e.value),
                              onModify: _canModify(e.value)
                                  ? () => _openModifySheet(e.value)
                                  : null,
                            )),
                  const SizedBox(height: DonySpacing.base),
                  OutlinedButton.icon(
                    onPressed: _createNewTrip,
                    icon: const DonyIcon('plus'),
                    label: const Text('Créer un nouveau trajet'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                ],
              ),
            );
          },
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
    final ordered =
        PaymentMethod.canonicalOrder.where(methods.contains).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'L\'expéditeur choisira parmi',
          style: tt.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: ordered.map((method) {
            return Container(
              key: Key('payment-method-preview-${method.wireName.toLowerCase()}'),
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
                  Icon(
                    method.icon,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
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
                color: kTextSecondary,
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
