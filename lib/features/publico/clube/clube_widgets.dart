import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/cache/com_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/erro_view.dart';
import 'clube.dart';

/// Enquanto a secretaria não preenche o nome oficial no backoffice.
const nomeDoClube = 'Leões de Porto Salvo';

void abrirLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// `https://www.leoesdeportosalvo.pt/` → `leoesdeportosalvo.pt`.
String dominio(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.isEmpty ? url : host.replaceFirst(RegExp(r'^www\.'), '');
}

/// O que acontece ao tocar num contacto; `null` para tipos que não se sabe
/// abrir (a lista de tipos é aberta).
VoidCallback? accaoDoContacto(Contacto c) => switch (c.tipo) {
  'telefone' => () => abrirLink('tel:${c.valor.replaceAll(' ', '')}'),
  'email' => () => abrirLink('mailto:${c.valor}'),
  _ => null,
};

IconData iconeDoContacto(Contacto c) => switch (c.tipo) {
  'telefone' => Icons.call_rounded,
  'email' => Icons.mail_outline_rounded,
  _ => Icons.info_outline_rounded,
};

/// Ícone pela modalidade: o slug vem do CISOC e não é uma lista fechada, por
/// isso procura-se por palavras e cai num ícone genérico.
IconData iconeDaModalidade(Modalidade m) {
  final chave = '${m.slug ?? ''} ${m.nome}'.toLowerCase();
  if (chave.contains('walking')) return Icons.directions_walk_rounded;
  if (chave.contains('patina')) return Icons.roller_skating_rounded;
  if (chave.contains('hoquei') || chave.contains('hóquei')) return Icons.sports_hockey_rounded;
  if (chave.contains('futsal') || chave.contains('futebol')) return Icons.sports_soccer_rounded;
  if (chave.contains('basquet')) return Icons.sports_basketball_rounded;
  if (chave.contains('volei') || chave.contains('vólei')) return Icons.sports_volleyball_rounded;
  if (chave.contains('andebol')) return Icons.sports_handball_rounded;
  if (chave.contains('gin')) return Icons.sports_gymnastics_rounded;
  if (chave.contains('natac') || chave.contains('nataç')) return Icons.pool_rounded;
  if (chave.contains('tenis') || chave.contains('ténis') || chave.contains('padel')) return Icons.sports_tennis_rounded;
  return Icons.sports_rounded;
}

/// Parágrafos de um texto simples do CISOC (separados por linha em branco).
List<String> paragrafos(String texto) =>
    texto.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

/// O brasão do clube num quadrado branco (lê-se igual em claro e escuro).
class Brasao extends StatelessWidget {
  const Brasao({super.key, this.tamanho = 72});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final pixeis = (tamanho * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: tamanho,
      height: tamanho,
      padding: EdgeInsets.all(tamanho * 0.1),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: AppRadius.mdAll),
      child: Image.asset(
        'assets/images/brasao.png',
        // O original tem 1500 px: descodifica-se só ao tamanho que se vê.
        cacheWidth: pixeis,
        semanticLabel: 'Brasão do clube',
      ),
    );
  }
}

/// Estados comuns das páginas do clube: a carregar, erro, ou os dados.
class ComClube extends ConsumerWidget {
  const ComClube({super.key, required this.builder});

  final Widget Function(BuildContext context, Dados<Clube> dados) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(clubeProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(clubeProvider)),
          data: (d) => builder(context, d),
        );
  }
}

/// Cartão de entrada para uma sub-página: ícone, título e uma linha de resumo.
class CartaoEntrada extends StatelessWidget {
  const CartaoEntrada({
    super.key,
    required this.icone,
    required this.titulo,
    required this.resumo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo, resumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Material(
      color: c.surfaceContainerLowest,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.smAll),
                    child: Icon(icone, color: c.onPrimaryContainer),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: c.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(titulo, style: t.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(resumo, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
