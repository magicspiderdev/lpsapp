import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/formatos.dart';
import '../../../core/rede/ligacao.dart';

/// Conversa com a secretaria (guia §4.14). As mesmas do portal e do backoffice.
///
/// O suporte é da conta da app: nunca leva `X-Socio`, mesmo a ver a conta de um
/// dependente.
class Conversa {
  final int id;

  /// A secretaria fechou-a: enviar dá `409 conversa_fechada`.
  final bool fechada;
  final String ultimaMensagem;
  final DateTime? ultimaEm, criadaEm;
  final bool ultimaDoClube;
  final int naoLidas;

  /// Arquivada pelo sócio — só para ele: a secretaria vê-a igual. Vale em todos
  /// os aparelhos, e uma mensagem nova tira-a do arquivo no servidor.
  final bool arquivada;

  const Conversa({
    required this.id,
    required this.fechada,
    this.arquivada = false,
    required this.ultimaMensagem,
    required this.ultimaDoClube,
    required this.naoLidas,
    this.ultimaEm,
    this.criadaEm,
  });

  factory Conversa.fromJson(Map<String, dynamic> j) => Conversa(
    id: j['id'] as int,
    fechada: j['fechada'] == true,
    arquivada: j['arquivada'] == true,
    ultimaMensagem: (j['ultima_mensagem'] ?? '') as String,
    ultimaDoClube: j['ultima_do_clube'] == true,
    naoLidas: (j['nao_lidas'] as int?) ?? 0,
    ultimaEm: dataApi(j['ultima_em']),
    criadaEm: dataApi(j['criada_em']),
  );
}

enum TipoAnexo { imagem, pdf, outro }

class Mensagem {
  final int id;

  /// Texto simples (a API já descodifica entidades). Pode vir vazio só com anexo.
  final String texto;

  /// `true` = secretaria; `false` = o sócio.
  final bool doClube;

  /// Não precisa do token. `null` com [anexoTipo] preenchido é um anexo antigo
  /// que não foi trazido do servidor anterior ([anexoIndisponivel]).
  final String? anexoUrl;
  final TipoAnexo? anexoTipo;
  final DateTime? enviadaEm;

  const Mensagem({
    required this.id,
    required this.texto,
    required this.doClube,
    this.anexoUrl,
    this.anexoTipo,
    this.enviadaEm,
  });

  factory Mensagem.fromJson(Map<String, dynamic> j) => Mensagem(
    id: j['id'] as int,
    texto: (j['texto'] ?? '') as String,
    doClube: j['do_clube'] == true,
    anexoUrl: j['anexo_url'] as String?,
    anexoTipo: switch (j['anexo_tipo']) {
      null => null,
      'imagem' => TipoAnexo.imagem,
      'pdf' => TipoAnexo.pdf,
      _ => TipoAnexo.outro,
    },
    enviadaEm: dataApi(j['enviada_em']),
  );

  bool get temAnexo => anexoUrl != null || anexoTipo != null;

  /// Havia um ficheiro, mas ficou no servidor da app anterior: mostra-se que
  /// existiu, sem se poder abrir.
  bool get anexoIndisponivel => anexoUrl == null && anexoTipo != null;
}

const tamanhoMaximoMensagem = 4000;

/// Conversas por arquivar (`GET /suporte` não traz as arquivadas).
final conversasProvider = StreamProvider.autoDispose<Dados<List<Conversa>>>(
  (ref) => _listaConversas(ref, arquivadas: false),
);

/// Só as arquivadas (`GET /suporte?arquivadas=1`).
final conversasArquivadasProvider = StreamProvider.autoDispose<Dados<List<Conversa>>>(
  (ref) => _listaConversas(ref, arquivadas: true),
);

Stream<Dados<List<Conversa>>> _listaConversas(Ref ref, {required bool arquivadas}) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioSocioProvider);
  final migracao = ref.read(migracaoArquivoProvider);
  final nr = sessao.socio.nrSocio;

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: arquivadas ? 'suporte.$nr.arquivadas' : 'suporte.$nr',
    pedido: () async {
      // O arquivo antigo, deste aparelho, passa primeiro para o servidor.
      await migracao?.garantir();
      return dadosDe(dio.get('/suporte', queryParameters: {if (arquivadas) 'arquivadas': 1}));
    },
    ler: (j) => [for (final c in j['conversas'] as List) Conversa.fromJson((c as Map).cast<String, dynamic>())],
  );
}

/// Abrir marca como lidas as mensagens da secretaria (é o que baixa o contador
/// de `/me/resumo`).
final mensagensProvider = StreamProvider.autoDispose.family<Dados<List<Mensagem>>, int>((ref, id) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioSocioProvider);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'suporte.${sessao.socio.nrSocio}.$id',
    pedido: () => dadosDe(dio.get('/suporte/$id')),
    ler: (j) => [for (final m in j['mensagens'] as List) Mensagem.fromJson((m as Map).cast<String, dynamic>())],
  );
});

/// Acções do chat. Texto tal como o sócio escreveu: sem HTML nem escapes.
extension AccoesSuporte on Dio {
  /// Abre uma conversa e devolve o id.
  Future<int> criarConversa(String texto) async =>
      (await dadosDe(post('/suporte', data: {'mensagem': texto})))['id_conversa'] as int;

  Future<void> responder(int conversa, String texto) => dadosDe(post('/suporte/$conversa', data: {'mensagem': texto}));

  /// Só para o sócio: não fecha nem marca como lida.
  Future<void> arquivarConversa(int conversa) => dadosDe(post('/suporte/$conversa/arquivar'));

  Future<void> desarquivarConversa(int conversa) => dadosDe(post('/suporte/$conversa/desarquivar'));

  /// JPEG, PNG ou PDF até 10 MB, com texto opcional.
  Future<void> enviarAnexo(int conversa, String caminho, {String? nome, String? texto}) async {
    await dadosDe(
      post(
        '/suporte/$conversa/anexo',
        data: FormData.fromMap({
          'ficheiro': await MultipartFile.fromFile(caminho, filename: nome),
          if (texto != null && texto.isNotEmpty) 'mensagem': texto,
        }),
      ),
    );
  }
}

/// Arquivar ou desarquivar à espera do servidor ([confirmadoEm] `null`), ou já
/// feito mas talvez ainda não visto numa lista acabada de pedir.
///
/// Classe e não record: distinguem-se pela identidade (qual acção é a última).
class ArquivoPendente {
  const ArquivoPendente(this.conversa, {required this.arquivada, this.confirmadoEm});

  final Conversa conversa;
  final bool arquivada;
  final DateTime? confirmadoEm;
}

/// O arquivo é do servidor (`POST /suporte/{id}/arquivar` e `/desarquivar`).
/// Isto guarda só a mudança optimista: a conversa muda de lista logo ao
/// deslizar e volta se o servidor recusar (a acção relança o erro, para o ecrã
/// avisar).
final arquivoConversasProvider = NotifierProvider<ArquivoConversas, Map<int, ArquivoPendente>>(ArquivoConversas.new);

class ArquivoConversas extends Notifier<Map<int, ArquivoPendente>> {
  @override
  Map<int, ArquivoPendente> build() {
    ref.watch(sessaoProvider);
    return const {};
  }

  Future<void> arquivar(Conversa c) => _mudar(c, arquivada: true);

  Future<void> desarquivar(Conversa c) => _mudar(c, arquivada: false);

  Future<void> _mudar(Conversa c, {required bool arquivada}) async {
    // Sem const: cada acção tem de ser um objecto novo.
    final pendente = ArquivoPendente(c, arquivada: arquivada);
    state = {...state, c.id: pendente};
    final dio = ref.read(dioSocioProvider);
    try {
      await (arquivada ? dio.arquivarConversa(c.id) : dio.desarquivarConversa(c.id));
    } on ApiException {
      // Só se desfaz o que ainda é nosso: um "Desfazer" entretanto prevalece.
      if (identical(state[c.id], pendente)) state = {...state}..remove(c.id);
      rethrow;
    }
    if (identical(state[c.id], pendente)) {
      state = {...state, c.id: ArquivoPendente(c, arquivada: arquivada, confirmadoEm: DateTime.now())};
    }
    ref
      ..invalidate(conversasProvider)
      ..invalidate(conversasArquivadasProvider);
  }
}

/// As duas listas do servidor, com o que se arquivou ou desarquivou entretanto.
///
/// Uma mudança conta enquanto não estiver confirmada, ou enquanto a lista for
/// anterior à confirmação (a da cache, por exemplo). Uma lista pedida depois já
/// a traz — e manda ela, que o servidor pode ter desarquivado por mensagem nova.
({List<Conversa> activas, List<Conversa> arquivadas}) listasDeConversas({
  required Dados<List<Conversa>>? activas,
  required Dados<List<Conversa>>? arquivadas,
  required Map<int, ArquivoPendente> pendentes,
}) => (
  activas: _comPendentes(activas, pendentes, arquivadas: false),
  arquivadas: _comPendentes(arquivadas, pendentes, arquivadas: true),
);

List<Conversa> _comPendentes(
  Dados<List<Conversa>>? d,
  Map<int, ArquivoPendente> pendentes, {
  required bool arquivadas,
}) {
  final contam = [
    for (final p in pendentes.values)
      if (p.confirmadoEm == null || d == null || d.obtidoEm.isBefore(p.confirmadoEm!)) p,
  ];
  final fora = {
    for (final p in contam)
      if (p.arquivada != arquivadas) p.conversa.id,
  };
  final lista = [
    for (final c in d?.valor ?? const <Conversa>[])
      if (!fora.contains(c.id)) c,
  ];
  final ids = {for (final c in lista) c.id};
  final entram = [
    for (final p in contam)
      if (p.arquivada == arquivadas && !ids.contains(p.conversa.id)) p.conversa,
  ];
  if (entram.isEmpty) return lista;
  // Mais recente primeiro, como vêm da API.
  final epoca = DateTime.fromMillisecondsSinceEpoch(0);
  return [...lista, ...entram]..sort((a, b) => (b.ultimaEm ?? epoca).compareTo(a.ultimaEm ?? epoca));
}

/// Passa para o servidor o arquivo que a app guardava **neste aparelho** antes
/// de a API o ter (na cache da sessão, em `suporte.arquivo.<nr>`: id →
/// `ultima_em` quando se arquivou).
///
/// Na primeira vez que há rede arquiva no servidor as que ainda vêm em
/// `GET /suporte` e não tiveram nada de novo desde então, e esvazia o arquivo
/// local, para não se repetir. Sem rede fica para o pedido seguinte.
final migracaoArquivoProvider = Provider<MigracaoArquivoLocal?>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) return null;
  return MigracaoArquivoLocal(
    dio: ref.read(dioSocioProvider),
    cache: ref.read(cacheProvider),
    chave: 'suporte.arquivo.${sessao.socio.nrSocio}',
  );
});

class MigracaoArquivoLocal {
  MigracaoArquivoLocal({required this.dio, required this.cache, required this.chave});

  final Dio dio;
  final CacheLocal cache;
  final String chave;

  bool _feita = false;
  Future<bool>? _emCurso;

  /// Nunca falha: o que não se conseguir agora tenta-se no pedido seguinte.
  Future<void> garantir() async {
    if (_feita) return;
    // As duas listas pedem ao mesmo tempo: esperam pela mesma migração.
    final emCurso = _emCurso ??= _migrar();
    try {
      _feita = await emCurso;
    } finally {
      _emCurso = null;
    }
  }

  Future<bool> _migrar() async {
    final e = await cache.ler(Ambito.sessao, chave);
    final arquivo = {
      for (final MapEntry(:key, :value) in (e?.dados ?? const <String, dynamic>{}).entries)
        ?int.tryParse(key): value is String ? DateTime.tryParse(value) : null,
    };
    if (arquivo.isEmpty) return true;

    try {
      final j = await dadosDe(dio.get('/suporte'));
      final conversas = [for (final c in j['conversas'] as List) Conversa.fromJson((c as Map).cast<String, dynamic>())];
      for (final c in conversas.where((c) => estaArquivada(c, arquivo))) {
        try {
          await dio.arquivarConversa(c.id);
        } on ApiException catch (erro) {
          if (falhaDeServico(erro)) rethrow;
          // Recusada (404, por exemplo): não há nada a guardar dela.
        }
      }
    } on ApiException {
      return false;
    }
    // A cache não apaga chaves: vazio quer dizer "já migrado".
    await cache.guardar(Ambito.sessao, chave, const {});
    return true;
  }
}

/// Regra do arquivo local antigo: arquivada e sem nada de novo desde então (uma
/// mensagem nova tirava-a do arquivo). Só serve à migração.
bool estaArquivada(Conversa c, Map<int, DateTime?> arquivo) {
  if (!arquivo.containsKey(c.id)) return false;
  final quando = arquivo[c.id];
  final ultima = c.ultimaEm;
  return quando == null || ultima == null || !ultima.isAfter(quando);
}
