import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/formatos.dart';
import '../../../core/widgets/em_breve.dart';

/// Agenda do clube: jogos e eventos, por ordem de data.
///
/// Contrato pedido ao CISOC (`GET /api/v2/publico/agenda`), alinhado com
/// `lps_cmp_jogos` e `lps_cnt_agenda` da arquitectura. Enquanto não existir, os
/// ecrãs mostram "em preparação" ou, em modo de demonstração, exemplos.
enum TipoItem { jogo, evento, desconhecido }

class Equipa {
  final String nome;
  final String? emblemaUrl;

  /// `true` = equipa do clube (para destacar).
  final bool doClube;

  const Equipa({required this.nome, this.emblemaUrl, this.doClube = false});

  factory Equipa.fromJson(Map<String, dynamic> j) => Equipa(
    nome: (j['nome'] ?? '') as String,
    emblemaUrl: j['emblema_url'] as String?,
    doClube: j['do_clube'] == true,
  );
}

class ItemAgenda {
  final TipoItem tipo;
  final String id, titulo;

  /// Início real. `dataConfirmada`/`horaConfirmada` a `false` = ainda por marcar
  /// (o legado tem jogos com dia por confirmar).
  final DateTime inicio;
  final bool dataConfirmada, horaConfirmada;
  final String? modalidade, prova, local, resumo, capaUrl;
  final Equipa? casa, fora;
  final int? golosCasa, golosFora;

  /// `agendado`, `a_decorrer`, `terminado`, `adiado`, `cancelado` — lista aberta.
  final String estado;

  /// Id da sessão de bilhética, quando há bilhetes para este jogo ou evento.
  final String? sessaoBilhetes;

  const ItemAgenda({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.inicio,
    required this.estado,
    this.dataConfirmada = true,
    this.horaConfirmada = true,
    this.modalidade,
    this.prova,
    this.local,
    this.resumo,
    this.capaUrl,
    this.casa,
    this.fora,
    this.golosCasa,
    this.golosFora,
    this.sessaoBilhetes,
  });

  factory ItemAgenda.fromJson(Map<String, dynamic> j) => ItemAgenda(
    tipo: switch (j['tipo']) {
      'jogo' => TipoItem.jogo,
      'evento' => TipoItem.evento,
      _ => TipoItem.desconhecido,
    },
    id: j['id'].toString(),
    titulo: (j['titulo'] ?? '') as String,
    inicio: dataApi(j['inicio']) ?? DateTime.now(),
    estado: (j['estado'] ?? 'agendado') as String,
    dataConfirmada: j['data_confirmada'] != false,
    horaConfirmada: j['hora_confirmada'] != false,
    modalidade: (j['modalidade'] as Map?)?['nome'] as String?,
    prova: (j['prova'] as Map?)?['nome'] as String?,
    local: j['local'] as String? ?? j['recinto'] as String?,
    resumo: j['resumo'] as String?,
    capaUrl: (j['capa'] as Map?)?['url'] as String?,
    casa: j['equipa_casa'] is Map ? Equipa.fromJson((j['equipa_casa'] as Map).cast<String, dynamic>()) : null,
    fora: j['equipa_fora'] is Map ? Equipa.fromJson((j['equipa_fora'] as Map).cast<String, dynamic>()) : null,
    golosCasa: (j['resultado'] as Map?)?['casa'] as int?,
    golosFora: (j['resultado'] as Map?)?['fora'] as int?,
    sessaoBilhetes: (j['bilhetes'] as Map?)?['sessao']?.toString(),
  );

  bool get terminado => estado == 'terminado';
  bool get cancelado => estado == 'cancelado' || estado == 'adiado';
  bool get temBilhetes => sessaoBilhetes != null;
  bool get temResultado => golosCasa != null && golosFora != null;
}

final agendaProvider = FutureProvider.autoDispose<List<ItemAgenda>>((ref) async {
  if (!modoDemonstracao) throw const EmPreparacao();
  return agendaExemplo;
});

/// Exemplos só para ver o desenho (modo de demonstração).
final agendaExemplo = [for (final j in _exemplos) ItemAgenda.fromJson(j)];

DateTime _daqui(int dias, int hora, [int minuto = 0]) {
  final d = DateTime.now().add(Duration(days: dias));
  return DateTime(d.year, d.month, d.day, hora, minuto);
}

final _exemplos = <Map<String, dynamic>>[
  {
    'tipo': 'jogo',
    'id': 1,
    'titulo': 'Leões Porto Salvo x Sporting CP',
    'inicio': _daqui(1, 21).toIso8601String(),
    'estado': 'agendado',
    'modalidade': {'nome': 'Hóquei em patins'},
    'prova': {'nome': 'Campeonato Nacional · 4.ª jornada'},
    'recinto': 'Pavilhão Municipal de Porto Salvo',
    'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'equipa_fora': {'nome': 'Sporting CP'},
    'bilhetes': {'sessao': 'S1'},
  },
  {
    'tipo': 'evento',
    'id': 2,
    'titulo': 'Jantar de Natal do clube',
    'inicio': _daqui(3, 20).toIso8601String(),
    'estado': 'agendado',
    'local': 'Sede do clube',
    'resumo': 'Jantar aberto a sócios e famílias, com entrega de prémios às equipas.',
    'bilhetes': {'sessao': 'S2'},
  },
  {
    'tipo': 'jogo',
    'id': 3,
    'titulo': 'Juvenis: Leões Porto Salvo x Oeiras',
    'inicio': _daqui(5, 10, 30).toIso8601String(),
    'estado': 'agendado',
    'hora_confirmada': false,
    'modalidade': {'nome': 'Futsal'},
    'prova': {'nome': 'Distrital de juvenis'},
    'recinto': 'Pavilhão Municipal de Porto Salvo',
    'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'equipa_fora': {'nome': 'CD Oeiras'},
  },
  {
    'tipo': 'jogo',
    'id': 4,
    'titulo': 'Benfica x Leões Porto Salvo',
    'inicio': _daqui(-2, 19).toIso8601String(),
    'estado': 'terminado',
    'modalidade': {'nome': 'Hóquei em patins'},
    'prova': {'nome': 'Campeonato Nacional · 3.ª jornada'},
    'recinto': 'Pavilhão da Luz',
    'equipa_casa': {'nome': 'SL Benfica'},
    'equipa_fora': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'resultado': {'casa': 2, 'fora': 3},
  },
  {
    'tipo': 'evento',
    'id': 6,
    'titulo': 'Assembleia Geral de sócios',
    'inicio': _daqui(8, 21).toIso8601String(),
    'estado': 'agendado',
    'local': 'Sede do clube',
    'resumo': 'Apresentação e votação das contas da época.',
  },
  {
    'tipo': 'jogo',
    'id': 7,
    'titulo': 'Patinagem: Torneio de Oeiras',
    'inicio': _daqui(2, 9, 30).toIso8601String(),
    'estado': 'agendado',
    'modalidade': {'nome': 'Patinagem artística'},
    'prova': {'nome': 'Torneio regional'},
    'recinto': 'Pavilhão de Oeiras',
    'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
    'equipa_fora': {'nome': 'Vários clubes'},
  },
  {
    'tipo': 'evento',
    'id': 5,
    'titulo': 'Torneio de Verão · inscrições abertas',
    'inicio': _daqui(12, 9).toIso8601String(),
    'estado': 'agendado',
    'local': 'Complexo desportivo',
    'resumo': 'Três dias de torneio para todos os escalões de formação.',
  },
];
