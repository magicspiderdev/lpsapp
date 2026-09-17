import 'package:flutter/material.dart';

import '../tema/tema.dart';
import 'imagem_rede.dart';

/// Superfície branca arredondada onde vivem as listas e os resumos.
class Bloco extends StatelessWidget {
  const Bloco({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(Tema.raio),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Título de secção pequeno, por cima de um [Bloco].
class TituloSeccao extends StatelessWidget {
  const TituloSeccao(this.texto, {super.key, this.accao});

  final String texto;
  final Widget? accao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: tema.textTheme.titleMedium)),
          ?accao,
        ],
      ),
    );
  }
}

/// Botão circular com legenda — a fila de acções rápidas.
class AccaoRedonda extends StatelessWidget {
  const AccaoRedonda({
    super.key,
    required this.icone,
    required this.legenda,
    required this.onTap,
    this.sobreEscuro = false,
  });

  final IconData icone;
  final String legenda;
  final VoidCallback onTap;

  /// Em cima do gradiente do clube: vidro claro em vez de superfície.
  final bool sobreEscuro;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fundo = sobreEscuro ? Colors.white.withValues(alpha: 0.16) : c.surfaceContainerLowest;
    final frente = sobreEscuro ? Colors.white : c.onSurface;

    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Material(
            color: fundo,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(dimension: 52, child: Icon(icone, color: frente, size: 24)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            legenda,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: frente),
          ),
        ],
      ),
    );
  }
}

/// Ícone numa pastilha arredondada, à esquerda das linhas de lista.
class IconePastilha extends StatelessWidget {
  const IconePastilha(this.icone, {super.key, this.cor});

  final IconData icone;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final cor = this.cor ?? c.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icone, size: 20, color: cor),
    );
  }
}

/// Avatar redondo com iniciais enquanto a fotografia não carrega.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nome, this.url, this.tamanho = 40});

  final String nome;
  final String? url;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciais = partes.isEmpty ? '?' : (partes.first[0] + (partes.length > 1 ? partes.last[0] : '')).toUpperCase();

    return ClipOval(
      child: Container(
        width: tamanho,
        height: tamanho,
        color: c.primaryContainer,
        alignment: Alignment.center,
        child: url == null
            ? _iniciais(iniciais, c)
            : ImagemRede(
                url!,
                largura: tamanho,
                altura: tamanho,
                fit: BoxFit.cover,
                falha: (_) => _iniciais(iniciais, c),
              ),
      ),
    );
  }

  Widget _iniciais(String texto, ColorScheme c) => Text(
    texto,
    style: TextStyle(fontWeight: FontWeight.w700, fontSize: tamanho * 0.36, color: c.onPrimaryContainer),
  );
}
