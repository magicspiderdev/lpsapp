import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/features/publico/noticias/noticias.dart';

void main() {
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
