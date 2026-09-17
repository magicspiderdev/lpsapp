import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'dados.dart';
import 'modelos.dart';
import 'widgets.dart';

/// Modalidades subscritas e mensalidades mês a mês.
class MensalidadesPage extends ConsumerWidget {
  const MensalidadesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(mensalidadesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mensalidades')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(mensalidadesProvider)),
        data: (d) {
          final m = d.valor;
          final activas = m.subscricoes.where((s) => s.ativa).toList();
          final meses = [...m.caderneta]..sort((a, b) => b.mes.compareTo(a.mes));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(mensalidadesProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                CabecalhoValor(
                  rotulo: m.totalPendente > 0 ? 'Em dívida' : 'Tudo em dia',
                  valor: euros(m.totalPendente),
                  cor: m.totalPendente > 0 ? CoresEstado.pendente : null,
                  detalhe: m.totalPendente > 0 ? 'Paga-se pelas faturas' : null,
                ),
                if (activas.isNotEmpty) ...[const TituloSeccao('Modalidades'), _Subscricoes(activas)],
                const TituloSeccao('Mês a mês'),
                if (meses.isEmpty)
                  const Bloco(padding: EdgeInsets.all(20), child: Text('Ainda não há mensalidades.'))
                else
                  Bloco(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, mes) in meses.indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          _LinhaMes(mes),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Subscricoes extends StatelessWidget {
  const _Subscricoes(this.subscricoes);

  final List<Subscricao> subscricoes;

  @override
  Widget build(BuildContext context) {
    return Bloco(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, s) in subscricoes.indexed) ...[
            if (i > 0) const Divider(indent: 72),
            ListTile(
              leading: const IconePastilha(Icons.sports_soccer_rounded),
              title: Text(_capital(s.modalidade)),
              subtitle: Text(
                [if (s.epoca != null) 'Época ${s.epoca}', if (s.incluiQuota) 'inclui a quota de sócio'].join(' · '),
              ),
              trailing: s.valorFixo == null ? null : Text('${euros(s.valorFixo!)}/mês'),
            ),
          ],
        ],
      ),
    );
  }

  static String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _LinhaMes extends StatelessWidget {
  const _LinhaMes(this.m);

  final MesModalidade m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final neutro = t.colorScheme.onSurfaceVariant;
    // Estimado: previsão, cinzento, nunca "em dívida" nem pagável (guia §4.6).
    final (texto, cor) = m.estimado
        ? ('Previsto', neutro)
        : switch (m.estado) {
            'pago' => ('Pago', CoresEstado.pago),
            'pendente' => ('Por pagar', CoresEstado.pendente),
            'futuro' => ('Por vencer', neutro),
            _ => (m.estado.isEmpty ? '—' : m.estado, neutro),
          };

    return InkWell(
      onTap: m.idFatura == null ? null : () => context.push('/socio/faturas/${m.idFatura}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.mesLabel, style: t.textTheme.titleSmall),
                  if (m.estimado) Text('valor previsto, a fatura ainda não foi emitida', style: t.textTheme.bodySmall),
                ],
              ),
            ),
            Text(euros(m.valor), style: t.textTheme.bodyMedium?.copyWith(color: m.estimado ? neutro : null)),
            const SizedBox(width: 10),
            EtiquetaEstado(texto, cor: cor),
            if (m.idFatura != null) Icon(Icons.chevron_right_rounded, color: neutro),
          ],
        ),
      ),
    );
  }
}

/// Conta corrente: créditos e débitos geridos pela secretaria. Só consulta.
class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(walletProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Conta corrente')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(walletProvider)),
        data: (d) {
          final w = d.valor;
          final movimentos = [...w.movimentos]
            ..sort((a, b) => (b.data ?? DateTime(0)).compareTo(a.data ?? DateTime(0)));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(walletProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                CabecalhoValor(
                  rotulo: 'Saldo',
                  valor: euros(w.saldo),
                  cor: w.saldo > 0 ? CoresEstado.pago : null,
                  detalhe: w.saldo > 0 ? 'A seu favor — é descontado nas próximas faturas.' : null,
                ),
                const TituloSeccao('Movimentos'),
                if (movimentos.isEmpty)
                  const Bloco(padding: EdgeInsets.all(20), child: Text('Sem movimentos.'))
                else
                  Bloco(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, mov) in movimentos.indexed) ...[
                          if (i > 0) const Divider(indent: 72),
                          ListTile(
                            leading: IconePastilha(
                              mov.credito ? Icons.south_west_rounded : Icons.north_east_rounded,
                              cor: mov.credito ? CoresEstado.pago : t.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(mov.descricao ?? (mov.credito ? 'Crédito' : 'Débito')),
                            subtitle: mov.data == null ? null : Text(dataCurta(mov.data!)),
                            trailing: Text(
                              '${mov.credito ? '+' : '−'}${euros(mov.valor)}',
                              style: t.textTheme.titleSmall?.copyWith(color: mov.credito ? CoresEstado.pago : null),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
