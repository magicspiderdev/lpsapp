import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/formatos.dart';
import '../../../core/rede/ligacao.dart';
import '../conta/contas.dart';

/// Documento de um processo de inscrição (guia §4.9).
class Documento {
  final int idInscricao;

  /// `ficha_inscricao`, `ficha_socio`, `termo_responsabilidade` — lista aberta.
  final String tipo, titulo;
  final DateTime? assinadoEm;
  final String? assinanteNome;

  /// `false` = registado mas ainda sem PDF gerado.
  final bool disponivel;

  const Documento({
    required this.idInscricao,
    required this.tipo,
    required this.titulo,
    required this.disponivel,
    this.assinadoEm,
    this.assinanteNome,
  });

  /// O caminho relativo à API, em vez de `download_url`: esse vem com o
  /// endereço do servidor tal como ele se vê, que pode não ser o que a app usa.
  String get caminho => '/documentos/$idInscricao/$tipo';
}

class Inscricao {
  final int id;
  final String? modalidade, epoca, estado;
  final DateTime? criadaEm;
  final List<Documento> documentos;

  const Inscricao({
    required this.id,
    required this.documentos,
    this.modalidade,
    this.epoca,
    this.estado,
    this.criadaEm,
  });

  factory Inscricao.fromJson(Map<String, dynamic> j) {
    final id = j['id_inscricao'] as int;
    return Inscricao(
      id: id,
      modalidade: j['modalidade'] as String?,
      epoca: j['epoca'] as String?,
      estado: j['estado'] as String?,
      criadaEm: dataApi(j['criada_em']),
      documentos: [
        for (final d in (j['documentos'] as List?) ?? const [])
          if (d is Map)
            Documento(
              idInscricao: id,
              tipo: (d['tipo'] ?? '') as String,
              titulo: (d['titulo'] ?? d['tipo'] ?? 'Documento') as String,
              disponivel: d['disponivel'] == true,
              assinadoEm: dataApi(d['assinado_em']),
              assinanteNome: d['assinante_nome'] as String?,
            ),
      ],
    );
  }
}

final documentosProvider = StreamProvider.autoDispose<Dados<List<Inscricao>>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (!temZonaPrivada(sessao)) throw StateError('Sem zona privada');
  ref.watch(ligacaoProvider);
  final conta = PedidosNaConta(ref);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'documentos.${chaveDaSessao(sessao)}.${conta.chave}',
    pedido: () => conta.get('/documentos'),
    ler: (j) => [for (final i in j['inscricoes'] as List) Inscricao.fromJson((i as Map).cast<String, dynamic>())],
  );
});

/// Pasta dos PDFs descarregados. Fica na cache temporária da app e apaga-se
/// quando a sessão acaba (ver [CacheEmDisco.limparSessao]).
Future<Directory> pastaDocumentos() async => Directory('${(await getTemporaryDirectory()).path}/documentos');

/// Devolve o PDF em disco: o já descarregado, ou descarrega-o agora.
///
/// Com `actualizar`, tenta sempre a versão do servidor e só usa a guardada se
/// não houver ligação — um documento pode ser reassinado.
Future<File> obterDocumento(PedidosNaConta conta, Documento d, {bool actualizar = true}) async {
  final pasta = await pastaDocumentos();
  await pasta.create(recursive: true);
  final ficheiro = File('${pasta.path}/${conta.chave}_${d.idInscricao}_${d.tipo}.pdf');

  if (!actualizar && await ficheiro.exists()) return ficheiro;
  try {
    final bytes = await conta.bytes(d.caminho);
    await ficheiro.writeAsBytes(bytes, flush: true);
    return ficheiro;
  } catch (_) {
    if (await ficheiro.exists()) return ficheiro;
    rethrow;
  }
}
