import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+33';

  static const _countryCodes = [
    ('+33', '🇫🇷 France'),
    ('+44', '🇬🇧 Royaume-Uni'),
    ('+1', '🇺🇸 États-Unis'),
    ('+221', '🇸🇳 Sénégal'),
    ('+225', '🇨🇮 Côte d\'Ivoire'),
    ('+223', '🇲🇱 Mali'),
    ('+237', '🇨🇲 Cameroun'),
    ('+241', '🇬🇦 Gabon'),
    ('+242', '🇨🇬 Congo'),
    ('+243', '🇨🇩 RD Congo'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    String local = _phoneController.text.trim();
    if (local.startsWith('0')) {
      local = local.substring(1);
    }
    return '$_selectedCountryCode$local';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<AuthBloc>().add(AuthSendOtpRequested(_fullPhoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthOtpSent) {
            context.push('/auth/otp');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  const Text(
                    'dony',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A6B3C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créer votre compte',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Entrez votre numéro de téléphone pour recevoir un code de vérification.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  _buildPhoneField(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Numéro de téléphone',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCountryCodeDropdown(),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '06 12 34 56 78',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A6B3C), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Entrez votre numéro';
                  }
                  final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 6) {
                    return 'Numéro trop court';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountryCodeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          items: _countryCodes.map((e) {
            return DropdownMenuItem(
              value: e.$1,
              child: Text('${e.$2} ${e.$1}', style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCountryCode = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Recevoir le code SMS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        );
      },
    );
  }
}
