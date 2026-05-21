import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class LegalWebViewScreen extends StatelessWidget {
  const LegalWebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DonyAppBar(title: title),
      body: Center(child: Text(url)),
    );
  }
}
