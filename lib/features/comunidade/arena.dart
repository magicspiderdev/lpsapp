import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

/// O aspecto da Comunidade: a "Arena".
///
/// A Comunidade é o jogo do clube — palpites, pontos, uma classificação,
/// prémios —, e tem fundo próprio, escuro nos dois modos. O canto chanfrado
/// dos painéis é a marca dela (nenhum outro ecrã o usa), e o ouro fica só para
/// o que se ganha.
class Arena extends StatelessWidget {
  const Arena({super.key, required this.child, this.fundo = false});

  final Widget child;

  /// Um ecrã inteiro (o separador, um passatempo): o pavilhão por trás, e o
  /// `Scaffold` e a barra de cima transparentes para ele se ver.
  final bool fundo;

  static final _tema = AppTheme.arena();
  static final _temaComFundo = _tema.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: _tema.appBarTheme.copyWith(backgroundColor: Colors.transparent),
  );

  @override
  Widget build(BuildContext context) => fundo
      ? FundoArena(
          child: Theme(data: _temaComFundo, child: child),
        )
      : Theme(data: _tema, child: child);
}

/// O pavilhão à noite por trás dos ecrãs da Comunidade.
///
/// Fica parado enquanto a lista corre por cima, como o fundo do menu de um
/// jogo. Escurece para baixo, onde está o texto que não vive em painéis (os
/// títulos, as regras): os painéis são opacos e não dependem dele.
class FundoArena extends StatelessWidget {
  const FundoArena({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppPalette.arenaFundo),
        Image.asset(
          'assets/images/arena.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
          gaplessPlayback: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.35, 1],
              colors: [
                AppPalette.arenaFundo.withValues(alpha: 0.35),
                AppPalette.arenaFundo.withValues(alpha: 0.7),
                AppPalette.arenaFundo.withValues(alpha: 0.9),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// O canto chanfrado dos painéis da Arena.
const chanfro = BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)));

ShapeBorder chanfroCom(Color linha, {double raio = 10}) => BeveledRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(raio)),
  side: BorderSide(color: linha),
);

/// O [Bloco] da Arena: painel com contorno, que se pode tocar.
class PainelArena extends StatelessWidget {
  const PainelArena({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap, this.destaque});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Cor do contorno quando o painel é o que está em jogo (o seu lugar, um
  /// jogo à espera de si). Sem ela, a linha discreta.
  final Color? destaque;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerLowest,
      shape: chanfroCom(destaque ?? c.outlineVariant),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A cor de uma posição: ouro, prata e bronze nos três primeiros.
Color? corDaPosicao(int posicao) => switch (posicao) {
  1 => AppPalette.ouro,
  2 => AppPalette.prata,
  3 => AppPalette.bronze,
  _ => null,
};

/// "3.º" num emblema chanfrado; com metal no pódio, contorno no resto.
class EmblemaPosicao extends StatelessWidget {
  const EmblemaPosicao(this.posicao, {super.key, this.tamanho = 36});

  final int posicao;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final metal = corDaPosicao(posicao);
    return Container(
      constraints: BoxConstraints(minWidth: tamanho, minHeight: tamanho),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: metal ?? t.colorScheme.surfaceContainerHigh,
        shape: chanfroCom(metal ?? t.colorScheme.outline, raio: tamanho / 4),
      ),
      child: Text(
        '$posicao.º',
        style: t.textTheme.titleSmall?.copyWith(
          fontWeight: AppTypography.extraBold,
          color: metal == null ? t.colorScheme.onSurface : AppPalette.onOuro,
        ),
      ),
    );
  }
}

/// Os pontos, em ouro: o contador da Arena.
class ChipPontos extends StatelessWidget {
  const ChipPontos(this.pontos, {super.key, this.grande = false});

  final int pontos;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final estilo = (grande ? t.textTheme.headlineSmall : t.textTheme.titleSmall)?.copyWith(
      color: AppPalette.ouro,
      fontWeight: AppTypography.extraBold,
      fontFeatures: AppTypography.tabular,
    );
    return Semantics(
      label: pontos == 1 ? '1 ponto' : '$pontos pontos',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Icon(Icons.bolt_rounded, size: grande ? 22 : 16, color: AppPalette.ouro),
          const SizedBox(width: 2),
          Text('$pontos', style: estilo),
          const SizedBox(width: 3),
          Text('pts', style: t.textTheme.labelMedium?.copyWith(color: AppPalette.ouro)),
        ],
      ),
    );
  }
}

/// Um marcador em placard: cada número na sua caixa. `null` é "por jogar".
class Placard extends StatelessWidget {
  const Placard({super.key, this.casa, this.fora, this.tamanho = 40});

  final int? casa, fora;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    if (casa == null || fora == null) {
      // Por jogar: o "VS" do ecrã de escolha de um jogo de luta.
      return Container(
        constraints: BoxConstraints(minWidth: tamanho * 1.3, minHeight: tamanho),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: ShapeDecoration(color: c.surfaceContainerHigh, shape: chanfroCom(c.outline, raio: 8)),
        child: Text(
          'VS',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: AppTypography.extraBold, color: c.onSurfaceVariant),
        ),
      );
    }
    Widget caixa(int n) => Container(
      constraints: BoxConstraints(minWidth: tamanho * 0.85, minHeight: tamanho),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: ShapeDecoration(color: c.surfaceContainerHighest, shape: chanfroCom(c.outline, raio: 6)),
      child: Text('$n', style: t.textTheme.headlineSmall?.copyWith(fontFeatures: AppTypography.tabular)),
    );
    return Semantics(
      label: '$casa a $fora',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [caixa(casa!), const SizedBox(width: 4), caixa(fora!)]),
    );
  }
}
