import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/sessao.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../conta/contas.dart';
import 'dados.dart';
import 'modelos.dart';
import 'widgets.dart';

/// Um pagamento: referência, valor, prazo e o link para pagar.
///
/// É o destino da notificação "pagamento emitido" (`/socio/pagamentos/{id}`,
/// pedido `2026-09-24-push-pagamento-emitido`), e abre também a partir do
/// histórico. Quando o pagamento é de um educando, a notificação traz
/// `?socio=<nr>` e o ecrã passa para a conta dele — `X-Socio`, como o resto.
///
/// Não há `GET /pagamentos/{id}`: procura-se no histórico da conta.
class PagamentoPage extends ConsumerStatefulWidget {
  const PagamentoPage({super.key, required this.id, this.socio});

  final int id;

  /// De quem é o pagamento, quando a notificação o diz.
  final int? socio;

  @override
  ConsumerState<PagamentoPage> createState() => _PagamentoPageState();
}

class _PagamentoPageState extends ConsumerState<PagamentoPage> {
  @override
  void initState() {
    super.initState();
    // Escolhe a conta antes do primeiro pedido, para ele já sair com o
    // `X-Socio` certo. Um número que não é da sessão nem de um educando cai
    // em `403 socio_nao_associado`, e o controller volta à conta de início.
    if (widget.socio case final nr?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(contaActivaProvider.notifier).escolher(nr);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(historicoPagamentosProvider);
    final dependente = ref.watch(dependenteActivoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(historicoPagamentosProvider)),
        data: (d) {
          final p = d.valor.where((p) => p.idPagamento == widget.id).firstOrNull;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(historicoPagamentosProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                if (dependente != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Conta de ${dependente.primeiroNome} · N.º ${dependente.nrSocio}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (p == null) const _NaoEncontrado() else _Detalhe(p, actual: d.actuais),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Detalhe extends ConsumerWidget {
  const _Detalhe(this.p, {required this.actual});

  final Pagamento p;

  /// Com dados da cache não se paga: o link pode já não ser este.
  final bool actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final (texto, cor) = estadoPagamentoVisual(p.estado, t.colorScheme.onSurfaceVariant);
    final podePagar =
        (ref.watch(dependenteActivoProvider)?.podePagar ?? true) &&
        sessaoTem(ref.watch(sessaoProvider), Capacidade.pagar);
    final hoje = DateUtils.dateOnly(DateTime.now());
    final expirado = p.limite != null && DateUtils.dateOnly(p.limite!).isBefore(hoje);
    final detalhe = [
      if (p.pendente && p.limite != null) 'Pagar até ${dataCurta(p.limite!)}',
      if (p.pago && p.pagoEm != null) 'Pago em ${dataCurta(p.pagoEm!)}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoValor(
          rotulo: p.descricao ?? 'Pagamento',
          valor: euros(p.valor),
          cor: p.pendente ? CoresEstado.pendente : null,
          detalhe: detalhe.isEmpty ? null : detalhe,
        ),
        Center(child: EtiquetaEstado(texto, cor: cor)),
        const TituloSeccao('Detalhes'),
        Bloco(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              if (p.referencia != null) _Linha('Referência', p.referencia!),
              if (p.metodo != null) _Linha('Método', p.metodo == 'mbway' ? 'MB WAY' : 'Referência / link'),
              if (p.data != null) _Linha('Emitido em', dataCurta(p.data!)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (p.pendente && p.urlPagamento != null && !expirado)
          if (!podePagar)
            NotaPermissao(explicacaoPermissao('pagar'), padding: EdgeInsets.zero)
          else
            FilledButton(
              // O valor e o método são os do pagamento emitido: a app não
              // envia nada, só abre o link do IfthenPay.
              onPressed: actual
                  ? () => launchUrl(Uri.parse(p.urlPagamento!), mode: LaunchMode.externalApplication)
                  : null,
              child: Text(actual ? 'Pagar agora' : 'Sem ligação para pagar'),
            )
        else if (p.pendente && expirado)
          Text(
            'O prazo deste pagamento acabou. Veja as quotas ou as faturas para pagar de novo.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor);

  final String rotulo, valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(rotulo, style: t.textTheme.bodySmall),
      trailing: Text(valor, style: t.textTheme.titleSmall),
    );
  }
}

/// Já saiu do histórico (anulado e limpo, ou de outra conta): em vez de um
/// ecrã vazio, o caminho para o que existe.
class _NaoEncontrado extends StatelessWidget {
  const _NaoEncontrado();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            'Este pagamento já não aparece na conta.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => context.go('/socio/pagamentos'), child: const Text('Ver os pagamentos')),
        ],
      ),
    );
  }
}
