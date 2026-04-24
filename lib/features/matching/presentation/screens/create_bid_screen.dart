import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _categories = [
  'Médicaments',
  'Vêtements',
  'Alimentation',
  'Électronique',
  'Autre',
];

class CreateBidScreen extends StatefulWidget {
  final AnnouncementModel announcement;

  const CreateBidScreen({super.key, required this.announcement});

  @override
  State<CreateBidScreen> createState() => _CreateBidScreenState();
}

class _CreateBidScreenState extends State<CreateBidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();

  String _category = _categories.first;
  bool _disclaimerAccepted = false;
  bool _showDisclaimer = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _valueCtrl.dispose();
    _descCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    super.dispose();
  }

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  double get _totalPrice {
    final kg = double.tryParse(_weightCtrl.text) ?? 0;
    return kg * _pricePerKg * 1.12; // +12% commission dony
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_disclaimerAccepted) {
      setState(() => _showDisclaimer = true);
      return;
    }
    context.read<BidBloc>().add(BidCreateRequested(
      announcementId: widget.announcement.id,
      weightKg: double.parse(_weightCtrl.text),
      declaredValueEur: double.parse(_valueCtrl.text),
      description: _descCtrl.text.trim(),
      contentCategory: _category,
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidCreated) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Demande envoyée !',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: kSuccess,
          ));
          context.go('/home');
        } else if (state is BidError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: kError,
          ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            title: Text('Envoyer un colis',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
            backgroundColor: kSurface,
            elevation: 0,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: _showDisclaimer
              ? _DisclaimerPage(
                  onAccept: () {
                    setState(() {
                      _disclaimerAccepted = true;
                      _showDisclaimer = false;
                    });
                    _submit();
                  },
                  onDecline: () => setState(() => _showDisclaimer = false),
                )
              : _FormPage(
                  formKey: _formKey,
                  weightCtrl: _weightCtrl,
                  valueCtrl: _valueCtrl,
                  descCtrl: _descCtrl,
                  recipientNameCtrl: _recipientNameCtrl,
                  recipientPhoneCtrl: _recipientPhoneCtrl,
                  category: _category,
                  onCategoryChanged: (v) => setState(() => _category = v!),
                  maxKg: _maxKg,
                  totalPrice: _totalPrice,
                  isLoading: state is BidLoading,
                  onSubmit: _submit,
                  onWeightChanged: (_) => setState(() {}),
                  announcement: widget.announcement,
                ),
        );
      },
    );
  }
}

class _FormPage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController weightCtrl;
  final TextEditingController valueCtrl;
  final TextEditingController descCtrl;
  final TextEditingController recipientNameCtrl;
  final TextEditingController recipientPhoneCtrl;
  final String category;
  final ValueChanged<String?> onCategoryChanged;
  final double maxKg;
  final double totalPrice;
  final bool isLoading;
  final VoidCallback onSubmit;
  final ValueChanged<String> onWeightChanged;
  final AnnouncementModel announcement;

  const _FormPage({
    required this.formKey,
    required this.weightCtrl,
    required this.valueCtrl,
    required this.descCtrl,
    required this.recipientNameCtrl,
    required this.recipientPhoneCtrl,
    required this.category,
    required this.onCategoryChanged,
    required this.maxKg,
    required this.totalPrice,
    required this.isLoading,
    required this.onSubmit,
    required this.onWeightChanged,
    required this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé trajet
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kGreenLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGreenPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flight_takeoff_rounded, color: kGreenPrimary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${announcement.departureCity} → ${announcement.arrivalCity}',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, color: kGreenDark, fontSize: 15),
                  ),
                  const Spacer(),
                  Text(
                    '${announcement.pricePerKg.toStringAsFixed(2)} €/kg',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600, color: kGreenPrimary, fontSize: 14),
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 24),
            _SectionTitle('Votre colis'),
            const SizedBox(height: 14),

            // Poids
            TextFormField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              onChanged: onWeightChanged,
              decoration: _inputDeco('Poids du colis (kg)', 'ex: 3.5',
                  suffix: 'kg',
                  hint2: 'Max ${maxKg.toStringAsFixed(1)} kg dispo'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Poids obligatoire';
                final kg = double.tryParse(v);
                if (kg == null || kg <= 0) return 'Poids invalide';
                if (kg > maxKg) return 'Max disponible : ${maxKg.toStringAsFixed(1)} kg';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Catégorie
            DropdownButtonFormField<String>(
              value: category,
              decoration: _inputDeco('Catégorie du contenu', ''),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: onCategoryChanged,
              validator: (v) => v == null ? 'Catégorie obligatoire' : null,
            ),
            const SizedBox(height: 14),

            // Description
            TextFormField(
              controller: descCtrl,
              maxLines: 3,
              decoration: _inputDeco('Description du contenu', 'Ex: 2 boubous, médicaments homéopathiques...'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Description obligatoire' : null,
            ),
            const SizedBox(height: 14),

            // Valeur déclarée
            TextFormField(
              controller: valueCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: _inputDeco('Valeur déclarée', 'ex: 120', suffix: '€'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Valeur obligatoire';
                final val = double.tryParse(v);
                if (val == null || val <= 0) return 'Valeur invalide';
                if (val > 500) return 'Valeur maximum : 500 €';
                return null;
              },
            ),

            const SizedBox(height: 24),
            _SectionTitle('Destinataire'),
            const SizedBox(height: 14),

            TextFormField(
              controller: recipientNameCtrl,
              decoration: _inputDeco('Prénom et nom du destinataire', 'ex: Amadou Diallo'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: recipientPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _inputDeco('Téléphone du destinataire', 'ex: +221 77 000 00 00'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Téléphone obligatoire' : null,
            ),

            const SizedBox(height: 28),

            // Récap prix
            if (totalPrice > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    _RecapRow('Transport (${weightCtrl.text} kg × ${announcement.pricePerKg.toStringAsFixed(2)} €)',
                        '${((double.tryParse(weightCtrl.text) ?? 0) * announcement.pricePerKg).toStringAsFixed(2)} €'),
                    const SizedBox(height: 6),
                    _RecapRow('Commission dony (12%)',
                        '${((double.tryParse(weightCtrl.text) ?? 0) * announcement.pricePerKg * 0.12).toStringAsFixed(2)} €'),
                    const Divider(height: 20),
                    _RecapRow('Total estimé', '${totalPrice.toStringAsFixed(2)} €',
                        bold: true),
                  ],
                ),
              ).animate().fadeIn(),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Continuer',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint, {String? suffix, String? hint2}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: hint2,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreenPrimary, width: 1.5)),
        filled: true,
        fillColor: kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 16, color: kTextPrimary),
      );
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _RecapRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: bold ? kTextPrimary : kTextSecondary,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: bold ? kGreenPrimary : kTextPrimary,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      );
}

class _DisclaimerPage extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _DisclaimerPage({required this.onAccept, required this.onDecline});

  @override
  State<_DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends State<_DisclaimerPage> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel_rounded, color: kWarning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Disclaimer légal douanier',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, color: const Color(0xFF92400E), fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 20),
                _LegalSection('Produits interdits', [
                  'Stupéfiants, drogues et substances psychotropes',
                  'Armes, munitions et explosifs',
                  'Contrefaçons et marchandises piratées',
                  'Denrées périssables non déclarées',
                  'Espèces animales protégées',
                  'Matières radioactives ou dangereuses',
                ]),
                const SizedBox(height: 16),
                _LegalSection('Responsabilité de l\'expéditeur', [
                  'Vous êtes seul responsable de la conformité du contenu avec la réglementation douanière des pays de départ et d\'arrivée.',
                  'Toute fausse déclaration douanière est passible de poursuites pénales.',
                  'dony décline toute responsabilité en cas de saisie ou de litige douanier lié à un contenu non déclaré ou interdit.',
                  'En cas de litige, les données de signature (date, heure, adresse IP) seront transmises aux autorités compétentes.',
                ]),
                const SizedBox(height: 16),
                _LegalSection('Médicaments', [
                  'Les médicaments soumis à ordonnance doivent être accompagnés des documents médicaux requis.',
                  'Le transport de médicaments contrôlés sans documentation peut entraîner une saisie à la douane.',
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _checked = !_checked),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checked,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                      activeColor: kGreenPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'J\'ai lu et j\'accepte les conditions d\'envoi et la réglementation douanière',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDecline,
                      child: Text('Retour',
                          style: GoogleFonts.plusJakartaSans(
                              color: kTextSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _checked ? widget.onAccept : null,
                      child: Text('Confirmer et envoyer',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final List<String> items;
  const _LegalSection(this.title, this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: kGreenPrimary, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Text(item,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: kTextSecondary, height: 1.5)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
