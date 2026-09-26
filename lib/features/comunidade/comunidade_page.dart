import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/cache/com_cache.dart';
import '../../core/tema/tema.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/estado_dados.dart';
import '../../core/widgets/imagem_rede.dart';
import '../publico/agenda/agenda.dart';
import '../publico/agenda/agenda_widgets.dart' show EmblemaEquipa;
import 'arena.dart';
import 'avatares.dart';
import 'comunidade.dart';

/// O separador "Comunidade": jogos para palpitar e relatar, a classificação do
/// "Adivinha o resultado" e os passatempos.
///
/// Sem sessão mostra-se o que é, e qualquer acção leva a entrar: todos os
/// pedidos da comunidade exigem conta (sócia ou não).
class ComunidadePage extends ConsumerWidget {
  const ComunidadePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessaoProvider) is SessaoAnonima) {
      return Arena(
        fundo: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('Comunidade')),
          body: const _Apresentacao(),
        ),
      );
    }
    // "Últimos": os jogos de hoje e de ontem que já acabaram, para quem lá
    // esteve dizer como acabou. Só existe quando há algum, e vem primeiro.
    final recentes = ref.watch(jogosComunidadeProvider('recentes')).valueOrNull?.valor ?? const [];
    final ultimos = ultimosJogos(recentes, DateTime.now());

    return Arena(
      fundo: true,
      child: DefaultTabController(
        // A chave muda com a tab: o controlador recomeça na primeira, que passa
        // a ser a "Últimos" quando ela aparece.
        key: ValueKey(ultimos.isNotEmpty),
        length: ultimos.isEmpty ? 3 : 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Comunidade'),
            actions: [_ContadorPontos(tabClassificacao: ultimos.isEmpty ? 1 : 2)],
            // A deslizar: com a letra grande, "Classificação" não cabe num terço.
            bottom: _Separadores(
              tabs: [
                if (ultimos.isNotEmpty) const Tab(text: 'Últimos'),
                const Tab(text: 'Jogos'),
                const Tab(text: 'Classificação'),
                const Tab(text: 'Passatempos'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              if (ultimos.isNotEmpty) _Ultimos(ultimos),
              const _Jogos(),
              const _Classificacao(),
              const _Passatempos(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Os separadores da Arena: o escolhido é uma pastilha chanfrada, como os
/// menus de um jogo.
class _Separadores extends StatelessWidget implements PreferredSizeWidget {
  const _Separadores({required this.tabs});

  final List<Widget> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerHeight: 0,
      padding: const EdgeInsets.fromLTRB(Tema.margem - 4, 0, Tema.margem - 4, 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: ShapeDecoration(color: c.primary, shape: chanfro),
      splashBorderRadius: BorderRadius.circular(10),
      labelColor: c.onPrimary,
      unselectedLabelColor: c.onSurfaceVariant,
      labelStyle: t.textTheme.labelLarge?.copyWith(fontWeight: AppTypography.extraBold),
      unselectedLabelStyle: t.textTheme.labelLarge,
      tabs: tabs,
    );
  }
}

/// O canto do jogador, sempre à vista: os pontos da época (tocar abre a
/// classificação) e o leão (tocar escolhe outro).
class _ContadorPontos extends ConsumerWidget {
  const _ContadorPontos({required this.tabClassificacao});

  final int tabClassificacao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eu = ref.watch(classificacaoProvider).valueOrNull?.valor.eu;
    final perfil = ref.watch(perfilComunidadeProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(right: Tema.margem - 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eu != null)
            Tooltip(
              message: 'Ver a classificação',
              child: Material(
                color: AppPalette.ouro.withValues(alpha: 0.12),
                shape: chanfroCom(AppPalette.ouro.withValues(alpha: 0.5), raio: 8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => DefaultTabController.of(context).animateTo(tabClassificacao),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ChipPontos(eu.pontos),
                  ),
                ),
              ),
            ),
          if (perfil != null && !perfil.bloqueado) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Escolher o seu avatar',
              child: InkWell(
                customBorder: chanfro,
                onTap: () => mudarAvatar(context, ref, perfil),
                child: ImagemAvatar(perfil.avatar, tamanho: 38),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Abre a grelha dos leões e grava o escolhido.
Future<void> mudarAvatar(BuildContext context, WidgetRef ref, PerfilComunidade perfil) async {
  final codigo = await escolherAvatar(context, actual: perfil.avatar);
  if (codigo == null || codigo == perfil.avatar || !context.mounted) return;
  final aviso = ScaffoldMessenger.of(context);
  try {
    await ref.read(perfilComunidadeProvider.notifier).mudarAvatar(codigo);
  } on ApiException catch (e) {
    if (e.erro == 'comunidade_bloqueada') ref.read(perfilComunidadeProvider.notifier).bloqueada();
    aviso.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Os jogos acabados de terminar, hoje e ontem.
class _Ultimos extends ConsumerWidget {
  const _Ultimos(this.jogos);

  final List<JogoComunidade> jogos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final hoje = DateTime.now();
    bool eHoje(DateTime d) => d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
    final deHoje = [
      for (final c in jogos)
        if (eHoje(c.jogo.inicio)) c,
    ];
    final deOntem = [
      for (final c in jogos)
        if (!eHoje(c.jogo.inicio)) c,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(jogosComunidadeProvider);
        await ref.read(jogosComunidadeProvider('recentes').future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Esteve num destes jogos ou viu-o? Conte-nos como acabou.',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          if (deHoje.isNotEmpty) ...[const TituloSeccao('Hoje'), for (final c in deHoje) _CartaoJogo(c)],
          if (deOntem.isNotEmpty) ...[const TituloSeccao('Ontem'), for (final c in deOntem) _CartaoJogo(c)],
        ],
      ),
    );
  }
}

/// O que é a comunidade, para quem ainda não entrou.
class _Apresentacao extends StatelessWidget {
  const _Apresentacao();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    Widget modo(IconData icone, Color cor, String titulo, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PainelArena(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(color: cor.withValues(alpha: 0.14), shape: chanfroCom(cor, raio: 10)),
              child: Icon(icone, color: cor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: t.textTheme.titleMedium?.copyWith(fontWeight: AppTypography.extraBold)),
                  const SizedBox(height: 2),
                  Text(texto, style: t.textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
      children: [
        Text('Entre em campo.', style: t.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'O jogo dos adeptos dos Leões, sócios ou não. Basta uma conta.',
          style: t.textTheme.bodyLarge?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        modo(
          Icons.bolt_rounded,
          AppPalette.ouro,
          'Adivinhe o resultado',
          'Palpite nos próximos jogos, some pontos e suba na classificação da época.',
        ),
        modo(
          Icons.campaign_outlined,
          c.primary,
          'Diga como acabou',
          'Esteve no jogo? Ajude a registar o resultado dos jogos que ainda não o têm.',
        ),
        modo(
          Icons.emoji_events_outlined,
          AppPalette.bronze,
          'Passatempos',
          'Participe e habilite-se aos prémios do clube.',
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => context.go(
            Uri(path: '/entrar', queryParameters: {'voltar': '/comunidade', 'motivo': 'comunidade'}).toString(),
          ),
          child: const Text('Entrar ou criar conta'),
        ),
      ],
    );
  }
}

// ── Jogos ──────────────────────────────────────────────────────────────────

class _Jogos extends ConsumerWidget {
  const _Jogos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentes = ref.watch(jogosComunidadeProvider('recentes'));
    final proximos = ref.watch(jogosComunidadeProvider('proximos'));

    Future<void> actualizar() async {
      ref.invalidate(jogosComunidadeProvider);
      await ref.read(jogosComunidadeProvider('proximos').future);
    }

    // Ambas por carregar: espera-se. Uma só com erro: mostra-se o erro nela.
    if (recentes.valueOrNull == null && proximos.valueOrNull == null) {
      if (recentes.hasError || proximos.hasError) {
        return ErroView(erro: (recentes.error ?? proximos.error)!, tentarDeNovo: actualizar);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final porRelatar = recentes.valueOrNull?.valor ?? const <JogoComunidade>[];
    final porPalpitar = proximos.valueOrNull?.valor ?? const <JogoComunidade>[];

    return RefreshIndicator(
      onRefresh: actualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
        children: [
          if (proximos.valueOrNull case final d?) AvisoDesactualizado(d, margem: const EdgeInsets.only(top: 12)),
          if (porRelatar.isNotEmpty) ...[
            const TituloSeccao('Como acabou?'),
            for (final j in porRelatar) _CartaoJogo(j),
          ],
          const TituloSeccao('Adivinhe o resultado'),
          if (porPalpitar.isEmpty)
            const _Vazio('Não há jogos nos próximos 14 dias. Volte mais perto do fim-de-semana.')
          else
            for (final j in porPalpitar) _CartaoJogo(j),
        ],
      ),
    );
  }
}

/// Um jogo da comunidade: as equipas e o que há para fazer nele. Tocar abre a
/// ficha do jogo, onde está o bloco inteiro.
class _CartaoJogo extends ConsumerWidget {
  const _CartaoJogo(this.c);

  final JogoComunidade c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final j = c.jogo;
    final p = c.palpites;
    final r = c.relatos;
    // Sem `permissoes.comunidade` (§2.10) não se convida a fazer nada.
    final pode = sessaoPode(ref.watch(sessaoProvider), 'comunidade');

    // O que há para fazer neste jogo; `destaque` é quando está à espera desta
    // conta, e então é um botão cheio.
    final (estado, destaque, icone) = switch (c) {
      _ when r.confirmado != null => ('Resultado confirmado: ${r.confirmado}', false, Icons.verified_outlined),
      _ when r.aberto && r.meu != null => ('Disse ${r.meu}', false, Icons.check_rounded),
      _ when pode && r.aberto && r.propostas.isNotEmpty => (
        '${_pessoas(r.propostas.first.relatos)} ${r.propostas.first.marcador}. Confirma?',
        true,
        Icons.how_to_vote_outlined,
      ),
      _ when pode && r.aberto => ('Diga como acabou', true, Icons.campaign_outlined),
      _ when p.meu != null => ('O seu palpite: ${p.meu}', false, Icons.bolt_rounded),
      _ when pode && p.aberto => ('Palpitar', true, Icons.bolt_rounded),
      _ => ('', false, null),
    };

    Widget lado(Equipa? e) => Column(
      children: [
        if (e != null) EmblemaEquipa(e, tamanho: 44) else const SizedBox.square(dimension: 44),
        const SizedBox(height: 8),
        Text(
          e?.nome ?? '—',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.textTheme.titleSmall?.copyWith(
            fontWeight: e?.doClube ?? false ? AppTypography.extraBold : null,
            color: e?.doClube ?? false ? t.colorScheme.onSurface : t.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PainelArena(
        destaque: destaque ? t.colorScheme.primary.withValues(alpha: 0.6) : null,
        onTap: () => context.push('/comunidade/jogo/${j.id}', extra: j),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      DateFormat(j.horaConfirmada ? "EEE, d MMM · HH:mm" : 'EEE, d MMM', 'pt_PT').format(j.inicio),
                      ?j.modalidade,
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: lado(j.casa)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Placard(casa: j.golosCasa, fora: j.golosFora),
                      ),
                      Expanded(child: lado(j.fora)),
                    ],
                  ),
                ],
              ),
            ),
            if (estado.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                color: destaque ? t.colorScheme.primary : t.colorScheme.surfaceContainerHigh,
                child: Row(
                  children: [
                    if (icone != null) ...[
                      Icon(icone, size: 20, color: destaque ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        estado,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: destaque ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant,
                          fontWeight: destaque ? AppTypography.extraBold : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: destaque ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _pessoas(int n) => n == 1 ? '1 pessoa diz' : '$n pessoas dizem';
}

// ── Classificação ──────────────────────────────────────────────────────────

class _Classificacao extends ConsumerWidget {
  const _Classificacao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final estado = ref.watch(classificacaoProvider);
    final perfil = ref.watch(perfilComunidadeProvider).valueOrNull;
    final palpites = ref.watch(meusPalpitesProvider).valueOrNull?.valor ?? const [];

    Future<void> actualizar() async {
      ref.invalidate(perfilComunidadeProvider);
      ref.invalidate(meusPalpitesProvider);
      ref.invalidate(classificacaoProvider);
      await ref.read(classificacaoProvider.future);
    }

    return estado.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErroView(erro: e, tentarDeNovo: actualizar),
      data: (Dados<Classificacao> d) {
        final c = d.valor;
        return RefreshIndicator(
          onRefresh: actualizar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
            children: [
              AvisoDesactualizado(d, margem: const EdgeInsets.only(top: 12)),
              if (perfil != null || c.eu != null) ...[
                const SizedBox(height: 12),
                _CartaoJogador(perfil: perfil, eu: c.eu),
              ],
              TituloSeccao(c.epoca == null ? 'Classificação' : 'Classificação ${c.epoca}'),
              if (c.linhas.isEmpty)
                const _Vazio('Ainda ninguém com alcunha pontuou esta época.')
              else ...[
                _Podio(c.linhas.take(3).toList()),
                if (c.linhas.length > 3) ...[
                  const SizedBox(height: 12),
                  PainelArena(
                    child: Column(
                      children: [
                        for (final (i, l) in c.linhas.skip(3).indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          _LinhaTabela(l),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  '${c.pontosExacto} pontos pelo resultado exacto, ${c.pontosVencedor} por acertar em quem ganha. '
                  'Em caso de empate, conta quem tem mais resultados exactos.',
                  style: t.textTheme.bodySmall,
                ),
              ),
              if (palpites.isNotEmpty) ...[
                const TituloSeccao('Os seus palpites'),
                PainelArena(
                  child: Column(
                    children: [
                      for (final (i, (jogo, m, pontos)) in palpites.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          onTap: () => context.push('/comunidade/jogo/${jogo.id}', extra: jogo),
                          title: Text(
                            '${jogo.casa?.nome ?? ''} ${m.casa}–${m.fora} ${jogo.fora?.nome ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              DateFormat('d MMM', 'pt_PT').format(jogo.inicio),
                              if (jogo.golosCasa != null) 'acabou ${jogo.golosCasa}–${jogo.golosFora}',
                            ].join(' · '),
                          ),
                          trailing: Text(
                            pontos == null ? '—' : '+$pontos',
                            style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: AppTypography.extraBold,
                              color: (pontos ?? 0) > 0 ? AppPalette.ouro : t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Uma linha da tabela, do 4.º para baixo (os três primeiros estão no pódio).
class _LinhaTabela extends StatelessWidget {
  const _LinhaTabela(this.l);

  final LinhaClassificacao l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      color: l.eu ? t.colorScheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          EmblemaPosicao(l.posicao),
          const SizedBox(width: 10),
          ImagemAvatar(l.avatar, tamanho: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.alcunha ?? (l.eu ? 'Você (sem alcunha)' : '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyLarge?.copyWith(fontWeight: l.eu ? AppTypography.extraBold : null),
                ),
                Text(_estatisticas(l), style: t.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Com a letra grande, os pontos encolhem antes de apertarem o nome.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: FittedBox(fit: BoxFit.scaleDown, child: ChipPontos(l.pontos)),
          ),
        ],
      ),
    );
  }
}

String _estatisticas(LinhaClassificacao l) =>
    '${l.exactos} ${l.exactos == 1 ? 'exacto' : 'exactos'} · ${l.palpites} ${l.palpites == 1 ? 'palpite' : 'palpites'}';

/// Os três primeiros, num pódio: o 1.º ao meio e mais alto, o 2.º à esquerda,
/// o 3.º à direita. Os degraus sobem uma vez, ao abrir.
class _Podio extends StatelessWidget {
  const _Podio(this.primeiros);

  /// Até três linhas, pela ordem da tabela.
  final List<LinhaClassificacao> primeiros;

  @override
  Widget build(BuildContext context) {
    // A ordem no pódio: 2.º, 1.º, 3.º. Com menos de três, o que houver.
    final lugares = [
      if (primeiros.length > 1) (primeiros[1], 0.7),
      (primeiros[0], 1.0),
      if (primeiros.length > 2) (primeiros[2], 0.5),
    ];
    final semAnimacao = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: semAnimacao ? 1 : 0, end: 1),
      duration: semAnimacao ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, subida, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, (l, altura)) in lugares.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _Degrau(l, altura: 56 + 64 * altura * subida)),
          ],
        ],
      ),
    );
  }
}

class _Degrau extends StatelessWidget {
  const _Degrau(this.l, {required this.altura});

  final LinhaClassificacao l;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final metal = corDaPosicao(l.posicao);
    final cor = metal ?? c.outline;

    return Column(
      children: [
        if (l.posicao == 1) const Icon(Icons.emoji_events_rounded, color: AppPalette.ouro, size: 28),
        ImagemAvatar(l.avatar, tamanho: l.posicao == 1 ? 60 : 48, aro: metal),
        const SizedBox(height: 6),
        Text(
          l.alcunha ?? (l.eu ? 'Você' : '—'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.textTheme.titleSmall?.copyWith(
            fontWeight: AppTypography.extraBold,
            color: l.eu ? c.primary : c.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: ChipPontos(l.pontos)),
        const SizedBox(height: 8),
        Container(
          height: altura,
          width: double.infinity,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [cor.withValues(alpha: 0.35), cor.withValues(alpha: 0.06)],
            ),
            shape: chanfroCom(l.eu ? c.primary : cor.withValues(alpha: 0.8)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${l.posicao}.º', style: t.textTheme.headlineMedium?.copyWith(color: metal ?? c.onSurface)),
          ),
        ),
      ],
    );
  }
}

/// O cartão de quem joga: a alcunha, o lugar e os pontos. Tocar escolhe ou
/// muda a alcunha. A alcunha nunca vem preenchida com o nome da pessoa:
/// aparecer na tabela é uma escolha (RGPD).
class _CartaoJogador extends ConsumerWidget {
  const _CartaoJogador({required this.perfil, required this.eu});

  final PerfilComunidade? perfil;
  final LinhaClassificacao? eu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final perfil = this.perfil;
    final eu = this.eu;

    if (perfil?.bloqueado ?? false) {
      return Text(
        'O clube suspendeu a sua participação na comunidade.',
        style: t.textTheme.bodyMedium?.copyWith(color: c.error),
      );
    }

    final alcunha = perfil == null ? eu?.alcunha : perfil.alcunha;
    return PainelArena(
      destaque: AppPalette.ouro.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(16),
      onTap: perfil == null ? null : () => mostrarAlcunha(context, ref, perfil.alcunha),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // O leão: tocar escolhe outro (o resto do cartão muda a alcunha).
              InkWell(
                customBorder: chanfro,
                onTap: perfil == null ? null : () => mudarAvatar(context, ref, perfil),
                child: ImagemAvatar(perfil?.avatar ?? eu?.avatar, tamanho: 60, aro: AppPalette.ouro),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: alcunha == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Escolha uma alcunha', style: t.textTheme.titleMedium),
                          Text(
                            'Joga na mesma sem ela, mas só aparece na tabela quem tem alcunha.',
                            style: t.textTheme.bodySmall,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('A sua alcunha', style: t.textTheme.bodySmall),
                          Text(alcunha, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.headlineSmall),
                        ],
                      ),
              ),
              if (perfil != null) Icon(Icons.edit_outlined, color: c.onSurfaceVariant),
            ],
          ),
          if (eu != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: c.outlineVariant),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EmblemaPosicao(eu.posicao),
                ChipPontos(eu.pontos, grande: true),
                Text(_estatisticas(eu), style: t.textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Escolher, mudar ou tirar a alcunha.
Future<void> mostrarAlcunha(BuildContext context, WidgetRef ref, String? actual) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FolhaAlcunha(actual),
  );
}

class _FolhaAlcunha extends ConsumerStatefulWidget {
  const _FolhaAlcunha(this.actual);

  final String? actual;

  @override
  ConsumerState<_FolhaAlcunha> createState() => _FolhaAlcunhaState();
}

class _FolhaAlcunhaState extends ConsumerState<_FolhaAlcunha> {
  // Começa com a alcunha que já tem, ou vazio — nunca com o nome da pessoa.
  late final _campo = TextEditingController(text: widget.actual ?? '');
  final _form = GlobalKey<FormState>();
  String? _erro;
  bool _aEnviar = false;

  /// As regras do servidor: 3 a 30 caracteres, letras, números, espaço, `.`, `-`, `_`.
  static final _permitida = RegExp(r'^[\p{L}\p{N} ._-]{3,30}$', unicode: true);

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _gravar(String? alcunha) async {
    if (alcunha != null && !_form.currentState!.validate()) return;
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      await ref.read(perfilComunidadeProvider.notifier).mudarAlcunha(alcunha);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.erro == 'comunidade_bloqueada') ref.read(perfilComunidadeProvider.notifier).bloqueada();
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Alcunha', style: t.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'É o nome com que aparece na classificação, à vista de todos. Não use o seu nome se não quiser.',
                  style: t.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _campo,
                  autofocus: true,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Alcunha', errorText: _erro),
                  validator: (v) => _permitida.hasMatch((v ?? '').trim())
                      ? null
                      : 'De 3 a 30 caracteres: letras, números, espaço, ponto, hífen e _.',
                  onFieldSubmitted: (_) => _gravar(_campo.text.trim()),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _aEnviar ? null : () => _gravar(_campo.text.trim()),
                  child: const Text('Guardar'),
                ),
                if (widget.actual != null)
                  TextButton(
                    onPressed: _aEnviar ? null : () => _gravar(null),
                    child: const Text('Sair da classificação'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Passatempos ────────────────────────────────────────────────────────────

class _Passatempos extends ConsumerWidget {
  const _Passatempos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(passatemposProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(passatemposProvider)),
          data: (d) => RefreshIndicator(
            onRefresh: () => ref.refresh(passatemposProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                if (d.valor.isEmpty)
                  const _Vazio('Não há passatempos neste momento. Quando o clube lançar um, aparece aqui.')
                else
                  for (final p in d.valor) CartaoPassatempo(p),
              ],
            ),
          ),
        );
  }
}

class CartaoPassatempo extends StatelessWidget {
  const CartaoPassatempo(this.p, {super.key});

  final Passatempo p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final aberto = p.fase == 'a_decorrer' && p.minha == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PainelArena(
        destaque: aberto ? AppPalette.ouro.withValues(alpha: 0.45) : null,
        onTap: () => context.push('/comunidade/passatempos/${p.uid}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.imagemUrl case final url?)
              Stack(
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: ImagemRede(url)),
                  Positioned(left: 12, top: 12, child: EtiquetaFase(p)),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.imagemUrl == null) ...[EtiquetaFase(p), const SizedBox(height: 10)],
                  Text(p.titulo, style: t.textTheme.titleMedium?.copyWith(fontWeight: AppTypography.extraBold)),
                  if (p.resumo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.resumo!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (p.premio != null) ...[
                    const SizedBox(height: 12),
                    // O prémio é o que está em jogo: em ouro.
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: ShapeDecoration(
                        color: AppPalette.ouro.withValues(alpha: 0.1),
                        shape: chanfroCom(AppPalette.ouro.withValues(alpha: 0.35), raio: 8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 20, color: AppPalette.ouro),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.premio!,
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: AppPalette.ouro,
                                fontWeight: AppTypography.semiBold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A fase do passatempo, e o que ela quer dizer para quem vê.
class EtiquetaFase extends StatelessWidget {
  const EtiquetaFase(this.p, {super.key});

  final Passatempo p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final (texto, fundo, frente) = switch ((p.fase, p.minha?.vencedor)) {
      ('resultados', true) => ('Ganhou!', AppPalette.ouro, AppPalette.onOuro),
      ('resultados', _) => ('Vencedores anunciados', c.surfaceContainerHigh, c.onSurfaceVariant),
      (_, _) when p.minha != null => ('Já participou', c.primaryContainer, c.onPrimaryContainer),
      ('a_decorrer', _) => ('A decorrer', c.primaryContainer, c.onPrimaryContainer),
      ('brevemente', _) => ('Brevemente', c.surfaceContainerHigh, c.onSurfaceVariant),
      ('terminado', _) => ('Terminado', c.surfaceContainerHigh, c.onSurfaceVariant),
      _ => ('', c.surfaceContainerHigh, c.onSurfaceVariant),
    };
    if (texto.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(color: fundo, shape: chanfroCom(frente.withValues(alpha: 0.3), raio: 6)),
      child: Text(
        texto,
        style: t.textTheme.labelMedium?.copyWith(color: frente, fontWeight: AppTypography.extraBold),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(texto, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    );
  }
}
