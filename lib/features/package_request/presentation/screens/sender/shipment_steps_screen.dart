import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Post-payment orchestration screen for an ACCEPTED package request.
///
/// Renders the green "X va livrer ton colis" header + 3 step cards as in
/// maquette `20-43-29`:
///   1. Compléter les détails — adresses, destinataire, valeur déclarée
///   2. QR code & numéro      — pour la remise du colis
///   3. Suivi & livraison     — scan QR à l'arrivée + timeline
///
/// Each card routes to the corresponding screen (existing
/// `/package-requests/:id/complete-details`, `/tracking/scan`,
/// `/tracking/:bidId/timeline`). The sticky bottom CTA suggests the next
/// step (typically "Compléter les détails →" right after payment).
///
/// State of each step is inferred client-side from the loaded
/// [PackageRequest]:
/// - step 1 = done when `pickupAddressLabel != null` (backend fills it after
///   the complete-details POST). For now the Flutter model doesn't expose
///   that field — we use `pickupNeighborhood` as a soft proxy until the DTO
///   is extended in a later story.
class ShipmentStepsScreen extends StatefulWidget {
  const ShipmentStepsScreen({
    required this.requestId,
    this.travelerDisplayName,
    super.key,
  });

  final String requestId;
  final String? travelerDisplayName;

  @override
  State<ShipmentStepsScreen> createState() => _ShipmentStepsScreenState();
}

class _ShipmentStepsScreenState extends State<ShipmentStepsScreen> {
  PackageRequest? _request;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final req = await getIt<PackageRequestRepository>().getById(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = req;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: DonyAppBar(title: widget.travelerDisplayName ?? 'Suivi'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _StepsBody(
                  request: _request!,
                  travelerDisplayName: widget.travelerDisplayName,
                  onRefresh: _load,
                ),
    );
  }
}

class _StepsBody extends StatelessWidget {
  const _StepsBody({
    required this.request,
    required this.onRefresh,
    this.travelerDisplayName,
  });

  final PackageRequest request;
  final String? travelerDisplayName;
  final VoidCallback onRefresh;

  bool get _step1Done => request.pickupNeighborhood != null &&
      request.deliveryNeighborhood != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final dateFmt = DateFormat('d MMM', 'fr');
    final travelerName = travelerDisplayName ?? 'Le voyageur';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, mq.padding.bottom + 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroHeader(
                travelerName: travelerName,
                corridor: '${request.departureCity} → ${request.arrivalCity}',
                date: dateFmt.format(request.desiredDate),
                price: request.targetPriceEur,
              ),
              const SizedBox(height: DonySpacing.lg),
              Text(
                'Étapes suivantes',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              _StepCard(
                index: 1,
                title: 'Compléter les détails',
                subtitle: 'Adresses · destinataire · valeur',
                done: _step1Done,
                active: !_step1Done,
                onTap: () async {
                  await context.push<bool>(
                    '/package-requests/${request.id}/complete-details',
                  );
                  if (context.mounted) onRefresh();
                },
              ),
              const SizedBox(height: DonySpacing.sm),
              _StepCard(
                index: 2,
                title: 'QR code & numéro',
                subtitle: 'Pour la remise du colis',
                done: false,
                active: _step1Done,
                onTap: _step1Done
                    ? () => _showQrPlaceholder(context)
                    : null,
              ),
              const SizedBox(height: DonySpacing.sm),
              _StepCard(
                index: 3,
                title: 'Suivi & livraison',
                subtitle: 'Scan QR à l\'arrivée',
                done: false,
                active: false,
                onTap: null,
              ),
            ],
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: mq.padding.bottom + 20,
          child: _StickyCta(
            label: _step1Done
                ? 'QR code & numéro →'
                : 'Compléter les détails →',
            onPressed: _step1Done
                ? () => _showQrPlaceholder(context)
                : () async {
                    await context.push<bool>(
                      '/package-requests/${request.id}/complete-details',
                    );
                    if (context.mounted) onRefresh();
                  },
          ),
        ),
      ],
    );
  }

  void _showQrPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'QR code disponible dès que le voyageur confirme le trajet'),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.travelerName,
    required this.corridor,
    required this.date,
    this.price,
  });

  final String travelerName;
  final String corridor;
  final String date;
  final double? price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DonyColors.referralGreen, DonyColors.referralGreenMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'DEMANDE ACCEPTÉE',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.92),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            '$travelerName va livrer ton colis',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: DonySpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Meta(label: corridor),
              _Meta(label: date),
              if (price != null)
                _Meta(label: '${price!.toStringAsFixed(0)} € ✓ payés'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.94),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final bgColor = done
        ? cs.primaryContainer.withValues(alpha: 0.4)
        : active
            ? cs.surface
            : cs.surface;
    final borderColor = active
        ? cs.primary
        : done
            ? cs.primary.withValues(alpha: 0.6)
            : cs.outlineVariant;
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: borderColor,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: done
                        ? cs.primary
                        : active
                            ? cs.primary
                            : cs.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? Icon(Icons.check_rounded,
                            color: cs.onPrimary, size: 18)
                        : Text(
                            '$index',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: active ? cs.onPrimary : cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickyCta extends StatelessWidget {
  const _StickyCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
            ),
          ),
        ),
      ),
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
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: DonySpacing.md),
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
