import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/rede/ligacao.dart';
import '../../socio/conta/contas.dart' show dependentesProvider;

/// Caminhos dos ecrãs dos educandos. `/socio/dependentes` é o `route` do push
/// que chega quando a secretaria decide um pedido (§2.3.5).
abstract final class RotasEducandos {
  static const lista = '/socio/dependentes';
  static const pedir = '/socio/dependentes/pedir';
  static String privacidade(int nrSocio) => '/socio/dependentes/$nrSocio/privacidade';
}

/// Um sócio de quem a conta é (ou pediu para ser) encarregada — `GET
/// /api/v2/me/dependentes` (§2.3.5). Qualquer conta, sócia ou não.
class Educando {
  final int nrSocio;

  /// Pendente: só o primeiro nome. Activo: o nome completo.
  final String nome;

  /// `pending`, `active` — lista aberta.
  final String estado;

  /// `pai`, `mae`, `encarregado`, `irmao`, `outro` — lista aberta.
  final String? relacao;
  final bool podePagar;

  /// `child`, `teen`, `adult` ou `null`. Só para textos, nunca para decidir.
  final String? faixaEtaria;
  final DateTime? pedidoEm, verificadoEm;

  const Educando({
    required this.nrSocio,
    required this.nome,
    required this.estado,
    this.relacao,
    this.podePagar = false,
    this.faixaEtaria,
    this.pedidoEm,
    this.verificadoEm,
  });

  factory Educando.fromJson(Map<String, dynamic> j) => Educando(
    nrSocio: (j['nr_socio'] as num).toInt(),
    nome: (j['nome'] ?? '') as String,
    estado: (j['estado'] ?? '') as String,
    relacao: j['relacao'] as String?,
    podePagar: j['pode_pagar'] == true,
    faixaEtaria: j['faixa_etaria'] as String?,
    pedidoEm: _data(j['pedido_em']),
    verificadoEm: _data(j['verificado_em']),
  );

  /// À espera da secretaria: **nenhuma** acção sobre o educando, só desistir.
  bool get pendente => estado == 'pending';
  bool get activo => estado == 'active';
}

DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<Educando> lerEducandos(Map<String, dynamic> data) => [
  for (final d in (data['dependentes'] as List?) ?? const [])
    if (d is Map && d['nr_socio'] is num) Educando.fromJson(d.cast<String, dynamic>()),
];

/// Activos primeiro, depois os pedidos por decidir, depois o que não se conhece.
List<Educando> ordenarEducandos(List<Educando> lista) {
  int peso(Educando e) => e.activo ? 0 : (e.pendente ? 1 : 2);
  return [...lista]..sort((a, b) {
    final p = peso(a).compareTo(peso(b));
    return p != 0 ? p : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
  });
}

/// Relações que se podem pedir (`POST /me/dependentes`), pela ordem do ecrã.
const relacoesPedido = ['mae', 'pai', 'encarregado'];

/// O nome de uma relação. Lista aberta: o que não se conhece mostra-se como vem.
String rotuloRelacao(String? relacao) => switch (relacao) {
  'pai' => 'Pai',
  'mae' => 'Mãe',
  'encarregado' => 'Encarregado de educação',
  'irmao' => 'Irmão',
  'outro' => 'Outra relação',
  null || '' => '',
  final r => r[0].toUpperCase() + r.substring(1),
};

/// Se a lista do servidor e a `conta.dependentes` da sessão discordam sobre
/// quem está activo — a secretaria decidiu um pedido e a sessão ainda não
/// sabe. Aí vale a pena renovar a sessão para trazer as capacidades.
bool sessaoDesactualizada(List<Educando> lista, ContaSessao? conta) {
  if (conta == null) return false;
  final activos = {
    for (final e in lista)
      if (e.activo) e.nrSocio,
  };
  final naSessao = {for (final d in conta.dependentes) d.nrSocio};
  return !activos.every(naSessao.contains) || !naSessao.every(activos.contains);
}

/// `GET /api/v2/me/dependentes` — activos **e** pendentes. Com cache, apagada
/// com a sessão.
final educandosProvider = StreamProvider.autoDispose<Dados<List<Educando>>>((ref) {
  if (ref.watch(sessaoProvider.select((s) => s is SessaoAnonima))) {
    return Stream.error(const ApiException(erro: 'sem_sessao', message: 'Entre na sua conta para continuar.'));
  }
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'educandos',
    pedido: () => dadosDe(dio.get('/me/dependentes')),
    ler: lerEducandos,
  );
});

/// O que se faz com a lista: pedir e deixar de acompanhar.
final educandosAccoesProvider = Provider<EducandosAccoes>(EducandosAccoes.new);

class EducandosAccoes {
  EducandosAccoes(this._ref);

  final Ref _ref;

  /// `POST /me/dependentes`. Devolve o pedido (ou a ligação, se ficou logo
  /// activa) e a `mensagem` do servidor para mostrar.
  ///
  /// Lança [ApiException]: `dados_nao_conferem`, `dependente_maior`,
  /// `encarregado_menor`, `ja_ligado`, `demasiados_pedidos` — todas com a
  /// `message` pronta.
  Future<({Educando? educando, String mensagem})> pedir({
    required int nrSocio,
    required DateTime dataNascimento,
    required String relacao,
  }) async {
    final d = await dadosDe(
      _ref
          .read(dioContaProvider)
          .post(
            '/me/dependentes',
            data: {'nr_socio': nrSocio, 'data_nascimento': diaIso(dataNascimento), 'relacao': relacao},
          ),
    );
    await _depois();
    final e = d['dependente'];
    return (
      educando: e is Map && e['nr_socio'] is num ? Educando.fromJson(e.cast<String, dynamic>()) : null,
      mensagem: (d['mensagem'] as String?) ?? 'Pedido registado. A secretaria confirma a ligação.',
    );
  }

  /// `DELETE /me/dependentes/{nr}` — deixar de acompanhar, ou desistir do pedido.
  /// Corpo em JSON: um DELETE form-encoded não é lido pelo servidor (guia §7).
  Future<void> remover(int nrSocio) async {
    await dadosDe(_ref.read(dioContaProvider).delete('/me/dependentes/$nrSocio', data: const {}));
    await _depois();
  }

  /// A secretaria decidiu, ou esta conta mudou a lista: recarrega-a, e renova a
  /// sessão para `conta.dependentes` (e as capacidades) acompanharem.
  Future<void> renovarSessao() async {
    try {
      await _ref.read(tokenStoreProvider).renovar();
    } catch (_) {
      // Sem rede, ou sem sessão: não é erro deste ecrã. O próximo refresh traz tudo.
    }
  }

  Future<void> _depois() async {
    // Pelo container, e não pelo `ref`: `ref.invalidate` monta (em debug) o
    // provider que ninguém está a ver — um GET inútil, e o `dependentesProvider`
    // numa conta sem ficha só sabe falhar.
    _ref.container
      ..invalidate(educandosProvider)
      ..invalidate(dependentesProvider);
    await renovarSessao();
  }
}

String diaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
