import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/sessao.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import 'contas.dart';

final _euros = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

/// Folha para escolher a conta: a do próprio e as dos sócios a seu cargo.
Future<void> mostrarSeletorConta(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (sheet) => const _SeletorConta(),
  );
}

class _SeletorConta extends StatelessWidget {
  const _SeletorConta();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text('Contas', style: tema.textTheme.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Text(
                'Consulte e pague a conta dos sócios a seu cargo.',
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
            ContasDaFamilia(depoisDeEscolher: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

/// A conta do próprio e as dos sócios a seu cargo, com a que se está a ver
/// marcada. Tocar numa passa a vê-la. Serve a folha e o Início.
class ContasDaFamilia extends ConsumerWidget {
  const ContasDaFamilia({super.key, this.depoisDeEscolher, this.comPropria = true});

  final VoidCallback? depoisDeEscolher;

  /// No Início a conta própria só aparece quando se está a ver outra — é o
  /// caminho de volta.
  final bool comPropria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    final activa = ref.watch(contaActivaProvider);
    final dependentes = ref.watch(dependentesProvider).valueOrNull?.valor ?? const <Dependente>[];
    if (!temZonaPrivada(sessao)) return const SizedBox.shrink();

    void escolher(int? nr) {
      ref.read(contaActivaProvider.notifier).escolher(nr);
      depoisDeEscolher?.call();
    }

    return Column(
      children: [
        // Um encarregado sem ficha não tem conta própria para mostrar.
        if (sessao is SessaoSocio && (comPropria || activa != null))
          _LinhaConta(
            nome: sessao.socio.nomeCompleto,
            fotoUrl: sessao.socio.fotoUrl,
            detalhe: 'A sua conta · N.º ${sessao.socio.nrSocio}',
            activa: activa == null,
            onTap: () => escolher(null),
          ),
        for (final d in dependentes)
          _LinhaConta(
            nome: d.nomeCompleto,
            fotoUrl: d.fotoUrl,
            detalhe: [
              'N.º ${d.nrSocio}',
              if (d.idade != null) '${d.idade} anos',
              if (d.estado != 1) d.estadoLabel,
              if (!d.podePagar) 'só consulta',
            ].join(' · '),
            valor: d.dividaTotal > 0 ? _euros.format(d.dividaTotal) : null,
            activa: activa == d.nrSocio,
            onTap: () => escolher(d.nrSocio),
          ),
      ],
    );
  }
}

class _LinhaConta extends StatelessWidget {
  const _LinhaConta({
    required this.nome,
    required this.detalhe,
    required this.activa,
    required this.onTap,
    this.fotoUrl,
    this.valor,
  });

  final String nome, detalhe;
  final String? fotoUrl, valor;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tema.raioPequeno),
          side: BorderSide(color: activa ? c.primary : Colors.transparent, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Avatar(nome: nome, url: fotoUrl, tamanho: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(detalhe, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (valor != null) ...[
                  const SizedBox(width: 8),
                  Text(valor!, style: tema.textTheme.titleSmall?.copyWith(color: c.error)),
                ],
                const SizedBox(width: 8),
                Icon(
                  activa ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: activa ? c.primary : c.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
