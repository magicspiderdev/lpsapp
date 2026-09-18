import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tema/tema.dart';

/// Visível enquanto o `/ping` responde; o router sai daqui sozinho.
///
/// A mesma imagem e a mesma cor do arranque nativo, para a passagem de um ao
/// outro não se notar.
class ArranquePage extends StatelessWidget {
  const ArranquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Tema.verdeEscuro,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // `cover`: a imagem é vertical e os ecrãs têm proporções diferentes.
            const Image(image: AssetImage('assets/images/splash.png'), fit: BoxFit.cover),
            Align(
              alignment: const Alignment(0, 0.82),
              child: SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
