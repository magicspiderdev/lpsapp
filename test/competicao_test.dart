import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/features/publico/agenda/agenda.dart';
import 'package:lpsapp/features/publico/agenda/agenda_widgets.dart';
import 'package:lpsapp/features/publico/competicao/competicao.dart';

/// Competição (guia §4.19): as provas de uma época e os jogos do clube.
///
/// O que estes testes fixam é o que o contrato promete e o ecrã precisa: a
/// época vem do servidor, as contagens são só de jogos do clube, e um jogo já
/// jogado sem resultado continua a ser um jogo já jogado.
void main() {
  group('prova', () {
    test('lê o slug, o formato, a modalidade e as contagens', () {
      final p = Prova.fromJson({
        'slug': 'liga-placard-futsal-2026-27',
        'nome': 'Liga Placard Futsal',
        'epoca': '2026-27',
        'formato': 'liga',
        'genero': 'masculino',
        'url_externo': null,
        'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
        'jogos': {'total': 22, 'realizados': 9, 'proximos': 13},
      });
      expect(p.slug, 'liga-placard-futsal-2026-27');
      expect(p.modalidadeSlug, 'futsal');
      expect(p.realizados, 9);
      expect(p.proximos, 13);
      expect(p.legenda, 'Liga · Futsal · masculino');
    });

    test('formato desconhecido não rebenta nem inventa etiqueta', () {
      final p = Prova.fromJson({
        'slug': 'supertaca-2026-27',
        'nome': 'Supertaça',
        'epoca': '2026-27',
        'formato': 'supertaca',
        'modalidade': {'slug': 'futsal', 'nome': 'Futsal'},
      });
      expect(p.formato, 'supertaca');
      expect(p.legenda, 'Futsal');
      expect(p.total, 0);
    });

    test('sem modalidade configurada no backoffice, a prova continua legível', () {
      final p = Prova.fromJson({'slug': 'taca-2026-27', 'nome': 'Taça', 'epoca': '2026-27', 'formato': 'taca'});
      expect(p.modalidade, isNull);
      expect(p.legenda, 'Taça');
    });
  });

  group('provas da época', () {
    test('a época actual vem do servidor, e as épocas para o histórico', () {
      final p = Provas.fromJson({
        'epoca_actual': '2026-27',
        'epoca': '2025-26',
        'epocas': ['2026-27', '2025-26'],
        'provas': [
          {'slug': 'liga-2025-26', 'nome': 'Liga', 'epoca': '2025-26', 'formato': 'liga'},
        ],
      });
      expect(p.epocaActual, '2026-27');
      expect(p.epoca, '2025-26');
      expect(p.epocas, ['2026-27', '2025-26']);
      expect(p.provas.single.slug, 'liga-2025-26');
    });

    test('época sem provas devolve lista vazia, não erro', () {
      final p = Provas.fromJson({'epoca_actual': '2026-27', 'epoca': '2019-20', 'epocas': [], 'provas': []});
      expect(p.provas, isEmpty);
      expect(p.epoca, '2019-20');
    });
  });

  group('página de uma prova', () {
    test('realizados e próximos vêm na forma da agenda', () {
      final d = ProvaDetalhe.fromJson({
        'prova': {'slug': 'liga-2026-27', 'nome': 'Liga', 'epoca': '2026-27', 'formato': 'liga'},
        'realizados': [
          {
            'tipo': 'jogo',
            'id': 12,
            'titulo': 'Leões x Sassoeiros',
            'inicio': '2026-09-19 10:00:00',
            'estado': 'terminado',
            'prova': {'slug': 'liga-2026-27', 'nome': 'Liga', 'jornada': 2},
            'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
            'equipa_fora': {'nome': 'Sassoeiros'},
            'resultado': {'casa': 4, 'fora': 1},
          },
        ],
        'proximos': [
          {
            'tipo': 'jogo',
            'id': 13,
            'titulo': 'Portimonense x Leões',
            'inicio': '2026-09-26 20:30:00',
            'estado': 'agendado',
            'prova': {'slug': 'liga-2026-27', 'nome': 'Liga', 'jornada': 3},
            'equipa_casa': {'nome': 'Portimonense'},
            'equipa_fora': {'nome': 'Leões Porto Salvo', 'do_clube': true},
          },
        ],
      });

      expect(d.prova.nome, 'Liga');
      expect(d.realizados.single.temResultado, isTrue);
      expect(d.realizados.single.casa?.doClube, isTrue);
      expect(d.proximos.single.jornada, 3);
      expect(d.proximos.single.temResultado, isFalse);
    });

    test('jogo já jogado sem resultado registado continua nos realizados', () {
      final d = ProvaDetalhe.fromJson({
        'prova': {'slug': 'liga-2026-27', 'nome': 'Liga', 'epoca': '2026-27'},
        'realizados': [
          {'tipo': 'jogo', 'id': 14, 'titulo': 'Leões x Oeiras', 'inicio': '2026-09-20 18:00:00', 'resultado': null},
        ],
      });
      expect(d.realizados, hasLength(1));
      expect(d.realizados.single.temResultado, isFalse);
      expect(d.proximos, isEmpty);
    });

    test('prova em falta na resposta não rebenta a leitura', () {
      final d = ProvaDetalhe.fromJson({'realizados': [], 'proximos': []});
      expect(d.prova.slug, '');
      expect(d.realizados, isEmpty);
    });
  });

  group('ficha de um jogo', () {
    test('uma linha lê o que aconteceu, de que lado, e o marcador já contado', () {
      final l = LinhaFicha.fromJson({
        'tipo': 'golo',
        'minuto': 12,
        'equipa': 'casa',
        'atleta': 'Tiago',
        'assistencia': 'Miguel',
        'atleta_saiu': null,
        'texto': null,
        'marcador': {'casa': 1, 'fora': 0},
      });
      expect(l.minuto, 12);
      expect(l.daCasa, isTrue);
      expect(l.daFora, isFalse);
      expect(l.assistencia, 'Miguel');
      expect(l.marcadorCasa, 1);
      expect(l.alteraMarcador, isTrue);
    });

    test('o marcador de um autogolo vem do servidor, não se conta cá', () {
      // A regra (conta para a outra equipa) é do lado de lá, de propósito.
      final l = LinhaFicha.fromJson({
        'tipo': 'autogolo',
        'minuto': 41,
        'equipa': 'fora',
        'atleta': 'André',
        'marcador': {'casa': 2, 'fora': 2},
      });
      expect(l.daFora, isTrue);
      expect(l.marcadorCasa, 2);
      expect(l.alteraMarcador, isTrue);
    });

    test('uma linha que não é golo não anuncia marcador novo', () {
      final l = LinhaFicha.fromJson({'tipo': 'amarelo', 'minuto': 18, 'equipa': 'casa', 'atleta': 'Rui'});
      expect(l.alteraMarcador, isFalse);
      // Sem `marcador` na resposta, fica 0-0 em vez de rebentar.
      expect((l.marcadorCasa, l.marcadorFora), (0, 0));
    });

    test('uma nota escrita depois do jogo não tem minuto nem equipa', () {
      final l = LinhaFicha.fromJson({
        'tipo': 'relato',
        'texto': 'Jogo decidido nos últimos dez minutos.',
        'marcador': {'casa': 2, 'fora': 3},
      });
      expect(l.minuto, isNull);
      expect(l.daCasa, isFalse);
      expect(l.daFora, isFalse);
      expect(l.texto, isNotNull);
    });

    test('um tipo que a app não conhece continua a ser lido', () {
      // A lista é aberta: quem decide ignorar é o ecrã, não a leitura.
      final l = LinhaFicha.fromJson({'tipo': 'tempo_morto', 'minuto': 30, 'marcador': {'casa': 0, 'fora': 1}});
      expect(l.tipo, 'tempo_morto');
      expect(l.alteraMarcador, isFalse);
    });

    test('o jogo traz árbitro, assistência e ficha; sem ficha é lista vazia, não erro', () {
      final d = JogoComFicha.fromJson({
        'jogo': {
          'tipo': 'jogo',
          'id': 12,
          'titulo': 'Leões x Sassoeiros',
          'inicio': '2026-09-19 10:00:00',
          'estado': 'terminado',
          'arbitro': 'António Silva',
          'espectadores': 340,
          'equipa_casa': {'nome': 'Leões Porto Salvo', 'do_clube': true},
          'equipa_fora': {'nome': 'Sassoeiros'},
          'resultado': {'casa': 4, 'fora': 1},
        },
        'ficha': [],
      });
      expect(d.jogo.arbitro, 'António Silva');
      expect(d.jogo.espectadores, 340);
      expect(d.ficha, isEmpty);
    });

    test('jogo em falta na resposta não rebenta a leitura', () {
      final d = JogoComFicha.fromJson({'ficha': []});
      expect(d.jogo.id, 'null');
      expect(d.ficha, isEmpty);
    });

    test('as listagens dizem onde há ficha, para não se pedir jogo a jogo', () {
      final com = ItemAgenda.fromJson({'tipo': 'jogo', 'id': 1, 'titulo': 'A', 'tem_ficha': true});
      final sem = ItemAgenda.fromJson({'tipo': 'jogo', 'id': 2, 'titulo': 'B'});
      expect(com.temFicha, isTrue);
      expect(sem.temFicha, isFalse);
    });
  });

  group('próximos e anteriores', () {
    ItemAgenda jogo(String titulo, DateTime inicio, {Map<String, dynamic>? resultado}) => ItemAgenda.fromJson({
      'tipo': 'jogo',
      'id': titulo.hashCode,
      'titulo': titulo,
      'inicio': inicio.toIso8601String(),
      'resultado': resultado,
    });

    final agora = DateTime(2026, 9, 21, 12);

    test('o corte é pela data: um jogo de ontem sem resultado é um jogo anterior', () {
      final (proximos, anteriores) = separarPorTempo([
        jogo('ontem, por registar', agora.subtract(const Duration(days: 1))),
        jogo('logo à noite', agora.add(const Duration(hours: 8))),
      ], agora: agora);

      expect(proximos.map((j) => j.titulo), ['logo à noite']);
      expect(anteriores.map((j) => j.titulo), ['ontem, por registar']);
      expect(anteriores.single.temResultado, isFalse);
    });

    test('os próximos vêm do mais perto, os anteriores do mais recente', () {
      final (proximos, anteriores) = separarPorTempo([
        jogo('daqui a três dias', agora.add(const Duration(days: 3))),
        jogo('há cinco dias', agora.subtract(const Duration(days: 5))),
        jogo('amanhã', agora.add(const Duration(days: 1))),
        jogo('anteontem', agora.subtract(const Duration(days: 2))),
      ], agora: agora);

      expect(proximos.map((j) => j.titulo), ['amanhã', 'daqui a três dias']);
      expect(anteriores.map((j) => j.titulo), ['anteontem', 'há cinco dias']);
    });

    test('um jogo a começar neste instante conta como próximo', () {
      final (proximos, anteriores) = separarPorTempo([jogo('agora', agora)], agora: agora);
      expect(proximos, hasLength(1));
      expect(anteriores, isEmpty);
    });

    test('sem jogos, as duas listas ficam vazias', () {
      final (proximos, anteriores) = separarPorTempo(const [], agora: agora);
      expect(proximos, isEmpty);
      expect(anteriores, isEmpty);
    });
  });

  group('exemplos da demonstração', () {
    test('a época actual traz provas de mais do que uma modalidade', () {
      final p = provasExemplo(null);
      expect(p.epoca, p.epocaActual);
      expect(p.provas.map((e) => e.modalidadeSlug).toSet().length, greaterThan(1));
    });

    test('uma época antiga traz só jogos já realizados', () {
      final p = provasExemplo('2025-26');
      expect(p.epoca, '2025-26');
      expect(p.provas.every((e) => e.proximos == 0), isTrue);
    });

    test('só um jogo já jogado tem ficha', () {
      final jogos = agendaExemplo.where((j) => j.tipo == TipoItem.jogo);
      final jogado = jogos.firstWhere((j) => j.temResultado);
      final porJogar = jogos.firstWhere((j) => !j.temResultado);
      expect(jogoExemplo(jogado.id).ficha, isNotEmpty);
      expect(jogoExemplo(porJogar.id).ficha, isEmpty);
    });

    test('a ficha de exemplo acaba no resultado oficial do jogo', () {
      final jogado = agendaExemplo.firstWhere((j) => j.temResultado);
      final ultima = jogoExemplo(jogado.id).ficha.last;
      expect((ultima.marcadorCasa, ultima.marcadorFora), (jogado.golosCasa, jogado.golosFora));
    });

    test('o detalhe de exemplo reaproveita os jogos da agenda', () {
      final d = provaExemplo('campeonato-nacional-hoquei-2026-27');
      expect(d.prova.nome, 'Campeonato Nacional');
      expect([...d.realizados, ...d.proximos].every((j) => j.tipo == TipoItem.jogo), isTrue);
    });
  });
}
