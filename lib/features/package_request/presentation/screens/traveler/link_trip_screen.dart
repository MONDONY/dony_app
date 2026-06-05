import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart';
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

/// Screen shown to the traveler after sender accepted the offer.
/// They must pick one of their existing trips matching the corridor + date,
/// or create a new one which will be auto-linked.
class LinkTripScreen extends StatefulWidget {
  const LinkTripScreen({required this.thread, super.key});
  final NegotiationThread thread;

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
  final _paymentMethodNotifier = ValueNotifier<PaymentMethod>(PaymentMethod.stripe);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadingNotifier.dispose();
    _errorNotifier.dispose();
    _requestNotifier.dispose();
    _matchingTripsNotifier.dispose();
    _selectedTripNotifier.dispose();
    _paymentMethodNotifier.dispose();
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
        final corridorMatch =
            cityKey(ann.departureCity) == cityKey(request.departureCity) &&
            cityKey(ann.arrivalCity) == cityKey(request.arrivalCity);
        final d = ann.departureDate;
        final dateMatch = !DateTime(d.year, d.month, d.day)
                .isBefore(DateTime(dateFrom.year, dateFrom.month, dateFrom.day)) &&
            !DateTime(d.year, d.month, d.day)
                .isAfter(DateTime(dateTo.year, dateTo.month, dateTo.day));
        return corridorMatch && dateMatch;
      }).toList();

      if (mounted) {
        _requestNotifier.value = request;
        _matchingTripsNotifier.value = matching;
        // Default to STRIPE; if STRIPE is not in accepted methods, pick first.
        if (request.acceptedPaymentMethods.contains(PaymentMethod.stripe)) {
          _paymentMethodNotifier.value = PaymentMethod.stripe;
        } else if (request.acceptedPaymentMethods.isNotEmpty) {
          _paymentMethodNotifier.value = request.acceptedPaymentMethods.first;
        }
        _loadingNotifier.value = false;
      }
    } catch (e) {
      if (mounted) {
        _errorNotifier.value = e.toString();
        _loadingNotifier.value = false;
      }
    }
  }

  void _selectTrip(AnnouncementModel ann) {
    _selectedTripNotifier.value = ann;
  }

  Future<void> _confirmTrip() async {
    final ann = _selectedTripNotifier.value;
    if (ann == null) return;
    context.read<NegotiationBloc>().add(NegotiationSubmitTripRequested(
      threadId: widget.thread.id,
      travelerAnnouncementId: ann.id,
      paymentMethod: _paymentMethodNotifier.value,
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
      paymentMethod: _paymentMethodNotifier.value,
    );
    await CreateAnnouncementBottomSheet.show(
      context,
      lockContext: lockContext,
      negotiationBloc: context.read<NegotiationBloc>(),
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
    await CreateAnnouncementBottomSheet.show(
      context,
      announcement: ann,
      lockCorridorAndDate: true,
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
          final errorCode = state.error.code ?? '';
          if (errorCode == 'payment-method/traveler-insufficient-funds-cash') {
            // Wallet insuffisant pour la commission cash : proposer recharge OU carte.
            _showCashInsufficientSheet(context);
            return;
          }
          final message =
              errorCode == 'payment-method/no-commission-card'
                  ? 'Ajoute d\'abord une carte de commission pour payer en cash.'
                  : state.error.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
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
                bottomNavigationBar: ValueListenableBuilder<AnnouncementModel?>(
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
                              ? '${DateFormat('EEE d MMM', 'fr').format(selectedTrip.departureDate)} · ${selectedTrip.availableKg} kg dispo'
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
    return ValueListenableBuilder<PaymentMethod>(
      valueListenable: _paymentMethodNotifier,
      builder: (context, selectedPaymentMethod, _) {
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
                      _PaymentMethodPicker(
                        methods: r.acceptedPaymentMethods,
                        selected: selectedPaymentMethod,
                        onChanged: (m) => _paymentMethodNotifier.value = m,
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
                              const Icon(Icons.flight_outlined,
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
                        icon: const Icon(Icons.add_rounded),
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
      },
    );
  }
}

/// Selector de méthode de paiement au moment de lier un trajet.
/// Affiche uniquement les méthodes présentes dans [methods].
class _PaymentMethodPicker extends StatelessWidget {
  const _PaymentMethodPicker({
    required this.methods,
    required this.selected,
    required this.onChanged,
  });

  final Set<PaymentMethod> methods;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

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
          'Mode de paiement',
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
            final isSelected = selected == method;
            return GestureDetector(
              key: Key('payment-method-${method.wireName.toLowerCase()}'),
              onTap: () => onChanged(method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base,
                  vertical: DonySpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primaryContainer : cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outline,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      method.icon,
                      size: 14,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: DonySpacing.xs),
                    Text(
                      method.displayLabel,
                      style: tt.labelMedium?.copyWith(
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: kError),
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
