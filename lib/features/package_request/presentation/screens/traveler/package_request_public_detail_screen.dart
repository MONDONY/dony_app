import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PackageRequestPublicDetailScreen extends StatefulWidget {
  const PackageRequestPublicDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestPublicDetailScreen> createState() =>
      _PackageRequestPublicDetailScreenState();
}

class _PackageRequestPublicDetailScreenState
    extends State<PackageRequestPublicDetailScreen> {
  PackageRequest? _request;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await getIt<PackageRequestRepository>().getById(widget.requestId);
      if (mounted) setState(() => _request = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final announcement = extra?['announcement'] as AnnouncementModel?;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const DonyAppBar(title: 'Demande'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(fontSize: 14, color: kError)),
                  ),
                )
              : _request == null
                  ? const SizedBox.shrink()
                  : PackageRequestPublicDetailBody(
                      request: _request!,
                      announcement: announcement,
                    ),
    );
  }
}

/// Extracted body widget — accepts a [PackageRequest] directly so it is
/// independently testable without DI or GoRouter setup.
class PackageRequestPublicDetailBody extends StatelessWidget {
  const PackageRequestPublicDetailBody({
    super.key,
    required this.request,
    this.announcement,
  });

  final PackageRequest request;
  final AnnouncementModel? announcement;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              MediaQuery.of(context).padding.bottom + 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DonySpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [DonyColors.blue500, DonyColors.blue700],
                  ),
                  borderRadius: BorderRadius.circular(DonyRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.departureCity,
                            style:
                                Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // 🔒 PRIX FERME badge — shown when not negotiable
                        if (!r.negotiable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(DonyRadius.full),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_rounded,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'PRIX FERME',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Icon(Icons.arrow_downward_rounded,
                        color: Colors.white70, size: 28),
                    Text(
                      r.arrivalCity,
                      style:
                          Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.md),
                    Text(
                      'Souhaité le ${r.desiredDate.day}/${r.desiredDate.month}/${r.desiredDate.year} (±${r.dateToleranceDays}j)',
                      style:
                          Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              _detailCard(context, 'Colis', [
                _kv(context, Icons.scale_rounded, 'Poids', '${r.weightKg} kg'),
                _kv(context, Icons.archive_rounded, 'Taille',
                    r.parcelSize.name.toUpperCase()),
                _kv(context, Icons.label_rounded, 'Catégorie',
                    r.contentCategory.label),
                if (r.description != null)
                  _kv(context, Icons.notes_rounded, 'Description',
                      r.description!),
              ]),
              if (r.targetPriceEur != null) ...[
                const SizedBox(height: DonySpacing.md),
                _detailCard(context, 'Budget', [
                  _kv(
                    context,
                    Icons.payments_rounded,
                    r.negotiable ? 'Prix cible' : 'Prix ferme',
                    PriceDisplay.eur(r.targetPriceEur!),
                  ),
                ]),
              ],
              if (r.pickupNeighborhood != null ||
                  r.deliveryNeighborhood != null) ...[
                const SizedBox(height: DonySpacing.md),
                _detailCard(context, 'Zones', [
                  if (r.pickupNeighborhood != null)
                    _kv(context, Icons.location_on_rounded, 'Pickup',
                        r.pickupNeighborhood!),
                  if (r.deliveryNeighborhood != null)
                    _kv(context, Icons.location_on_rounded, 'Livraison',
                        r.deliveryNeighborhood!),
                ]),
              ],
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: r.negotiable
              ? DonyButton(
                  label: 'Faire une offre',
                  onPressed: () => MakeOfferBottomSheet.show(
                    context,
                    packageRequestId: r.id,
                    targetPriceEur: r.targetPriceEur,
                    weightKg: announcement?.availableKg ?? r.weightKg,
                    departureCity: r.departureCity,
                    arrivalCity: r.arrivalCity,
                    initialDate: announcement?.departureDate,
                  ),
                )
              : _FirmPriceCta(request: r, announcement: announcement),
        ),
      ],
    );
  }

  static Widget _detailCard(
      BuildContext context, String title, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: DonySpacing.md),
          ...children,
        ],
      ),
    );
  }

  static Widget _kv(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextSecondary),
          const SizedBox(width: DonySpacing.md),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 13, color: kTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// CTA button for firm-price requests — tapping dispatches
/// [NegotiationStartRequested] with [proposedPriceEur = targetPriceEur].
///
/// Wrapped in a [BlocProvider] internally so it can live either inside or
/// outside an existing negotiation scope.
class _FirmPriceCta extends StatelessWidget {
  const _FirmPriceCta({required this.request, this.announcement});

  final PackageRequest request;
  final AnnouncementModel? announcement;

  @override
  Widget build(BuildContext context) {
    final price = request.targetPriceEur;
    final label = price != null
        ? 'Prendre à ${PriceDisplay.eur(price)} · Prix ferme'
        : 'Prendre ce colis';

    return BlocProvider(
      create: (_) => getIt<NegotiationBloc>(),
      child: Builder(
        builder: (ctx) => BlocConsumer<NegotiationBloc, NegotiationState>(
          listener: (ctx, state) {
            if (state is NegotiationLoaded) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Offre confirmée'),
                  backgroundColor: kSuccess,
                ),
              );
            } else if (state is NegotiationError) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(state.error.message)),
              );
            }
          },
          builder: (ctx, state) {
            final isLoading = state is NegotiationLoading;
            return DonyButton(
              key: const Key('take-firm-price'),
              label: isLoading ? 'Envoi…' : label,
              isLoading: isLoading,
              onPressed: isLoading || price == null
                  ? null
                  : () {
                      // For firm-price, traveler date = now+7 as default;
                      // MakeOfferBottomSheet would normally capture the date.
                      // Here we open the full offer sheet pre-filled but
                      // locked at the firm price.
                      MakeOfferBottomSheet.show(
                        ctx,
                        packageRequestId: request.id,
                        targetPriceEur: price,
                        weightKg:
                            announcement?.availableKg ?? request.weightKg,
                        departureCity: request.departureCity,
                        arrivalCity: request.arrivalCity,
                        initialDate: announcement?.departureDate,
                        isFirmPrice: true,
                      );
                    },
            );
          },
        ),
      ),
    );
  }
}
