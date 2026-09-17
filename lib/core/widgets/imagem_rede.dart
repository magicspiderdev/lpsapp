import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagem da rede guardada em disco: depois de vista uma vez, aparece sem ligação.
class ImagemRede extends StatelessWidget {
  const ImagemRede(this.url, {super.key, this.fit = BoxFit.cover, this.largura, this.altura, this.falha});

  final String url;
  final BoxFit fit;
  final double? largura, altura;

  /// O que mostrar se não houver imagem (sem rede e nunca vista, ou URL partido).
  final WidgetBuilder? falha;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: largura,
      height: altura,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (context, _, _) => falha?.call(context) ?? const SizedBox.shrink(),
    );
  }
}
