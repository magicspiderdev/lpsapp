import 'package:flutter/material.dart';

/// Visível enquanto o `/ping` responde; o router sai daqui sozinho.
class ArranquePage extends StatelessWidget {
  const ArranquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
