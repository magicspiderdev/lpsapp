import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/clientes.dart';
import '../../core/api/envelope.dart';
import '../../core/auth/sessao.dart';
import '../../core/cache/cache_local.dart';
import '../../core/cache/com_cache.dart';
import '../../core/formatos.dart';
import '../../core/rede/ligacao.dart';
import '../publico/bilheteira/bilheteira.dart' show SemSessao;
import '../socio/conta/contas.dart' show dependentesProvider;
import '../socio/documentos/documentos.dart' show pastaDocumentos;

/// Inscrever-se como sócio pela conta v2 (guia §4.21).
///
/// Quatro passos, por esta ordem: **dados → o clube decide → assinar →
/// pagar**. A app não sabe a ordem de cor: cada inscrição traz o
/// `proximo_passo`, e é ele que escolhe o ecrã. Submeter não cria sócio
/// nenhum — cria um pedido; o sócio nasce sozinho quando o pagamento entra.

// ── Modelos ────────────────────────────────────────────────────────────────

/// O que falta fazer, do lado de quem se inscreveu. Vem do servidor por
/// extenso (`proximo_passo`); o que não se conhece fica [desconhecido] e o
/// ecrã mostra só o `estado_label`, sem botões.
enum PassoInscricao {
  /// Está do lado do clube.
  aguardar,

  /// Admitida: assinar os documentos de `por_assinar`.
  assinar,

  /// Assinada: pagar as primeiras quotas.
  pagar,

  /// Acabou — concluída, recusada ou cancelada.
  nada,

  /// Um passo que esta versão da app não conhece.
  desconhecido,
}

PassoInscricao passoDe(Object? proximoPasso) => switch (proximoPasso) {
  'aguardar' => PassoInscricao.aguardar,
  'assinar' => PassoInscricao.assinar,
  'pagar' => PassoInscricao.pagar,
  'nada' => PassoInscricao.nada,
  _ => PassoInscricao.desconhecido,
};

/// Um documento a assinar (`ficha_socio`, `termo_responsabilidade` — lista aberta).
class DocumentoInscricao {
  final String tipo, nome;
  final bool assinado;
  final DateTime? assinadoEm;

  /// Quem assinou. Num menor, o encarregado de educação.
  final String? assinante;

  const DocumentoInscricao({
    required this.tipo,
    required this.nome,
    required this.assinado,
    this.assinadoEm,
    this.assinante,
  });

  factory DocumentoInscricao.fromJson(Map<String, dynamic> j) => DocumentoInscricao(
    tipo: (j['tipo'] ?? '') as String,
    nome: (j['nome'] ?? j['tipo'] ?? 'Documento') as String,
    assinado: j['assinado'] == true,
    assinadoEm: dataApi(j['assinado_em']),
    assinante: j['assinante'] as String?,
  );
}

/// As primeiras quotas. **`firme: false` quer dizer estimativa**: antes da
/// admissão o valor sai do escalão da idade, e é o clube que o confirma.
class QuotasInscricao {
  final int meses, minimoMeses, maximoMeses;
  final double valor;
  final double? valorMes;
  final bool firme;
  final DateTime? pagoEm;

  const QuotasInscricao({
    required this.meses,
    required this.valor,
    required this.firme,
    required this.minimoMeses,
    required this.maximoMeses,
    this.valorMes,
    this.pagoEm,
  });

  factory QuotasInscricao.fromJson(Map<String, dynamic> j) {
    final minimo = (j['minimo_meses'] as num?)?.toInt() ?? 3;
    final maximo = (j['maximo_meses'] as num?)?.toInt() ?? 12;
    return QuotasInscricao(
      meses: (j['meses'] as num?)?.toInt() ?? minimo,
      valor: (j['valor'] as num?)?.toDouble() ?? 0,
      valorMes: (j['valor_mes'] as num?)?.toDouble(),
      firme: j['firme'] == true,
      minimoMeses: minimo,
      // Um máximo abaixo do mínimo deixava o contador sem escolha possível.
      maximoMeses: maximo < minimo ? minimo : maximo,
      pagoEm: dataApi(j['pago_em']),
    );
  }

  static const vazias = QuotasInscricao(meses: 3, valor: 0, firme: false, minimoMeses: 3, maximoMeses: 12);
}

/// Uma inscrição de sócio, tal como `GET /me/inscricoes/{id}` a devolve.
class InscricaoSocio {
  final String id;

  /// `submetida` → `admitida` → `assinada` → `concluida`; `recusada` e
  /// `cancelada` são saídas. **Lista aberta**: nunca decidir só por aqui.
  final String estado;
  final String estadoLabel;

  /// `propria` ou `dependente`.
  final String para;
  final String nome;
  final DateTime? dataNascimento;
  final bool menor;

  /// O número **reservado** na admissão — ainda não há sócio, há a certeza de
  /// qual será o número. É o que vai impresso na ficha a assinar.
  final int? nrSocio;
  final DateTime? admitidaEm;
  final List<DocumentoInscricao> documentos;
  final List<String> porAssinar;
  final QuotasInscricao quotas;
  final PassoInscricao passo;

  /// Porque foi recusada, escrito pela secretaria.
  final String? motivo;
  final DateTime? criadoEm;

  /// O pedido de pagamento ainda por pagar (`PENDENTE` e dentro do `limite`),
  /// com a forma da resposta do `POST …/pagamento`; `null` em todos os outros
  /// casos (§4.21, desde 2026-09-26). Quem volta à inscrição vê-o em vez de
  /// pedir outro.
  final PagamentoInscricao? pagamento;

  const InscricaoSocio({
    required this.id,
    required this.estado,
    required this.estadoLabel,
    required this.para,
    required this.nome,
    required this.passo,
    this.dataNascimento,
    this.menor = false,
    this.nrSocio,
    this.admitidaEm,
    this.documentos = const [],
    this.porAssinar = const [],
    this.quotas = QuotasInscricao.vazias,
    this.motivo,
    this.criadoEm,
    this.pagamento,
  });

  factory InscricaoSocio.fromJson(Map<String, dynamic> j) => InscricaoSocio(
    id: '${j['id']}',
    estado: (j['estado'] ?? '') as String,
    estadoLabel: (j['estado_label'] ?? j['estado'] ?? '') as String,
    para: (j['para'] ?? 'propria') as String,
    nome: (j['nome'] ?? '') as String,
    dataNascimento: dataApi(j['data_nascimento']),
    menor: j['menor'] == true,
    nrSocio: (j['nr_socio'] as num?)?.toInt(),
    admitidaEm: dataApi(j['admitida_em']),
    documentos: [
      for (final d in (j['documentos'] as List?) ?? const [])
        if (d is Map) DocumentoInscricao.fromJson(d.cast<String, dynamic>()),
    ],
    porAssinar: [
      for (final t in (j['por_assinar'] as List?) ?? const [])
        if (t is String) t,
    ],
    quotas: j['quotas'] is Map
        ? QuotasInscricao.fromJson((j['quotas'] as Map).cast<String, dynamic>())
        : QuotasInscricao.vazias,
    passo: passoDe(j['proximo_passo']),
    motivo: switch (j['motivo']) {
      final String m when m.trim().isNotEmpty => m,
      _ => null,
    },
    criadoEm: dataApi(j['criado_em']),
    pagamento: switch (j['pagamento']) {
      final Map<dynamic, dynamic> p => PagamentoInscricao.fromJson(p.cast<String, dynamic>()),
      _ => null,
    },
  );

  bool get paraDependente => para == 'dependente';
  bool get concluida => estado == 'concluida';
  bool get recusada => estado == 'recusada';
  bool get cancelada => estado == 'cancelada';

  /// O documento a assinar agora: um de cada vez, pela ordem de `por_assinar`.
  DocumentoInscricao? get proximoDocumento {
    final tipo = porAssinar.firstOrNull;
    if (tipo == null) return null;
    return documentos.where((d) => d.tipo == tipo).firstOrNull ??
        DocumentoInscricao(tipo: tipo, nome: _nomeDoTipo(tipo), assinado: false);
  }

  List<DocumentoInscricao> get assinados => [
    for (final d in documentos)
      if (d.assinado) d,
  ];

  /// Desistir só antes de assinar (§4.21): depois há um compromisso escrito, e
  /// quem desiste fala com a secretaria. O servidor tem a palavra final.
  bool get podeDesistir => (passo == PassoInscricao.aguardar || passo == PassoInscricao.assinar) && assinados.isEmpty;

  static String _nomeDoTipo(String tipo) => switch (tipo) {
    'ficha_socio' => 'Ficha de Sócio',
    'termo_responsabilidade' => 'Termo de Responsabilidade',
    _ => 'Documento',
  };
}

/// O formulário do primeiro passo. Só o que o contrato pede — e os campos do
/// encarregado só quando é para um dependente. **A app não calcula idades**:
/// quem tem menos de 18 anos como `propria` recebe `422` do servidor, com a
/// razão escrita.
class DadosInscricao {
  final bool dependente;
  final String nome;
  final DateTime dataNascimento;
  final String? nif, cc, morada, cp, localidade, email, telefone;
  final String? encNome, encParentesco, encCc, encTelefone, encEmail;

  const DadosInscricao({
    required this.dependente,
    required this.nome,
    required this.dataNascimento,
    this.nif,
    this.cc,
    this.morada,
    this.cp,
    this.localidade,
    this.email,
    this.telefone,
    this.encNome,
    this.encParentesco,
    this.encCc,
    this.encTelefone,
    this.encEmail,
  });

  Map<String, dynamic> toJson() => {
    'para': dependente ? 'dependente' : 'propria',
    'nome': nome.trim(),
    'data_nascimento': _dia(dataNascimento),
    'nif': ?_limpo(nif),
    'cc': ?_limpo(cc),
    'morada': ?_limpo(morada),
    'cp': ?_limpo(cp),
    'localidade': ?_limpo(localidade),
    'email': ?_limpo(email),
    'telefone': ?_limpo(telefone),
    // O encarregado só vai quando é para um dependente: numa inscrição
    // própria os campos nem aparecem no ecrã.
    if (dependente) ...{
      'enc_nome': ?_limpo(encNome),
      'enc_parentesco': ?_limpo(encParentesco),
      'enc_cc': ?_limpo(encCc),
      'enc_telefone': ?_limpo(encTelefone),
      'enc_email': ?_limpo(encEmail),
    },
  };

  static String? _limpo(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// O pedido de pagamento das primeiras quotas. **Não é pago**: o `201` só diz
/// que o pedido existe. O `metodo` que vale é este — um MB WAY que falhe cai
/// para PayByLink.
class PagamentoInscricao {
  final int? referencia;
  final String metodo;
  final double valor;
  final int meses;
  final String? urlPagamento, telefone;
  final DateTime? limite;

  const PagamentoInscricao({
    required this.metodo,
    required this.valor,
    required this.meses,
    this.referencia,
    this.urlPagamento,
    this.telefone,
    this.limite,
  });

  factory PagamentoInscricao.fromJson(Map<String, dynamic> j) => PagamentoInscricao(
    referencia: (j['referencia'] as num?)?.toInt(),
    metodo: (j['metodo'] ?? '') as String,
    valor: (j['valor'] as num?)?.toDouble() ?? 0,
    meses: (j['meses'] as num?)?.toInt() ?? 0,
    urlPagamento: switch (j['url_pagamento']) {
      final String u when u.isNotEmpty => u,
      _ => null,
    },
    telefone: j['telefone'] as String?,
    limite: dataApi(j['limite']),
  );

  bool get mbway => metodo == 'mbway';
  bool get temLink => urlPagamento != null;

  String get metodoLegivel => switch (metodo) {
    'mbway' => 'MB WAY',
    'paybylink' => 'Multibanco / link',
    _ => metodo,
  };
}

/// `409 ja_existe` ao submeter: já há uma inscrição a meio para esta pessoa.
/// Devolve o id dela, para a abrir em vez de recomeçar.
///
/// Vem em `id` (desde 2026-09-26, com o `estado` ao lado); `inscricao`, com o
/// mesmo valor, fica para quem o lia antes — aceitam-se os dois.
String? inscricaoExistente(ApiException e) {
  if (e.erro != 'ja_existe') return null;
  return switch ((e.dados['id'], e.dados['inscricao'])) {
    (final String id, _) when id.isNotEmpty => id,
    (_, final String id) when id.isNotEmpty => id,
    (_, final Map m) when m['id'] is String => m['id'] as String,
    _ => null,
  };
}

// ── Pedidos ────────────────────────────────────────────────────────────────

/// As chamadas da inscrição, em `/api/v2` com o token da conta. Nenhuma
/// escrita se repete sozinha e nenhuma vai com dados da cache.
class Inscricoes {
  const Inscricoes(this._dio);

  final Dio _dio;

  Future<List<InscricaoSocio>> listar() async => _lista(await dadosDe(_dio.get('/me/inscricoes')));

  Future<InscricaoSocio> obter(String id) async => _uma(await dadosDe(_dio.get('/me/inscricoes/$id')));

  /// Lança [ApiException]; com `ja_existe`, ver [inscricaoExistente].
  Future<InscricaoSocio> submeter(DadosInscricao dados) async =>
      _uma(await dadosDe(_dio.post('/me/inscricoes', data: dados.toJson())));

  /// Assina [documento] com a imagem desenhada no ecrã. Sem `assinante_nome`:
  /// o servidor põe o de quem se inscreve, ou o do encarregado num menor.
  Future<InscricaoSocio> assinar(String id, {required String documento, required Uint8List png}) async => _uma(
    await dadosDe(
      _dio.post('/me/inscricoes/$id/assinar', data: {'documento': documento, 'assinatura': dataUriPng(png)}),
    ),
  );

  /// Pede o pagamento. Não se envia valor nenhum: o que conta é o da resposta.
  Future<(PagamentoInscricao, InscricaoSocio)> pagar(
    String id, {
    required int meses,
    required String metodo,
    String? telefone,
  }) async {
    final d = await dadosDe(
      _dio.post(
        '/me/inscricoes/$id/pagamento',
        data: {'meses': meses, 'metodo': metodo, if (metodo == 'mbway' && telefone != null) 'telefone': telefone},
      ),
    );
    return (PagamentoInscricao.fromJson(((d['pagamento'] as Map?) ?? const {}).cast<String, dynamic>()), _uma(d));
  }

  Future<InscricaoSocio> desistir(String id) async => _uma(await dadosDe(_dio.delete('/me/inscricoes/$id')));

  /// O PDF assinado, em bytes. Com o mesmo `Authorization` dos outros pedidos
  /// — por isso não se abre o endereço num browser.
  Future<Uint8List> pdf(String id, String tipo) async {
    try {
      final r = await _dio.get<List<int>>(
        '/me/inscricoes/$id/documentos/$tipo',
        options: Options(responseType: ResponseType.bytes, headers: {'Accept': 'application/pdf'}),
      );
      return Uint8List.fromList(r.data ?? const []);
    } on DioException catch (e) {
      // O erro vem em JSON, mas chega como bytes.
      if (e.response?.data case final List<int> bytes) {
        try {
          final j = jsonDecode(utf8.decode(bytes));
          if (j is Map && j['erro'] is String) {
            throw ApiException(
              httpStatus: e.response?.statusCode,
              erro: j['erro'] as String,
              message: (j['message'] as String?) ?? 'Ocorreu um erro.',
            );
          }
        } on FormatException {
          // não era JSON
        }
      }
      throw ApiException.deDio(e);
    }
  }

  static InscricaoSocio _uma(Map<String, dynamic> d) =>
      InscricaoSocio.fromJson(((d['inscricao'] as Map?) ?? const {}).cast<String, dynamic>());

  static List<InscricaoSocio> _lista(Map<String, dynamic> d) => [
    for (final i in (d['inscricoes'] as List?) ?? const [])
      if (i is Map && i['id'] != null) InscricaoSocio.fromJson(i.cast<String, dynamic>()),
  ];
}

/// `data:image/png;base64,…` — a forma que `/assinar` aceita.
String dataUriPng(Uint8List png) => 'data:image/png;base64,${base64Encode(png)}';

/// Guarda o PDF na pasta dos documentos (a que se apaga com a sessão) e
/// devolve o ficheiro. Sempre a versão do servidor.
Future<File> guardarPdfInscricao(Inscricoes api, String id, String tipo) async {
  final bytes = await api.pdf(id, tipo);
  final pasta = await pastaDocumentos();
  await pasta.create(recursive: true);
  final ficheiro = File('${pasta.path}/inscricao_${id}_$tipo.pdf');
  await ficheiro.writeAsBytes(bytes, flush: true);
  return ficheiro;
}

final inscricoesApiProvider = Provider<Inscricoes>((ref) => Inscricoes(ref.read(dioContaProvider)));

/// `GET /me/inscricoes` — as minhas, da mais recente para a mais antiga. Com
/// cache da sessão: é só para mostrar em que ponto estão, nunca para pagar.
final minhasInscricoesProvider = StreamProvider.autoDispose<Dados<List<InscricaoSocio>>>((ref) {
  if (ref.watch(sessaoProvider.select((s) => s is SessaoAnonima))) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'inscricoes.socio',
    pedido: () => dadosDe(dio.get('/me/inscricoes')),
    ler: Inscricoes._lista,
  );
});

/// Uma inscrição, sempre do servidor — é ela que decide os botões, e não se
/// assina nem se paga com o que estava guardado. Cada escrita devolve a
/// inscrição inteira, que substitui a que se tinha.
final inscricaoProvider = AsyncNotifierProvider.autoDispose.family<InscricaoController, InscricaoSocio, String>(
  InscricaoController.new,
);

class InscricaoController extends AutoDisposeFamilyAsyncNotifier<InscricaoSocio, String> {
  /// O fim já foi tratado (sessão renovada, dependentes recarregados).
  bool _fimTratado = false;

  Inscricoes get _api => ref.read(inscricoesApiProvider);

  @override
  Future<InscricaoSocio> build(String id) async {
    // Só a entrada e a saída contam: um refresh que traga a conta nova não
    // tem de voltar a pedir a inscrição.
    if (ref.watch(sessaoProvider.select((s) => s is SessaoAnonima))) throw const SemSessao();
    final i = await _api.obter(id);
    _aoMudar(null, i);
    return i;
  }

  /// Volta a pedir sem passar pelo estado de carregamento: é o que o
  /// acompanhamento do pagamento faz de 5 em 5 segundos.
  Future<InscricaoSocio> actualizar() async {
    final i = await _api.obter(arg);
    _substituir(i);
    return i;
  }

  /// Recarrega depois de um `409 estado_invalido`: o servidor sabe melhor.
  void recarregar() => ref.invalidateSelf();

  Future<void> assinar(String documento, Uint8List png) async =>
      _substituir(await _api.assinar(arg, documento: documento, png: png));

  Future<PagamentoInscricao> pagar({required int meses, required String metodo, String? telefone}) async {
    final (pagamento, inscricao) = await _api.pagar(arg, meses: meses, metodo: metodo, telefone: telefone);
    _substituir(inscricao);
    return pagamento;
  }

  Future<void> desistir() async => _substituir(await _api.desistir(arg));

  void _substituir(InscricaoSocio i) {
    final antes = state.valueOrNull;
    state = AsyncData(i);
    ref.invalidate(minhasInscricoesProvider);
    _aoMudar(antes, i);
  }

  /// Uma inscrição que chega a `concluida` muda a conta:
  /// - `propria` — a conta fica ligada ao sócio novo. Renova-se a sessão para
  ///   ela trazer a ficha (o [SessaoController] muda de estado sozinho).
  /// - `dependente` — o menor passa a estar a cargo de quem o inscreveu
  ///   (§2.3.4), e a lista de dependentes muda.
  ///
  /// Também quando se abre uma que **já** estava concluída: o pagamento pode
  /// ter entrado com a app fechada. Só se renova se a conta ainda não tiver
  /// ficha — senão já foi feito.
  void _aoMudar(InscricaoSocio? antes, InscricaoSocio agora) {
    if (!agora.concluida || _fimTratado || antes?.concluida == true) return;
    _fimTratado = true;
    if (agora.paraDependente) {
      ref.invalidate(dependentesProvider);
    } else if (ref.read(sessaoProvider) is! SessaoConta) {
      return;
    }
    // A sessão traz a ficha nova, ou `conta.dependentes` com o menor e as
    // capacidades por ele (§2.12).
    // Nada disto pode estragar o ecrã: sem rede (ou sem refresh guardado),
    // fica para o próximo refresh, e a sessão chega lá sozinha.
    try {
      ref.read(tokenStoreProvider).renovar().catchError((Object _) {});
    } catch (_) {}
  }
}
