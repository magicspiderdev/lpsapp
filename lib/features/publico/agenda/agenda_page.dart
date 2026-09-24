import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/com_cache.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'agenda.dart';
import 'agenda_widgets.dart';

/// Jogos e eventos do clube: o que vem aí e o que já se passou, agrupados por
/// dia.
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
              child: Row(
                children: [
                  Expanded(
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
                  IconButton(
                    tooltip: 'Competições',
                    onPressed: () => context.push('/agenda/competicao'),
                    icon: const Icon(Icons.emoji_events_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: estado.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => e is EmPreparacao
                    ? const PainelEmPreparacao(
                        icone: Icons.event_outlined,
                        titulo: 'Agenda a caminho',
                        texto: 'Jogos de todas as modalidades e eventos do clube,\ncom aviso antes de começarem.',
                      )
                    : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(agendaProvider)),
                data: (d) => _Agenda(
                  dados: d,
                  filtro: _filtro,
                  onFiltro: (f) => setState(() => _filtro = f),
                  actualizar: () => ref.refresh(agendaProvider.future),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Agenda extends ConsumerWidget {
  const _Agenda({required this.dados, required this.filtro, required this.onFiltro, required this.actualizar});

  final Dados<List<ItemAgenda>> dados;
  final String? filtro;
  final ValueChanged<String?> onFiltro;
  final Future<void> Function() actualizar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O passado vem aos poucos: a janela inicial são dias, e recua-se mais
    // quando alguém chega ao fim da lista.
    final mais = ref.watch(maisAnterioresProvider);
    final itens = [...dados.valor, ...mais.itens];
    final modalidades = {
      for (final i in itens)
        if (i.modalidade != null) i.modalidade!,
    }.toList()..sort();

    final visiveis = itens.where((i) {
      if (filtro == null) return true;
      if (filtro == 'Eventos') return i.tipo == TipoItem.evento;
      return i.modalidade == filtro;
    });

    final (proximos, anteriores) = separarPorTempo(visiveis);

    return SeparadoresDeTempo(
      // Fora de época não há nada à frente: abrir nos próximos seria abrir num
      // ecrã vazio com a informação toda no separador do lado.
      comecarNosAnteriores: proximos.isEmpty && anteriores.isNotEmpty,
      acimaDosSeparadores: Padding(
        padding: const EdgeInsets.fromLTRB(Tema.margem, 4, Tema.margem, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AvisoDesactualizado(dados, margem: const EdgeInsets.only(bottom: 8)),
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
          ],
        ),
      ),
      proximos: ListaDeJogos(
        itens: proximos,
        actualizar: actualizar,
        vazio: const PainelEmPreparacao(
          icone: Icons.event_busy_outlined,
          titulo: 'Nada marcado',
          texto: 'Não há jogos nem eventos à frente com este filtro.',
        ),
      ),
      anteriores: ListaDeJogos(
        itens: anteriores,
        actualizar: actualizar,
        carregarMais: ref.read(maisAnterioresProvider.notifier).carregar,
        aCarregarMais: mais.aCarregar,
        haMais: !mais.fim,
        vazio: const PainelEmPreparacao(
          icone: Icons.history_rounded,
          titulo: 'Nada para trás',
          texto: 'Não há jogos nem eventos passados com este filtro.',
        ),
      ),
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
