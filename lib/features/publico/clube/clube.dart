import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/widgets/em_breve.dart';

/// Informação geral do clube (`GET /api/v2/publico/clube`, a pedir ao CISOC).
class Contacto {
  final String tipo, valor;
  final String? etiqueta;

  const Contacto({required this.tipo, required this.valor, this.etiqueta});

  factory Contacto.fromJson(Map<String, dynamic> j) => Contacto(
    tipo: (j['tipo'] ?? '') as String,
    valor: (j['valor'] ?? '') as String,
    etiqueta: j['etiqueta'] as String?,
  );
}

class Modalidade {
  final String nome;
  final String? escaloes;

  const Modalidade({required this.nome, this.escaloes});

  factory Modalidade.fromJson(Map<String, dynamic> j) =>
      Modalidade(nome: (j['nome'] ?? '') as String, escaloes: j['escaloes'] as String?);
}

class Clube {
  final String nome;
  final int? fundadoEm;
  final String? lema, historia, morada, mapaUrl, site;
  final List<Contacto> contactos;
  final List<String> horario;
  final List<Modalidade> modalidades;

  /// `rede` → endereço (facebook, instagram, youtube…). Lista aberta.
  final Map<String, String> redes;

  const Clube({
    required this.nome,
    this.fundadoEm,
    this.lema,
    this.historia,
    this.morada,
    this.mapaUrl,
    this.site,
    this.contactos = const [],
    this.horario = const [],
    this.modalidades = const [],
    this.redes = const {},
  });

  factory Clube.fromJson(Map<String, dynamic> j) => Clube(
    nome: (j['nome'] ?? '') as String,
    fundadoEm: j['fundado_em'] as int?,
    lema: j['lema'] as String?,
    historia: j['historia'] as String?,
    morada: j['morada'] as String?,
    mapaUrl: j['mapa_url'] as String?,
    site: j['site'] as String?,
    contactos: [
      for (final c in (j['contactos'] as List?) ?? const []) Contacto.fromJson((c as Map).cast<String, dynamic>()),
    ],
    horario: [for (final h in (j['horario'] as List?) ?? const []) h.toString()],
    modalidades: [
      for (final m in (j['modalidades'] as List?) ?? const []) Modalidade.fromJson((m as Map).cast<String, dynamic>()),
    ],
    redes: {
      for (final MapEntry(:key, :value) in ((j['redes'] as Map?) ?? const {}).entries) key.toString(): value.toString(),
    },
  );
}

final clubeProvider = FutureProvider.autoDispose<Clube>((ref) async {
  if (!modoDemonstracao) throw const EmPreparacao();
  return clubeExemplo;
});

/// Exemplo só para ver o desenho (modo de demonstração). Os dados verdadeiros
/// vêm do CISOC, onde a secretaria os mantém.
final clubeExemplo = Clube.fromJson({
  'nome': 'Clube Recreativo Leões de Porto Salvo',
  'fundado_em': 1972,
  'lema': 'A família leonina de Porto Salvo',
  'historia':
      'Fundado em 1972, o clube nasceu para dar desporto e convívio às famílias de Porto Salvo. '
      'Hoje tem centenas de atletas na formação, equipas em competições nacionais e distritais, e '
      'uma vida social que junta sócios de todas as idades.',
  'morada': 'Rua do Clube, 1 · 2740-000 Porto Salvo, Oeiras',
  'mapa_url': 'https://maps.google.com/?q=Le%C3%B5es+de+Porto+Salvo',
  'site': 'https://leoesdeportosalvo.pt',
  'contactos': [
    {'tipo': 'telefone', 'valor': '214 000 000', 'etiqueta': 'Secretaria'},
    {'tipo': 'email', 'valor': 'geral@leoesdeportosalvo.pt'},
    {'tipo': 'email', 'valor': 'socios@leoesdeportosalvo.pt', 'etiqueta': 'Sócios'},
  ],
  'horario': ['Dias úteis · 18:00 às 21:00', 'Sábados · 10:00 às 13:00'],
  'modalidades': [
    {'nome': 'Hóquei em patins', 'escaloes': 'Formação e seniores'},
    {'nome': 'Futsal', 'escaloes': 'Formação'},
    {'nome': 'Patinagem artística', 'escaloes': 'Todos os escalões'},
    {'nome': 'Ginástica', 'escaloes': 'Formação'},
  ],
  'redes': {
    'facebook': 'https://facebook.com/leoesdeportosalvo',
    'instagram': 'https://instagram.com/leoesdeportosalvo',
    'youtube': 'https://youtube.com/@leoesdeportosalvo',
  },
});
