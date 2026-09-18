import 'package:flutter/material.dart';

/// Visível enquanto o `/ping` responde; o router sai daqui sozinho.
///
/// Sem imagem de marca: o arranque nativo já mostra o ícone do clube e esta
/// passa a ser só a espera, com o fundo da app por baixo.
class ArranquePage extends StatelessWidget {
  const ArranquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
