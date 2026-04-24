import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HandoverScreen extends StatefulWidget {
  final BidModel bid;
  const HandoverScreen({super.key, required this.bid});

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  DateTime? _windowStart;
  DateTime? _windowEnd;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _windowStart = dt;
        if (_windowEnd != null && !_windowEnd!.isAfter(dt)) {
          _windowEnd = null;
        }
      } else {
        _windowEnd = dt;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_windowStart == null || _windowEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez définir le début et la fin de la fenêtre'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_windowEnd!.isAfter(_windowStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fin de la fenêtre doit être après le début'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<BidBloc>().add(BidHandoverRequested(
      bidId: widget.bid.id,
      location: _locationCtrl.text.trim(),
      windowStart: _windowStart!,
      windowEnd: _windowEnd!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidHandoverSet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fenêtre de remise enregistrée. L\'expéditeur a été notifié.'),
              backgroundColor: kSuccess,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          context.go('/announcements');
        } else if (state is BidError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: kError,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: kGreenPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Fenêtre de remise',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 18, color: kTextPrimary),
          ),
          centerTitle: false,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: kBorder),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoBanner(),
                const SizedBox(height: 24),
                _Section(
                  title: 'Lieu de remise',
                  child: TextFormField(
                    controller: _locationCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Lieu requis' : null,
                    decoration: _inputDecoration('Ex: Gare du Nord, Paris — Hall 2'),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kTextPrimary),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Fenêtre horaire',
                  child: Column(
                    children: [
                      _DateTimeTile(
                        label: 'Début',
                        value: _windowStart,
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickDateTime(true),
                      ),
                      const SizedBox(height: 12),
                      _DateTimeTile(
                        label: 'Fin',
                        value: _windowEnd,
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickDateTime(false),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        ),
        bottomNavigationBar: _SubmitBar(onSubmit: _submit),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: kTextHint),
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreenPrimary, width: 1.5)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGreenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreenPrimary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: kGreenPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'L\'expéditeur recevra une notification avec le lieu et l\'heure de remise dès que vous confirmez.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kGreenDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value != null ? kGreenPrimary.withOpacity(0.4) : kBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value != null ? kGreenPrimary : kTextHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextHint)),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(value!)
                        : 'Sélectionner',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: value != null ? kTextPrimary : kTextHint,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kTextHint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final VoidCallback onSubmit;
  const _SubmitBar({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BidBloc, BidState>(
      builder: (context, state) {
        final isLoading = state is BidLoading;
        return Container(
          color: kSurface,
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreenPrimary,
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
                : Text('Confirmer la fenêtre de remise',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        );
      },
    );
  }
}
