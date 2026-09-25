import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/links_legais.dart';
import 'clube.dart';
import 'clube_paginas.dart';
import 'clube_widgets.dart';

/// O clube num ecrã: quem é, atalhos para falar com ele, e cartões para o
/// resto (história, modalidades, contactos), cada um na sua página.
class ClubePage extends ConsumerWidget {
  const ClubePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ComClube(
          builder: (context, d) {
            final c = d.valor;
            return RefreshIndicator(
              edgeOffset: MediaQuery.paddingOf(context).top,
              onRefresh: () => ref.refresh(clubeProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _Cabecalho(c),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AvisoDesactualizado(d, margem: const EdgeInsets.only(top: AppSpacing.lg)),
                        if (c.modalidades.isNotEmpty) ...[
                          TituloSeccao(
                            'Modalidades',
                            accao: TextButton(
                              onPressed: () => context.push('/noticias/clube/modalidades'),
                              child: const Text('Ver todas'),
                            ),
                          ),
                          _CarrosselModalidades(c.modalidades),
                        ],
                        if (c.historia != null || c.temContactos) ...[
                          const TituloSeccao('Conhecer o clube'),
                          _Entradas(c),
                        ],
                        // O que o clube pôs no menu da app (páginas, submenus,
                        // links). Sem menu não aparece nada.
                        const EntradasMenu(titulo: TituloSeccao('Mais sobre o clube')),
                        if (c.redes.isNotEmpty) ...[const TituloSeccao('Siga o clube'), _Redes(c.redes)],
                        const SizedBox(height: AppSpacing.xl),
                        // Para quem usa a app sem conta: a política tem de se
                        // encontrar dentro da app, não só no registo.
                        const LinksLegais(alinhamento: WrapAlignment.center),
                        const _Versao(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Topo verde: voltar, brasão, nome, lema, pílulas e atalhos de contacto.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.c);

  final Clube c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cores = AppColors.of(context);
    final atalhos = <Widget>[
      if (c.telefone case final tel?)
        AccaoRedonda(icone: Icons.call_rounded, legenda: 'Ligar', sobreEscuro: true, onTap: accaoDoContacto(tel)!),
      if (c.email case final email?)
        AccaoRedonda(
          icone: Icons.mail_outline_rounded,
          legenda: 'Email',
          sobreEscuro: true,
          onTap: accaoDoContacto(email)!,
        ),
      if (c.mapaUrl case final mapa?)
        AccaoRedonda(icone: Icons.map_outlined, legenda: 'Mapa', sobreEscuro: true, onTap: () => abrirLink(mapa)),
      if (c.site case final site?)
        AccaoRedonda(icone: Icons.public_rounded, legenda: 'Site', sobreEscuro: true, onTap: () => abrirLink(site)),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: cores.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        MediaQuery.paddingOf(context).top + AppSpacing.xs,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Voltar',
            style: IconButton.styleFrom(backgroundColor: cores.brandSurface, foregroundColor: cores.onBrand),
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go('/noticias'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Brasao(tamanho: 76),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nome ?? nomeDoClube, style: t.headlineSmall?.copyWith(color: cores.onBrand)),
                    if (c.lema != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(c.lema!, style: t.bodyMedium?.copyWith(color: cores.onBrandMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (c.fundadoEm != null || c.modalidades.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (c.fundadoEm != null) _Pilula(Icons.flag_outlined, 'Desde ${c.fundadoEm}'),
                if (c.modalidades.isNotEmpty)
                  _Pilula(
                    Icons.sports_rounded,
                    '${c.modalidades.length} ${c.modalidades.length == 1 ? 'modalidade' : 'modalidades'}',
                  ),
              ],
            ),
          ],
          if (atalhos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            // Com quatro, partilham a largura; com menos, ficam à esquerda.
            Row(
              children: [
                for (final a in atalhos)
                  if (atalhos.length == 4)
                    Expanded(child: a)
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xl),
                      child: a,
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula(this.icone, this.texto);

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: ShapeDecoration(color: cores.brandSurface, shape: AppRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: cores.onBrand),
          const SizedBox(width: AppSpacing.sm),
          // Com a letra do sistema muito grande, parte a linha em vez de sair da pílula.
          Flexible(
            child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cores.onBrand)),
          ),
        ],
      ),
    );
  }
}

/// As modalidades lado a lado; cada uma abre a sua página.
class _CarrosselModalidades extends StatelessWidget {
  const _CarrosselModalidades(this.modalidades);

  final List<Modalidade> modalidades;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    // A altura acompanha a letra do sistema, para os nomes não serem cortados.
    final altura = MediaQuery.textScalerOf(context).scale(1) * 64 + 76;
    return SizedBox(
      height: altura,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Os cartões vão até à borda do ecrã: percebe-se que há mais para o lado.
        clipBehavior: Clip.none,
        itemCount: modalidades.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final m = modalidades[i];
          return SizedBox(
            width: 136,
            child: Material(
              color: c.surfaceContainerLowest,
              borderRadius: AppRadius.lgAll,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                // Só se abre o que tem página (`tem_pagina`): as outras são só o nome.
                onTap: m.temPagina ? () => context.push('/noticias/clube/modalidades/${m.slug}') : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                        child: Icon(iconeDaModalidade(m), color: c.onPrimaryContainer, size: 26),
                      ),
                      const Spacer(),
                      Text(m.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall),
                      if (m.escaloes != null || m.temPagina)
                        Text(
                          m.escaloes ?? 'Horários e treinos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cartões para a história e para os contactos, lado a lado.
class _Entradas extends StatelessWidget {
  const _Entradas(this.c);

  final Clube c;

  @override
  Widget build(BuildContext context) {
    final cartoes = [
      if (c.historia != null)
        CartaoEntrada(
          icone: Icons.auto_stories_outlined,
          titulo: 'História',
          resumo: c.fundadoEm != null ? 'Desde ${c.fundadoEm}: como tudo começou' : 'Como tudo começou',
          onTap: () => context.push('/noticias/clube/historia'),
        ),
      if (c.temContactos)
        CartaoEntrada(
          icone: Icons.place_outlined,
          titulo: 'Contactos e horário',
          resumo: c.horario.isNotEmpty ? c.horario.first : (c.morada ?? 'Onde estamos e como falar connosco'),
          onTap: () => context.push('/noticias/clube/contactos'),
        ),
    ];
    // Um só cartão ocupa a largura; dois partilham a linha, com a mesma altura.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, cartao) in cartoes.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: cartao),
          ],
        ],
      ),
    );
  }
}

class _Redes extends StatelessWidget {
  const _Redes(this.redes);

  final Map<String, String> redes;

  static const _icones = {
    'facebook': Icons.facebook_rounded,
    'instagram': Icons.photo_camera_outlined,
    'youtube': Icons.smart_display_outlined,
    'tiktok': Icons.music_note_rounded,
  };

  static String _nome(String rede) => switch (rede) {
    'facebook' => 'Facebook',
    'instagram' => 'Instagram',
    'youtube' => 'YouTube',
    'tiktok' => 'TikTok',
    _ => rede.isEmpty ? 'Ligação' : rede[0].toUpperCase() + rede.substring(1),
  };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final MapEntry(:key, :value) in redes.entries)
          ActionChip(
            avatar: Icon(_icones[key] ?? Icons.link_rounded, color: c.primary),
            label: Text(_nome(key)),
            onPressed: () => abrirLink(value),
          ),
      ],
    );
  }
}

/// Rodapé discreto com a versão da app.
class _Versao extends StatefulWidget {
  const _Versao();

  @override
  State<_Versao> createState() => _VersaoState();
}

class _VersaoState extends State<_Versao> {
  // Pedido uma vez: no `build` seria um pedido novo a cada reconstrução.
  final _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snap) => Text(
        snap.data == null ? 'LPS Neo' : 'LPS Neo · versão ${snap.data!.version} (${snap.data!.buildNumber})',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFeatures: AppTypography.tabular),
      ),
    );
  }
}
