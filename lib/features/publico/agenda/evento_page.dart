import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tema/tema.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'agenda.dart';
import 'agenda_widgets.dart';

/// Um evento do clube, por extenso: quando é, onde, e a descrição inteira.
///
/// **Não há endpoint de detalhe para eventos.** O que se sabe de um evento vem
/// todo na agenda (`descricao`, `capa`, `fim` — §4.17), por isso este ecrã lê
/// da lista que já está em memória, em vez de inventar uma chamada. Está
/// pedido ao CISOC em `docs/pedidos-app/2026-09-22-detalhe-de-evento.md`: com
/// ele, um link para um evento antigo passa a abrir sem depender da janela de
/// datas que a agenda carregou.
class EventoPage extends ConsumerWidget {
  const EventoPage({super.key, required this.referencia, this.inicial});

  /// `slug` do evento, ou o `id` quando ele não tem slug.
  final String referencia;

  /// O evento como o cartão o conhece — quem chega por toque já o traz.
  final ItemAgenda? inicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final recuo = ref.watch(maisAnterioresProvider);
    final evento = inicial ?? _procurar([...?agenda.valueOrNull?.valor, ...recuo.itens], referencia);

    return Scaffold(
      appBar: AppBar(title: const Text('Evento')),
      body: switch ((evento, agenda)) {
        (final ItemAgenda e, _) => _Evento(e),
        (null, AsyncLoading()) => const Center(child: CircularProgressIndicator()),
        (null, AsyncError(:final error)) when error is! EmPreparacao => ErroView(
          erro: error,
          tentarDeNovo: () => ref.invalidate(agendaProvider),
        ),
        // A agenda respondeu e este evento não está lá: ou já saiu da janela
        // de datas que se carregou, ou deixou de existir.
        _ => const _NaoEstaNaAgenda(),
      },
    );
  }

  static ItemAgenda? _procurar(List<ItemAgenda> itens, String referencia) {
    for (final i in itens) {
      if (i.slug == referencia || i.id == referencia) return i;
    }
    return null;
  }
}

class _NaoEstaNaAgenda extends StatelessWidget {
  const _NaoEstaNaAgenda();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconePastilha(Icons.event_busy_outlined),
            const SizedBox(height: 16),
            Text('Evento não encontrado', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Este evento já não está na agenda do clube.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: () => context.go('/agenda'), child: const Text('Ver a agenda')),
          ],
        ),
      ),
    );
  }
}

class _Evento extends StatelessWidget {
  const _Evento(this.e);

  final ItemAgenda e;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 40),
      children: [
        if (e.capaUrl case final capa?) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(Tema.raio),
            child: AspectRatio(aspectRatio: 16 / 9, child: ImagemRede(capa)),
          ),
          const SizedBox(height: 20),
        ],
        Text(e.titulo, style: t.textTheme.headlineSmall),
        if (e.cancelado) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cores.error.container,
                borderRadius: BorderRadius.circular(Tema.raioPequeno),
              ),
              child: Text(
                e.estado == 'adiado' ? 'Adiado' : 'Cancelado',
                style: TextStyle(color: cores.error.foreground, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
        if (e.resumo case final resumo?) ...[
          const SizedBox(height: 12),
          Text(resumo, style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.onSurfaceVariant, height: 1.4)),
        ],
        const SizedBox(height: 20),
        Bloco(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinhaInfo(Icons.event_outlined, 'Quando', quandoPorExtenso(e)),
              if (e.local case final local?) LinhaInfo(Icons.place_outlined, 'Onde', local),
            ],
          ),
        ),
        if (e.sessaoBilhetes case final sessao?) ...[const SizedBox(height: 16), BotaoBilhetes(sessao, grande: true)],
        // `descricao` é texto simples, com os parágrafos separados por linha
        // em branco (§4.17) — não é HTML e não se compõe como tal.
        if (e.descricao case final texto?) ...[
          const SizedBox(height: 24),
          for (final paragrafo in texto.split(RegExp(r'\n\s*\n')))
            if (paragrafo.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(paragrafo.trim(), style: t.textTheme.bodyLarge?.copyWith(height: 1.55)),
              ),
        ],
      ],
    );
  }
}
