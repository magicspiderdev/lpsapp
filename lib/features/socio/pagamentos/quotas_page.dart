import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../conta/contas.dart';
import 'dados.dart';
import 'modelos.dart';
import 'pagar_sheet.dart';
import 'widgets.dart';

/// Caderneta de quotas, ordens por pagar e botão de pagar.
class QuotasPage extends ConsumerStatefulWidget {
  const QuotasPage({super.key, this.abrirPagamento = false});

  /// Vindo do botão "Pagar" do início: abre logo a folha de pagamento.
  final bool abrirPagamento;

  @override
  ConsumerState<QuotasPage> createState() => _QuotasPageState();
}

class _QuotasPageState extends ConsumerState<QuotasPage> {
  bool _jaAbriu = false;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(quotasProvider);
    final podePagarConta = ref.watch(dependenteActivoProvider)?.podePagar ?? true;

    // Abrir a folha uma vez, com dados actuais (não com a cache, que pode estar velha).
    final d = estado.valueOrNull;
    if (widget.abrirPagamento && !_jaAbriu && d != null && d.actuais && d.valor.podePagar && podePagarConta) {
      _jaAbriu = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mostrarPagarQuotas(context, d.valor);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quotas')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(quotasProvider)),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(quotasProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 120),
            children: [
              AvisoDesactualizado(d),
              _Resumo(d.valor),
              for (final o in d.valor.ordensPendentes) _Ordem(o, d),
              const TituloSeccao('Caderneta'),
              _Caderneta(d.valor.caderneta),
            ],
          ),
        ),
      ),
      bottomNavigationBar: switch (d) {
        final d? when d.valor.podePagar && podePagarConta => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 12),
            child: FilledButton(
              // Com dados da cache não se paga: o valor e as ordens podem já não ser estes.
              onPressed: d.actuais ? () => mostrarPagarQuotas(context, d.valor) : null,
              child: Text(d.actuais ? 'Pagar quotas' : 'Sem ligação para pagar'),
            ),
          ),
        ),
        _ => null,
      },
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo(this.q);

  final Quotas q;

  @override
  Widget build(BuildContext context) {
    if (q.isento) {
      return const CabecalhoValor(rotulo: 'Quotas', valor: 'Isento', detalhe: 'Não há quotas a pagar.');
    }
    final pendentes = q.caderneta.where((m) => m.estado == EstadoMes.pendente).length;
    return CabecalhoValor(
      rotulo: q.totalPendente > 0 ? 'Em dívida' : 'Tudo em dia',
      valor: euros(q.totalPendente),
      cor: q.totalPendente > 0 ? CoresEstado.pendente : null,
      detalhe: [
        if (pendentes > 0) '$pendentes ${pendentes == 1 ? 'mês' : 'meses'} por pagar',
        if (q.ultimaQuota != null) 'última paga: ${_mesAno(q.ultimaQuota!)}',
      ].join(' · '),
    );
  }
}

String _mesAno(DateTime d) {
  const meses = ['jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.', 'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.'];
  return '${meses[d.month - 1]} ${d.year}';
}

/// Uma ordem de quotas por pagar: abrir o link, ver a referência, cancelar.
class _Ordem extends ConsumerWidget {
  const _Ordem(this.o, this.d);

  final OrdemPendente o;
  final Dados<Quotas> d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Bloco(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconePastilha(Icons.schedule_rounded, cor: CoresEstado.aguardar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento por concluir', style: t.textTheme.titleSmall),
                      Text(o.meses, style: t.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(euros(o.valor), style: t.textTheme.titleMedium),
              ],
            ),
            if (o.referencia != null || o.limite != null) ...[
              const SizedBox(height: 10),
              Text(
                [
                  if (o.referencia != null) 'Referência ${o.referencia}',
                  if (o.limite != null) 'pagar até ${dataCurta(o.limite!)}',
                ].join(' · '),
                style: t.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (o.urlPagamento != null)
                  OutlinedButton(
                    onPressed: () => launchUrl(Uri.parse(o.urlPagamento!), mode: LaunchMode.externalApplication),
                    child: const Text('Pagar agora'),
                  ),
                if (o.cancelavel && d.actuais)
                  TextButton(onPressed: () => _cancelar(context, ref), child: const Text('Cancelar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar pagamento?'),
        content: Text('A referência de ${euros(o.valor)} deixa de poder ser paga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Manter')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancelar pagamento')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(pedidosNaContaProvider).cancelarOrdem(o.idPagamento);
      refrescarContas(ref);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

/// Meses agrupados por ano, do mais recente para o mais antigo.
class _Caderneta extends StatelessWidget {
  const _Caderneta(this.meses);

  final List<MesQuota> meses;

  @override
  Widget build(BuildContext context) {
    if (meses.isEmpty) {
      return const Bloco(padding: EdgeInsets.all(20), child: Text('Ainda não há quotas registadas.'));
    }
    final porAno = <int, List<MesQuota>>{};
    for (final m in meses) {
      porAno.putIfAbsent(m.mes.year, () => []).add(m);
    }
    final anos = porAno.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (final ano in anos) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('$ano', style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          Bloco(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, m) in (porAno[ano]!..sort((a, b) => b.mes.compareTo(a.mes))).indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  _LinhaMes(m),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LinhaMes extends StatelessWidget {
  const _LinhaMes(this.m);

  final MesQuota m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final neutro = t.colorScheme.onSurfaceVariant;
    final (texto, cor) = switch (m.estado) {
      EstadoMes.pago || EstadoMes.pagoLegacy => ('Pago', CoresEstado.pago),
      EstadoMes.pendente => ('Em dívida', CoresEstado.pendente),
      EstadoMes.futuro => ('Por vencer', neutro),
      EstadoMes.isento => ('Isento', neutro),
      EstadoMes.desconhecido => ('—', neutro),
    };
    // pago_legacy: valor desconhecido — não mostrar "0,00 €".
    final valor = m.valor == null ? '' : euros(m.valor!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.mesLabel, style: t.textTheme.titleSmall),
                if (m.tipo != null || m.pagoEm != null)
                  Text(
                    [if (m.tipo != null) m.tipo!, if (m.pagoEm != null) 'pago a ${dataCurta(m.pagoEm!)}'].join(' · '),
                    style: t.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (valor.isNotEmpty) ...[Text(valor, style: t.textTheme.bodyMedium), const SizedBox(width: 10)],
          EtiquetaEstado(texto, cor: cor),
        ],
      ),
    );
  }
}
