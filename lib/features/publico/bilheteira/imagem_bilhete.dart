import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/formatos.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'bilheteira.dart';

/// O bilhete desenhado como imagem, para ir dentro da mensagem que se envia.
///
/// **Um QR sozinho não serve**: quem o recebe fica com um quadrado sem saber a
/// que jogo pertence nem a que horas é. Vai um bilhete inteiro — jogo, dia,
/// recinto, zona, o QR, o código por extenso e o aviso de que entra uma vez.
///
/// Desenha-se no `Canvas` e não a partir de um widget: não é preciso ter nada
/// no ecrã (partilha-se de qualquer sítio) e o resultado não depende do
/// tamanho do telemóvel nem da letra do sistema.
///
/// O fundo do QR é **branco nos dois modos**, como no ecrã: um QR invertido
/// não lê em todos os leitores da portaria.
Future<Uint8List?> imagemDoBilhete(BilheteComprado b) async {
  const largura = 1000.0;
  const margem = 72.0;
  const conteudo = largura - margem * 2;
  const qr = 560.0;

  final quando = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_PT').format(b.inicio);
  final hora = DateFormat('HH:mm').format(b.inicio);

  final titulo = _texto(b.titulo, conteudo, 46, FontWeight.w800, Colors.white, maxLinhas: 3);
  final subtitulo = b.subtitulo == null
      ? null
      : _texto(b.subtitulo!, conteudo, 28, FontWeight.w500, Colors.white.withValues(alpha: 0.88), maxLinhas: 2);

  final data = _texto('${quando[0].toUpperCase()}${quando.substring(1)} · $hora', conteudo, 30, FontWeight.w600, _tinta);
  final sitio = b.local == null ? null : _texto(b.local!, conteudo, 26, FontWeight.w400, _cinza, maxLinhas: 2);
  final lugar = _texto(
    [b.zona, ?b.lugar, b.preco == 0 ? 'Grátis' : euros(b.preco)].where((s) => s.isNotEmpty).join(' · '),
    conteudo,
    26,
    FontWeight.w400,
    _cinza,
  );
  final codigo = _texto(b.codigo, conteudo, 38, FontWeight.w700, _tinta, espaco: 3);
  final titular = b.titular == null ? null : _texto(b.titular!, conteudo, 24, FontWeight.w400, _cinza, maxLinhas: 1);
  final aviso = _texto(
    'Este código entra uma vez só. Mostre-o à entrada.',
    conteudo,
    24,
    FontWeight.w500,
    _cinza,
  );

  // A altura sai das medidas reais do texto: um título de três linhas não
  // pode ficar por cima do QR.
  final alturaCabecalho = margem + titulo.height + (subtitulo == null ? 0 : 10 + subtitulo.height) + margem * 0.7;
  var y = alturaCabecalho + 44;
  final yData = y;
  y += data.height + (sitio == null ? 0 : 6 + sitio.height) + 6 + lugar.height + 36;
  final yQr = y;
  y += qr + 28;
  final yCodigo = y;
  y += codigo.height + (titular == null ? 0 : 14 + titular.height) + 30 + aviso.height + margem;
  final altura = y;

  final gravador = ui.PictureRecorder();
  final canvas = Canvas(gravador, Rect.fromLTWH(0, 0, largura, altura));

  // Fundo branco, e não a superfície do tema: a imagem vai para fora da app,
  // onde não há modo escuro nenhum.
  canvas.drawRect(Rect.fromLTWH(0, 0, largura, altura), Paint()..color = Colors.white);

  // Cabeçalho com o verde do clube.
  final cabecalho = Rect.fromLTWH(0, 0, largura, alturaCabecalho);
  canvas.drawRect(
    cabecalho,
    Paint()..shader = AppColors.clubGradient.createShader(cabecalho),
  );
  canvas.drawParagraph(titulo, Offset(margem, margem));
  if (subtitulo != null) {
    canvas.drawParagraph(subtitulo, Offset(margem, margem + titulo.height + 10));
  }

  // Picotado, como no cartão da carteira.
  final tracejado = Paint()
    ..color = const Color(0xFFDFE2E6)
    ..strokeWidth = 3;
  for (var x = margem; x < largura - margem; x += 26) {
    canvas.drawLine(Offset(x, alturaCabecalho + 22), Offset(x + 13, alturaCabecalho + 22), tracejado);
  }

  canvas.drawParagraph(data, Offset(margem, yData));
  var yTexto = yData + data.height;
  if (sitio != null) {
    canvas.drawParagraph(sitio, Offset(margem, yTexto + 6));
    yTexto += 6 + sitio.height;
  }
  canvas.drawParagraph(lugar, Offset(margem, yTexto + 6));

  // O QR, centrado e sobre branco.
  canvas.save();
  canvas.translate((largura - qr) / 2, yQr);
  QrPainter(
    data: b.codigo,
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _qr),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _qr),
  ).paint(canvas, const Size(qr, qr));
  canvas.restore();

  canvas.drawParagraph(codigo, Offset(margem, yCodigo));
  var yFim = yCodigo + codigo.height;
  if (titular != null) {
    canvas.drawParagraph(titular, Offset(margem, yFim + 14));
    yFim += 14 + titular.height;
  }
  canvas.drawParagraph(aviso, Offset(margem, yFim + 30));

  final imagem = await gravador.endRecording().toImage(largura.toInt(), altura.toInt());
  try {
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    imagem.dispose();
  }
}

/// Os módulos do QR: escuros sobre branco, como no ecrã do bilhete.
const _qr = AppPalette.qrForeground;
const _tinta = AppPalette.grey900;
const _cinza = AppPalette.grey600;

ui.Paragraph _texto(
  String texto,
  double largura,
  double tamanho,
  FontWeight peso,
  Color cor, {
  double espaco = 0,
  int? maxLinhas,
}) {
  final construtor = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontFamily: AppTypography.family,
      fontSize: tamanho,
      fontWeight: peso,
      maxLines: maxLinhas,
      ellipsis: maxLinhas == null ? null : '…',
    ),
  )..pushStyle(ui.TextStyle(color: cor, letterSpacing: espaco, height: 1.25));
  construtor.addText(texto);
  final paragrafo = construtor.build()..layout(ui.ParagraphConstraints(width: largura));
  return paragrafo;
}
