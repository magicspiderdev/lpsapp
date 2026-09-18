import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/formatos.dart';
import '../../../core/rede/ligacao.dart';

/// Uma notificação que o clube enviou (guia §4.16).
///
/// É o histórico do push: mostra o que foi enviado mesmo que a notificação não
/// tenha chegado ao aparelho (app fechada, permissões recusadas, telemóvel novo).
class Notificacao {
  final int id;
  final String titulo, texto;
  final String? imagemUrl;

  /// Enviada só a este sócio, em vez de a um tópico.
  final bool pessoal;

  /// `all`, `socios`, … — lista aberta, só serve para contexto.
  final String? topico;
  final DateTime? enviadaEm;

  const Notificacao({
    required this.id,
    required this.titulo,
    required this.texto,
    required this.pessoal,
    this.imagemUrl,
    this.topico,
    this.enviadaEm,
  });

  factory Notificacao.fromJson(Map<String, dynamic> j) => Notificacao(
    id: j['id'] as int,
    titulo: (j['titulo'] ?? '') as String,
    // Texto simples com quebras de linha, que podem vir como `\r\n`.
    texto: ((j['texto'] ?? '') as String).replaceAll('\r\n', '\n'),
    pessoal: j['pessoal'] == true,
    imagemUrl: j['imagem_url'] as String?,
    topico: j['topico'] as String?,
    enviadaEm: dataApi(j['enviada_em']),
  );
}

class PaginaNotificacoes {
  final List<Notificacao> notificacoes;

  /// `antes_de` da página seguinte; `null` quando não há mais.
  final int? antesDe;

  const PaginaNotificacoes(this.notificacoes, this.antesDe);

  factory PaginaNotificacoes.fromJson(Map<String, dynamic> j) => PaginaNotificacoes(
    [for (final n in j['notificacoes'] as List) Notificacao.fromJson((n as Map).cast<String, dynamic>())],
    (j['proxima_pagina'] as Map?)?['antes_de'] as int?,
  );

  int get maiorId => notificacoes.isEmpty ? 0 : notificacoes.first.id;
}

const _porPagina = 30;

/// Sempre da conta da sessão: `/notificacoes` não aceita `X-Socio` (guia §2.3.4).
Future<Map<String, dynamic>> _pedirPagina(Dio dio, {int? antesDe}) => dadosDe(
  dio.get('/notificacoes', queryParameters: {'limite': _porPagina, 'antes_de': ?antesDe}),
);

/// Primeira página, com cache: abre sem rede.
final notificacoesProvider = StreamProvider.autoDispose<Dados<PaginaNotificacoes>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final dio = ref.read(dioSocioProvider);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'notificacoes.${sessao.socio.nrSocio}',
    pedido: () => _pedirPagina(dio),
    ler: PaginaNotificacoes.fromJson,
  );
});

/// Páginas seguintes, carregadas ao fazer scroll. Só com rede; recomeçam quando
/// a primeira página muda.
class MaisNotificacoes {
  final List<Notificacao> notificacoes;

  /// `antes_de` a pedir a seguir; `null` = chegou ao fim.
  final int? antesDe;
  final bool aCarregar, iniciado;

  const MaisNotificacoes({
    this.notificacoes = const [],
    this.antesDe,
    this.aCarregar = false,
    this.iniciado = false,
  });

  /// Antes do primeiro pedido não se sabe se há mais: manda o que veio na
  /// primeira página.
  bool temMais(int? antesDePrimeira) => iniciado ? antesDe != null : antesDePrimeira != null;
}

final maisNotificacoesProvider = NotifierProvider.autoDispose<MaisNotificacoesController, MaisNotificacoes>(
  MaisNotificacoesController.new,
);

class MaisNotificacoesController extends AutoDisposeNotifier<MaisNotificacoes> {
  @override
  MaisNotificacoes build() {
    ref.watch(notificacoesProvider.select((d) => d.valueOrNull?.obtidoEm));
    return const MaisNotificacoes();
  }

  Future<void> carregar(int? antesDePrimeira) async {
    final antes = state;
    final proxima = antes.iniciado ? antes.antesDe : antesDePrimeira;
    if (antes.aCarregar || proxima == null || !ref.read(ligacaoProvider)) return;

    state = MaisNotificacoes(
      notificacoes: antes.notificacoes,
      antesDe: antes.antesDe,
      iniciado: antes.iniciado,
      aCarregar: true,
    );
    try {
      final p = PaginaNotificacoes.fromJson(await _pedirPagina(ref.read(dioSocioProvider), antesDe: proxima));
      state = MaisNotificacoes(
        notificacoes: [...antes.notificacoes, ...p.notificacoes],
        antesDe: p.antesDe,
        iniciado: true,
      );
    } catch (_) {
      state = antes; // sem rede: fica o que já está
    }
  }
}

/// A maior `id` que o sócio já viu.
///
/// Não há "lida" no servidor (guia §4.16): guarda-se aqui, por sócio, e apaga-se
/// com a sessão como o resto da cache do sócio.
final vistasProvider = AsyncNotifierProvider<VistasController, int>(VistasController.new);

class VistasController extends AsyncNotifier<int> {
  String? _chave;

  @override
  Future<int> build() async {
    final sessao = ref.watch(sessaoProvider);
    if (sessao is! SessaoSocio) {
      _chave = null;
      return 0;
    }
    _chave = 'notificacoes.vistas.${sessao.socio.nrSocio}';
    final guardado = await ref.read(cacheProvider).ler(Ambito.sessao, _chave!);
    return (guardado?.dados['id'] as int?) ?? 0;
  }

  /// Chamado ao abrir o ecrã: tudo o que já está na lista deixa de ser novo.
  Future<void> marcarVistas(int id) async {
    final chave = _chave;
    if (chave == null || id <= (state.valueOrNull ?? 0)) return;
    state = AsyncData(id);
    await ref.read(cacheProvider).guardar(Ambito.sessao, chave, {'id': id});
  }
}

/// Quantas notificações da primeira página ainda não foram vistas.
final notificacoesNovasProvider = Provider.autoDispose<int>((ref) {
  final vistas = ref.watch(vistasProvider).valueOrNull;
  final pagina = ref.watch(notificacoesProvider).valueOrNull?.valor;
  if (vistas == null || pagina == null) return 0;
  return pagina.notificacoes.where((n) => n.id > vistas).length;
});
