import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class CompleteDetailsScreen extends StatefulWidget {
  const CompleteDetailsScreen({required this.requestId, super.key});
  final String requestId;

  @override
  State<CompleteDetailsScreen> createState() => _CompleteDetailsScreenState();
}

class _CompleteDetailsScreenState extends State<CompleteDetailsScreen> {
  final _form = GlobalKey<FormState>();
  final _pickupAddrCtrl = TextEditingController();
  final _pickupLatCtrl = TextEditingController();
  final _pickupLngCtrl = TextEditingController();
  final _deliveryAddrCtrl = TextEditingController();
  final _deliveryLatCtrl = TextEditingController();
  final _deliveryLngCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _declaredCtrl = TextEditingController();
  bool _disclaimer = false;
  bool _submitting = false;

  @override
  void dispose() {
    _pickupAddrCtrl.dispose();
    _pickupLatCtrl.dispose();
    _pickupLngCtrl.dispose();
    _deliveryAddrCtrl.dispose();
    _deliveryLatCtrl.dispose();
    _deliveryLngCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _declaredCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_disclaimer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez accepter les conditions'),
          backgroundColor: kError,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await getIt<PackageRequestRepository>().completeDetails(
        widget.requestId,
        pickupAddressLabel: _pickupAddrCtrl.text.trim(),
        pickupLat: double.parse(_pickupLatCtrl.text.replaceAll(',', '.')),
        pickupLng: double.parse(_pickupLngCtrl.text.replaceAll(',', '.')),
        deliveryAddressLabel: _deliveryAddrCtrl.text.trim(),
        deliveryLat: double.parse(_deliveryLatCtrl.text.replaceAll(',', '.')),
        deliveryLng: double.parse(_deliveryLngCtrl.text.replaceAll(',', '.')),
        recipientName: _recipientNameCtrl.text.trim(),
        recipientPhone: _recipientPhoneCtrl.text.trim(),
        declaredValueEur:
            double.parse(_declaredCtrl.text.replaceAll(',', '.')),
        disclaimerSigned: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Détails enregistrés'),
            backgroundColor: kSuccess,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kError),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          'Détails de livraison',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 24, 20, MediaQuery.of(context).padding.bottom + 100),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('Pickup'),
                  TextFormField(
                    controller: _pickupAddrCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Adresse de récupération'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pickupLatCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                        decoration:
                            const InputDecoration(labelText: 'Lat'),
                        validator: _coord,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pickupLngCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                        decoration:
                            const InputDecoration(labelText: 'Lng'),
                        validator: _coord,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _section('Livraison'),
                  TextFormField(
                    controller: _deliveryAddrCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Adresse de livraison'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _deliveryLatCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                        decoration:
                            const InputDecoration(labelText: 'Lat'),
                        validator: _coord,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _deliveryLngCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                        decoration:
                            const InputDecoration(labelText: 'Lng'),
                        validator: _coord,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _section('Destinataire'),
                  TextFormField(
                    controller: _recipientNameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nom complet'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recipientPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      hintText: '+221771234567',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requis';
                      if (!RegExp(r'^\+[1-9]\d{6,14}$')
                          .hasMatch(v.trim())) {
                        return 'Format E.164 (+221…)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _section('Valeur déclarée'),
                  TextFormField(
                    controller: _declaredCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valeur du contenu',
                      suffixText: '€',
                    ),
                    validator: (v) {
                      final d = double.tryParse(
                          (v ?? '').replaceAll(',', '.'));
                      if (d == null) return 'Valeur invalide';
                      if (d < 0 || d > 500) return 'Entre 0 et 500€';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _section('Déclaration'),
                  CheckboxListTile(
                    value: _disclaimer,
                    onChanged: (v) =>
                        setState(() => _disclaimer = v ?? false),
                    activeColor: kGreenPrimary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Je certifie que le contenu est légal et conforme à la valeur déclarée.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: kTextSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: DonyButton(
              label: _submitting ? 'Envoi…' : 'Confirmer',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kTextSecondary,
            letterSpacing: 1.2,
          ),
        ),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  String? _coord(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requis';
    final d = double.tryParse(v.replaceAll(',', '.'));
    if (d == null) return 'Invalide';
    return null;
  }
}
