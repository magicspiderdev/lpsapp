import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import 'clube.dart';

/// Informação geral: quem é o clube, onde é, como falar com ele.
class ClubePage extends ConsumerWidget {
  const ClubePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(clubeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('O clube')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is EmPreparacao
            ? const PainelEmPreparacao(
                icone: Icons.info_outline_rounded,
                titulo: 'Informação do clube a caminho',
                texto: 'História, modalidades, morada, horário da secretaria\ne contactos, actualizados pelo clube.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(clubeProvider)),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
          children: [
            _Cabecalho(c),
            if (c.historia != null) ...[
              const TituloSeccao('História'),
              Bloco(
                padding: const EdgeInsets.all(16),
                child: Text(c.historia!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
              ),
            ],
            if (c.modalidades.isNotEmpty) ...[
              const TituloSeccao('Modalidades'),
              Bloco(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final (i, m) in c.modalidades.indexed) ...[
                      if (i > 0) const Divider(indent: 72),
                      ListTile(
                        leading: const IconePastilha(Icons.sports_handball_outlined),
                        title: Text(m.nome),
                        subtitle: m.escaloes == null ? null : Text(m.escaloes!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const TituloSeccao('Contactos'),
            _Contactos(c),
            if (c.horario.isNotEmpty) ...[
              const TituloSeccao('Secretaria'),
              Bloco(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in c.horario)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(h)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (c.redes.isNotEmpty) ...[const TituloSeccao('Siga o clube'), _Redes(c.redes)],
            const TituloSeccao('Aplicação'),
            const _Versao(),
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.c);

  final Clube c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: Tema.gradienteClube, borderRadius: BorderRadius.circular(Tema.raio)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Text(
              'LPS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(c.nome, style: t.textTheme.headlineSmall?.copyWith(color: Colors.white)),
          if (c.lema != null) ...[
            const SizedBox(height: 4),
            Text(c.lema!, style: t.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
          ],
          if (c.fundadoEm != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Desde ${c.fundadoEm}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Contactos extends StatelessWidget {
  const _Contactos(this.c);

  final Clube c;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[
      if (c.morada != null)
        _Accao(
          icone: Icons.place_outlined,
          titulo: c.morada!,
          detalhe: 'Ver no mapa',
          onTap: c.mapaUrl == null ? null : () => _abrir(c.mapaUrl!),
        ),
      for (final contacto in c.contactos)
        _Accao(
          icone: contacto.tipo == 'telefone' ? Icons.call_outlined : Icons.mail_outline_rounded,
          titulo: contacto.valor,
          detalhe: contacto.etiqueta,
          onTap: () => _abrir(
            contacto.tipo == 'telefone' ? 'tel:${contacto.valor.replaceAll(' ', '')}' : 'mailto:${contacto.valor}',
          ),
        ),
      if (c.site != null)
        _Accao(icone: Icons.public_rounded, titulo: c.site!, detalhe: 'Sítio do clube', onTap: () => _abrir(c.site!)),
    ];

    return Bloco(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, l) in linhas.indexed) ...[if (i > 0) const Divider(indent: 72), l],
        ],
      ),
    );
  }
}

class _Accao extends StatelessWidget {
  const _Accao({required this.icone, required this.titulo, this.detalhe, this.onTap});

  final IconData icone;
  final String titulo;
  final String? detalhe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: IconePastilha(icone),
      title: Text(titulo),
      subtitle: detalhe == null ? null : Text(detalhe!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _Redes extends StatelessWidget {
  const _Redes(this.redes);

  final Map<String, String> redes;

  static const _icones = {
    'facebook': Icons.facebook_rounded,
    'instagram': Icons.camera_alt_outlined,
    'youtube': Icons.play_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final MapEntry(:key, :value) in redes.entries)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _abrir(value),
                child: SizedBox.square(
                  dimension: 52,
                  // Rede desconhecida: ícone genérico de ligação.
                  child: Icon(_icones[key] ?? Icons.link_rounded, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Versao extends StatelessWidget {
  const _Versao();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        return Bloco(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const IconePastilha(Icons.phone_iphone_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LPS Neo', style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      info == null ? 'App do clube' : 'Versão ${info.version} (${info.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _abrir(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
