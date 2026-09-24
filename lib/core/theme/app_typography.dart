import 'package:flutter/material.dart';

/// Tipografia da app (design system, `docs/ui-audit.md` §6.2).
///
/// Uma família, **Inter**, incluída na app (`assets/fonts/`). Três pesos:
/// [regular] para ler, [semiBold] para títulos e rótulos, [extraBold] para
/// títulos de ecrã e valores grandes. Nenhum `fontSize` fora deste ficheiro:
/// os ecrãs usam os papéis do `textTheme`.
///
/// | Papel            | px / linha | Uso                                        |
/// |------------------|------------|--------------------------------------------|
/// | `displaySmall`   | 40 / 44    | O valor em dívida ou o total               |
/// | `headlineLarge`  | 30 / 36    | Título de ecrã (Notícias, Área de sócio)   |
/// | `headlineMedium` | 26 / 32    | Título de artigo                           |
/// | `headlineSmall`  | 22 / 28    | Título de folha, destaque, resultado       |
/// | `titleLarge`     | 20 / 26    | Barra superior, título de detalhe          |
/// | `titleMedium`    | 17 / 24    | Título de secção e de cartão               |
/// | `titleSmall`     | 15 / 20    | Título de linha de lista                   |
/// | `bodyLarge`      | 16 / 24    | Texto de leitura (notícia, mensagem)       |
/// | `bodyMedium`     | 15 / 22    | Texto corrente, listas, formulários        |
/// | `bodySmall`      | 13 / 18    | Legendas e metadados (cor secundária)      |
/// | `labelLarge`     | 15 / 20    | Botões                                     |
/// | `labelMedium`    | 12 / 16    | Etiquetas, pílulas, navegação, sobretítulos|
/// | `labelSmall`     | 12 / 16    | O mínimo da app: nada abaixo de 12 px      |
///
/// Num mesmo ecrã, no máximo quatro destes tamanhos.
abstract final class AppTypography {
  static const family = 'Inter';

  static const regular = FontWeight.w400;
  static const semiBold = FontWeight.w600;
  static const extraBold = FontWeight.w800;

  /// Algarismos da mesma largura: euros e contagens alinham em coluna e não
  /// "dançam" quando o valor muda.
  static const tabular = [FontFeature.tabularFigures()];

  /// Sobretítulo em maiúsculas por cima do título de ecrã ("CALENDÁRIO").
  static const eyebrowLetterSpacing = 1.2;

  static TextTheme textTheme(ColorScheme c) {
    TextStyle estilo(double tamanho, double linha, FontWeight peso, {double espaco = 0, Color? cor}) => TextStyle(
      fontFamily: family,
      fontSize: tamanho,
      height: linha / tamanho,
      fontWeight: peso,
      letterSpacing: espaco,
      color: cor ?? c.onSurface,
      // Sem isto o Flutter distribui a altura extra só por baixo da letra.
      leadingDistribution: TextLeadingDistribution.even,
    );

    return TextTheme(
      displayLarge: estilo(56, 60, extraBold, espaco: -1.6),
      displayMedium: estilo(48, 52, extraBold, espaco: -1.4),
      displaySmall: estilo(40, 44, extraBold, espaco: -1.2).copyWith(fontFeatures: tabular),
      headlineLarge: estilo(30, 36, extraBold, espaco: -1),
      headlineMedium: estilo(26, 32, extraBold, espaco: -0.8),
      headlineSmall: estilo(22, 28, extraBold, espaco: -0.5),
      titleLarge: estilo(20, 26, semiBold, espaco: -0.4),
      titleMedium: estilo(17, 24, semiBold, espaco: -0.2).copyWith(fontFeatures: tabular),
      titleSmall: estilo(15, 20, semiBold).copyWith(fontFeatures: tabular),
      bodyLarge: estilo(16, 24, regular),
      bodyMedium: estilo(15, 22, regular),
      bodySmall: estilo(13, 18, regular, cor: c.onSurfaceVariant),
      labelLarge: estilo(15, 20, semiBold),
      labelMedium: estilo(12, 16, semiBold, espaco: 0.4),
      labelSmall: estilo(12, 16, semiBold, espaco: 0.4),
    );
  }
}
