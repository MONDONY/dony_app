import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const List<String> _reasons = [
  'Vol annulé',
  'Urgence personnelle',
  'Problème de santé',
  'Changement d\'itinéraire',
  'Autre',
];

class CancellationScreen extends StatefulWidget {
  final String announcementId;
  const CancellationScreen({super.key, required this.announcementId});

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  String? _selectedReason;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_selectedReason == null) return null;
    if (_selectedReason == 'Autre' && _otherCtrl.text.trim().isNotEmpty) {
      return _otherCtrl.text.trim();
    }
    return _selectedReason;
  }

  void _confirm(BuildContext context) {
    final reason = _finalReason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une raison'),
          backgroundColor: DonyColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmer l\'annulation',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text(
          'Cette action annulera votre trajet et remboursera automatiquement tous les expéditeurs concernés.',
          style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.sora(color: DonyColors.grey400)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<CancellationBloc>().add(CancellationTripRequested(
                    announcementId: widget.announcementId,
                    reason: reason,
                  ));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: DonyColors.error, foregroundColor: Colors.white, elevation: 0),
            child: Text('Confirmer',
                style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CancellationBloc, CancellationState>(
      listener: (context, state) {
        if (state is CancellationSuccess) {
          context.pushReplacement('/cancellations/rematch',
              extra: state.cancellation);
        } else if (state is CancellationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: DonyColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: DonyColors.grey50,
        appBar: AppBar(
          backgroundColor: DonyColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: DonyColors.green400),
            onPressed: () => context.pop(),
          ),
          title: Text('Annuler le trajet',
              style: GoogleFonts.sora(
                  fontWeight: FontWeight.w700, fontSize: 18, color: DonyColors.ink900)),
          centerTitle: false,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: DonyColors.grey100),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WarningBanner(),
              const SizedBox(height: 24),
              Text('Raison de l\'annulation',
                  style: GoogleFonts.sora(
                      fontSize: 14, fontWeight: FontWeight.w700, color: DonyColors.ink900)),
              const SizedBox(height: 12),
              ..._reasons.map((reason) => _ReasonTile(
                    label: reason,
                    selected: _selectedReason == reason,
                    onTap: () => setState(() => _selectedReason = reason),
                  )),
              if (_selectedReason == 'Autre') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherCtrl,
                  decoration: InputDecoration(
                    hintText: 'Précisez...',
                    hintStyle: GoogleFonts.sora(color: DonyColors.grey200),
                    filled: true,
                    fillColor: DonyColors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: DonyColors.grey100)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: DonyColors.green400, width: 1.5)),
                  ),
                  style: GoogleFonts.sora(fontSize: 14),
                  maxLines: 3,
                ),
              ],
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
        bottomNavigationBar: _BottomBar(onConfirm: () => _confirm(context)),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DonyColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: DonyColors.error, size: 20),
              const SizedBox(width: 8),
              Text('Attention',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700, fontSize: 14, color: DonyColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cette annulation affectera tous les expéditeurs liés à ce trajet. Leurs remboursements seront traités automatiquement.',
            style: GoogleFonts.sora(fontSize: 13, color: DonyColors.grey400),
          ),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ReasonTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? DonyColors.green100 : DonyColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? DonyColors.green400 : DonyColors.grey100, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? DonyColors.green400 : DonyColors.grey200,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 14,
                    color: selected ? DonyColors.green400 : DonyColors.ink900,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onConfirm;
  const _BottomBar({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return Container(
          color: DonyColors.white,
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          child: ElevatedButton(
            onPressed: isLoading ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: DonyColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Confirmer l\'annulation',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        );
      },
    );
  }
}
