import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../noticias/corpo_blocos.dart';
import 'clube.dart';
import 'clube_widgets.dart';

/// Largura máxima do texto corrido: linhas mais longas cansam a leitura (e em
/// tablets o texto não se espalha pelo ecrã todo).
const _larguraLeitura = BoxConstraints(maxWidth: AppSpacing.maxContentWidth);

/// `/noticias/clube/historia`
class HistoriaClubePage extends StatelessWidget {
  const HistoriaClubePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('História')),
      body: ComClube(
        builder: (context, d) {
          final c = d.valor;
          final texto = c.historia;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
            children: [
              AvisoDesactualizado(d),
              Row(
                children: [
                  const Brasao(tamanho: 56),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nome ?? nomeDoClube, style: t.textTheme.titleMedium),
                        if (c.fundadoEm != null) Text('Fundado em ${c.fundadoEm}', style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (texto == null)
                Text('A história do clube ainda não foi publicada.', style: t.textTheme.bodyMedium)
              // Com a formatação do backoffice (títulos, negritos, listas), já
              // limpa no servidor.
              else if (c.historiaHtml != null)
                Center(
                  child: ConstrainedBox(constraints: _larguraLeitura, child: TextoHtml(c.historiaHtml!)),
                )
              else
                Center(
                  child: ConstrainedBox(
                    constraints: _larguraLeitura,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, p) in paragrafos(texto).indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                            // O primeiro parágrafo abre o texto, um pouco maior.
                            child: Text(p, style: i == 0 ? t.textTheme.titleMedium : t.textTheme.bodyLarge),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// `/noticias/clube/modalidades`
class ModalidadesPage extends StatelessWidget {
  const ModalidadesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modalidades')),
      body: ComClube(
        builder: (context, d) {
          final modalidades = d.valor.modalidades;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
            children: [
              AvisoDesactualizado(d),
              if (modalidades.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                  child: Text(
                    'As modalidades ainda não foram publicadas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                // Duas colunas: as modalidades lêem-se de relance.
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: modalidades.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisExtent: MediaQuery.textScalerOf(context).scale(1) * 60 + 100,
                  ),
                  itemBuilder: (context, i) => _CartaoModalidade(modalidades[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CartaoModalidade extends StatelessWidget {
  const _CartaoModalidade(this.m);

  final Modalidade m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Material(
      color: c.surfaceContainerLowest,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: m.temPagina ? () => context.push('/noticias/clube/modalidades/${m.slug}') : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                child: Icon(iconeDaModalidade(m), color: c.onPrimaryContainer, size: 28),
              ),
              const Spacer(),
              Text(m.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium),
              if (m.escaloes != null || m.temPagina)
                Text(
                  m.escaloes == null ? 'Horários e treinos' : 'Escalões: ${m.escaloes}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/noticias/clube/modalidades/{slug}`
class ModalidadePage extends StatelessWidget {
  const ModalidadePage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ComClube(
      builder: (context, d) {
        final m = d.valor.modalidades.where((m) => m.slug == slug).firstOrNull;
        if (m == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text('Esta modalidade já não aparece no clube.', style: t.textTheme.bodyMedium),
              ),
            ),
          );
        }
        final cores = AppColors.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(m.nome)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
            children: [
              AvisoDesactualizado(d),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(gradient: cores.brandGradient, borderRadius: AppRadius.lgAll),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: cores.brandSurface, shape: BoxShape.circle),
                      child: Icon(iconeDaModalidade(m), color: cores.onBrand, size: 34),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.nome, style: t.textTheme.headlineSmall?.copyWith(color: cores.onBrand)),
                          if (m.escaloes != null)
                            Text(
                              'Escalões: ${m.escaloes}',
                              style: t.textTheme.bodyMedium?.copyWith(color: cores.onBrandMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (m.descricao != null)
                for (final p in paragrafos(m.descricao!))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Text(p, style: t.textTheme.bodyLarge),
                  ),
              if (m.temPagina)
                _CorpoModalidade(m.slug!)
              else if (m.descricao == null)
                Text(
                  'Para saber horários de treino e como inscrever um atleta, fale com a secretaria.',
                  style: t.textTheme.bodyLarge,
                ),
              const SizedBox(height: AppSpacing.lg),
              if (d.valor.temContactos) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.push('/noticias/clube/contactos'),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Contactar a secretaria'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// O horário, os escalões e o resto que a modalidade publicou
/// (`/clube/modalidades/{slug}`).
class _CorpoModalidade extends ConsumerWidget {
  const _CorpoModalidade(this.slug);

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(paginaModalidadeProvider(slug))
        .when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(paginaModalidadeProvider(slug))),
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AvisoDesactualizado(d),
              CorpoBlocos(d.valor.corpo),
            ],
          ),
        );
  }
}

/// `/noticias/clube/contactos`
class ContactosClubePage extends StatelessWidget {
  const ContactosClubePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contactos e horário')),
      body: ComClube(
        builder: (context, d) {
          final c = d.valor;
          final linhas = <Widget>[
            for (final contacto in c.contactos)
              ListTile(
                leading: IconePastilha(iconeDoContacto(contacto)),
                title: Text(contacto.valor),
                subtitle: contacto.etiqueta == null ? null : Text(contacto.etiqueta!),
                trailing: accaoDoContacto(contacto) == null ? null : const Icon(Icons.chevron_right_rounded),
                onTap: accaoDoContacto(contacto),
              ),
            if (c.site != null)
              ListTile(
                leading: const IconePastilha(Icons.public_rounded),
                title: Text(dominio(c.site!)),
                subtitle: const Text('Sítio do clube'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => abrirLink(c.site!),
              ),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
            children: [
              AvisoDesactualizado(d),
              if (c.morada != null) ...[
                Bloco(
                  onTap: c.mapaUrl == null ? null : () => abrirLink(c.mapaUrl!),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      const IconePastilha(Icons.place_outlined),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Morada', style: t.textTheme.bodySmall),
                            Text(c.morada!, style: t.textTheme.titleSmall),
                          ],
                        ),
                      ),
                      if (c.mapaUrl != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text('Mapa', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
                      ],
                    ],
                  ),
                ),
              ],
              if (c.horario.isNotEmpty) ...[
                const TituloSeccao('Horário da secretaria'),
                Bloco(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      for (final (i, h) in c.horario.indexed) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 20, color: t.colorScheme.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: Text(h, style: t.textTheme.bodyLarge)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (linhas.isNotEmpty) ...[
                const TituloSeccao('Falar connosco'),
                Bloco(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (final (i, l) in linhas.indexed) ...[if (i > 0) const Divider(indent: 72), l],
                    ],
                  ),
                ),
              ],
              if (!c.temContactos)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                  child: Text(
                    'Os contactos do clube ainda não foram publicados.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
