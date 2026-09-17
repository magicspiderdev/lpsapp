import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'agenda.dart';

/// Jogos e eventos do clube, agrupados por dia.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  /// `null` = tudo; senão, o nome da modalidade ou 'Eventos'.
  String? _filtro;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(agendaProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 20, Tema.margem, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALENDÁRIO',
                    style: t.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Agenda', style: t.headlineLarge),
                ],
              ),
            ),
            Expanded(
              child: estado.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => e is EmPreparacao
                    ? const PainelEmPreparacao(
                        icone: Icons.event_outlined,
                        titulo: 'Agenda a caminho',
                        texto: 'Jogos de todas as modalidades e eventos do clube,\ncom aviso antes de começarem.',
                      )
                    : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(agendaProvider)),
                data: (itens) => _Lista(itens: itens, filtro: _filtro, onFiltro: (f) => setState(() => _filtro = f)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.itens, required this.filtro, required this.onFiltro});

  final List<ItemAgenda> itens;
  final String? filtro;
  final ValueChanged<String?> onFiltro;

  @override
  Widget build(BuildContext context) {
    final modalidades = {
      for (final i in itens)
        if (i.modalidade != null) i.modalidade!,
    }.toList()..sort();
    final visiveis = itens.where((i) {
      if (filtro == null) return true;
      if (filtro == 'Eventos') return i.tipo == TipoItem.evento;
      return i.modalidade == filtro;
    }).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));

    final porDia = <DateTime, List<ItemAgenda>>{};
    for (final i in visiveis) {
      porDia.putIfAbsent(DateUtils.dateOnly(i.inicio), () => []).add(i);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Filtro('Tudo', activo: filtro == null, onTap: () => onFiltro(null)),
              for (final m in modalidades) _Filtro(m, activo: filtro == m, onTap: () => onFiltro(m)),
              _Filtro('Eventos', activo: filtro == 'Eventos', onTap: () => onFiltro('Eventos')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (visiveis.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: PainelEmPreparacao(
              icone: Icons.event_busy_outlined,
              titulo: 'Nada marcado',
              texto: 'Não há jogos nem eventos com este filtro.',
            ),
          ),
        for (final dia in porDia.keys) ...[_Dia(dia), for (final i in porDia[dia]!) _Cartao(i)],
      ],
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro(this.texto, {required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: activo ? c.primary : c.surfaceContainerLowest,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              texto,
              style: TextStyle(color: activo ? c.onPrimary : c.onSurface, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia(this.dia);

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

/// Um jogo (com as duas equipas) ou um evento (com fotografia e resumo).
class _Cartao extends StatelessWidget {
  const _Cartao(this.i);

  final ItemAgenda i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hora = i.horaConfirmada ? DateFormat('HH:mm').format(i.inicio) : 'Hora por confirmar';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Bloco(
        padding: const EdgeInsets.all(14),
        onTap: i.temBilhetes ? () => context.push('/bilhetes/${i.sessaoBilhetes}') : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(hora, style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      if (i.modalidade != null) i.modalidade!,
                      if (i.prova != null) i.prova!,
                      if (i.tipo == TipoItem.evento) 'Evento',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall,
                  ),
                ),
                if (i.cancelado)
                  Text(
                    i.estado == 'adiado' ? 'Adiado' : 'Cancelado',
                    style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (i.tipo == TipoItem.jogo && i.casa != null && i.fora != null) _Confronto(i) else _Evento(i),
            if (i.local != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: t.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(i.local!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                  ),
                  if (i.temBilhetes)
                    Text('Bilhetes', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Confronto extends StatelessWidget {
  const _Confronto(this.i);

  final ItemAgenda i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    Widget equipa(Equipa e, {required bool esquerda}) => Expanded(
      child: Row(
        mainAxisAlignment: esquerda ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (esquerda) _Emblema(e),
          if (esquerda) const SizedBox(width: 8),
          Flexible(
            child: Text(
              e.nome,
              textAlign: esquerda ? TextAlign.start : TextAlign.end,
              maxLines: 2,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: e.doClube ? FontWeight.w800 : FontWeight.w500),
            ),
          ),
          if (!esquerda) const SizedBox(width: 8),
          if (!esquerda) _Emblema(e),
        ],
      ),
    );

    return Row(
      children: [
        equipa(i.casa!, esquerda: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: i.temResultado
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _Emblema extends StatelessWidget {
  const _Emblema(this.e);

  final Equipa e;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: e.doClube ? c.primaryContainer : c.surfaceContainerHigh, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: e.emblemaUrl != null
          ? ImagemRede(e.emblemaUrl!, fit: BoxFit.contain)
          : Icon(Icons.shield_outlined, size: 18, color: e.doClube ? c.primary : c.onSurfaceVariant),
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
