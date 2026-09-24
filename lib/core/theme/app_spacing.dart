import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Espaçamento em grelha de 4 pt (design system, `docs/ui-audit.md` §6.3).
///
/// Relação antes de tamanho: coisas ligadas ficam a [sm]; o salto para o grupo
/// seguinte é o triplo ([xl]). Nada de 6, 10, 14 ou 20.
abstract final class AppSpacing {
  /// Título e subtítulo da mesma linha.
  static const xs = 4.0;

  /// Elementos relacionados; título de secção → bloco.
  static const sm = 8.0;

  /// Entre cartões; entre campos de formulário.
  static const md = 12.0;

  /// Margem lateral e padding interior dos blocos.
  static const lg = 16.0;

  /// Antes de um título de secção; padding de folhas e diálogos.
  static const xl = 24.0;

  /// Entre grupos (formulário → acção); topo dos ecrãs de entrada.
  static const xxl = 32.0;

  /// Estados vazios; respiro no fim das listas.
  static const xxxl = 48.0;

  /// A margem lateral de **todos** os ecrãs (acaba a alternância 16/20).
  static const screen = lg;

  static const screenPadding = EdgeInsets.symmetric(horizontal: screen);

  /// Fim de uma lista com botão fixo em baixo: o botão (56) mais respiro.
  static const bottomBarClearance = xxxl + 56;

  /// Alvo de toque mínimo (Material 48 dp). Um botão pode *parecer* menor,
  /// desde que a área tocável tenha isto.
  static const minTouchTarget = 48.0;

  /// Largura máxima do conteúdo: em tablets as linhas não passam disto.
  static const maxContentWidth = 600.0;
}

/// Raios (§6.4). Um raio interior = raio exterior − padding, para os cantos
/// ficarem concêntricos.
abstract final class AppRadius {
  /// Miniaturas pequenas; o canto "da ponta" das bolhas do chat.
  static const xs = 8.0;

  /// Miniaturas (notícia, evento, notificação), anexos.
  static const sm = 12.0;

  /// Campos, avisos, snackbars, cartão físico, QR.
  static const md = 16.0;

  /// Blocos, cartões, capa de destaque, bolhas do chat.
  static const lg = 24.0;

  /// Base do cabeçalho do sócio; topo das folhas.
  static const xl = 32.0;

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));

  /// Botões, filtros, etiquetas, pílulas: em vez de `circular(100)`.
  static const pill = StadiumBorder();
}

/// Elevação (§6.5). A app é plana: separa por cor, não por sombra. Só os
/// objectos "físicos" (o cartão, os bilhetes) levam sombra, tingida de verde.
abstract final class AppShadows {
  /// Cartão de sócio e bilhetes, sobre o fundo. Sem sombra no modo escuro: a
  /// profundidade vem da superfície mais clara.
  static List<BoxShadow> level1(Brightness brilho) => brilho == Brightness.dark
      ? const []
      : [BoxShadow(color: AppPalette.greenDark.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 8))];

  static List<BoxShadow> level1Of(BuildContext context) => level1(Theme.of(context).brightness);
}

/// Movimento (§6.6).
abstract final class AppMotion {
  /// Micro-interacções: cor, estado de um botão.
  static const short = Duration(milliseconds: 150);

  /// Elementos a entrar ou a sair.
  static const medium = Duration(milliseconds: 250);

  /// Objectos em transição (o cartão a virar).
  static const long = Duration(milliseconds: 400);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// [duracao], ou zero se o sistema pediu para remover animações.
  static Duration of(BuildContext context, Duration duracao) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duracao;
}
