import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/features/publico/noticias/noticias.dart';

void main() {
  _extras();

  test('notícia sem capa e com blocos de tipos desconhecidos ou malformados', () {
    final n = Noticia.fromJson({
      'slug': 'vitoria',
      'titulo': 'Vitória',
      'resumo': null,
      'categoria': {'slug': 'clube', 'nome': 'Clube', 'cor': null},
      'publicado_em': '2026-09-05 20:00:00',
      'corpo': [
        {'tipo': 'texto', 'html': '<p>Olá</p>'},
        {'tipo': 'tipo_novo', 'x': 1},
        {'sem_tipo': true},
        'lixo',
      ],
    });
    expect(n.capa, isNull);
    expect(n.categoria?.nome, 'Clube');
    expect(n.publicadoEm, DateTime(2026, 9, 5, 20));
    expect(n.corpo.map((b) => b['tipo']), ['texto', 'tipo_novo']);
  });
}

/// Etiquetas, "veja também" e relacionados — §4.20, desde 2026-09-21.
void _extras() {
  group('etiquetas e relacionados', () {
    Noticia lerCom(Map<String, dynamic> extra) => Noticia.fromJson({
      'slug': 'empate',
      'titulo': 'Empate na estreia',
      'corpo': const [],
      ...extra,
    });

    test('lê as etiquetas', () {
      final n = lerCom({
        'etiquetas': [
          {'slug': 'juniores', 'nome': 'Juniores'},
          {'slug': 'futsal', 'nome': 'Futsal'},
        ],
      });
      expect(n.etiquetas.map((e) => e.slug), ['juniores', 'futsal']);
      expect(n.etiquetas.first.nome, 'Juniores');
    });

    test('o "veja também" são notícias em forma de resumo', () {
      final n = lerCom({
        'relacionadas': [
          {'slug': 'outra', 'titulo': 'Outra notícia', 'publicado_em': '2026-09-18 12:45:56'},
        ],
      });
      expect(n.relacionadas.single.slug, 'outra');
      expect(n.relacionadas.single.publicadoEm?.day, 18);
    });

    test('um jogo relacionado mostra-se mas não leva a lado nenhum', () {
      final n = lerCom({
        'relacionados': [
          {
            'tipo': 'jogo',
            'id': 12,
            'titulo': 'Leões x Sassoeiros',
            'inicio': '2026-09-19 10:00:00',
            'local': 'Pavilhão Municipal',
          },
        ],
      });
      final r = n.relacionados.single;
      expect(r.id, '12'); // inteiro na API, texto cá dentro: é só uma chave
      expect(r.local, 'Pavilhão Municipal');
      expect(r.rota, isNull);
    });

    test('uma sessão de bilhética abre a bilheteira pelo uid', () {
      final n = lerCom({
        'relacionados': [
          {'tipo': 'sessao', 'id': '01J8ABC', 'titulo': 'Gala de Natal', 'estado': 'a_venda'},
        ],
      });
      expect(n.relacionados.single.rota, '/bilhetes/01J8ABC');
      expect(n.relacionados.single.estado, 'a_venda');
    });

    test('um tipo de relacionado desconhecido ignora-se, e o resto fica', () {
      final n = lerCom({
        'relacionados': [
          {'tipo': 'galeria', 'id': 9, 'titulo': 'Fotografias'},
          {'tipo': 'sessao', 'id': '01J8', 'titulo': 'Jantar'},
          'lixo',
          {'titulo': 'sem tipo nem id'},
        ],
      });
      // O desconhecido é lido (a lista é aberta), mas não inventa rota.
      expect(n.relacionados.map((r) => r.tipo), ['galeria', 'sessao']);
      expect(n.relacionados.first.rota, isNull);
    });

    test('um artigo sem nenhum dos campos novos continua a ler-se', () {
      final n = lerCom({});
      expect(n.etiquetas, isEmpty);
      expect(n.relacionadas, isEmpty);
      expect(n.relacionados, isEmpty);
      expect(n.titulo, 'Empate na estreia');
    });
  });

  test('o exemplo da demonstração cobre etiquetas, relacionados e veja também', () {
    final n = noticiaExemplo('vitoria-no-derby');
    expect(n.etiquetas, isNotEmpty);
    expect(n.relacionados.any((r) => r.rota != null), isTrue);
    expect(n.relacionadas, isNotEmpty);
    expect(n.relacionadas.every((r) => r.slug != n.slug), isTrue);
  });
}
