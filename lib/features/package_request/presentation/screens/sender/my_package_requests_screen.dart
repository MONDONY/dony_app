import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MyPackageRequestsScreen extends StatelessWidget {
  const MyPackageRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<PackageRequestBloc>()..add(const FetchMyRequests()),
      child: const _ListView(),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: Text(
          'Mes demandes',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: BlocBuilder<PackageRequestBloc, PackageRequestState>(
        builder: (context, state) {
          if (state.status == PackageRequestListStatus.loading) {
            return const Center(
                child: CircularProgressIndicator(color: kGreenPrimary));
          }
          if (state.status == PackageRequestListStatus.error) {
            return _Error(
              message: state.errorMessage ?? 'Erreur',
              onRetry: () => context
                  .read<PackageRequestBloc>()
                  .add(const FetchMyRequests()),
            );
          }
          if (state.requests.isEmpty) {
            return _Empty(
              onCreate: () => context.push('/package-requests/new'),
            );
          }
          return RefreshIndicator(
            color: kGreenPrimary,
            onRefresh: () async {
              context
                  .read<PackageRequestBloc>()
                  .add(const RefreshMyRequests());
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: state.requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = state.requests[i];
                return _RequestCard(request: r)
                    .animate()
                    .fadeIn(
                      duration: 200.ms,
                      delay: (60 * i).ms,
                    )
                    .slideY(begin: 0.04);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/package-requests/new'),
        backgroundColor: kGreenPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nouvelle demande',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final PackageRequest request;

  Color get _statusColor => switch (request.status) {
        PackageRequestStatus.open => kGreenPrimary,
        PackageRequestStatus.negotiating => kWarning,
        PackageRequestStatus.accepted => kSuccess,
        PackageRequestStatus.completed => kSuccess,
        PackageRequestStatus.expired => kTextHint,
        PackageRequestStatus.cancelled => kError,
      };

  String get _statusLabel => switch (request.status) {
        PackageRequestStatus.open => 'Ouverte',
        PackageRequestStatus.negotiating => 'Négociation',
        PackageRequestStatus.accepted => 'Acceptée',
        PackageRequestStatus.completed => 'Livrée',
        PackageRequestStatus.expired => 'Expirée',
        PackageRequestStatus.cancelled => 'Annulée',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/package-requests/${request.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.departureCity} → ${request.arrivalCity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${request.desiredDate.day}/${request.desiredDate.month}/${request.desiredDate.year}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: kTextSecondary),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.scale_rounded,
                      size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${request.weightKg} kg',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: kTextSecondary),
                  ),
                ],
              ),
              if (request.targetPriceEur != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Budget: ${request.targetPriceEur!.toStringAsFixed(0)} €',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kGreenPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.outbox_rounded,
                size: 64, color: kTextHint),
            const SizedBox(height: 16),
            Text(
              'Aucune demande',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première demande d\'envoi de colis',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            DonyButton(label: 'Créer une demande', onPressed: onCreate),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
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
            const SizedBox(height: 12),
            Text(
              'Erreur',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
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
