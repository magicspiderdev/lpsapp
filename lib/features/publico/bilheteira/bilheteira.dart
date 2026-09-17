import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/formatos.dart';
import '../../../core/widgets/em_breve.dart';

/// Bilheteira: sessões à venda (jogos, espectáculos, jantares).
///
/// Contrato pedido ao CISOC (`GET /api/v2/publico/bilhetes/sessoes`), alinhado
/// com o módulo `Ticketing` da arquitectura. Uma sessão pode ou não ser um jogo.
class Zona {
  final String id, nome;
  final double preco;
  final bool disponivel;
  final String? nota;

  const Zona({required this.id, required this.nome, required this.preco, this.disponivel = true, this.nota});

  factory Zona.fromJson(Map<String, dynamic> j) => Zona(
    id: j['id'].toString(),
    nome: (j['nome'] ?? '') as String,
    preco: ((j['preco'] as num?) ?? 0).toDouble(),
    disponivel: j['disponivel'] != false,
    nota: j['nota'] as String?,
  );
}

class Sessao {
  final String id, titulo;
  final String? subtitulo, local, capaUrl;
  final DateTime inicio;
  final bool esgotado;

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
    precoDesde: (j['preco_desde'] as num?)?.toDouble(),
    zonas: [for (final z in (j['zonas'] as List?) ?? const []) Zona.fromJson((z as Map).cast<String, dynamic>())],
  );
}

final sessoesProvider = FutureProvider.autoDispose<List<Sessao>>((ref) async {
  if (!modoDemonstracao) throw const EmPreparacao();
  return sessoesExemplo;
});

final sessaoProvider = FutureProvider.autoDispose.family<Sessao, String>((ref, id) async {
  if (!modoDemonstracao) throw const EmPreparacao();
  return sessoesExemplo.firstWhere((s) => s.id == id);
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
];
