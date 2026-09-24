import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';
import '../../../core/links.dart';
import '../../../core/tema/tema.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/imagem_rede.dart';

/// O corpo de um artigo ou da página de uma modalidade: a lista de blocos da
/// API pública (§6). É a mesma nos dois sítios de propósito — o backoffice tem
/// um editor só.
///
/// Só se compõem os tipos que a app conhece; os outros ignoram-se (invariante
/// I7), e um bloco a que falte o essencial também.
class CorpoBlocos extends StatelessWidget {
  const CorpoBlocos(this.blocos, {super.key});

  final List<Map<String, dynamic>> blocos;

  @override
  Widget build(BuildContext context) {
    // Blocos seguidos com o mesmo `estilo` são uma secção só, no mesmo fundo.
    final seccoes = <(String?, List<Widget>)>[];
    for (final b in blocos) {
      final w = _bloco(context, b);
      if (w == null) continue;
      final estilo = _estilos.contains(b['estilo']) ? b['estilo'] as String : null;
      if (seccoes.isNotEmpty && seccoes.last.$1 == estilo && estilo != null) {
        seccoes.last.$2.add(w);
      } else {
        seccoes.add((estilo, [w]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (estilo, filhos) in seccoes)
          if (estilo == null)
            for (final f in filhos) Padding(padding: const EdgeInsets.only(top: 16), child: f)
          else
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: _fundo(context, estilo),
                  borderRadius: BorderRadius.circular(Tema.raioPequeno),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final f in filhos) Padding(padding: const EdgeInsets.only(top: 16), child: f)],
                ),
              ),
            ),
      ],
    );
  }

  /// Os `estilo` que a app sabe desenhar. Lista aberta: o resto fica sem fundo.
  static const _estilos = {'branco', 'claro', 'verde', 'ouro'};

  /// O estilo é um nome e não uma cor: cada cliente escolhe a sua.
  static Color _fundo(BuildContext context, String estilo) {
    final c = Theme.of(context).colorScheme;
    return switch (estilo) {
      'branco' => c.surfaceContainerLowest,
      'verde' => c.primaryContainer,
      'ouro' => AppColors.of(context).warning.container,
      _ => c.surfaceContainerHigh,
    };
  }

  static Widget? _bloco(BuildContext context, Map<String, dynamic> b) {
    // A imagem vem com o URL montado (`capa.url`, blocos `imagem`); o `uid` só
    // aparece nos exemplos do modo de demonstração.
    final urlImagem = b['url'] as String? ?? (b['uid'] is String ? Config.mediaUrl(b['uid'] as String) : null);

    return switch (b['tipo']) {
      'texto' => TextoHtml(b['html'] as String? ?? ''),
      'imagem' when urlImagem != null => _Imagem(b, urlImagem),
      'video' when b['miniatura_url'] is String || b['url'] is String => _Video(b),
      'tabela' when b['linhas'] is List && (b['linhas'] as List).isNotEmpty => _Tabela(b),
      'mapa' when b['url'] is String => _Mapa(b),
      'citacao' => _Citacao(b['texto'] as String? ?? ''),
      'separador' => const Divider(),
      _ => null,
    };
  }
}

/// HTML da lista branca do servidor: o bloco `texto` e a `historia_html` do
/// clube.
///
/// Desde 2026-09-21 leva marcação (§4.20): `<p> <br> <strong> <em> <u> <s>
/// <h2>`–`<h4> <ul> <ol> <li> <blockquote> <a>`, lista curta, fixa e
/// **garantida no servidor** — o que não está nela é removido na gravação. Por
/// isso se compõe directamente, sem `WebView` e sem voltar a sanitizar: não há
/// `<img>`, `<iframe>`, `<script>`, `style` nem `on*` para interpretar.
class TextoHtml extends StatelessWidget {
  const TextoHtml(this.html, {super.key});

  final String html;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return HtmlWidget(
      html,
      textStyle: tema.textTheme.bodyLarge?.copyWith(height: 1.6),
      customStylesBuilder: (e) => switch (e.localName) {
        'h2' || 'h3' || 'h4' => const {'margin': '20px 0 6px', 'line-height': '1.25'},
        'ul' || 'ol' => const {'margin': '8px 0'},
        'blockquote' => const {'margin': '12px 0', 'padding-left': '12px'},
        'a' => {'color': _cor(tema.colorScheme.primary), 'text-decoration': 'none'},
        _ => null,
      },
      onTapUrl: (url) => Links.abrir(context, url),
    );
  }

  /// O CSS do compositor não conhece `Color`: precisa de `#rrggbb`.
  static String _cor(Color c) =>
      '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0')}';
}

class _Citacao extends StatelessWidget {
  const _Citacao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tema.colorScheme.primary, width: 3)),
      ),
      child: Text(texto, style: tema.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
    );
  }
}

/// Uma fotografia do corpo, com o crédito e a legenda que a acompanham.
class _Imagem extends StatelessWidget {
  const _Imagem(this.b, this.url);

  final Map<String, dynamic> b;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final legenda = [
      if (b['legenda'] is String) b['legenda'] as String,
      if (b['credito'] is String) 'Fotografia: ${b['credito']}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tema.raioPequeno),
          child: ImagemRede(url, fit: BoxFit.fitWidth),
        ),
        if (legenda.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(legenda, style: tema.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Um vídeo do YouTube: a miniatura, e o vídeo abre onde já se vê vídeos.
///
/// Mostrar só a miniatura até alguém carregar é a mesma escolha que o
/// `embed_url` faz no site (`youtube-nocookie`): nada é pedido ao YouTube até
/// haver um toque. Um `provedor` desconhecido trata-se como link simples.
class _Video extends StatelessWidget {
  const _Video(this.b);

  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final url = b['url'] as String?;
    final miniatura = b['miniatura_url'] as String?;
    final legenda = b['legenda'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(Tema.raioPequeno),
          onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tema.raioPequeno),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (miniatura != null)
                  AspectRatio(aspectRatio: 16 / 9, child: ImagemRede(miniatura))
                else
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(color: tema.colorScheme.surfaceContainerHigh),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ),
        if (legenda != null) ...[
          const SizedBox(height: 6),
          Text(legenda, style: tema.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Um horário de treinos, os escalões por ano de nascimento…
///
/// O servidor garante-a rectangular e com células em texto puro, por isso
/// desenha-se sem verificar nada. Uma tabela larga num telemóvel desliza para o
/// lado em vez de encolher a letra; uma estreita ocupa a largura toda.
class _Tabela extends StatelessWidget {
  const _Tabela(this.b);

  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    final linhas = [
      for (final l in b['linhas'] as List) [for (final celula in l as List) celula?.toString() ?? ''],
    ];
    final colunas = linhas.first.length;
    final comCabecalho = b['cabecalho'] == true;
    final titulo = b['titulo'] as String?;

    Widget celula(String texto, {required bool cabecalho, required bool primeira}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        texto,
        style: cabecalho
            ? tema.textTheme.labelLarge?.copyWith(color: c.onSurfaceVariant)
            // Num quadro "etiqueta → valor" a primeira coluna é a etiqueta.
            : primeira && !comCabecalho
            ? tema.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
            : tema.textTheme.bodyMedium,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titulo != null && titulo.trim().isNotEmpty) ...[
          Text(titulo, style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(Tema.raioPequeno),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, limites) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: limites.maxWidth),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  // A última coluna estica para a tabela encher a largura.
                  columnWidths: {colunas - 1: const IntrinsicColumnWidth(flex: 1)},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(horizontalInside: BorderSide(color: c.outlineVariant)),
                  children: [
                    for (final (i, l) in linhas.indexed)
                      TableRow(
                        decoration: i == 0 && comCabecalho ? BoxDecoration(color: c.surfaceContainerHigh) : null,
                        children: [
                          for (final (j, t) in l.indexed) celula(t, cabecalho: i == 0 && comCabecalho, primeira: j == 0),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Um sítio: o campo de treinos, o pavilhão.
///
/// A app não mostra o mapa embebido (o Google Maps põe cookies logo ao abrir):
/// abre o `url`, que cai na aplicação de mapas ou no browser.
class _Mapa extends StatelessWidget {
  const _Mapa(this.b);

  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    final local = (b['local'] as String?)?.trim();
    final legenda = (b['legenda'] as String?)?.trim();

    return Material(
      color: c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tema.raioPequeno),
        side: BorderSide(color: c.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(b['url'] as String), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.place_outlined, color: c.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      local == null || local.isEmpty ? 'Ver no mapa' : local,
                      style: tema.textTheme.titleSmall,
                    ),
                    Text(
                      legenda == null || legenda.isEmpty ? 'Abrir no mapa' : legenda,
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 20, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
