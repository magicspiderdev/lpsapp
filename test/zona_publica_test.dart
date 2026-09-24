import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/features/publico/agenda/agenda.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';
import 'package:lpsapp/features/publico/clube/clube.dart';

/// Agenda, bilheteira e clube: a API pública já existe (guia §4.17), menos a
/// carteira de bilhetes, que agora vem de `/api/v2/me/bilhetes` (§4.18).
void main() {
  group('bilhetes comprados', _bilhetesComprados);
  _bilheteira2();
  _compraComVariosBilhetes();

  group('agenda', () {
    test('jogo com resultado, equipa do clube e bilhetes', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'jogo',
        'id': 812,
        'titulo': 'Benfica x Leões',
        'inicio': '2026-09-15 19:00:00',
        'estado': 'terminado',
        'modalidade': {'nome': 'Hóquei em patins'},
        'prova': {'nome': 'Nacional'},
        'recinto': 'Pavilhão da Luz',
        'equipa_casa': {'nome': 'SL Benfica'},
        'equipa_fora': {'nome': 'Leões Porto Salvo', 'do_clube': true},
        'resultado': {'casa': 2, 'fora': 3},
        'bilhetes': {'sessao': 'S9'},
      });
      expect(i.tipo, TipoItem.jogo);
      expect(i.terminado, isTrue);
      expect(i.temResultado, isTrue);
      expect(i.fora?.doClube, isTrue);
      expect(i.local, 'Pavilhão da Luz');
      expect(i.sessaoBilhetes, 'S9');
    });

    test('hora por confirmar e tipo desconhecido não rebentam', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'gala',
        'id': 5,
        'titulo': 'Gala do clube',
        'inicio': '2026-10-01 00:00:00',
        'hora_confirmada': false,
      });
      expect(i.tipo, TipoItem.desconhecido);
      expect(i.horaConfirmada, isFalse);
      expect(i.estado, 'agendado');
      expect(i.temBilhetes, isFalse);
    });

    test('a lista vem em data.itens, e o que não for um item ignora-se', () {
      final itens = itensDaAgenda({
        'de': '2026-09-14',
        'ate': '2026-11-20',
        'itens': [
          {'tipo': 'jogo', 'id': 1, 'titulo': 'Um jogo', 'inicio': '2026-09-26 20:30:00'},
          'lixo',
          {'tipo': 'evento', 'id': 2, 'titulo': 'Um evento', 'inicio': '2026-09-27 21:00:00'},
        ],
      });
      expect(itens.map((i) => i.titulo), ['Um jogo', 'Um evento']);
    });

    test('sem itens (ou com a chave em falta) devolve lista vazia', () {
      expect(itensDaAgenda({'de': '2026-09-14', 'ate': '2026-11-20'}), isEmpty);
    });

    test('prova e modalidade trazem slug e jornada', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'jogo',
        'id': 3,
        'titulo': 'Leões x Portimonense',
        'inicio': '2026-09-26 20:30:00',
        'prova': {'slug': 'liga-placard-futsal-2026-27', 'nome': 'Liga Placard Futsal', 'jornada': 3},
        'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
      });
      expect(i.provaSlug, 'liga-placard-futsal-2026-27');
      expect(i.modalidadeSlug, 'futsal');
      expect(i.provaComJornada, 'Liga Placard Futsal · 3.ª jornada');
    });

    test('prova sem jornada mostra só o nome', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'jogo',
        'id': 4,
        'titulo': 'Torneio',
        'inicio': '2026-09-26 20:30:00',
        'prova': {'slug': 'torneio-2026-27', 'nome': 'Torneio regional'},
      });
      expect(i.provaComJornada, 'Torneio regional');
      expect(i.jornada, isNull);
    });

    test('evento traz slug, fim e descrição', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'evento',
        'id': 7,
        'slug': 'jantar-de-natal',
        'titulo': 'Jantar de Natal',
        'inicio': '2026-12-02 20:00:00',
        'fim': '2026-12-02 23:30:00',
        'descricao': 'Na sede, com lugares limitados.',
        'estado': 'cancelado',
      });
      expect(i.slug, 'jantar-de-natal');
      expect(i.fim?.hour, 23);
      expect(i.descricao, isNotNull);
      // Um evento cancelado continua na agenda: mostra-se com aviso.
      expect(i.cancelado, isTrue);
    });

    test('exemplos da demonstração cobrem jogo, evento e resultado', () {
      expect(agendaExemplo.any((i) => i.tipo == TipoItem.jogo), isTrue);
      expect(agendaExemplo.any((i) => i.tipo == TipoItem.evento), isTrue);
      expect(agendaExemplo.any((i) => i.temResultado), isTrue);
    });
  });

  group('bilheteira', () {
    test('sessão com zonas, preço desde e esgotado', () {
      final s = Sessao.fromJson({
        'id': 'S1',
        'titulo': 'Jogo',
        'inicio': '2026-09-20 21:00:00',
        'preco_desde': 5,
        'esgotado': false,
        'zonas': [
          {'id': 'Z1', 'nome': 'Central', 'preco': 10},
          {'id': 'Z2', 'nome': 'Criança', 'preco': 0, 'disponivel': false},
        ],
      });
      expect(s.precoDesde, 5.0);
      expect(s.zonas.first.disponivel, isTrue);
      expect(s.zonas.last.preco, 0.0);
      expect(s.zonas.last.disponivel, isFalse);
    });

    test('resposta de produção: id ULID, zonas com id numérico e exige_socio', () {
      final s = Sessao.fromJson({
        'id': '01M2X7Y601VARR4JF5NPXYFGFS',
        'titulo': 'Jantar Natal',
        'subtitulo': null,
        'inicio': '2026-12-05 20:00:00',
        'local': 'Complexo Desportivo Leões de Porto Salvo',
        'capa': null,
        'estado': 'a_venda',
        'id_jogo': null,
        'id_evento': null,
        'esgotado': false,
        'preco_desde': 12.5,
        'zonas': [
          {'id': 1, 'nome': 'Adultos', 'preco': 20, 'disponivel': true, 'exige_socio': false, 'nota': null},
          {'id': 2, 'nome': 'Sócios', 'preco': 15, 'disponivel': true, 'exige_socio': true, 'nota': null},
        ],
      });
      expect(s.aVenda, isTrue);
      expect(s.motivoFechada, isNull);
      expect(s.capaUrl, isNull);
      expect(s.zonas.first.id, '1');
      expect(s.zonas.last.exigeSocio, isTrue);
    });

    test('sessão cancelada, encerrada, esgotada ou de estado desconhecido não está à venda', () {
      Sessao comEstado(String estado, {bool esgotado = false}) => Sessao.fromJson({
        'id': 'x',
        'titulo': 'x',
        'inicio': '2026-12-05 20:00:00',
        'estado': estado,
        'esgotado': esgotado,
      });
      expect(comEstado('cancelada').motivoFechada, 'Sessão cancelada');
      expect(comEstado('encerrada').motivoFechada, 'Venda encerrada');
      expect(comEstado('a_venda', esgotado: true).motivoFechada, 'Esgotado');
      expect(comEstado('suspensa').aVenda, isFalse);
    });
  });

  group('clube', () {
    test('lê contactos, horário, modalidades e redes', () {
      final c = clubeExemplo;
      expect(c.fundadoEm, 1972);
      expect(c.contactos.any((x) => x.tipo == 'telefone'), isTrue);
      expect(c.horario, isNotEmpty);
      expect(c.modalidades.first.nome, isNotEmpty);
      expect(c.redes.keys, contains('facebook'));
    });

    test('resposta de produção quase vazia: modalidades, redes como lista vazia', () {
      final c = Clube.fromJson({
        'nome': null,
        'fundado_em': null,
        'historia': '',
        'contactos': [],
        'horario': [],
        'redes': [],
        'modalidades': [
          {'slug': 'futsal', 'nome': 'Futsal', 'escaloes': 'Todos', 'descricao': null},
        ],
      });
      expect(c.nome, isNull);
      expect(c.historia, isNull); // texto vazio conta como não preenchido
      expect(c.redes, isEmpty);
      expect(c.semInformacao, isTrue);
      expect(c.modalidades.single.slug, 'futsal');
    });

    test('tem_pagina e historia_html, como vêm de produção', () {
      final c = Clube.fromJson({
        'historia': 'Uma história\n\nMais texto',
        'historia_html': '<h2>Uma história</h2><p>Mais texto</p>',
        'modalidades': [
          {'slug': 'futebol', 'nome': 'Futebol', 'escaloes': null, 'descricao': null, 'tem_pagina': true},
          {'slug': 'futsal', 'nome': 'Futsal', 'tem_pagina': false},
          {'nome': 'Sem slug', 'tem_pagina': true}, // sem slug não há página para abrir
        ],
      });
      expect(c.historiaHtml, startsWith('<h2>'));
      expect([for (final m in c.modalidades) m.temPagina], [true, false, false]);
    });

    test('página de uma modalidade: blocos desconhecidos passam, a app ignora-os ao desenhar', () {
      final p = PaginaModalidade.fromJson({
        'slug': 'futebol',
        'nome': 'Futebol',
        'corpo': [
          {'tipo': 'texto', 'html': '<p>Olá</p>'},
          {'tipo': 'mapa', 'local': 'Campo', 'url': 'https://www.google.com/maps/search/?api=1&query=Campo'},
          {'tipo': 'tipo_que_ainda_nao_existe'},
          'lixo',
        ],
      });
      expect(p.modalidade.temPagina, isTrue);
      expect([for (final b in p.corpo) b['tipo']], ['texto', 'mapa', 'tipo_que_ainda_nao_existe']);
    });

    test('campos em falta ficam nulos, sem rebentar', () {
      final c = Clube.fromJson({'nome': 'Clube'});
      expect(c.fundadoEm, isNull);
      expect(c.contactos, isEmpty);
      expect(c.redes, isEmpty);
    });
  });
}

/// Bilhetes comprados (a carteira): o código é a credencial que a portaria lê.
void _bilhetesComprados() {
  test('bilhete válido e bilhete usado', () {
    final b = BilheteComprado.fromJson({
      'id': 'B1',
      'codigo': 'LPS-2026-0001-8F3A',
      'titulo': 'Jogo',
      'zona': 'Sócio',
      'inicio': '2026-09-18 21:00:00',
      'preco': 5,
      'estado': 'VALIDO',
      'titular': 'João',
    });
    expect(b.valido, isTrue);
    expect(b.usado, isFalse);
    expect(b.codigo, 'LPS-2026-0001-8F3A');

    final usado = BilheteComprado.fromJson({'id': 'B3', 'titulo': 'x', 'zona': 'y', 'estado': 'usado'});
    expect(usado.usado, isTrue);
    expect(usado.valido, isFalse);
  });

  test('estado desconhecido não conta como válido', () {
    final b = BilheteComprado.fromJson({'id': 'B4', 'titulo': 'x', 'zona': 'y', 'estado': 'reembolsado'});
    expect(b.valido, isFalse);
  });

  test('exemplos têm bilhetes por usar e um já usado', () {
    expect(bilhetesExemplo.where((b) => b.valido).length, greaterThan(1));
    expect(bilhetesExemplo.any((b) => b.usado), isTrue);
    expect(bilhetesExemplo.every((b) => b.codigo.isNotEmpty), isTrue);
  });
}

/// Zonas e carteira, como vêm desde 2026-09-22 (§4.17 e §4.18).
void _bilheteira2() {
  group('zona: onde e por quem se compra', () {
    test('zona da app traz limite do servidor', () {
      final z = Zona.fromJson({
        'id': 12,
        'nome': 'Bancada central',
        'preco': 7.5,
        'venda': 'app',
        'url_compra': null,
        'max_por_conta': 4,
        'exige_socio': false,
      });
      expect(z.naApp, isTrue);
      expect(z.gratuita, isFalse);
      expect(z.maximo, 4);
      // Paga já não implica sócio: é só o que o clube marcar.
      expect(z.exigeSocio, isFalse);
    });

    test('zona externa não se compra na app e abre o url', () {
      final z = Zona.fromJson({
        'id': 13,
        'nome': 'Bilheteira BOL',
        'preco': 12,
        'venda': 'externa',
        'url_compra': 'https://bol.pt/x',
        'max_por_conta': null,
      });
      expect(z.naApp, isFalse);
      expect(z.urlCompra, 'https://bol.pt/x');
    });

    test('venda desconhecida trata-se como "não se compra aqui"', () {
      final z = Zona.fromJson({'id': 1, 'nome': 'X', 'preco': 5, 'venda': 'balcao'});
      expect(z.naApp, isFalse);
    });

    test('sem max_por_conta usa o limite do seletor', () {
      final z = Zona.fromJson({'id': 1, 'nome': 'X', 'preco': 0});
      expect(z.gratuita, isTrue);
      expect(z.maximo, maxBilhetesPorZona);
    });
  });

  group('carteira', () {
    test('um bilhete traz a sessão, a encomenda e o estado da sessão', () {
      final b = BilheteComprado.fromJson({
        'id': '01J9',
        'codigo': 'LPS-7K3M-9QXA-2FHD',
        'sessao': '01J8',
        'encomenda': '01JA',
        'titulo': 'Jantar de Natal',
        'inicio': '2026-12-02 20:00:00',
        'zona': 'Adulto',
        'preco': 20,
        'titular': 'João Mendes',
        'estado': 'valido',
        'sessao_estado': 'a_venda',
      });
      expect(b.sessao, '01J8');
      expect(b.encomenda, '01JA');
      expect(b.sessaoEstado, 'a_venda');
      expect(b.valido, isTrue);
    });

    test('sessão cancelada anula o bilhete', () {
      final b = BilheteComprado.fromJson({
        'id': '1',
        'codigo': 'LPS-1',
        'titulo': 'X',
        'inicio': '2026-12-02 20:00:00',
        'zona': 'A',
        'preco': 0,
        'estado': 'anulado',
        'sessao_estado': 'cancelada',
      });
      expect(b.anulado, isTrue);
      expect(b.valido, isFalse);
    });

    test('estado desconhecido não conta como válido', () {
      final b = BilheteComprado.fromJson({
        'id': '1',
        'codigo': 'LPS-1',
        'titulo': 'X',
        'inicio': '2026-12-02 20:00:00',
        'zona': 'A',
        'preco': 0,
        'estado': 'devolvido',
      });
      expect(b.valido, isFalse);
      expect(b.usado, isFalse);
      expect(b.anulado, isFalse);
    });
  });
}

/// Bilhetes do mesmo evento: é o que o cartão da carteira junta e o que o
/// swipe percorre.
void _compraComVariosBilhetes() {
  BilheteComprado bilhete(
    String id, {
    String? encomenda,
    String? sessao,
    String zona = 'Adulto',
    String estado = 'valido',
    String inicio = '2026-12-02 20:00:00',
    String titulo = 'Jogo',
  }) => BilheteComprado.fromJson({
    'id': id,
    'codigo': 'LPS-$id',
    'titulo': titulo,
    'inicio': inicio,
    'zona': zona,
    'preco': 10,
    'estado': estado,
    'encomenda': encomenda,
    'sessao': sessao,
  });

  group('agrupar por evento', () {
    test('dois bilhetes do mesmo jogo são um cartão, não dois', () {
      final grupos = agruparPorEvento([
        bilhete('1', encomenda: 'E1', sessao: 'S1'),
        bilhete('2', encomenda: 'E1', sessao: 'S1'),
      ]);
      expect(grupos, hasLength(1));
      expect(grupos.single.quantos, 2);
      expect(grupos.single.bilhetes.map((b) => b.id), ['1', '2']);
    });

    test('duas compras para o mesmo jogo continuam a ser um jogo', () {
      // É o caso normal desde que a compra é de uma zona: um bilhete de sócio
      // e um de convidado para o mesmo jogo são duas encomendas.
      final grupos = agruparPorEvento([
        bilhete('1', encomenda: 'E1', sessao: 'S1', zona: 'Sócios'),
        bilhete('2', encomenda: 'E2', sessao: 'S1', zona: 'Não sócios'),
      ]);
      expect(grupos, hasLength(1));
      expect(grupos.single.zonas, '1 Sócios · 1 Não sócios');
    });

    test('jogos diferentes ficam em cartões diferentes', () {
      final grupos = agruparPorEvento([
        bilhete('1', sessao: 'S1'),
        bilhete('2', sessao: 'S2', titulo: 'Outro jogo'),
      ]);
      expect(grupos, hasLength(2));
    });

    test('sem sessão, a compra é o palpite seguinte — e nunca junta tudo', () {
      final grupos = agruparPorEvento([
        bilhete('1', encomenda: 'E1'),
        bilhete('2', encomenda: 'E1'),
        bilhete('3', encomenda: 'E2'),
      ]);
      expect(grupos.map((g) => g.quantos), [2, 1]);
    });

    test('sem sessão nem compra, cada bilhete fica por si', () {
      final grupos = agruparPorEvento([bilhete('1'), bilhete('2')]);
      expect(grupos, hasLength(2));
    });

    test('cada bilhete do grupo tem o seu código', () {
      final grupo = agruparPorEvento([
        bilhete('1', sessao: 'S1'),
        bilhete('2', sessao: 'S1'),
      ]).single;
      expect(grupo.bilhetes[0].codigo, isNot(grupo.bilhetes[1].codigo));
    });

    test('uma zona só aparece uma vez quando os bilhetes são todos dela', () {
      final grupo = agruparPorEvento([
        bilhete('1', sessao: 'S1', zona: 'Sócios'),
        bilhete('2', sessao: 'S1', zona: 'Sócios'),
      ]).single;
      expect(grupo.zonas, 'Sócios');
      expect(grupo.total, 20);
    });

    test('meio usados: o que interessa à porta é quantos faltam', () {
      final grupo = agruparPorEvento([
        bilhete('1', sessao: 'S1'),
        bilhete('2', sessao: 'S1', estado: 'usado'),
      ]).single;
      expect(grupo.quantos, 2);
      expect(grupo.porUsar, 1);
      expect(grupo.todosUsados, isFalse);
    });

    test('todos usados diz-se de uma vez', () {
      final grupo = agruparPorEvento([
        bilhete('1', sessao: 'S1', estado: 'usado'),
        bilhete('2', sessao: 'S1', estado: 'anulado'),
      ]).single;
      expect(grupo.todosUsados, isTrue);
      expect(grupo.porUsar, 0);
    });
  });
}
