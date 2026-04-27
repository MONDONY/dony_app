import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _categories = [
  'Vêtements',
  'Médicaments',
  'Documents',
  'Nourriture',
  'Électronique',
  'Cadeaux',
];

class CreateBidScreen extends StatefulWidget {
  final AnnouncementModel announcement;

  const CreateBidScreen({super.key, required this.announcement});

  @override
  State<CreateBidScreen> createState() => _CreateBidScreenState();
}

class _CreateBidScreenState extends State<CreateBidScreen> {
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();

  double _weightKg = 6;
  String _category = _categories[0];
  bool _disclaimerAccepted = false;
  bool _showDisclaimer = false;

  double get _maxKg => widget.announcement.availableKg;
  double get _pricePerKg => widget.announcement.pricePerKg;

  double get _totalPrice {
    return _weightKg * _pricePerKg * 1.12;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _valueCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Description obligatoire');
      return;
    }
    final val = double.tryParse(_valueCtrl.text);
    if (val == null || val <= 0) {
      _showError('Valeur déclarée invalide');
      return;
    }
    if (val > 500) {
      _showError('Valeur maximum : 500 €');
      return;
    }
    if (_recipientNameCtrl.text.trim().isEmpty) {
      _showError('Nom du destinataire obligatoire');
      return;
    }
    if (_recipientPhoneCtrl.text.trim().isEmpty) {
      _showError('Téléphone du destinataire obligatoire');
      return;
    }
    if (!_disclaimerAccepted) {
      setState(() => _showDisclaimer = true);
      return;
    }
    context.read<BidBloc>().add(BidCreateRequested(
      announcementId: widget.announcement.id,
      weightKg: _weightKg,
      declaredValueEur: val,
      description: _descCtrl.text.trim(),
      contentCategory: _category,
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DonyColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidCreated) {
          // Le bid est créé — redirige immédiatement vers le paiement.
          // context.go remplace la pile pour éviter de revenir au formulaire.
          context.go('/payments/pay', extra: state.bid);
        } else if (state is BidError) {
          _showError(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is BidLoading;

        if (_showDisclaimer) {
          return _DisclaimerPage(
            onAccept: () {
              setState(() {
                _disclaimerAccepted = true;
                _showDisclaimer = false;
              });
              _submit();
            },
            onDecline: () => setState(() => _showDisclaimer = false),
          );
        }

        return Scaffold(
          backgroundColor: DonyColors.grey50,
          appBar: AppBar(
            title: Text(
              'Déclarer un colis',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            backgroundColor: DonyColors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: DonyColors.green400),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: 1 / 3,
                backgroundColor: DonyColors.grey50,
                valueColor: const AlwaysStoppedAnimation<Color>(DonyColors.green400),
                minHeight: 3,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicateur étape
                Text(
                  'ÉTAPE 1/3 — LE COLIS',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.green400,
                    letterSpacing: 0.8,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 20),

                // Stepper poids
                _WeightStepper(
                  weightKg: _weightKg,
                  maxKg: _maxKg,
                  onChanged: (v) => setState(() => _weightKg = v),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: 24),

                // Catégorie
                Text(
                  'Catégorie du contenu',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DonyColors.ink900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) => _CategoryChip(
                    label: cat,
                    selected: _category == cat,
                    onTap: () => setState(() => _category = cat),
                  )).toList(),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),

                // Description
                Text(
                  'Description détaillée',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DonyColors.ink900,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Médicaments pour diabète + 2 tee-shirts enfants',
                    hintStyle: GoogleFonts.sora(
                      color: DonyColors.grey200,
                      fontSize: 14,
                    ),
                  ),
                  style: GoogleFonts.sora(fontSize: 14),
                ).animate().fadeIn(delay: 140.ms),
                const SizedBox(height: 20),

                // Valeur déclarée
                Text(
                  'Valeur déclarée (€)',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DonyColors.ink900,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 8),
                      child: Icon(Icons.euro_rounded, size: 18, color: DonyColors.grey400),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    hintText: '120',
                    helperText: 'Plafond : 500 € — couvre l\'assurance en cas de sinistre',
                    helperStyle: GoogleFonts.sora(
                      fontSize: 12,
                      color: DonyColors.grey400,
                    ),
                  ),
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: 160.ms),
                const SizedBox(height: 20),

                // Warning contenu interdit
                _ContentWarning().animate().fadeIn(delay: 180.ms),
                const SizedBox(height: 28),

                // Destinataire
                Text(
                  'Destinataire',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.ink900,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _recipientNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Prénom et nom du destinataire',
                    hintText: 'ex: Amadou Diallo',
                  ),
                  style: GoogleFonts.sora(fontSize: 14),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _recipientPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Téléphone du destinataire',
                    hintText: 'ex: +221 77 000 00 00',
                  ),
                  style: GoogleFonts.sora(fontSize: 14),
                ).animate().fadeIn(delay: 220.ms),
              ],
            ),
          ),
          bottomSheet: _BottomBar(
            totalPrice: _totalPrice,
            isLoading: isLoading,
            onSubmit: _submit,
          ),
        );
      },
    );
  }
}

// ── Stepper poids ────────────────────────────────────────────────────────────

class _WeightStepper extends StatelessWidget {
  const _WeightStepper({
    required this.weightKg,
    required this.maxKg,
    required this.onChanged,
  });

  final double weightKg;
  final double maxKg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                onTap: weightKg > 1
                    ? () => onChanged((weightKg - 1).clamp(1, maxKg))
                    : null,
              ),
              const SizedBox(width: 28),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: weightKg.toStringAsFixed(0),
                      style: GoogleFonts.sora(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: DonyColors.ink900,
                      ),
                    ),
                    TextSpan(
                      text: 'kg',
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: DonyColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              _StepperButton(
                icon: Icons.add_rounded,
                onTap: weightKg < maxKg
                    ? () => onChanged((weightKg + 1).clamp(1, maxKg))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Max ${maxKg.toStringAsFixed(0)} kg sur ce trajet',
            style: GoogleFonts.sora(
              fontSize: 13,
              color: DonyColors.grey400,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap != null ? DonyColors.white : DonyColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap != null ? DonyColors.grey100 : DonyColors.grey50,
          ),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap != null ? DonyColors.ink900 : DonyColors.grey200,
        ),
      ),
    );
  }
}

// ── Chips catégorie ──────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DonyColors.ink900 : DonyColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DonyColors.ink900 : DonyColors.grey100,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : DonyColors.ink900,
          ),
        ),
      ),
    );
  }
}

// ── Warning contenu interdit ─────────────────────────────────────────────────

class _ContentWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contenu interdit',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pas d\'armes, drogues, liquides inflammables ou espèces. Le voyageur peut refuser au contrôle.',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barre de bas ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.totalPrice,
    required this.isLoading,
    required this.onSubmit,
  });

  final double totalPrice;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: DonyColors.white,
        border: Border(top: BorderSide(color: DonyColors.grey100)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total estimé',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: DonyColors.grey400,
                ),
              ),
              Text(
                '${totalPrice.toStringAsFixed(0)} €',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.ink900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Continuer',
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page disclaimer ──────────────────────────────────────────────────────────

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
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Conditions d\'envoi',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: DonyColors.green400),
          onPressed: widget.onDecline,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                        const Icon(Icons.gavel_rounded, color: DonyColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Disclaimer légal douanier',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                              fontSize: 14,
                            ),
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
                    'Vous êtes seul responsable de la conformité du contenu avec la réglementation douanière.',
                    'Toute fausse déclaration douanière est passible de poursuites pénales.',
                    'dony décline toute responsabilité en cas de saisie ou de litige douanier.',
                  ]),
                  const SizedBox(height: 16),
                  _LegalSection('Médicaments', [
                    'Les médicaments soumis à ordonnance doivent être accompagnés des documents médicaux requis.',
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: DonyColors.white,
              border: Border(top: BorderSide(color: DonyColors.grey100)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _checked = !_checked),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _checked,
                        onChanged: (v) =>
                            setState(() => _checked = v ?? false),
                        activeColor: DonyColors.green400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'J\'ai lu et j\'accepte les conditions d\'envoi et la réglementation douanière',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            color: DonyColors.ink900,
                            fontWeight: FontWeight.w500,
                          ),
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
                        child: Text(
                          'Retour',
                          style: GoogleFonts.sora(
                            color: DonyColors.grey400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checked ? widget.onAccept : null,
                        child: Text(
                          'Confirmer',
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
        Text(
          title,
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: DonyColors.ink900,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: DonyColors.green400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: DonyColors.grey400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
