import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/arranque/boas_vindas.dart';
import '../../core/links.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Um slide: a ilustração (um ícone grande e três pequenos à volta), o título
/// e o texto.
class _Slide {
  final IconData icone;
  final List<IconData> satelites;
  final String titulo, texto;

  /// O primeiro leva o brasão em vez do ícone.
  final bool brasao;

  const _Slide({
    required this.icone,
    required this.titulo,
    required this.texto,
    this.satelites = const [],
    this.brasao = false,
  });
}

const _slides = [
  _Slide(
    icone: Icons.shield,
    brasao: true,
    satelites: [Icons.sports_soccer_rounded, Icons.favorite_rounded, Icons.groups_rounded],
    titulo: 'Bem-vindo à nova app dos Leões',
    texto: 'Tudo o que se passa no clube, num só sítio. Para sócios e para todos os adeptos.',
  ),
  _Slide(
    icone: Icons.event_rounded,
    satelites: [Icons.newspaper_rounded, Icons.scoreboard_outlined, Icons.emoji_events_outlined],
    titulo: 'Notícias, jogos e resultados',
    texto: 'A agenda de todas as modalidades, os resultados, as fichas dos jogos e as notícias do clube.',
  ),
  _Slide(
    icone: Icons.confirmation_number_rounded,
    satelites: [Icons.qr_code_2_rounded, Icons.stadium_outlined, Icons.share_rounded],
    titulo: 'Bilhetes no telemóvel',
    texto: 'Compre os bilhetes na app e mostre o código à entrada. Ficam guardados, mesmo sem rede.',
  ),
  _Slide(
    icone: Icons.groups_rounded,
    satelites: [Icons.psychology_alt_outlined, Icons.campaign_outlined, Icons.card_giftcard_rounded],
    titulo: 'Comunidade Leões',
    texto: 'Adivinhe os resultados, conte-nos como acabou o jogo e participe nos passatempos.',
  ),
  _Slide(
    icone: Icons.badge_rounded,
    satelites: [Icons.euro_rounded, Icons.family_restroom_rounded, Icons.support_agent_rounded],
    titulo: 'A sua área de sócio',
    texto: 'O cartão digital, as quotas e os pagamentos, a conta da família e o contacto com a secretaria.',
  ),
];

/// `/boas-vindas` — os slides da primeira vez que a app abre neste aparelho.
///
/// Explicam o que a app tem, sem pedir nada: entrar é opcional, e quem salta
/// vai directo para a zona pública. Depois de vistos (ou saltados) não voltam.
class BoasVindasPage extends ConsumerStatefulWidget {
  const BoasVindasPage({super.key});

  @override
  ConsumerState<BoasVindasPage> createState() => _BoasVindasPageState();
}

class _BoasVindasPageState extends ConsumerState<BoasVindasPage> {
  final _paginas = PageController();
  int _actual = 0;

  bool get _ultimo => _actual == _slides.length - 1;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  /// Sai para onde ia (um link aberto à primeira), ou para o início. Com
  /// [entrar], passa primeiro pelo login e volta ao mesmo destino.
  Future<void> _terminar({bool entrar = false}) async {
    final para = Links.voltarSeguro(GoRouterState.of(context).uri.queryParameters['para']) ?? '/noticias';
    await ref.read(boasVindasProvider.notifier).marcarVistas();
    if (!mounted) return;
    context.go(entrar ? Uri(path: '/entrar', queryParameters: {'voltar': para}).toString() : para);
  }

  void _seguinte() => _paginas.nextPage(duration: AppMotion.long, curve: AppMotion.enter);

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: cores.brandGradient),
          child: SafeArea(
            child: Column(
              children: [
                // Saltar, sempre à mão — menos no último, onde o botão já é "Começar".
                SizedBox(
                  height: AppSpacing.minTouchTarget + AppSpacing.sm,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      duration: AppMotion.medium,
                      opacity: _ultimo ? 0 : 1,
                      child: TextButton(
                        onPressed: _ultimo ? null : _terminar,
                        style: TextButton.styleFrom(foregroundColor: cores.onBrand),
                        child: const Text('Saltar'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _paginas,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _actual = i),
                    itemBuilder: (context, i) => AnimatedBuilder(
                      animation: _paginas,
                      // Quanto este slide está afastado do centro: esbate-se
                      // enquanto se arrasta, e o seguinte aparece.
                      builder: (context, filho) {
                        final pagina = _paginas.hasClients && _paginas.position.haveDimensions
                            ? _paginas.page ?? _actual.toDouble()
                            : _actual.toDouble();
                        final distancia = (pagina - i).abs().clamp(0.0, 1.0);
                        return Opacity(opacity: 1 - distancia * 0.6, child: filho);
                      },
                      child: _PaginaSlide(_slides[i]),
                    ),
                  ),
                ),
                _Pontos(total: _slides.length, actual: _actual),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppPalette.green,
                            minimumSize: const Size.fromHeight(56),
                          ),
                          onPressed: _ultimo ? _terminar : _seguinte,
                          child: Text(_ultimo ? 'Começar' : 'Seguinte'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Só no fim, e como segunda opção: a app abre-se sem conta.
                      AnimatedOpacity(
                        duration: AppMotion.medium,
                        opacity: _ultimo ? 1 : 0,
                        child: TextButton(
                          onPressed: _ultimo ? () => _terminar(entrar: true) : null,
                          style: TextButton.styleFrom(foregroundColor: cores.onBrand),
                          child: Text('Já tenho conta · Entrar', style: t.labelLarge?.copyWith(color: cores.onBrand)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginaSlide extends StatelessWidget {
  const _PaginaSlide(this.s);

  final _Slide s;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final t = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, limites) {
        // A ilustração dá o espaço ao texto em ecrãs baixos ou com letra grande.
        final lado = math.min(limites.maxWidth * 0.72, limites.maxHeight * 0.52).clamp(140.0, 300.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: limites.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Ilustracao(s, lado: lado),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  s.titulo,
                  textAlign: TextAlign.center,
                  style: t.headlineMedium?.copyWith(color: cores.onBrand, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    s.texto,
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: cores.onBrandMuted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Um círculo de vidro com o ícone principal (ou o brasão) e três bolhas à
/// volta com os ícones do que o slide fala.
class _Ilustracao extends StatelessWidget {
  const _Ilustracao(this.s, {required this.lado});

  final _Slide s;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final centro = lado * 0.58;
    final bolha = lado * 0.24;

    // Posições das bolhas, à volta do círculo (fracções do lado).
    const posicoes = [Offset(0.02, 0.10), Offset(0.76, 0.02), Offset(0.70, 0.72)];

    return ExcludeSemantics(
      child: SizedBox(
        width: lado,
        height: lado,
        child: Stack(
          children: [
            // Anéis de fundo, discretos.
            for (final (f, a) in [(1.0, 0.06), (0.8, 0.08)])
              Center(
                child: Container(
                  width: lado * f,
                  height: lado * f,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)),
                ),
              ),
            Center(
              child: Container(
                width: centro,
                height: centro,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                padding: EdgeInsets.all(centro * (s.brasao ? 0.16 : 0.24)),
                child: s.brasao
                    ? Image.asset(
                        'assets/images/brasao.png',
                        cacheWidth: (centro * MediaQuery.devicePixelRatioOf(context)).round(),
                      )
                    : FittedBox(child: Icon(s.icone, color: AppPalette.green)),
              ),
            ),
            for (final (i, icone) in s.satelites.indexed.take(posicoes.length))
              Positioned(
                left: posicoes[i].dx * lado,
                top: posicoes[i].dy * lado,
                child: Container(
                  width: bolha,
                  height: bolha,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cores.brandSurface,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Icon(icone, color: Colors.white, size: bolha * 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Os pontos que dizem em que slide se está. O actual é uma pílula.
class _Pontos extends StatelessWidget {
  const _Pontos({required this.total, required this.actual});

  final int total, actual;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Página ${actual + 1} de $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.enter,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == actual ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == actual ? 1 : 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
