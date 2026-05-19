import 'package:flutter/material.dart';

class ScanIdentifyScreen extends StatelessWidget {
  const ScanIdentifyScreen({super.key, this.etape, this.focusNumber = false});

  final String? etape;
  final bool focusNumber;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Identify')));
}
