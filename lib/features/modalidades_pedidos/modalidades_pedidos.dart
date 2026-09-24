import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/clientes.dart';
import '../../core/api/envelope.dart';
import '../../core/auth/sessao.dart';
import '../../core/cache/cache_local.dart';
import '../../core/cache/com_cache.dart';
import '../../core/formatos.dart';
import '../../core/rede/ligacao.dart';
import '../publico/bilheteira/bilheteira.dart' show SemSessao;

/// Pedir a inscrição ou a baixa de um atleta numa modalidade (guia §4.22).
///
/// **Pedir não é inscrever, e pedir a baixa não é sair.** Cria-se um pedido que
/// a secretaria decide; é a aprovação que começa (ou acaba) a mensalidade, e
/// essa é cobrada pelo ciclo normal da v1. Não há pagamento nenhum aqui.
///
/// Não confundir com as mensalidades da v1 (`socio/pagamentos/`, o que já se
/// paga) nem com as modalidades públicas (`publico/clube/`, o que o clube tem).

/// Os caminhos destes ecrãs. Debaixo de `/socio/conta`, que abre para qualquer
/// sessão: uma conta sem ficha pode ser encarregada de alguém e pedir por ele.
abstract final class RotasModalidades {
  static const lista = '/socio/conta/modalidades';
  static const pedir = '$lista/pedir';
  static String pedido(String id) => '$lista/${Uri.encodeComponent(id)}';

  /// O formulário já com a modalidade (e o tipo) escolhidos — da página de uma
  /// modalidade pública, por exemplo.
  static String pedirCom({String? modalidade, String? tipo}) {
    final q = {'modalidade': ?modalidade, 'tipo': ?tipo};
    return Uri(path: pedir, queryParameters: q.isEmpty ? null : q).toString();
  }
}

abstract final class TipoPedido {
  static const inscricao = 'inscricao';
  static const baixa = 'baixa';
}

/// Um pedido de inscrição ou de baixa. `estado` e `tipo` são listas abertas:
/// o ecrã decide por [aberto] e [cancelavel] e mostra os `*_label` do servidor.
class PedidoModalidade {
  final String id, tipo, tipoLabel, estado, estadoLabel;
  final bool aberto, cancelavel;
  final String? modalidadeSlug;
  final String modalidadeNome;
  final int? atletaNrSocio;
  final String atletaNome;
  final String? observacoes;

  /// €/mês pela tabela de preços e pela idade de hoje. **Pode ser `null`**
  /// (não há preço para aquela idade, e sempre numa baixa): aí o valor é
  /// confirmado pela secretaria — nunca "0 €".
  final num? valorEstimado;

  /// Porque foi recusado, escrito por uma pessoa. Mostra-se tal e qual.
  final String? motivo;
  final DateTime? criadoEm, decididoEm;

  const PedidoModalidade({
    required this.id,
    required this.tipo,
    required this.tipoLabel,
    required this.estado,
    required this.estadoLabel,
    required this.aberto,
    required this.cancelavel,
    required this.modalidadeNome,
    required this.atletaNome,
    this.modalidadeSlug,
    this.atletaNrSocio,
    this.observacoes,
    this.valorEstimado,
    this.motivo,
    this.criadoEm,
    this.decididoEm,
  });

  factory PedidoModalidade.fromJson(Map<String, dynamic> j) {
    final m = j['modalidade'] is Map ? (j['modalidade'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final a = j['atleta'] is Map ? (j['atleta'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final tipo = (j['tipo'] as String?) ?? '';
    final estado = (j['estado'] as String?) ?? '';
    return PedidoModalidade(
      id: '${j['id'] ?? ''}',
      tipo: tipo,
      tipoLabel: _texto(j['tipo_label']) ?? _capitalizar(tipo),
      estado: estado,
      estadoLabel: _texto(j['estado_label']) ?? _capitalizar(estado),
      aberto: j['aberto'] == true,
      cancelavel: j['cancelavel'] == true,
      modalidadeSlug: _texto(m['slug']),
      modalidadeNome: _texto(m['nome']) ?? _texto(m['slug']) ?? 'Modalidade',
      atletaNrSocio: (a['nr_socio'] as num?)?.toInt(),
      atletaNome: _texto(a['nome_completo']) ?? '',
      observacoes: _texto(j['observacoes']),
      valorEstimado: j['valor_estimado'] is num ? j['valor_estimado'] as num : null,
      motivo: _texto(j['motivo']),
      criadoEm: dataApi(j['criado_em']),
      decididoEm: dataApi(j['decidido_em']),
    );
  }

  bool get baixa => tipo == TipoPedido.baixa;

  /// Recusado, com a razão escrita. Pelo motivo, e não por comparar o estado:
  /// a razão é o que se tem para mostrar.
  bool get temMotivo => !aberto && motivo != null;

  /// Uma baixa recusada quase nunca é um "não" — é "resolva isto primeiro".
  /// Merece um caminho para falar com a secretaria.
  bool get baixaPorResolver => baixa && temMotivo;
}

/// Por quem a conta pode pedir: o sócio dela (sempre o primeiro) e os que tem
/// a cargo. Os que não podem vêm à mesma, com a razão.
class AtletaElegivel {
  final int nrSocio;
  final String nome, relacao;
  final int? idade;
  final bool podeInscrever;
  final String? porqueNao;

  const AtletaElegivel({
    required this.nrSocio,
    required this.nome,
    required this.relacao,
    this.idade,
    this.podeInscrever = true,
    this.porqueNao,
  });

  factory AtletaElegivel.fromJson(Map<String, dynamic> j) => AtletaElegivel(
    nrSocio: (j['nr_socio'] as num).toInt(),
    nome: _texto(j['nome_completo']) ?? 'Sócio n.º ${j['nr_socio']}',
    relacao: (j['relacao'] as String?) ?? '',
    idade: (j['idade'] as num?)?.toInt(),
    podeInscrever: j['pode_inscrever'] != false,
    porqueNao: _texto(j['porque_nao']),
  );

  bool get proprio => relacao == 'proprio';

  /// A linha de baixo no seletor: "Eu · 41 anos", "Pai · 12 anos".
  String get descricao {
    final quem = proprio ? 'Eu' : (relacao.isEmpty ? 'A cargo' : 'A cargo (${relacao.replaceAll('_', ' ')})');
    return idade == null ? quem : '$quem · $idade anos';
  }

  /// Se pode ser escolhido para este [tipo]. `pode_inscrever` diz respeito à
  /// inscrição: a baixa não exige ficha activa (§4.22.3), por isso quem
  /// desistiu de sócio também pode fechar a modalidade.
  bool podePara(String tipo) => tipo == TipoPedido.baixa || podeInscrever;
}

class PedidosModalidades {
  final List<PedidoModalidade> pedidos;
  final List<AtletaElegivel> atletas;

  const PedidosModalidades({this.pedidos = const [], this.atletas = const []});

  factory PedidosModalidades.fromJson(Map<String, dynamic> j) => PedidosModalidades(
    pedidos: [
      for (final p in (j['pedidos'] as List?) ?? const [])
        if (p is Map) PedidoModalidade.fromJson(p.cast<String, dynamic>()),
    ],
    atletas: [
      for (final a in (j['atletas'] as List?) ?? const [])
        if (a is Map && a['nr_socio'] is num) AtletaElegivel.fromJson(a.cast<String, dynamic>()),
    ],
  );

  /// Os que esperam decisão primeiro; depois os mais recentes.
  List<PedidoModalidade> get ordenados {
    final l = [...pedidos];
    l.sort((a, b) {
      if (a.aberto != b.aberto) return a.aberto ? -1 : 1;
      final da = a.criadoEm, db = b.criadoEm;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return l;
  }
}

/// A linha do valor, pronta a mostrar. `null` numa baixa: aí o que interessa é
/// até quando se paga, e isso só se sabe quando alguém decidir.
String? textoValorEstimado(PedidoModalidade p) {
  if (p.baixa) return null;
  final v = p.valorEstimado;
  if (v == null) return 'O valor é confirmado pela secretaria.';
  return 'Cerca de ${euros(v)}/mês (estimativa; o valor final é fixado na aprovação)';
}

String? _texto(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

String _capitalizar(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

// ── Pedidos à API ────────────────────────────────────────────────────────────

/// `GET /me/modalidades` — os pedidos da conta e por quem pode pedir. Com
/// cache no âmbito da sessão: são dados pessoais. Recarrega-se sempre que o
/// ecrã abre, porque o push da decisão pode não ter chegado.
final pedidosModalidadesProvider = StreamProvider.autoDispose<Dados<PedidosModalidades>>((ref) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'modalidades.pedidos',
    pedido: () => dadosDe(dio.get('/me/modalidades')),
    ler: PedidosModalidades.fromJson,
  );
});

/// `GET /me/modalidades/{id}` — um pedido.
final pedidoModalidadeProvider = StreamProvider.autoDispose.family<Dados<PedidoModalidade>, String>((ref, id) {
  if (ref.watch(sessaoProvider) is SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'modalidades.pedido.$id',
    pedido: () => dadosDe(dio.get('/me/modalidades/${Uri.encodeComponent(id)}')),
    ler: (d) => PedidoModalidade.fromJson((d['pedido'] as Map).cast<String, dynamic>()),
  );
});

/// As escritas. Nunca a partir da cache: cada uma vai ao servidor e devolve o
/// pedido como ele ficou.
class AccoesModalidades {
  AccoesModalidades(this._dio);

  final Dio _dio;

  /// `POST /me/modalidades`. O [nrSocio] vai sempre explícito — o seletor já
  /// o tem, e assim o pedido diz por quem é sem depender do que a conta é.
  Future<PedidoModalidade> pedir({
    required String modalidade,
    required String tipo,
    required int nrSocio,
    String? observacoes,
  }) async {
    final obs = observacoes?.trim();
    final d = await dadosDe(
      _dio.post(
        '/me/modalidades',
        data: {
          'modalidade': modalidade,
          'tipo': tipo,
          'nr_socio': nrSocio,
          if (obs != null && obs.isNotEmpty) 'observacoes': obs,
        },
      ),
    );
    return PedidoModalidade.fromJson((d['pedido'] as Map).cast<String, dynamic>());
  }

  /// `DELETE /me/modalidades/{id}` — desistir, enquanto está por decidir.
  Future<PedidoModalidade> cancelar(String id) async {
    final d = await dadosDe(_dio.delete('/me/modalidades/${Uri.encodeComponent(id)}'));
    return PedidoModalidade.fromJson((d['pedido'] as Map).cast<String, dynamic>());
  }
}

final accoesModalidadesProvider = Provider<AccoesModalidades>((ref) => AccoesModalidades(ref.watch(dioContaProvider)));

/// O máximo de `observacoes` que o servidor guarda.
const maxObservacoes = 500;
