import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Os traços de uma assinatura, em coordenadas do quadro. Cada traço é o
/// caminho de um dedo pousado até ser levantado.
class TracosAssinatura extends ChangeNotifier {
  final _tracos = <List<Offset>>[];
  Size _tamanho = Size.zero;

  List<List<Offset>> get tracos => List.unmodifiable(_tracos);

  /// Um toque só não é assinatura: é preciso haver um traço com comprimento.
  bool get vazia => !_tracos.any((t) => t.length > 1);

  void _comecar(Offset p) {
    _tracos.add([p]);
    notifyListeners();
  }

  void _continuar(Offset p) {
    if (_tracos.isEmpty) return;
    _tracos.last.add(p);
    notifyListeners();
  }

  void limpar() {
    _tracos.clear();
    notifyListeners();
  }

  /// A assinatura em PNG, com fundo transparente — vai para cima da linha de
  /// assinatura do PDF. Tinta sempre escura, mesmo no modo escuro: é papel.
  ///
  /// [larguraMaxima] mantém a imagem leve (o servidor recusa mais de ~600 kB,
  /// e uma assinatura não precisa de mais do que isto para se ler impressa).
  Future<Uint8List> png({double larguraMaxima = 900}) async {
    final base = _tamanho.isEmpty ? const Size(600, 200) : _tamanho;
    final escala = (larguraMaxima / base.width).clamp(1.0, 3.0);
    final gravador = ui.PictureRecorder();
    final canvas = Canvas(gravador)..scale(escala);
    pintarTracos(canvas, _tracos, cor: const Color(0xFF0B0D10));
    final imagem = await gravador.endRecording().toImage((base.width * escala).ceil(), (base.height * escala).ceil());
    try {
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      return dados!.buffer.asUint8List();
    } finally {
      imagem.dispose();
    }
  }
}

/// Desenha os traços com curvas pelos pontos médios, para a linha não sair aos
/// bicos quando o dedo corre depressa.
void pintarTracos(Canvas canvas, List<List<Offset>> tracos, {required Color cor, double espessura = 2.6}) {
  final tinta = Paint()
    ..color = cor
    ..strokeWidth = espessura
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  for (final t in tracos) {
    if (t.isEmpty) continue;
    if (t.length == 1) {
      canvas.drawCircle(t.first, espessura / 2, tinta..style = PaintingStyle.fill);
      tinta.style = PaintingStyle.stroke;
      continue;
    }
    final caminho = Path()..moveTo(t.first.dx, t.first.dy);
    for (var i = 1; i < t.length - 1; i++) {
      final meio = Offset((t[i].dx + t[i + 1].dx) / 2, (t[i].dy + t[i + 1].dy) / 2);
      caminho.quadraticBezierTo(t[i].dx, t[i].dy, meio.dx, meio.dy);
    }
    caminho.lineTo(t.last.dx, t.last.dy);
    canvas.drawPath(caminho, tinta);
  }
}

/// O quadro onde se assina com o dedo. Fundo claro de papel em qualquer tema,
/// com a linha e o "✕" de onde se assina.
///
/// Dentro de uma lista, assinar não pode fazer a lista andar: o quadro fica
/// com o dedo **logo ao pousar** ([_ArrastoImediato]). Com um
/// `GestureDetector` normal, um traço vertical perdia para o scroll — a lista
/// decide com menos movimento do que o arrastar em todas as direcções.
class QuadroAssinatura extends StatefulWidget {
  const QuadroAssinatura({super.key, required this.tracos, this.altura = 200});

  final TracosAssinatura tracos;
  final double altura;

  @override
  State<QuadroAssinatura> createState() => _QuadroAssinaturaState();
}

class _QuadroAssinaturaState extends State<QuadroAssinatura> {
  static const _papel = Color(0xFFFDFDFB);
  static const _tinta = Color(0xFF0B0D10);
  static const _guia = Color(0xFF84878D);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Quadro de assinatura. Assine com o dedo.',
      child: LayoutBuilder(
        builder: (context, limites) {
          widget.tracos._tamanho = Size(limites.maxWidth, widget.altura);
          return Container(
            height: widget.altura,
            decoration: BoxDecoration(
              color: _papel,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: c.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _ArrastoImediato: GestureRecognizerFactoryWithHandlers<_ArrastoImediato>(
                  _ArrastoImediato.new,
                  (r) => r
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = ((d) => widget.tracos._comecar(d.localPosition))
                    ..onUpdate = ((d) => widget.tracos._continuar(d.localPosition)),
                ),
              },
              child: ListenableBuilder(
                listenable: widget.tracos,
                builder: (context, _) => CustomPaint(
                  size: Size(limites.maxWidth, widget.altura),
                  painter: _PintorAssinatura(widget.tracos.tracos),
                  foregroundPainter: const _PintorGuia(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Um arrastar em todas as direcções que ganha ao pousar o dedo, sem esperar
/// que os outros (o scroll da lista) desistam.
class _ArrastoImediato extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _PintorAssinatura extends CustomPainter {
  const _PintorAssinatura(this.tracos);

  final List<List<Offset>> tracos;

  @override
  void paint(Canvas canvas, Size size) => pintarTracos(canvas, tracos, cor: _QuadroAssinaturaState._tinta);

  // Os traços mudam dentro da mesma lista: desenha-se sempre que o quadro avisa.
  @override
  bool shouldRepaint(_PintorAssinatura old) => true;
}

/// A linha de base e o "✕". Não entram no PNG — só servem para orientar.
class _PintorGuia extends CustomPainter {
  const _PintorGuia();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - AppSpacing.xxl;
    final linha = Paint()
      ..color = _QuadroAssinaturaState._guia.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(AppSpacing.xl, y), Offset(size.width - AppSpacing.xl, y), linha);
    final x = TextPainter(
      text: const TextSpan(
        text: '✕',
        style: TextStyle(color: _QuadroAssinaturaState._guia, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    x.paint(canvas, Offset(AppSpacing.xl, y - x.height - AppSpacing.xs));
  }

  @override
  bool shouldRepaint(_PintorGuia old) => false;
}
