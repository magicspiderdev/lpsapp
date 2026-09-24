import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tema/tema.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../agenda/agenda.dart';
import '../agenda/agenda_widgets.dart';
import 'competicao.dart';
import '../../comunidade/bloco_comunidade.dart';

/// A ficha de um jogo: quem jogou, como acabou, e o que aconteceu lá dentro.
///
/// `GET /competicao/jogos/{id}` (guia §4.19). O jogo chega quase sempre com o
/// toque num cartão, e esse cartão já sabe as equipas e o resultado: vem em
/// [inicial] e desenha o placard enquanto a ficha não chega, para o ecrã não
/// abrir a girar. Por link, [inicial] é `null` e espera-se pelo servidor.
class JogoPage extends ConsumerWidget {
  const JogoPage({super.key, required this.id, this.inicial});

  final String id;
  final ItemAgenda? inicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(jogoProvider(id));
    final dados = estado.valueOrNull;
    // O que o servidor diz manda sobre o que o cartão trazia.
    final jogo = dados?.valor.jogo ?? inicial;

    return Scaffold(
      appBar: AppBar(
        title: Text(jogo?.prova ?? jogo?.modalidade ?? 'Jogo', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: switch ((jogo, estado)) {
        // Nem cartão nem resposta: só aqui se espera de ecrã vazio.
        (null, AsyncLoading()) => const Center(child: CircularProgressIndicator()),
        (null, AsyncError(:final error)) =>
          error is EmPreparacao
              ? const PainelEmPreparacao(
                  icone: Icons.sports_score_rounded,
                  titulo: 'Fichas de jogo a caminho',
                  texto: 'Golos, cartões e relato, jogo a jogo.',
                )
              : ErroView(erro: error, tentarDeNovo: () => ref.invalidate(jogoProvider(id))),
        (final ItemAgenda j, _) => RefreshIndicator(
          onRefresh: () => ref.refresh(jogoProvider(id).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 40),
            children: [
              if (dados != null) AvisoDesactualizado(dados),
              _Placard(j),
              const SizedBox(height: 12),
              _Detalhes(j),
              // Palpitar antes, relatar depois. Só em jogos do clube com id
              // da competição; se falhar, a ficha fica igual.
              BlocoComunidade(id),
              if (j.sessaoBilhetes != null) ...[
                const SizedBox(height: 16),
                BotaoBilhetes(j.sessaoBilhetes!, grande: true),
              ],
              const SizedBox(height: 8),
              // Sem resposta ainda não se sabe se há ficha; a lista diz que
              // ela existe, e é isso que se mostra em vez de "ficha por
              // escrever" que logo a seguir se desmente.
              _Ficha(jogo: j, linhas: dados?.valor.ficha, aCarregar: dados == null && j.temFicha),
            ],
          ),
        ),
        // Com o cartão em mão, um erro do servidor não apaga o que já se sabe.
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// O placard: as duas equipas, o resultado oficial e quando foi.
class _Placard extends StatelessWidget {
  const _Placard(this.j);

  final ItemAgenda j;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);

    Widget equipa(Equipa? e) => Expanded(
      child: Column(
        children: [
          if (e != null) EmblemaEquipa(e, tamanho: 52),
          const SizedBox(height: 8),
          Text(
            e?.nome ?? '—',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleSmall?.copyWith(fontWeight: e?.doClube == true ? FontWeight.w800 : FontWeight.w500),
          ),
        ],
      ),
    );

    return Bloco(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      child: Column(
        children: [
          if (j.provaComJornada case final prova?)
            Text(prova, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              equipa(j.casa),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ConstrainedBox(
                  // Com a letra do sistema no máximo, o resultado deixava de
                  // caber entre as duas equipas: encolhe ele, que se lê à
                  // mesma, e não os nomes, que já vêm cortados.
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: j.temResultado
                        ? Text('${j.golosCasa} - ${j.golosFora}', style: t.textTheme.headlineMedium)
                        : Text('vs', style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ),
                ),
              ),
              equipa(j.fora),
            ],
          ),
          const SizedBox(height: 16),
          Text(quandoPorExtenso(j), textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
          if (_etiquetaDeEstado(j) case final estado?) ...[
            const SizedBox(height: 12),
            _Pastilha(estado.$1, cor: estado.$2 ? cores.error : cores.info),
          ],
        ],
      ),
    );
  }
}

/// O estado, quando é preciso dizê-lo — e se é um problema.
///
/// `agendado` e `terminado` não se anunciam: a data e o resultado já os dizem.
/// A lista é aberta, por isso o que não se conhece fica de fora.
(String, bool)? _etiquetaDeEstado(ItemAgenda j) => switch (j.estado) {
  'adiado' => ('Adiado', true),
  'cancelado' => ('Cancelado', true),
  'a_decorrer' => ('A decorrer', false),
  'interrompido' => ('Interrompido', true),
  _ => null,
};

class _Pastilha extends StatelessWidget {
  const _Pastilha(this.texto, {required this.cor});

  final String texto;
  final StatusColor cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cor.container, borderRadius: BorderRadius.circular(Tema.raioPequeno)),
      child: Text(
        texto,
        style: TextStyle(color: cor.foreground, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

/// Recinto, prova, árbitro e assistência — o que houver.
class _Detalhes extends StatelessWidget {
  const _Detalhes(this.j);

  final ItemAgenda j;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[
      if (j.local case final local?) LinhaInfo(Icons.place_outlined, 'Recinto', local),
      if (j.modalidade case final m?) LinhaInfo(Icons.sports_rounded, 'Modalidade', m),
      if (j.arbitro case final a?) LinhaInfo(Icons.sports_rounded, 'Arbitragem', a),
      if (j.espectadores case final n?) LinhaInfo(Icons.groups_outlined, 'Assistência', '$n espectadores'),
    ];
    if (linhas.isEmpty && j.provaSlug == null) return const SizedBox.shrink();

    return Bloco(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...linhas,
          if (j.provaSlug case final slug?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextButton(
                onPressed: () => context.push('/agenda/competicao/$slug'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                // Row própria, e não `TextButton.icon`: a dele não deixa o
                // texto encolher, e com a letra do sistema grande transborda.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 18),
                    const SizedBox(width: 8),
                    // O nome da prova já está no placard e no cabeçalho.
                    const Flexible(child: Text('Todos os jogos da prova')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// O que aconteceu dentro do jogo, do apito inicial ao final.
class _Ficha extends StatelessWidget {
  const _Ficha({required this.jogo, required this.linhas, required this.aCarregar});

  final ItemAgenda jogo;

  /// `null` = ainda não houve resposta do servidor.
  final List<LinhaFicha>? linhas;
  final bool aCarregar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // Tipos que não se conhecem ignoram-se: a lista é aberta e aparecem
    // tipos novos sem aviso (guia §4.19).
    final visiveis = [
      for (final l in linhas ?? const <LinhaFicha>[])
        if (_descrever(l) != null) l,
    ];

    if (linhas == null) {
      return aCarregar
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          : const SizedBox.shrink();
    }

    if (visiveis.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.edit_note_rounded, size: 28, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              // Sem ficha não é erro: é o caso normal enquanto ninguém a
              // escreveu, e antes do jogo é sempre assim.
              jogo.inicio.isAfter(DateTime.now()) ? 'A ficha abre quando o jogo começar' : 'Ficha por escrever',
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccao('Ficha de jogo'),
        Bloco(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final l in visiveis) _LinhaDaFicha(l, jogo: jogo)],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          // O marcador da ficha pode estar a meio de ser escrito; o oficial é
          // o do jogo, e é esse que está no placard (guia §4.19).
          'A ficha é escrita pelo clube e pode estar incompleta. O resultado oficial é o do placard.',
          style: t.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LinhaDaFicha extends StatelessWidget {
  const _LinhaDaFicha(this.l, {required this.jogo});

  final LinhaFicha l;
  final ItemAgenda jogo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final descricao = _descrever(l)!;
    final cores = AppColors.of(context);
    final cor = switch (descricao.cor) {
      _Cor.golo => t.colorScheme.primary,
      _Cor.falta => cores.error.foreground,
      _Cor.aviso => cores.warning.foreground,
      _Cor.neutra => t.colorScheme.onSurfaceVariant,
    };
    final equipa = l.daCasa ? jogo.casa : (l.daFora ? jogo.fora : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Acompanha a letra do sistema: com ela no máximo, "41'" não cabia
            // numa coluna fixa e empurrava a linha para fora do cartão.
            width: MediaQuery.textScalerOf(context).scale(17).clamp(17, 40),
            child: Text(
              l.minuto == null ? '' : "${l.minuto}'",
              textAlign: TextAlign.end,
              style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Icon(descricao.icone, size: 18, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (equipa != null) ...[
                      Padding(padding: const EdgeInsets.only(top: 1), child: EmblemaEquipa(equipa, tamanho: 18)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(descricao.texto, style: t.textTheme.titleSmall)),
                  ],
                ),
                if (descricao.detalhe case final detalhe?) ...[
                  const SizedBox(height: 2),
                  Text(detalhe, style: t.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          // O marcador só ao lado de quem o mudou: repeti-lo em cada linha
          // faria a ficha parecer uma tabela de resultados.
          if (l.alteraMarcador) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${l.marcadorCasa}-${l.marcadorFora}', style: t.textTheme.labelLarge),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Cor { golo, falta, aviso, neutra }

/// O que uma linha diz, no ecrã. `null` nos tipos que a app não conhece —
/// **a lista é aberta** e aparecem tipos novos sem aviso.
class _Descricao {
  const _Descricao(this.icone, this.texto, {this.detalhe, this.cor = _Cor.neutra});

  final IconData icone;
  final String texto;
  final String? detalhe;
  final _Cor cor;
}

_Descricao? _descrever(LinhaFicha l) {
  final quem = l.atleta;
  return switch (l.tipo) {
    'golo' => _Descricao(
      Icons.sports_score_rounded,
      quem ?? 'Golo',
      detalhe: l.assistencia == null ? null : 'Assistência de ${l.assistencia}',
      cor: _Cor.golo,
    ),
    'penalti' => _Descricao(
      Icons.sports_score_rounded,
      quem ?? 'Golo',
      detalhe: 'De grande penalidade',
      cor: _Cor.golo,
    ),
    // Conta para a outra equipa, e o servidor já o somou ao marcador — do
    // lado de cá só se diz de quem foi o pé.
    'autogolo' => _Descricao(
      Icons.sports_score_rounded,
      quem ?? 'Autogolo',
      detalhe: 'Na própria baliza',
      cor: _Cor.falta,
    ),
    'penalti_falhado' => _Descricao(
      Icons.block_rounded,
      quem ?? 'Grande penalidade falhada',
      detalhe: quem == null ? null : 'Falhou a grande penalidade',
    ),
    // Sem nome de atleta o cartão é o próprio título: repeti-lo por baixo não
    // acrescentava nada.
    'amarelo' => _Descricao(
      Icons.style_rounded,
      quem ?? 'Cartão amarelo',
      detalhe: quem == null ? null : 'Cartão amarelo',
      cor: _Cor.aviso,
    ),
    'vermelho' => _Descricao(
      Icons.style_rounded,
      quem ?? 'Cartão vermelho',
      detalhe: quem == null ? null : 'Cartão vermelho',
      cor: _Cor.falta,
    ),
    // `atleta` é quem **entrou**; `atleta_saiu` quem saiu.
    'substituicao' => _Descricao(
      Icons.swap_horiz_rounded,
      quem == null ? 'Substituição' : 'Entra $quem',
      detalhe: l.atletaSaiu == null ? null : 'Sai ${l.atletaSaiu}',
    ),
    'inicio' => const _Descricao(Icons.play_arrow_rounded, 'Início do jogo'),
    'intervalo' => const _Descricao(Icons.pause_rounded, 'Intervalo'),
    'fim' => const _Descricao(Icons.flag_rounded, 'Fim do jogo'),
    'relato' => l.texto == null ? null : _Descricao(Icons.chat_bubble_outline_rounded, l.texto!),
    _ => null,
  };
}
