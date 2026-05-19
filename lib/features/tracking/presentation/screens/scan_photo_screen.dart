import 'package:flutter/material.dart';

class ScanPhotoScreen extends StatelessWidget {
  const ScanPhotoScreen({
    super.key,
    required this.bidId,
    required this.etape,
    required this.packageLabel,
  });

  final String bidId;
  final String etape;
  final String packageLabel;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Photo')));
}
