import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagem da rede guardada em disco: depois de vista uma vez, aparece sem ligação.
class ImagemRede extends StatelessWidget {
  const ImagemRede(this.url, {super.key, this.fit = BoxFit.cover, this.largura, this.altura, this.falha, this.larguraCache});

  final String url;
  final BoxFit fit;
  final double? largura, altura;

  /// O que mostrar se não houver imagem (sem rede e nunca vista, ou URL partido).
  final WidgetBuilder? falha;

  /// Largura, em píxeis, a que a imagem é descodificada — para ficheiros
  /// grandes mostrados pequenos (um emblema de 500 KB num círculo de 28).
  final int? larguraCache;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: largura,
      height: altura,
      memCacheWidth: larguraCache,
      fadeInDuration: const Duration(milliseconds: 200),
      // Centrado: o CachedNetworkImage põe o substituto no canto da caixa.
      errorWidget: (context, _, _) => Center(child: falha?.call(context) ?? const SizedBox.shrink()),
      placeholder: falha == null ? null : (context, _) => Center(child: falha!(context)),
    );
  }
}
