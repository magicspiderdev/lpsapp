import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/config.dart';
import '../../../core/formatos.dart';
import '../../../core/auth/sessao.dart' as auth;
import '../../../core/rede/ligacao.dart';

/// Bilheteira: sessões à venda (jogos, espectáculos, jantares).
///
/// `GET /api/v2/publico/bilhetes/sessoes` e `/bilhetes/sessoes/{id}` (guia
/// §4.17, esquemas `Sessao` e `Zona` do `openapi-v2.yaml`). O catálogo é
/// público; a carteira e a compra são da conta (`/api/v2/me/bilhetes`, §4.18).
class Zona {
  /// Número na API; texto aqui, por ser só uma chave.
  final String id, nome;
  final double preco;
  final bool disponivel;

  /// Zona só para sócios. **Desde 2026-09-22 é só o que o clube marcar**: uma
  /// zona paga deixou de o exigir por ser paga, porque um pagamento já não
  /// precisa de número de sócio. Nunca deduzir isto do preço.
  final bool exigeSocio;
  final String? nota;

  /// `app` (compra-se aqui) ou `externa` (abre-se o [urlCompra]). Lista
  /// aberta: um valor desconhecido trata-se como "não se compra na app".
  final String venda;

  /// Onde se compra, na venda externa.
  final String? urlCompra;

  /// Bilhetes desta zona por conta, somando todas as compras. `null` na venda
  /// externa — e é o servidor que manda, não um número inventado cá.
  final int? maxPorConta;

  const Zona({
    required this.id,
    required this.nome,
    required this.preco,
    this.disponivel = true,
    this.exigeSocio = false,
    this.nota,
    this.venda = 'app',
    this.urlCompra,
    this.maxPorConta,
  });

  factory Zona.fromJson(Map<String, dynamic> j) => Zona(
    id: j['id'].toString(),
    nome: (j['nome'] ?? '') as String,
    preco: ((j['preco'] as num?) ?? 0).toDouble(),
    disponivel: j['disponivel'] != false,
    exigeSocio: j['exige_socio'] == true,
    nota: j['nota'] as String?,
    venda: ((j['venda'] ?? 'app') as String).toLowerCase(),
    urlCompra: j['url_compra'] as String?,
    maxPorConta: (j['max_por_conta'] as num?)?.toInt(),
  );

  /// Compra-se dentro da app?
  bool get naApp => venda == 'app';

  /// Gratuita: qualquer conta a leva, e fica logo paga.
  bool get gratuita => preco == 0;

  /// Quantos se podem escolher de uma vez. O servidor tem a palavra final
  /// (`409 limite_bilhetes`); isto é só o que o seletor deixa carregar.
  int get maximo => maxPorConta ?? maxBilhetesPorZona;
}

class Sessao {
  final String id, titulo;
  final String? subtitulo, local, capaUrl;
  final DateTime inicio;
  final bool esgotado;

  /// `a_venda`, `encerrada`, `cancelada` — lista aberta.
  final String estado;

  /// Preço mais baixo à venda; `null` quando não há nada disponível.
  final double? precoDesde;
  final List<Zona> zonas;

  const Sessao({
    required this.id,
    required this.titulo,
    required this.inicio,
    this.subtitulo,
    this.local,
    this.capaUrl,
    this.esgotado = false,
    this.estado = 'a_venda',
    this.precoDesde,
    this.zonas = const [],
  });

  factory Sessao.fromJson(Map<String, dynamic> j) => Sessao(
    id: j['id'].toString(),
    titulo: (j['titulo'] ?? '') as String,
    subtitulo: j['subtitulo'] as String?,
    local: j['local'] as String?,
    capaUrl: (j['capa'] as Map?)?['url'] as String?,
    inicio: dataApi(j['inicio']) ?? DateTime.now(),
    esgotado: j['esgotado'] == true,
    estado: ((j['estado'] ?? 'a_venda') as String).toLowerCase(),
    precoDesde: (j['preco_desde'] as num?)?.toDouble(),
    zonas: [for (final z in (j['zonas'] as List?) ?? const []) Zona.fromJson((z as Map).cast<String, dynamic>())],
  );

  /// Só uma sessão à venda e não esgotada deixa escolher bilhetes. Estados
  /// desconhecidos contam como fechados.
  bool get aVenda => estado == 'a_venda' && !esgotado;

  /// Porque não se pode escolher, em texto; `null` se está à venda.
  String? get motivoFechada => switch (estado) {
    'a_venda' => esgotado ? 'Esgotado' : null,
    'cancelada' => 'Sessão cancelada',
    'encerrada' => 'Venda encerrada',
    _ => 'Venda indisponível',
  };
}

/// Quantidades por zona no link de volta do login: `1-2,2-1` (zona 1: dois
/// bilhetes; zona 2: um). Valores estranhos ignoram-se.
Map<String, int> quantidadesDoLink(String? z) => {
  for (final par in (z ?? '').split(','))
    if (par.split('-') case [final zona, final q] when zona.isNotEmpty && (int.tryParse(q) ?? 0) > 0)
      zona: int.parse(q).clamp(1, maxBilhetesPorZona),
};

String quantidadesParaLink(Map<String, int> q) => [
  for (final MapEntry(:key, :value) in q.entries)
    if (value > 0) '$key-$value',
].join(',');

/// Limite por zona e por compra (o mesmo que o ecrã deixa escolher).
const maxBilhetesPorZona = 6;

/// Sessões à venda, com cache: abre sem rede com a última lista.
final sessoesProvider = StreamProvider.autoDispose<Dados<List<Sessao>>>((ref) {
  if (modoDemonstracao) return Stream.value(Dados(sessoesExemplo, DateTime.now()));
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'bilhetes.sessoes',
    pedido: () => dadosDe(dio.get('/bilhetes/sessoes')),
    ler: (d) => [
      for (final s in (d['sessoes'] as List?) ?? const []) Sessao.fromJson((s as Map).cast<String, dynamic>()),
    ],
  );
});

/// Uma sessão com as zonas e os preços.
final sessaoProvider = StreamProvider.autoDispose.family<Dados<Sessao>, String>((ref, id) {
  if (modoDemonstracao) return Stream.value(Dados(sessoesExemplo.firstWhere((s) => s.id == id), DateTime.now()));
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'bilhetes.sessao.$id',
    pedido: () => dadosDe(dio.get('/bilhetes/sessoes/$id')),
    ler: (d) => Sessao.fromJson((d['sessao'] as Map).cast<String, dynamic>()),
  );
});

DateTime _daqui(int dias, int hora) {
  final d = DateTime.now().add(Duration(days: dias));
  return DateTime(d.year, d.month, d.day, hora);
}

/// Exemplos só para ver o desenho (modo de demonstração).
final sessoesExemplo = [
  Sessao.fromJson({
    'id': 'S1',
    'titulo': 'Leões Porto Salvo x Sporting CP',
    'subtitulo': 'Hóquei em patins · Campeonato Nacional',
    'local': 'Pavilhão Municipal de Porto Salvo',
    'inicio': _daqui(1, 21).toIso8601String(),
    'preco_desde': 5,
    'zonas': [
      {'id': 'Z1', 'nome': 'Bancada central', 'preco': 10},
      {'id': 'Z2', 'nome': 'Bancada lateral', 'preco': 7.5},
      {'id': 'Z3', 'nome': 'Sócio', 'preco': 5, 'nota': 'Preço com desconto de sócio'},
      {'id': 'Z4', 'nome': 'Criança até 12 anos', 'preco': 0, 'nota': 'Entrada gratuita'},
    ],
  }),
  Sessao.fromJson({
    'id': 'S2',
    'titulo': 'Jantar de Natal do clube',
    'subtitulo': 'Com entrega de prémios às equipas',
    'local': 'Sede do clube',
    'inicio': _daqui(3, 20).toIso8601String(),
    'preco_desde': 20,
    'zonas': [
      {'id': 'Z5', 'nome': 'Adulto', 'preco': 20},
      {'id': 'Z6', 'nome': 'Criança até 12 anos', 'preco': 10},
    ],
  }),
  Sessao.fromJson({
    'id': 'S3',
    'titulo': 'Leões Porto Salvo x FC Porto',
    'subtitulo': 'Hóquei em patins · Taça de Portugal',
    'local': 'Pavilhão Municipal de Porto Salvo',
    'inicio': _daqui(18, 18).toIso8601String(),
    'esgotado': true,
    'zonas': [
      {'id': 'Z7', 'nome': 'Bancada central', 'preco': 12, 'disponivel': false},
      {'id': 'Z8', 'nome': 'Bancada lateral', 'preco': 9, 'disponivel': false},
    ],
  }),
  Sessao.fromJson({
    'id': 'S4',
    'titulo': 'Passeio de sócios a Sintra',
    'subtitulo': 'Autocarro, almoço e visita guiada',
    'local': 'Partida da sede do clube',
    'inicio': _daqui(25, 9).toIso8601String(),
    'preco_desde': 15,
    'zonas': [
      {'id': 'Z9', 'nome': 'Sócio', 'preco': 15, 'nota': 'Inclui almoço'},
      {'id': 'Z10', 'nome': 'Convidado', 'preco': 25},
    ],
  }),
];

// ── Bilhetes comprados (a carteira) ────────────────────────────────────────

/// Um bilhete que já é do utilizador. O `codigo` é o que o QR mostra e a
/// portaria valida — como o `hashid` do cartão de sócio, trata-se como
/// credencial: não vai para logs nem é partilhado fora do ecrã do bilhete.
class BilheteComprado {
  final String id, codigo, titulo, zona;
  final String? subtitulo, local, titular, lugar;
  final DateTime inicio;
  final double preco;

  /// `valido`, `usado`, `anulado` — lista aberta.
  final String estado;

  const BilheteComprado({
    required this.id,
    required this.codigo,
    required this.titulo,
    required this.zona,
    required this.inicio,
    required this.preco,
    required this.estado,
    this.subtitulo,
    this.local,
    this.titular,
    this.lugar,
    this.sessao,
    this.encomenda,
    this.sessaoEstado,
    this.convite = false,
    this.conviteMensagem,
  });

  /// Um convite (§4.18): posto na carteira pelo clube, sem compra — um prémio
  /// de passatempo, um convidado. O código e a porta são iguais.
  final bool convite;

  /// Porque o recebeu ("Prémio: passatempo do dérbi"). Pode faltar.
  final String? conviteMensagem;

  /// A sessão e a encomenda de onde veio, para voltar lá.
  final String? sessao, encomenda;

  /// `a_venda`, `encerrada`, `cancelada` — uma sessão cancelada anula os seus
  /// bilhetes, e é isso que explica um `estado: anulado`.
  final String? sessaoEstado;

  factory BilheteComprado.fromJson(Map<String, dynamic> j) => BilheteComprado(
    id: j['id'].toString(),
    codigo: (j['codigo'] ?? '') as String,
    titulo: (j['titulo'] ?? '') as String,
    zona: (j['zona'] ?? '') as String,
    inicio: dataApi(j['inicio']) ?? DateTime.now(),
    preco: ((j['preco'] as num?) ?? 0).toDouble(),
    estado: ((j['estado'] ?? 'valido') as String).toLowerCase(),
    subtitulo: j['subtitulo'] as String?,
    local: j['local'] as String?,
    titular: j['titular'] as String?,
    lugar: j['lugar'] as String?,
    sessao: j['sessao']?.toString(),
    encomenda: j['encomenda']?.toString(),
    sessaoEstado: (j['sessao_estado'] as String?)?.toLowerCase(),
    convite: j['convite'] is Map,
    conviteMensagem: switch (j['convite']) {
      {'mensagem': final String m} when m.trim().isNotEmpty => m.trim(),
      _ => null,
    },
  );

  bool get valido => estado == 'valido';
  bool get usado => estado == 'usado';
  bool get anulado => estado == 'anulado';
}

/// A carteira (`GET /api/v2/me/bilhetes`).
///
/// Vai para `Ambito.seguro` e não para a cache comum: o `codigo` é a
/// credencial da portaria, como o QR do cartão. Fica guardada para **abrir sem
/// rede** — um bilhete que não abre no pavilhão não serve de nada — e
/// desaparece com a sessão.
final meusBilhetesProvider = StreamProvider.autoDispose<Dados<List<BilheteComprado>>>((ref) {
  if (modoDemonstracao) return Stream.value(Dados(bilhetesExemplo, DateTime.now()));
  // Sem sessão não há carteira: é o ecrã que convida a entrar.
  if (ref.watch(auth.sessaoProvider) is auth.SessaoAnonima) return Stream.error(const SemSessao());
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioContaProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.seguro,
    chave: 'bilhetes.meus',
    pedido: () => dadosDe(dio.get('/me/bilhetes')),
    ler: (d) => [
      for (final b in (d['bilhetes'] as List?) ?? const [])
        if (b is Map) BilheteComprado.fromJson(b.cast<String, dynamic>()),
    ],
  );
});

/// Um bilhete, da carteira já guardada. Não se pede ao servidor de propósito:
/// no pavilhão pode não haver rede, e o código não muda.
final bilheteProvider = Provider.autoDispose.family<BilheteComprado?, String>((ref, id) {
  final carteira = ref.watch(meusBilhetesProvider).valueOrNull?.valor ?? const <BilheteComprado>[];
  for (final b in carteira) {
    if (b.id == id) return b;
  }
  return null;
});

/// Os bilhetes de um evento, juntos.
///
/// A carteira mostra **um cartão por evento**, não um por bilhete: quem leva
/// dois bilhetes para o mesmo jogo tem um jogo, não dois cartões iguais
/// seguidos. Lá dentro passa-se de um código para o outro arrastando o dedo,
/// que é como a portaria os lê — um a um, sem voltar à lista entre pessoas.
class GrupoBilhetes {
  /// Pelo menos um, por construção.
  final List<BilheteComprado> bilhetes;

  const GrupoBilhetes(this.bilhetes);

  BilheteComprado get primeiro => bilhetes.first;
  String get titulo => primeiro.titulo;
  String? get subtitulo => primeiro.subtitulo;
  String? get local => primeiro.local;
  DateTime get inicio => primeiro.inicio;
  int get quantos => bilhetes.length;
  double get total => bilhetes.fold(0, (s, b) => s + b.preco);

  int get porUsar => bilhetes.where((b) => b.valido).length;
  bool get todosUsados => porUsar == 0;

  /// "Sócios", ou "1 Sócios · 1 Não sócios" quando vieram de compras
  /// diferentes — uma encomenda é de uma zona, por isso isso acontece.
  String get zonas {
    final contagem = <String, int>{};
    for (final b in bilhetes) {
      if (b.zona.isNotEmpty) contagem[b.zona] = (contagem[b.zona] ?? 0) + 1;
    }
    if (contagem.isEmpty) return '';
    if (contagem.length == 1) return contagem.keys.single;
    return [for (final MapEntry(:key, :value) in contagem.entries) '$value $key'].join(' · ');
  }
}

/// O que junta dois bilhetes no mesmo cartão: **o evento**.
///
/// Não a compra. Comprar um bilhete de sócio e um de convidado para o mesmo
/// jogo são duas encomendas (uma encomenda é de uma zona, §4.18) e na carteira
/// isso continua a ser um jogo só. Sem `sessao` — dados antigos — a compra é o
/// melhor palpite seguinte.
String chaveDoEvento(BilheteComprado b) => b.sessao ?? b.encomenda ?? b.id;

/// Agrupa por evento, sem mexer na ordem com que a carteira veio.
List<GrupoBilhetes> agruparPorEvento(Iterable<BilheteComprado> bilhetes) {
  final porEvento = <String, List<BilheteComprado>>{};
  for (final b in bilhetes) {
    porEvento.putIfAbsent(chaveDoEvento(b), () => []).add(b);
  }
  return [for (final grupo in porEvento.values) GrupoBilhetes(grupo)];
}

/// A carteira por evento: o que ainda vem primeiro, o que já passou depois.
///
/// O corte é **pela data**, como na agenda: um bilhete por usar de um jogo de
/// ontem não volta a ser um jogo que vem aí.
final carteiraProvider = Provider.autoDispose<(List<GrupoBilhetes>, List<GrupoBilhetes>)>((ref) {
  final carteira = ref.watch(meusBilhetesProvider).valueOrNull?.valor ?? const <BilheteComprado>[];
  final agora = DateTime.now();
  final proximos = <GrupoBilhetes>[];
  final passados = <GrupoBilhetes>[];
  for (final g in agruparPorEvento(carteira)) {
    (g.inicio.isBefore(agora) ? passados : proximos).add(g);
  }
  proximos.sort((a, b) => a.inicio.compareTo(b.inicio));
  passados.sort((a, b) => b.inicio.compareTo(a.inicio));
  return (proximos, passados);
});

/// Os bilhetes do mesmo evento que um bilhete, por ordem, para se passar de um
/// para o outro sem voltar à lista.
final bilhetesDoEventoProvider = Provider.autoDispose.family<List<BilheteComprado>, String>((ref, id) {
  final carteira = ref.watch(meusBilhetesProvider).valueOrNull?.valor ?? const <BilheteComprado>[];
  final bilhete = ref.watch(bilheteProvider(id));
  if (bilhete == null) return const [];

  final chave = chaveDoEvento(bilhete);
  final grupo = carteira.where((b) => chaveDoEvento(b) == chave).toList();
  return grupo.isEmpty ? [bilhete] : grupo;
});

/// Não há sessão nenhuma — não é erro, é um convite a entrar.
class SemSessao implements Exception {
  const SemSessao();
}

/// Exemplos só para ver o desenho (modo de demonstração).
final bilhetesExemplo = [
  BilheteComprado.fromJson({
    'id': 'B1',
    'codigo': 'LPS-2026-0001-8F3A',
    'titulo': 'Leões Porto Salvo x Sporting CP',
    'subtitulo': 'Hóquei em patins · Campeonato Nacional',
    'local': 'Pavilhão Municipal de Porto Salvo',
    'inicio': _daqui(1, 21).toIso8601String(),
    'zona': 'Sócio',
    'lugar': 'Bancada central · Fila C',
    'preco': 5,
    'titular': 'João Pedro Lopes Mendes',
    'estado': 'valido',
  }),
  BilheteComprado.fromJson({
    'id': 'B2',
    'codigo': 'LPS-2026-0002-2C7D',
    'titulo': 'Jantar de Natal do clube',
    'subtitulo': 'Com entrega de prémios às equipas',
    'local': 'Sede do clube',
    'inicio': _daqui(3, 20).toIso8601String(),
    'zona': 'Adulto',
    'preco': 20,
    'titular': 'João Pedro Lopes Mendes',
    'estado': 'valido',
  }),
  BilheteComprado.fromJson({
    'id': 'B3',
    'codigo': 'LPS-2026-0003-9A1B',
    'titulo': 'Leões Porto Salvo x CD Oeiras',
    'subtitulo': 'Futsal · Distrital',
    'local': 'Pavilhão Municipal de Porto Salvo',
    'inicio': _daqui(-6, 18).toIso8601String(),
    'zona': 'Bancada lateral',
    'preco': 7.5,
    'titular': 'João Pedro Lopes Mendes',
    'estado': 'usado',
  }),
];
