import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({Key? key}) : super(key: key);

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _departureDate;
  double _availableKg = 10.0;
  final _priceController = TextEditingController();

  final List<String> _corridors = [
    'Paris', 'Lyon', 'Marseille',
    'Dakar', 'Abidjan', 'Bamako', 'Douala'
  ];

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A6B3C), // kGreenPrimary
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_departureDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La date de départ est obligatoire')),
        );
        return;
      }
      if (_departureCity == _arrivalCity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La ville de départ et d\'arrivée doivent être différentes')),
        );
        return;
      }

      final price = double.tryParse(_priceController.text);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer un prix valide')),
        );
        return;
      }

      context.read<AnnouncementBloc>().add(
        AnnouncementCreateRequested(
          departureCity: _departureCity!,
          arrivalCity: _arrivalCity!,
          departureDate: _departureDate!,
          availableKg: _availableKg,
          pricePerKg: price,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // kBackground
      appBar: AppBar(
        title: const Text('Publier un trajet', style: TextStyle(color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Annonce publiée avec succès !'),
                backgroundColor: Color(0xFF69F0AE),
              ),
            );
            context.go('/announcements');
          } else if (state is AnnouncementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFD32F2F),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AnnouncementLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Détails de votre voyage',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Ville de départ',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      value: _departureCity,
                      items: _corridors.map((city) {
                        return DropdownMenuItem(value: city, child: Text(city));
                      }).toList(),
                      onChanged: (val) => setState(() => _departureCity = val),
                      validator: (val) => val == null ? 'Veuillez sélectionner une ville' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Ville d\'arrivée',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      value: _arrivalCity,
                      items: _corridors.map((city) {
                        return DropdownMenuItem(value: city, child: Text(city));
                      }).toList(),
                      onChanged: (val) => setState(() => _arrivalCity = val),
                      validator: (val) => val == null ? 'Veuillez sélectionner une ville' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de départ',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          _departureDate == null 
                              ? 'Sélectionner une date' 
                              : DateFormat('dd/MM/yyyy').format(_departureDate!),
                          style: TextStyle(
                            color: _departureDate == null ? Colors.grey.shade600 : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Capacité disponible (kg)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _availableKg,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '${_availableKg.round()} kg',
                      activeColor: const Color(0xFF1A6B3C),
                      onChanged: (val) {
                        setState(() {
                          _availableKg = val;
                        });
                      },
                    ),
                    Center(child: Text('${_availableKg.round()} kg', style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Prix par kg (€)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        suffixText: '€',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Veuillez entrer un prix';
                        if (double.tryParse(val) == null) return 'Prix invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6B3C), // kGreenPrimary
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Publier mon trajet', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
              ),
            ),
          );
        },
      ),
    );
  }
}
