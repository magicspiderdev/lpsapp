import 'package:flutter/material.dart';

import '../../core/tema/tema.dart';

/// Marca do clube no topo dos ecrãs de entrada.
class MarcaClube extends StatelessWidget {
  const MarcaClube({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: Tema.gradienteClube,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: const Text('LPS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.5)),
      ),
    );
  }
}

class AvisoErro extends StatelessWidget {
  const AvisoErro(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tema.raioPequeno),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: c.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: c.error, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class ProgressoBotao extends StatelessWidget {
  const ProgressoBotao({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}
