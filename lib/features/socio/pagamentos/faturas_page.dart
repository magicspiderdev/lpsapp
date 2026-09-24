import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/sessao.dart';
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

class FaturasPage extends ConsumerWidget {
  const FaturasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(faturasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Faturas')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(faturasProvider)),
        data: (d) {
          final porPagar = d.valor.where((f) => !f.paga).toList();
          final pagas = d.valor.where((f) => f.paga).toList();
          final emDivida = porPagar.fold<double>(0, (s, f) => s + f.emFalta);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(faturasProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                CabecalhoValor(
                  rotulo: emDivida > 0 ? 'Por pagar' : 'Tudo em dia',
                  valor: euros(emDivida),
                  cor: emDivida > 0 ? CoresEstado.pendente : null,
                  detalhe: porPagar.isEmpty
                      ? null
                      : '${porPagar.length} ${porPagar.length == 1 ? 'fatura' : 'faturas'} por pagar',
                ),
                if (d.valor.isEmpty) const Bloco(padding: EdgeInsets.all(20), child: Text('Ainda não há faturas.')),
                if (porPagar.isNotEmpty) ...[const TituloSeccao('Por pagar'), _Lista(porPagar)],
                if (pagas.isNotEmpty) ...[const TituloSeccao('Pagas'), _Lista(pagas)],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista(this.faturas);

  final List<Fatura> faturas;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Bloco(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, f) in faturas.indexed) ...[
            if (i > 0) const Divider(indent: 72),
            ListTile(
              onTap: () => context.push('/socio/faturas/${f.id}'),
              leading: IconePastilha(
                f.paga ? Icons.check_rounded : Icons.receipt_long_rounded,
                cor: f.paga ? CoresEstado.pago : CoresEstado.pendente,
              ),
              title: Text(f.mesLabel),
              subtitle: Text(f.paga ? 'Paga' : 'Por pagar'),
              trailing: Text(euros(f.valorTotal), style: t.textTheme.titleSmall),
            ),
          ],
        ],
      ),
    );
  }
}

class FaturaPage extends ConsumerWidget {
  const FaturaPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(faturaProvider(id));
    final podePagarConta = ref.watch(dependenteActivoProvider)?.podePagar ?? true;
    final podePagarIdade = sessaoTem(ref.watch(sessaoProvider), Capacidade.pagar);
    final d = estado.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(d?.valor.fatura.mesLabel ?? 'Fatura')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(faturaProvider(id))),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(faturaProvider(id).future),
          child: _Detalhe(d.valor, aviso: AvisoDesactualizado(d)),
        ),
      ),
      bottomNavigationBar: switch (d) {
        final d? when !d.valor.fatura.paga && podePagarConta && !podePagarIdade => SafeArea(
          child: NotaPermissao(explicacaoPermissao('pagar')),
        ),
        final d? when !d.valor.fatura.paga && podePagarConta => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 12),
            child: FilledButton(
              onPressed: d.actuais ? () => mostrarPagarFatura(context, d.valor.fatura) : null,
              child: Text(d.actuais ? 'Pagar ${euros(d.valor.fatura.emFalta)}' : 'Sem ligação para pagar'),
            ),
          ),
        ),
        _ => null,
      },
    );
  }
}

class _Detalhe extends StatelessWidget {
  const _Detalhe(this.d, {required this.aviso});

  final DetalheFatura d;
  final Widget aviso;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final f = d.fatura;
    final p = d.pagamento;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
      children: [
        aviso,
        CabecalhoValor(
          rotulo: f.paga ? 'Paga' : 'Por pagar',
          valor: euros(f.valorTotal),
          cor: f.paga ? null : CoresEstado.pendente,
          detalhe: [
            if (f.nrFatura != null) 'Fatura ${f.nrFatura}',
            if (f.geradoEm != null) 'emitida a ${dataCurta(f.geradoEm!)}',
          ].join(' · '),
        ),
        const TituloSeccao('Detalhe'),
        Bloco(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final (i, l) in d.linhas.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(l.descricao, style: t.textTheme.bodyMedium)),
                      const SizedBox(width: 12),
                      Text(euros(l.valor), style: t.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('Total', style: t.textTheme.titleSmall)),
                    Text(euros(f.valorTotal), style: t.textTheme.titleSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (p != null) ...[
          const TituloSeccao('Pagamento'),
          Bloco(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(euros(p.valor), style: t.textTheme.titleSmall),
                      Text(
                        [
                          if (p.pagoEm != null) 'pago a ${dataCurta(p.pagoEm!)}',
                          if (!p.pago && p.limite != null) 'pagar até ${dataCurta(p.limite!)}',
                        ].join(' · '),
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) {
                    final (texto, cor) = estadoPagamentoVisual(p.estado, t.colorScheme.onSurfaceVariant);
                    return EtiquetaEstado(texto, cor: cor);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Histórico de pagamentos (guia §4.10).
class HistoricoPagamentosPage extends ConsumerWidget {
  const HistoricoPagamentosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(historicoPagamentosProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(historicoPagamentosProvider)),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(historicoPagamentosProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
            children: [
              AvisoDesactualizado(d),
              if (d.valor.isEmpty)
                const Bloco(padding: EdgeInsets.all(20), child: Text('Ainda não há pagamentos.'))
              else
                Bloco(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, p) in d.valor.indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        InkWell(
                          onTap: () => context.push('/socio/pagamentos/${p.idPagamento}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.descricao ?? 'Pagamento',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if ((p.pagoEm ?? p.data) != null) dataCurta((p.pagoEm ?? p.data)!),
                                          if (p.metodo == 'mbway') 'MB WAY',
                                          if (p.metodo == 'paybylink') 'Referência',
                                        ].join(' · '),
                                        style: t.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(euros(p.valor), style: t.textTheme.titleSmall),
                                    const SizedBox(height: 4),
                                    Builder(
                                      builder: (context) {
                                        final (texto, cor) = estadoPagamentoVisual(
                                          p.estado,
                                          t.colorScheme.onSurfaceVariant,
                                        );
                                        return EtiquetaEstado(texto, cor: cor);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
