import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/rede/ligacao.dart';
import '../conta/contas.dart';
import '../inicio_page.dart';
import 'modelos.dart';

/// Pedidos à conta que se está a ver (própria ou de um dependente).
final pedidosNaContaProvider = Provider.autoDispose<PedidosNaConta>(PedidosNaConta.new);

/// Consulta com cache, na conta activa, apagada quando a sessão acaba.
Stream<Dados<T>> _consulta<T>(
  Ref ref,
  String nome,
  String caminho,
  T Function(Map<String, dynamic>) ler, {
  Map<String, dynamic>? query,
}) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final conta = PedidosNaConta(ref);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: '$nome.${sessao.socio.nrSocio}.${conta.chave}',
    pedido: () => conta.get(caminho, query: query),
    ler: ler,
  );
}

final quotasProvider = StreamProvider.autoDispose<Dados<Quotas>>(
  (ref) => _consulta(ref, 'quotas', '/quotas', Quotas.fromJson),
);

final faturasProvider = StreamProvider.autoDispose<Dados<List<Fatura>>>(
  (ref) => _consulta(
    ref,
    'faturas',
    '/faturas',
    (j) => [for (final f in j['faturas'] as List) Fatura.fromJson((f as Map).cast<String, dynamic>())],
  ),
);

final faturaProvider = StreamProvider.autoDispose.family<Dados<DetalheFatura>, int>(
  (ref, id) => _consulta(ref, 'fatura.$id', '/faturas/$id', DetalheFatura.fromJson),
);

final historicoPagamentosProvider = StreamProvider.autoDispose<Dados<List<Pagamento>>>(
  (ref) => _consulta(
    ref,
    'pagamentos',
    '/pagamentos',
    (j) => [for (final p in j['pagamentos'] as List) Pagamento.fromJson((p as Map).cast<String, dynamic>())],
    query: const {'limite': 100},
  ),
);

/// Depois de pagar, cancelar ou confirmar: tudo o que mostra dinheiro volta a pedir.
void refrescarContas(WidgetRef ref) {
  ref.invalidate(resumoProvider);
  ref.invalidate(quotasProvider);
  ref.invalidate(faturasProvider);
  ref.invalidate(faturaProvider);
  ref.invalidate(historicoPagamentosProvider);
  ref.invalidate(dependentesProvider);
}

/// Acções que mexem em dinheiro. Nunca com cache e nunca repetidas sozinhas.
extension AccoesPagamento on PedidosNaConta {
  /// `quantidade` é uma preferência: o servidor ajusta ao mínimo e ao máximo e
  /// calcula o valor (guia §4.11).
  Future<ResultadoPagamento> pagarQuotas({required int quantidade, required String metodo, String? telefone}) async =>
      ResultadoPagamento.fromJson(
        await post('/quotas/pagar', {
          'quantidade': quantidade,
          'metodo': metodo,
          if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
        }),
      );

  Future<ResultadoPagamento> pagarFatura(int id, {required String metodo, String? telefone}) async =>
      ResultadoPagamento.fromJson(
        await post('/faturas/$id/pagar', {
          'metodo': metodo,
          if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
        }),
      );

  Future<void> cancelarOrdem(int idPagamento) => delete('/quotas/ordens/$idPagamento');

  /// Estado actual de um pagamento, para acompanhar a confirmação (que é assíncrona).
  Future<Pagamento?> estadoPagamento(int idPagamento) async {
    final j = await get('/pagamentos', query: const {'limite': 50});
    for (final p in j['pagamentos'] as List) {
      final pagamento = Pagamento.fromJson((p as Map).cast<String, dynamic>());
      if (pagamento.idPagamento == idPagamento) return pagamento;
    }
    return null;
  }
}
