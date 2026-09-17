import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/rede/ligacao.dart';

/// Um sócio a cargo do sócio da sessão (guia §2.3.4). As ligações são criadas
/// pela secretaria; a app só as lê.
class Dependente {
  final int nrSocio, estado;
  final String nomeCompleto, estadoLabel, relacaoLabel;
  final String? fotoUrl;
  final int? idade;

  /// `false` = só consulta: esconder os botões de pagar.
  final bool podePagar;
  final bool temModalidade, temCartao;
  final double dividaTotal;

  const Dependente({
    required this.nrSocio,
    required this.estado,
    required this.nomeCompleto,
    required this.estadoLabel,
    required this.relacaoLabel,
    required this.podePagar,
    required this.temModalidade,
    required this.temCartao,
    required this.dividaTotal,
    this.fotoUrl,
    this.idade,
  });

  factory Dependente.fromJson(Map<String, dynamic> j) => Dependente(
    nrSocio: j['nr_socio'] as int,
    estado: j['estado'] as int,
    nomeCompleto: j['nome_completo'] as String,
    estadoLabel: j['estado_label'] as String,
    // `relacao` é uma lista aberta; o label vem pronto do servidor.
    relacaoLabel: (j['relacao_label'] ?? j['relacao'] ?? '') as String,
    podePagar: j['pode_pagar'] as bool,
    temModalidade: j['tem_modalidade'] as bool,
    temCartao: j['tem_cartao'] as bool,
    dividaTotal: ((j['divida'] as Map?)?['total'] as num? ?? 0).toDouble(),
    fotoUrl: j['foto_url'] as String?,
    idade: j['idade'] as int?,
  );

  String get primeiroNome {
    final p = nomeCompleto.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1);
  }
}

/// `GET /me/dependentes` — sempre da conta da sessão, nunca com `X-Socio`.
final dependentesProvider = StreamProvider.autoDispose<Dados<List<Dependente>>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider);
  // Lido já: o pedido corre depois de um await, quando o provider pode ter sido descartado.
  final dio = ref.read(dioSocioProvider);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'dependentes.${sessao.socio.nrSocio}',
    pedido: () => dadosDe(dio.get('/me/dependentes')),
    ler: (j) => [for (final d in j['dependentes'] as List) Dependente.fromJson((d as Map).cast<String, dynamic>())],
  );
});

/// De quem é a conta que se está a ver: `null` = a do próprio sócio.
///
/// Só em memória (guia §2.3.4): a ligação pode ser removida pela secretaria a
/// qualquer momento, por isso não se guarda como credencial nem entre arranques.
final contaActivaProvider = NotifierProvider<ContaActivaController, int?>(ContaActivaController.new);

class ContaActivaController extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(sessaoProvider); // outra sessão, ou saída: volta à conta própria
    return null;
  }

  void escolher(int? nrSocio) {
    final sessao = ref.read(sessaoProvider);
    state = sessao is SessaoSocio && nrSocio == sessao.socio.nrSocio ? null : nrSocio;
  }

  /// `403 socio_nao_associado`: a secretaria removeu a ligação. Volta à conta
  /// própria e recarrega a lista, como pede o guia.
  void ligacaoRemovida() {
    state = null;
    ref.invalidate(dependentesProvider);
  }
}

/// O dependente activo, se houver e se ainda constar da lista.
final dependenteActivoProvider = Provider.autoDispose<Dependente?>((ref) {
  final nr = ref.watch(contaActivaProvider);
  if (nr == null) return null;
  final lista = ref.watch(dependentesProvider).valueOrNull?.valor ?? const [];
  for (final d in lista) {
    if (d.nrSocio == nr) return d;
  }
  return null;
});

/// Pedidos à conta que se está a ver, com `X-Socio` quando é a de um dependente.
///
/// Criado no corpo do provider (com `ref.watch(contaActivaProvider)`), não dentro
/// do pedido: o pedido corre depois de awaits, quando o provider já pode ter sido
/// descartado.
class PedidosNaConta {
  PedidosNaConta(Ref ref)
    : _dio = ref.read(dioSocioProvider),
      _nr = ref.watch(contaActivaProvider),
      _conta = ref.read(contaActivaProvider.notifier);

  final Dio _dio;
  final int? _nr;
  final ContaActivaController _conta;

  /// Parte da chave de cache: cada conta tem a sua.
  String get chave => _nr?.toString() ?? 'proprio';

  Options? get _opcoes => _nr == null ? null : Options(headers: {'X-Socio': '$_nr'});

  Future<Map<String, dynamic>> get(String caminho, {Map<String, dynamic>? query}) =>
      _tratar(_dio.get(caminho, queryParameters: query, options: _opcoes));

  Future<Map<String, dynamic>> post(String caminho, Map<String, dynamic> corpo) =>
      _tratar(_dio.post(caminho, data: corpo, options: _opcoes));

  /// Corpo em JSON: um DELETE form-encoded não é lido pelo servidor (guia §7).
  Future<Map<String, dynamic>> delete(String caminho) =>
      _tratar(_dio.delete(caminho, data: const {}, options: _opcoes));

  /// Descarrega um ficheiro (ex.: PDF). Com o mesmo `Authorization` dos outros
  /// pedidos — por isso não se abre o URL num browser (guia §4.9).
  Future<List<int>> bytes(String caminho) async {
    try {
      final r = await _dio.get<List<int>>(
        caminho,
        options: (_opcoes ?? Options()).copyWith(responseType: ResponseType.bytes),
      );
      return r.data ?? const [];
    } on DioException catch (e) {
      // O erro vem em JSON, mas chega como bytes.
      final dados = e.response?.data;
      if (dados is List<int>) {
        try {
          final j = jsonDecode(utf8.decode(dados));
          if (j is Map && j['erro'] is String) {
            final erro = ApiException(
              httpStatus: e.response?.statusCode,
              erro: j['erro'] as String,
              message: (j['message'] as String?) ?? 'Ocorreu um erro.',
            );
            if (_nr != null && erro.erro == 'socio_nao_associado') _conta.ligacaoRemovida();
            throw erro;
          }
        } on FormatException {
          // não era JSON
        }
      }
      throw ApiException.deDio(e);
    }
  }

  Future<Map<String, dynamic>> _tratar(Future<Response<dynamic>> pedido) async {
    try {
      return await dadosDe(pedido);
    } on ApiException catch (e) {
      if (_nr != null && e.erro == 'socio_nao_associado') _conta.ligacaoRemovida();
      rethrow;
    }
  }
}
