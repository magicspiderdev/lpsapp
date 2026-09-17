import 'package:flutter/material.dart';

import '../config.dart';
import '../tema/tema.dart';
import 'blocos.dart';

/// Área desenhada mas ainda sem API. Não é um erro: é uma promessa.
class EmPreparacao implements Exception {
  const EmPreparacao();
}

class PainelEmPreparacao extends StatelessWidget {
  const PainelEmPreparacao({super.key, required this.icone, required this.titulo, required this.texto});

  final IconData icone;
  final String titulo, texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconePastilha(icone),
            const SizedBox(height: 16),
            Text(titulo, textAlign: TextAlign.center, style: t.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(texto, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
            if (!modoDemonstracao) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Tema.raioPequeno),
                ),
                child: Text('Brevemente', style: t.textTheme.labelMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
