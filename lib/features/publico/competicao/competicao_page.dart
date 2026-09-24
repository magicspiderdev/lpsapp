import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../agenda/agenda_widgets.dart';
import 'competicao.dart';

/// As competições do clube, por época.
///
/// Abre na época que o clube pôs em vigor (`epoca_actual`). O selector só
/// aparece quando há mais do que uma: com uma só, é o clube a dizer que não
/// quer histórico na app.
class CompeticaoPage extends ConsumerStatefulWidget {
  const CompeticaoPage({super.key});

  @override
  ConsumerState<CompeticaoPage> createState() => _CompeticaoPageState();
}

class _CompeticaoPageState extends ConsumerState<CompeticaoPage> {
  /// `null` = a actual, que só o servidor sabe qual é.
  String? _epoca;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(provasProvider(_epoca));

    // Uma época escolhida que deixou de se poder pedir dá `404`: volta-se à
    // que está em vigor, em vez de mostrar um erro.
    ref.listen(provasProvider(_epoca), (_, s) {
      if (_epoca != null && s.error is ApiException && (s.error as ApiException).httpStatus == 404) {
        setState(() => _epoca = null);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Competições')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is EmPreparacao
            ? const PainelEmPreparacao(
                icone: Icons.emoji_events_outlined,
                titulo: 'Competições a caminho',
                texto: 'Os jogos de cada prova, época a época.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(provasProvider(_epoca))),
        data: (d) {
          final p = d.valor;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(provasProvider(_epoca).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                if (p.epocas.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final e in p.epocas)
                          _Epoca(
                            e,
                            actual: e == p.epocaActual,
                            activa: e == p.epoca,
                            // A actual pede-se sem parâmetro: é o servidor que
                            // a decide, e amanhã pode ser outra.
                            onTap: () => setState(() => _epoca = e == p.epocaActual ? null : e),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (p.provas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: PainelEmPreparacao(
                      icone: Icons.emoji_events_outlined,
                      titulo: 'Sem provas',
                      texto: 'Não há competições registadas nesta época.',
                    ),
                  ),
                for (final prova in p.provas) _CartaoProva(prova),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Epoca extends StatelessWidget {
  const _Epoca(this.epoca, {required this.actual, required this.activa, required this.onTap});

  final String epoca;
  final bool actual, activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: activa ? c.primary : c.surfaceContainerLowest,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              actual ? '$epoca · época actual' : epoca,
              style: TextStyle(color: activa ? c.onPrimary : c.onSurface, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoProva extends StatelessWidget {
  const _CartaoProva(this.p);

  final Prova p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Bloco(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/agenda/competicao/${p.slug}'),
        child: Row(
          children: [
            IconePastilha(switch (p.formato) {
              'taca' => Icons.emoji_events_outlined,
              'torneio' => Icons.workspace_premium_outlined,
              'amigavel' => Icons.handshake_outlined,
              _ => Icons.scoreboard_outlined,
            }),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nome, style: t.textTheme.titleSmall),
                  if (p.legenda.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(p.legenda, style: t.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    // As contagens são só de jogos do clube — dizê-lo evita a
                    // pergunta de quem sabe que a liga tem mais jogos.
                    '${p.realizados} jogados · ${p.proximos} por jogar',
                    style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Uma prova: o que vem aí primeiro, e depois o que já se jogou.
class ProvaPage extends ConsumerWidget {
  const ProvaPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(provaProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(estado.valueOrNull?.valor.prova.nome ?? 'Competição')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is EmPreparacao
            ? const PainelEmPreparacao(
                icone: Icons.emoji_events_outlined,
                titulo: 'Competições a caminho',
                texto: 'Os jogos de cada prova, época a época.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(provaProvider(slug))),
        data: (d) {
          final detalhe = d.valor;
          Future<void> actualizar() => ref.refresh(provaProvider(slug).future);

          return SeparadoresDeTempo(
            // Uma prova acabada abre no que aconteceu, não num ecrã vazio.
            comecarNosAnteriores: detalhe.proximos.isEmpty && detalhe.realizados.isNotEmpty,
            acimaDosSeparadores: Padding(
              padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [AvisoDesactualizado(d), _Cabecalho(detalhe.prova)],
              ),
            ),
            proximos: ListaDeJogos(
              itens: detalhe.proximos,
              actualizar: actualizar,
              // O nome da prova já está no cabeçalho: aqui basta a jornada.
              mostrarProva: false,
              vazio: const PainelEmPreparacao(
                icone: Icons.event_busy_outlined,
                titulo: 'Sem jogos marcados',
                texto: 'Não há jogos do clube por jogar nesta prova.',
              ),
            ),
            anteriores: ListaDeJogos(
              itens: detalhe.realizados,
              actualizar: actualizar,
              mostrarProva: false,
              // "Já jogado" é pela data: um jogo sem resultado registado
              // aparece aqui à mesma, e é isso que se deve mostrar.
              vazio: const PainelEmPreparacao(
                icone: Icons.history_rounded,
                titulo: 'Ainda não se jogou',
                texto: 'Esta prova ainda não tem jogos do clube realizados.',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.p);

  final Prova p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.nome, style: t.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            [if (p.epoca.isNotEmpty) 'Época ${p.epoca}', if (p.legenda.isNotEmpty) p.legenda].join(' · '),
            style: t.textTheme.bodySmall,
          ),
          if (p.urlExterno case final url?) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Página oficial da prova'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ],
        ],
      ),
    );
  }
}
