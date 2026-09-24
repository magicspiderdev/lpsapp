/// A imagem que vai na partilha de um bilhete.
///
/// Desenha-se mesmo: um PNG que sai vazio, ou que rebenta com um título
/// comprido, só se descobria com o telemóvel na mão e a mensagem já enviada.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';
import 'package:lpsapp/features/publico/bilheteira/imagem_bilhete.dart';

BilheteComprado _bilhete({
  String titulo = 'Leões Porto Salvo x Portimonense',
  String? subtitulo = 'Liga Placard Futsal',
  String? local = 'Complexo Desportivo Leões de Porto Salvo',
  String zona = 'Sócios',
  String? lugar,
  String? titular = 'João Pedro Lopes Mendes',
  double preco = 0,
}) => BilheteComprado.fromJson({
  'id': 'B1',
  'codigo': 'LPS-7K3M-9QXA-2FHD',
  'titulo': titulo,
  'subtitulo': subtitulo,
  'local': local,
  'inicio': '2026-09-26 20:30:00',
  'zona': zona,
  'lugar': lugar,
  'preco': preco,
  'titular': titular,
  'estado': 'valido',
});

/// Um PNG começa sempre por esta assinatura.
const _assinaturaPng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Desenhar uma imagem é trabalho do motor, fora do relógio falso dos testes:
/// sem `runAsync` o `await` nunca voltaria.
Future<Uint8List?> _desenhar(WidgetTester t, BilheteComprado b) async =>
    (await t.runAsync<Uint8List?>(() => imagemDoBilhete(b)));

void main() {
  setUpAll(() => initializeDateFormatting('pt_PT'));

  testWidgets('desenha um PNG com o bilhete', (t) async {
    final bytes = await _desenhar(t, _bilhete());

    expect(bytes, isNotNull);
    expect(bytes!.take(8), _assinaturaPng);
    // Um PNG de um bilhete inteiro não cabe em dois quilobytes: se coubesse,
    // saiu branco.
    expect(bytes.length, greaterThan(4000));
  });

  testWidgets('um título de três linhas não fica por cima do QR', (t) async {
    // A altura sai das medidas do texto: com um título comprido a imagem tem
    // de crescer, não de sobrepor.
    final curto = await _desenhar(t, _bilhete(titulo: 'Leões x Oeiras', subtitulo: null, local: null));
    final comprido = await _desenhar(
      t,
      _bilhete(
        titulo: 'Clube Recreativo Leões de Porto Salvo x Associação Desportiva de Fundação de Oeiras e Carnaxide',
      ),
    );

    expect(curto, isNotNull);
    expect(comprido, isNotNull);
    expect(_altura(comprido!), greaterThan(_altura(curto!)));
  });

  testWidgets('sem local, sem titular e com lugar, desenha na mesma', (t) async {
    final bytes = await _desenhar(
      t,
      _bilhete(local: null, titular: null, subtitulo: null, lugar: 'Fila C, lugar 12', preco: 7.5),
    );
    expect(bytes, isNotNull);
    expect(bytes!.take(8), _assinaturaPng);
  });

  testWidgets('um bilhete quase vazio não rebenta o desenho', (t) async {
    final bytes = await _desenhar(
      t,
      BilheteComprado.fromJson({'id': 'B2', 'codigo': 'LPS-0000-0000-0000', 'titulo': '', 'zona': ''}),
    );
    expect(bytes, isNotNull);
  });
}

/// A altura vem do cabeçalho IHDR do PNG (bytes 20..23, big-endian).
int _altura(Uint8List png) => ByteData.sublistView(png, 20, 24).getUint32(0);
