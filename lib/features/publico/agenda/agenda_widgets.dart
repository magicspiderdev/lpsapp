import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'agenda.dart';

/// A rota da ficha de um item da agenda, ou `null` quando não há nada para
/// abrir (um tipo de uma versão futura da API).
///
/// Um jogo tem ficha no servidor (`/competicao/jogos/{id}`, guia §4.19); um
/// evento não tem endpoint de detalhe e abre-se com o que a agenda já trouxe,
/// por isso vai pelo `slug` quando o tem, como as notícias.
String? rotaDoItem(ItemAgenda i) => switch (i.tipo) {
  TipoItem.jogo => '/agenda/jogo/${Uri.encodeComponent(i.id)}',
  TipoItem.evento => '/agenda/evento/${Uri.encodeComponent(i.slug ?? i.id)}',
  TipoItem.desconhecido => null,
};

/// O cartão de um item da agenda: um jogo (com as duas equipas e o resultado)
/// ou um evento (com fotografia e resumo).
///
/// Vive aqui, e não na página, porque a competição mostra os mesmos jogos —
/// a API devolve-os na mesma forma de propósito (guia §4.19).
class CartaoAgenda extends StatelessWidget {
  const CartaoAgenda(this.i, {super.key, this.mostrarProva = true});

  final ItemAgenda i;

  /// Na página de uma prova o nome dela está no cabeçalho: aí mostra-se só a
  /// jornada, que é o que distingue um jogo do seguinte.
  final bool mostrarProva;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // Sem hora confirmada não se escreve nada no lugar dela.
    //
    // O guia da API sugere "hora por confirmar", mas na prática a importação
    // da federação traz jogos sem hora e ela nunca chega a ser confirmada por
    // ninguém: a frase prometia um acerto que não acontece. Fica só o dia. O
    // que **não** se pode mostrar é `00:00`, que é o que a API manda nesses
    // casos e não significa meia-noite.
    final hora = i.horaConfirmada ? DateFormat('HH:mm').format(i.inicio) : null;
    final contexto = [
      if (mostrarProva) ...[
        if (i.modalidade != null) i.modalidade!,
        if (i.provaComJornada != null) i.provaComJornada!,
      ] else if (i.jornada != null)
        '${i.jornada}.ª jornada',
      if (i.tipo == TipoItem.evento) 'Evento',
    ].join(' · ');

    final ficha = rotaDoItem(i);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Bloco(
        padding: const EdgeInsets.all(14),
        // O cartão abre a ficha; os bilhetes têm botão próprio, para quem já
        // sabe o que quer não ter de passar por aqui.
        onTap: ficha == null ? null : () => context.push(ficha, extra: i),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hora != null || contexto.isNotEmpty || i.cancelado) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Uma linha que flui: a hora e o nome de uma prova nem
                  // sempre cabem lado a lado num ecrã estreito.
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (hora != null)
                          Text(hora, style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary)),
                        if (contexto.isNotEmpty) Text(contexto, style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (i.cancelado) ...[
                    const SizedBox(width: 8),
                    Text(
                      i.estado == 'adiado' ? 'Adiado' : 'Cancelado',
                      style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.error),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (i.tipo == TipoItem.jogo && i.casa != null && i.fora != null) _Confronto(i) else _Evento(i),
            // O rodapé aparece por causa do recinto ou dos bilhetes: um jogo
            // à venda sem recinto registado não pode ficar sem o botão.
            if (i.local != null || i.temBilhetes) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (i.local case final local?) ...[
                    Icon(Icons.place_outlined, size: 16, color: t.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(local, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                    ),
                  ] else
                    const Spacer(),
                  if (i.sessaoBilhetes case final sessao?) ...[
                    const SizedBox(width: 8),
                    Flexible(child: BotaoBilhetes(sessao)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uma linha de informação de uma ficha: ícone, o que é, e o valor.
class LinhaInfo extends StatelessWidget {
  const LinhaInfo(this.icone, this.etiqueta, this.valor, {super.key});

  final IconData icone;
  final String etiqueta, valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: t.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(valor, style: t.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A data por extenso de um item da agenda, com a hora só quando ela existe.
///
/// Um jogo sem hora confirmada mostra o dia e mais nada: `00:00` é o que a API
/// manda nesses casos e não significa meia-noite.
String quandoPorExtenso(ItemAgenda i) {
  final dia = DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_PT').format(i.inicio);
  final data = dia[0].toUpperCase() + dia.substring(1);
  if (!i.dataConfirmada) return '$data (data por confirmar)';
  if (!i.horaConfirmada) return data;
  final fim = i.fim;
  final horas = fim == null
      ? DateFormat('HH:mm').format(i.inicio)
      : '${DateFormat('HH:mm').format(i.inicio)} às ${DateFormat('HH:mm').format(fim)}';
  return '$data · $horas';
}

/// "Bilhetes", dentro de um cartão que abre a ficha: quem já sabe o que quer
/// vai direito à bilheteira sem passar pelo detalhe.
class BotaoBilhetes extends StatelessWidget {
  const BotaoBilhetes(this.sessao, {super.key, this.grande = false});

  final String sessao;

  /// Na ficha é o botão principal do ecrã, não uma pastilha de canto.
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    void abrir() => context.push('/bilhetes/$sessao');

    if (grande) {
      return FilledButton.icon(
        onPressed: abrir,
        icon: const Icon(Icons.confirmation_number_outlined, size: 20),
        label: const Text('Comprar bilhetes'),
      );
    }

    return Material(
      color: c.primaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Bilhetes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// Divide em "o que vem aí" e "o que já se passou".
///
/// O corte é **pela data**, não por haver resultado — é a regra da API (§4.19)
/// e é a que não faz desaparecer um jogo: o de ontem que ainda ninguém
/// registou pertence ao passado, e mostra-se sem resultado.
(List<ItemAgenda>, List<ItemAgenda>) separarPorTempo(Iterable<ItemAgenda> itens, {DateTime? agora}) {
  final momento = agora ?? DateTime.now();
  final proximos = <ItemAgenda>[];
  final anteriores = <ItemAgenda>[];
  for (final i in itens) {
    (i.inicio.isBefore(momento) ? anteriores : proximos).add(i);
  }
  // O que vem aí lê-se do mais próximo para a frente; o que passou, do mais
  // recente para trás — em ambos os casos, o que interessa fica em cima.
  proximos.sort((a, b) => a.inicio.compareTo(b.inicio));
  anteriores.sort((a, b) => b.inicio.compareTo(a.inicio));
  return (proximos, anteriores);
}

/// Dois separadores que também se trocam arrastando o dedo: "Próximos" e
/// "Anteriores".
class SeparadoresDeTempo extends StatelessWidget {
  const SeparadoresDeTempo({
    super.key,
    required this.proximos,
    required this.anteriores,
    this.acimaDosSeparadores,
    this.comecarNosAnteriores = false,
  });

  final Widget proximos, anteriores;

  /// O que fica por cima dos separadores e serve os dois (avisos, filtros).
  final Widget? acimaDosSeparadores;
  final bool comecarNosAnteriores;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: comecarNosAnteriores ? 1 : 0,
      child: Column(
        children: [
          ?acimaDosSeparadores,
          const TabBar(
            tabs: [
              Tab(text: 'Próximos'),
              Tab(text: 'Anteriores'),
            ],
          ),
          // O TabBarView já troca de separador ao arrastar.
          Expanded(child: TabBarView(children: [proximos, anteriores])),
        ],
      ),
    );
  }
}

/// Lista de jogos e eventos agrupados por dia, com "puxar para actualizar" e,
/// quando há mais para trás, com carregamento à medida que se desce.
class ListaDeJogos extends StatefulWidget {
  const ListaDeJogos({
    super.key,
    required this.itens,
    required this.vazio,
    this.actualizar,
    this.mostrarProva = true,
    this.carregarMais,
    this.aCarregarMais = false,
    this.haMais = false,
  });

  final List<ItemAgenda> itens;

  /// O que mostrar quando não há nada — cada ecrã diz a sua razão.
  final Widget vazio;
  final Future<void> Function()? actualizar;
  final bool mostrarProva;

  /// Pedir o pedaço seguinte. Chamado ao aproximar-se do fim da lista.
  final VoidCallback? carregarMais;
  final bool aCarregarMais;

  /// Ainda há coisas para carregar. É o que justifica o rodapé.
  final bool haMais;

  @override
  State<ListaDeJogos> createState() => _ListaDeJogosState();
}

class _ListaDeJogosState extends State<ListaDeJogos> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Falta pouco para o fim da lista (ou a lista nem sequer enche o ecrã):
  /// está na hora de ir buscar o pedaço seguinte.
  ///
  /// A conta é feita pela posição, e não só ao arrastar: uma lista curta de
  /// mais para se arrastar nunca geraria um evento de scroll, e o rodapé
  /// ficava a girar para sempre à espera de um dedo.
  void _talvezCarregar() {
    if (!mounted || widget.carregarMais == null || !widget.haMais || widget.aCarregarMais) return;
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final p = _scroll.position;
    if (p.maxScrollExtent - p.pixels < 400) widget.carregarMais!();
  }

  @override
  Widget build(BuildContext context) {
    final porDia = <DateTime, List<ItemAgenda>>{};
    for (final i in widget.itens) {
      porDia.putIfAbsent(DateUtils.dateOnly(i.inicio), () => []).add(i);
    }

    // Depois de desenhado sabe-se o tamanho real; antes disso, não.
    if (widget.carregarMais != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _talvezCarregar());
    }

    final lista = ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // Com mais para trás a caminho não se diz "não há nada": ainda não se
        // sabe.
        if (widget.itens.isEmpty && !widget.haMais)
          Padding(padding: const EdgeInsets.only(top: 48), child: widget.vazio),
        for (final dia in porDia.keys) ...[
          CabecalhoDia(dia),
          for (final i in porDia[dia]!) CartaoAgenda(i, mostrarProva: widget.mostrarProva),
        ],
        if (widget.haMais)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );

    final comScroll = widget.carregarMais == null
        ? lista
        : NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _talvezCarregar();
              return false;
            },
            child: lista,
          );

    return widget.actualizar == null ? comScroll : RefreshIndicator(onRefresh: widget.actualizar!, child: comScroll);
  }
}

/// O cabeçalho de um dia numa lista agrupada por data.
class CabecalhoDia extends StatelessWidget {
  const CabecalhoDia(this.dia, {super.key});

  final DateTime dia;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hoje = DateUtils.dateOnly(DateTime.now());
    final diferenca = dia.difference(hoje).inDays;
    final etiqueta = switch (diferenca) {
      0 => 'Hoje',
      1 => 'Amanhã',
      -1 => 'Ontem',
      _ => DateFormat("EEEE, d 'de' MMMM", 'pt_PT').format(dia),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        etiqueta[0].toUpperCase() + etiqueta.substring(1),
        style: t.textTheme.titleSmall?.copyWith(color: diferenca == 0 ? t.colorScheme.primary : null),
      ),
    );
  }
}

/// Abaixo disto o emblema e o espaço ao lado dele já não deixam nada
/// para o nome da equipa.
const _larguraMinimaComEmblema = 88.0;

class _Confronto extends StatelessWidget {
  const _Confronto(this.i);

  final ItemAgenda i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    // O emblema tem tamanho fixo, por isso num ecrã estreito com a letra
    // grande pode sobrar-lhe menos espaço do que ele ocupa. Quando isso
    // acontece é ele que sai: quem joga diz-se pelo nome.
    Widget equipa(Equipa e, {required bool esquerda}) => Expanded(
      child: LayoutBuilder(
        builder: (_, limites) {
          final comEmblema = limites.maxWidth >= _larguraMinimaComEmblema;
          return Row(
            mainAxisAlignment: esquerda ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (esquerda && comEmblema) ...[EmblemaEquipa(e), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  e.nome,
                  textAlign: esquerda ? TextAlign.start : TextAlign.end,
                  // Três linhas porque a caixa do resultado come o meio do
                  // cartão: entre "Cr Leões Porto Sa..." e mais uma linha,
                  // ganha o nome inteiro.
                  maxLines: i.temResultado ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: e.doClube ? FontWeight.w800 : FontWeight.w500),
                ),
              ),
              if (!esquerda && comEmblema) ...[const SizedBox(width: 6), EmblemaEquipa(e)],
            ],
          );
        },
      ),
    );

    return Row(
      children: [
        equipa(i.casa!, esquerda: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: i.temResultado
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${i.golosCasa} - ${i.golosFora}', style: t.textTheme.titleMedium),
                )
              : Text('vs', style: t.textTheme.bodySmall),
        ),
        equipa(i.fora!, esquerda: false),
      ],
    );
  }
}

/// O emblema de uma equipa. Também serve a ficha e o placard do jogo, por
/// isso o tamanho é dado por quem o usa.
class EmblemaEquipa extends StatelessWidget {
  const EmblemaEquipa(this.e, {super.key, this.tamanho = 28});

  final Equipa e;

  /// No cartão é pequeno de propósito: o nome da equipa é que tem de caber.
  /// Entre "Cr Leões Porto Salvo" cortado e um emblema maior, ganha o nome.
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    // Os emblemas vêm da API (`emblema_url`, carregados no backoffice). O que
    // ainda não tem: a nossa equipa leva o brasão da app — é o que faz
    // encontrar o nosso jogo numa lista de doze equipas —, as outras um escudo.
    final pixeis = (tamanho * MediaQuery.devicePixelRatioOf(context)).round();
    final escudo = Icon(Icons.shield_outlined, size: tamanho * 0.64, color: c.onSurfaceVariant);
    final brasao = Image.asset('assets/images/brasao.png', cacheWidth: pixeis, semanticLabel: 'Brasão do clube');
    final Widget dentro = switch (e.emblemaUrl) {
      // Os ficheiros vêm em tamanho de impressão: descodifica-se ao do ecrã.
      final String url => ImagemRede(url, fit: BoxFit.contain, larguraCache: pixeis, falha: (_) => e.doClube ? brasao : escudo),
      _ when e.doClube => brasao,
      _ => escudo,
    };
    final temImagem = e.emblemaUrl != null || e.doClube;

    return Container(
      width: tamanho,
      height: tamanho,
      // Fundo branco para os emblemas, desenhados para papel; folga para o
      // círculo não cortar as pontas de um escudo.
      padding: EdgeInsets.all(temImagem ? tamanho * 0.08 : 0),
      decoration: BoxDecoration(color: temImagem ? Colors.white : c.surfaceContainerHigh, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Center(child: dentro),
    );
  }
}

class _Evento extends StatelessWidget {
  const _Evento(this.i);

  final ItemAgenda i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (i.capaUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(dimension: 56, child: ImagemRede(i.capaUrl!)),
          ),
          const SizedBox(width: 12),
        ] else ...[
          const IconePastilha(Icons.celebration_outlined),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i.titulo, style: t.textTheme.titleSmall),
              if (i.resumo != null) ...[
                const SizedBox(height: 2),
                Text(i.resumo!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
