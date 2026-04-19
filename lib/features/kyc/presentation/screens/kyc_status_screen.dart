import 'dart:async';

import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  static const _kGreen = Color(0xFF1A6B3C);
  static const _kBg = Color(0xFFF8F9FA);

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _loadStatus() {
    context.read<KycBloc>().add(const KycStatusRefreshed());
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadStatus();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: BlocConsumer<KycBloc, KycState>(
        listener: (context, state) {
          if (state is KycStatusLoaded) {
            if (state.kycStatus == 'PENDING') {
              _startPolling();
            } else {
              _stopPolling();
            }
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state is KycLoading || state is KycInitial)
                    const CircularProgressIndicator(color: _kGreen)
                  else if (state is KycStatusLoaded)
                    _buildStatusContent(context, state)
                  else if (state is KycError)
                    _buildErrorContent(context, state.message),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, KycStatusLoaded state) {
    switch (state.kycStatus) {
      case 'VERIFIED':
        return _buildVerifiedContent(context);
      case 'REJECTED':
        return _buildRejectedContent(context);
      default:
        return _buildPendingContent();
    }
  }

  Widget _buildVerifiedContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF5EF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified, color: _kGreen, size: 52),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        const Text(
          'Identité vérifiée ✓',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A6B3C),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Votre identité a été vérifiée avec succès. Vous pouvez maintenant accéder à toutes les fonctionnalités de dony.',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Accéder à l\'app',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.hourglass_empty_rounded, color: Colors.amber.shade600, size: 48),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        const Text(
          'Vérification en cours',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Votre dossier est en cours d\'analyse. Vous serez notifié dès que la vérification sera terminée (généralement quelques minutes).',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const _PollingIndicator(),
      ],
    );
  }

  Widget _buildRejectedContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cancel_outlined, color: Colors.red.shade500, size: 48),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        const Text(
          'Vérification échouée',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Nous n\'avons pas pu vérifier votre identité. Assurez-vous que votre document est lisible et réessayez.',
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => context.go('/kyc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Réessayer la vérification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 64),
        const SizedBox(height: 16),
        Text(message,
            style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _loadStatus,
          child: const Text('Réessayer', style: TextStyle(color: _kGreen)),
        ),
      ],
    );
  }
}

class _PollingIndicator extends StatelessWidget {
  const _PollingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.amber.shade600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Vérification automatique toutes les 30s',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
