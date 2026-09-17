import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/rede/ligacao.dart';
import '../conta/contas.dart';

/// `GET /me/cartao` (guia §4.4).
///
/// `hashid` e `qrConteudo` são a credencial que a portaria valida: não vão
/// para logs e a cache fica no armazenamento seguro.
class Cartao {
  final int nrSocio, estado;
  final String nomeCompleto, estadoLabel, qrConteudo;
  final String? fotoUrl;
  final DateTime? dataSocio;
  final bool valido;

  const Cartao({
    required this.nrSocio,
    required this.estado,
    required this.nomeCompleto,
    required this.estadoLabel,
    required this.qrConteudo,
    required this.valido,
    this.fotoUrl,
    this.dataSocio,
  });

  factory Cartao.fromJson(Map<String, dynamic> j) => Cartao(
    nrSocio: j['nr_socio'] as int,
    estado: j['estado'] as int,
    nomeCompleto: j['nome_completo'] as String,
    estadoLabel: j['estado_label'] as String,
    qrConteudo: j['qr_conteudo'] as String,
    valido: j['valido'] as bool,
    fotoUrl: j['foto_url'] as String?,
    dataSocio: j['data_socio'] is String ? DateTime.tryParse(j['data_socio'] as String) : null,
  );
}

/// `null` = `409 sem_cartao` (o sócio ainda não tem cartão emitido).
typedef CartaoOuNada = Cartao?;

final cartaoProvider = StreamProvider.autoDispose<Dados<CartaoOuNada>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final conta = PedidosNaConta(ref);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.seguro,
    // Por conta vista: o cartão de um dependente é o que o encarregado mostra à entrada.
    chave: 'cartao.${sessao.socio.nrSocio}.${conta.chave}',
    pedido: () async {
      try {
        return await conta.get('/me/cartao');
      } on ApiException catch (e) {
        if (e.erro == 'sem_cartao') return const {'sem_cartao': true};
        rethrow;
      }
    },
    ler: (j) => j['sem_cartao'] == true ? null : Cartao.fromJson(j),
  );
});
