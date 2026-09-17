import 'package:flutter/material.dart';

import '../api/api_exception.dart';

/// Erro de carregamento com "tentar novamente". A `message` da API já vem
/// pronta a mostrar; outros erros ficam com um texto genérico.
class ErroView extends StatelessWidget {
  const ErroView({super.key, required this.erro, required this.tentarDeNovo});

  final Object erro;
  final VoidCallback tentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final texto = erro is ApiException ? (erro as ApiException).message : 'Não foi possível carregar. Tente novamente.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: tentarDeNovo, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
