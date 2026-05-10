import 'package:dio/dio.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PackageRequestDetailScreen extends StatefulWidget {
  const PackageRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<PackageRequestDetailScreen> createState() =>
      _PackageRequestDetailScreenState();
}

class _PackageRequestDetailScreenState
    extends State<PackageRequestDetailScreen> {
  PackageRequest? _request;
  List<NegotiationThread> _threads = const [];
  String? _error;
  bool _loading = true;
  bool _cancelling = false;

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
      final repo = getIt<PackageRequestRepository>();
      final r = await repo.getById(widget.requestId);
      List<NegotiationThread> threads = const [];
      try {
        threads = await repo.listThreadsForRequest(widget.requestId);
      } catch (_) {
        // Ignore thread fetch errors — detail still loads
      }
      if (mounted) {
        setState(() {
          _request = r;
          _threads = threads;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Erreur');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await getIt<PackageRequestRepository>().cancel(widget.requestId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kError),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: kGreenPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Détail',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreenPrimary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _request == null
                  ? const SizedBox.shrink()
                  : _DetailView(
                      request: _request!,
                      threads: _threads,
                      cancelling: _cancelling,
                      onCancel: _cancel,
                      onComplete: () => context.push(
                          '/package-requests/${widget.requestId}/complete-details'),
                    ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.request,
    required this.threads,
    required this.cancelling,
    required this.onCancel,
    required this.onComplete,
  });
  final PackageRequest request;
  final List<NegotiationThread> threads;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final canCancel = request.status == PackageRequestStatus.open ||
        request.status == PackageRequestStatus.negotiating;
    final showCompleteCta = request.status == PackageRequestStatus.accepted &&
        request.pickupNeighborhood == null;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).padding.bottom + 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Card(
                title: 'Itinéraire',
                children: [
                  _Row(
                      icon: Icons.flight_takeoff_rounded,
                      label: 'Départ',
                      value: request.departureCity),
                  _Row(
                      icon: Icons.flight_land_rounded,
                      label: 'Arrivée',
                      value: request.arrivalCity),
                  _Row(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value:
                          '${request.desiredDate.day}/${request.desiredDate.month}/${request.desiredDate.year} (±${request.dateToleranceDays}j)'),
                ],
              ),
              const SizedBox(height: 12),
              _Card(
                title: 'Colis',
                children: [
                  _Row(
                      icon: Icons.scale_rounded,
                      label: 'Poids',
                      value: '${request.weightKg} kg'),
                  _Row(
                      icon: Icons.archive_rounded,
                      label: 'Taille',
                      value: request.parcelSize.name.toUpperCase()),
                  _Row(
                      icon: Icons.label_rounded,
                      label: 'Catégorie',
                      value: request.contentCategory),
                  if (request.description != null)
                    _Row(
                        icon: Icons.notes_rounded,
                        label: 'Description',
                        value: request.description!),
                ],
              ),
              if (request.targetPriceEur != null) ...[
                const SizedBox(height: 12),
                _Card(
                  title: 'Budget',
                  children: [
                    _Row(
                        icon: Icons.payments_rounded,
                        label: 'Prix cible',
                        value:
                            '${request.targetPriceEur!.toStringAsFixed(0)} €'),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _ThreadsSection(threads: threads),
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
        ),
        if (showCompleteCta)
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: DonyButton(
              label: 'Compléter les détails',
              onPressed: onComplete,
            ),
          )
        else if (canCancel)
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: DonyButton(
              label: cancelling ? 'Annulation…' : 'Annuler la demande',
              variant: DonyButtonVariant.destructive,
              isLoading: cancelling,
              onPressed: onCancel,
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kTextSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: kError),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}


class _ThreadsSection extends StatelessWidget {
  const _ThreadsSection({required this.threads});
  final List<NegotiationThread> threads;

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: kTextHint),
            const SizedBox(height: 8),
            Text(
              "Aucune proposition pour le moment",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Tu seras notifié·e dès qu'un voyageur fait une offre",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: kTextHint,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                "Propositions reçues",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kGreenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${threads.length}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kGreenDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...threads.map((t) => _ThreadTile(thread: t)),
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final NegotiationThread thread;

  Color _statusColor() => switch (thread.status) {
        NegotiationThreadStatus.open => kWarning,
        NegotiationThreadStatus.awaitingTrip => kGreenPrimary,
        NegotiationThreadStatus.awaitingPayment => kGreenPrimary,
        NegotiationThreadStatus.accepted => kSuccess,
        NegotiationThreadStatus.rejected => kError,
        NegotiationThreadStatus.autoRejected => kTextHint,
        NegotiationThreadStatus.expired => kTextHint,
      };

  String _statusLabel() => switch (thread.status) {
        NegotiationThreadStatus.open => "En cours",
        NegotiationThreadStatus.awaitingTrip => "Attente trajet",
        NegotiationThreadStatus.awaitingPayment => "Attente paiement",
        NegotiationThreadStatus.accepted => "Acceptée",
        NegotiationThreadStatus.rejected => "Rejetée",
        NegotiationThreadStatus.autoRejected => "Auto-rejetée",
        NegotiationThreadStatus.expired => "Expirée",
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push("/negotiations/${thread.id}"),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kGreenLight,
                  child: const Icon(Icons.person_rounded, color: kGreenPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "${thread.currentPriceEur.toStringAsFixed(0)} €",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: kGreenPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor().withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _statusColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Round ${thread.roundsCount}/5  ·  ${thread.travelerAvailableKg.toStringAsFixed(1)} kg dispo",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: kTextHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
