import 'dart:async';

import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Captured from BLoC state on screen open / resend
  String _verificationId = '';
  String _phoneNumber = '';

  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is AuthOtpSent) {
      _verificationId = state.verificationId;
      _phoneNumber = state.phoneNumber;
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _verify() {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez le code à 6 chiffres')),
      );
      return;
    }
    context.read<AuthBloc>().add(
          AuthPhoneVerified(verificationId: _verificationId, smsCode: _otpCode),
        );
  }

  void _resend() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _secondsLeft = 60);
    _startTimer();
    context.read<AuthBloc>().add(AuthSendOtpRequested(_phoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthOtpSent) {
            // Resend flow — update captured IDs
            setState(() {
              _verificationId = state.verificationId;
              _phoneNumber = state.phoneNumber;
            });
          } else if (state is AuthOtpVerified) {
            context.go('/auth/role');
          } else if (state is AuthAuthenticated) {
            context.go('/home');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Code de vérification',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Code envoyé au\n$_phoneNumber',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  _buildOtpFields(),
                  const SizedBox(height: 32),
                  _buildVerifyButton(isLoading),
                  const SizedBox(height: 24),
                  _buildResendSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 48,
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1A6B3C), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildVerifyButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : _verify,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A6B3C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Vérifier',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Center(
      child: _secondsLeft > 0
          ? Text(
              'Renvoyer le code dans $_secondsLeft s',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            )
          : TextButton(
              onPressed: _resend,
              child: const Text(
                'Renvoyer le code',
                style: TextStyle(
                  color: Color(0xFF1A6B3C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}
