import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../cache/com_cache.dart';
import '../tema/tema.dart';

/// "hoje às 14:32", "ontem às 09:10", "12 set. às 18:00".
String quandoFoiObtido(DateTime d, {DateTime? agora}) {
  final hoje = DateUtils.dateOnly(agora ?? DateTime.now());
  final dia = DateUtils.dateOnly(d);
  final hora = DateFormat('HH:mm').format(d);
  if (dia == hoje) return 'hoje às $hora';
  if (dia == hoje.subtract(const Duration(days: 1))) return 'ontem às $hora';
  return '${DateFormat('d MMM', 'pt_PT').format(d)} às $hora';
}

/// Aviso de que a informação é a última guardada, porque não foi possível actualizar.
/// Não ocupa espaço quando os dados estão actuais.
class AvisoDesactualizado extends StatelessWidget {
  const AvisoDesactualizado(this.dados, {super.key, this.margem = const EdgeInsets.only(bottom: 12)});

  final Dados<Object?> dados;
  final EdgeInsetsGeometry margem;

  @override
  Widget build(BuildContext context) {
    if (!dados.desactualizados) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    final semRede = dados.falhaAoActualizar?.erro == 'sem_ligacao';

    return Padding(
      padding: margem,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(Tema.raioPequeno)),
        child: Row(
          children: [
            Icon(semRede ? Icons.cloud_off_rounded : Icons.sync_problem_rounded, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${semRede ? 'Sem ligação' : 'Serviço indisponível'} · informação de ${quandoFoiObtido(dados.obtidoEm)}',
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
