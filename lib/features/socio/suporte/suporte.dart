import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const Conversa({
    required this.id,
    required this.fechada,
    required this.ultimaMensagem,
    required this.ultimaDoClube,
    required this.naoLidas,
    this.ultimaEm,
    this.criadaEm,
  });

  factory Conversa.fromJson(Map<String, dynamic> j) => Conversa(
    id: j['id'] as int,
    fechada: j['fechada'] == true,
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

  /// Não precisa do token.
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
}

const tamanhoMaximoMensagem = 4000;

final conversasProvider = StreamProvider.autoDispose<Dados<List<Conversa>>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioSocioProvider);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'suporte.${sessao.socio.nrSocio}',
    pedido: () => dadosDe(dio.get('/suporte')),
    ler: (j) => [for (final c in j['conversas'] as List) Conversa.fromJson((c as Map).cast<String, dynamic>())],
  );
});

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
