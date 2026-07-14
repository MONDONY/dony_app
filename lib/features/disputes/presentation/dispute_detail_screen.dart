import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:flutter/material.dart';

/// Stub minimal — complété en B5 (écran détail litige).
class DisputeDetailScreen extends StatelessWidget {
  const DisputeDetailScreen({super.key, required this.dispute});
  final DisputeModel dispute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Litige')),
      body: const SizedBox.shrink(),
    );
  }
}
