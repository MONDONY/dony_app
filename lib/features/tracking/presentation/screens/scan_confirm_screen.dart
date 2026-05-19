import 'package:flutter/material.dart';

class ScanConfirmScreen extends StatelessWidget {
  const ScanConfirmScreen({
    super.key,
    required this.bidId,
    required this.etape,
    required this.packageLabel,
    this.photoPath,
    this.gpsLat,
    this.gpsLon,
  });

  final String bidId;
  final String etape;
  final String packageLabel;
  final String? photoPath;
  final double? gpsLat;
  final double? gpsLon;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Confirm')));
}
