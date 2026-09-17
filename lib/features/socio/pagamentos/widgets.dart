import 'package:flutter/material.dart';

import '../../../core/tema/tema.dart';

/// Etiqueta pequena de estado ("Pago", "Pendente", …).
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.texto, {super.key, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

abstract final class CoresEstado {
  static const pago = Color(0xFF12A15F);
  static const pendente = Tema.alerta;
  static const aguardar = Color(0xFFB7791F);
}

/// Cor e texto de um estado de pagamento; estados desconhecidos ficam neutros.
(String, Color) estadoPagamentoVisual(String estado, Color neutro) => switch (estado) {
  'PAGO' => ('Pago', CoresEstado.pago),
  'PENDENTE' => ('Por pagar', CoresEstado.aguardar),
  'CANCELADO' => ('Cancelado', neutro),
  'ANULADO' => ('Anulado', neutro),
  'RENOVADO' => ('Renovado', neutro),
  _ => (estado.isEmpty ? '—' : estado[0] + estado.substring(1).toLowerCase(), neutro),
};

/// Resumo grande no topo de um ecrã de dinheiro.
class CabecalhoValor extends StatelessWidget {
  const CabecalhoValor({super.key, required this.rotulo, required this.valor, this.detalhe, this.cor});

  final String rotulo, valor;
  final String? detalhe;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(valor, style: t.textTheme.displaySmall?.copyWith(color: cor, fontSize: 40)),
          if (detalhe != null) ...[
            const SizedBox(height: 2),
            Text(detalhe!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
