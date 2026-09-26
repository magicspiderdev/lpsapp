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
  const CorpoBlocos(this.blocos, {super.key, this.noSite});

  final List<Map<String, dynamic>> blocos;

  /// A mesma página no site. O bloco `html` (HTML livre, com o CSS e os
  /// scripts que traz) não se desenha na app: vira um botão que a abre lá.
  /// Sem ele, o bloco ignora-se.
  final Uri? noSite;

  /// Abaixo disto os blocos com `ocupa` empilham-se: num telemóvel ao alto,
  /// um terço da largura é uma coluna onde não cabe uma frase.
  static const larguraParaColunas = 520.0;

  @override
  Widget build(BuildContext context) {
    // Blocos seguidos com o mesmo `estilo` são uma secção só, no mesmo fundo.
    final seccoes = <(String?, List<(Widget, double?)>)>[];
    for (final b in blocos) {
      final w = _bloco(context, b, noSite);
      if (w == null) continue;
      final estilo = _estilos.contains(b['estilo']) ? b['estilo'] as String : null;
      final entrada = (w, fracao(b['ocupa']));
      if (seccoes.isNotEmpty && seccoes.last.$1 == estilo && estilo != null) {
        seccoes.last.$2.add(entrada);
      } else {
        seccoes.add((estilo, [entrada]));
      }
    }

    return LayoutBuilder(
      builder: (context, limites) {
        final colunas = limites.maxWidth >= larguraParaColunas;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (estilo, filhos) in seccoes)
              if (estilo == null)
                for (final f in _linhas(filhos, colunas)) Padding(padding: const EdgeInsets.only(top: 16), child: f)
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
                      children: [
                        for (final f in _linhas(filhos, colunas))
                          Padding(padding: const EdgeInsets.only(top: 16), child: f),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// A fracção da linha de um bloco (`ocupa`, guia público §6); `null` é a
  /// linha inteira — também para um valor que a app não conheça.
  static double? fracao(Object? ocupa) => switch (ocupa) {
    '1/2' => 1 / 2,
    '1/3' => 1 / 3,
    '2/3' => 2 / 3,
    '1/4' => 1 / 4,
    '3/4' => 3 / 4,
    _ => null,
  };

  /// Os blocos de uma secção em linhas: os seguidos com `ocupa` ficam lado a
  /// lado enquanto a soma couber; o que não couber, ou um bloco sem `ocupa`,
  /// começa linha nova. Sem [colunas] (ecrã estreito) empilham-se pela ordem.
  static List<Widget> _linhas(List<(Widget, double?)> blocos, bool colunas) {
    if (!colunas) return [for (final (w, _) in blocos) w];

    final linhas = <List<(Widget, double)>>[];
    final saida = <Widget>[];
    var soma = 0.0;

    void fechar() {
      if (linhas.isEmpty) return;
      final linha = linhas.removeLast();
      final resto = 1 - linha.fold<double>(0, (s, e) => s + e.$2);
      saida.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (w, f)) in linha.indexed) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(flex: (f * 12).round(), child: w),
            ],
            // Uma linha que não enche fica encostada à esquerda.
            if (resto > 0.01) Spacer(flex: (resto * 12).round()),
          ],
        ),
      );
    }

    for (final (w, f) in blocos) {
      if (f == null) {
        fechar();
        soma = 0;
        saida.add(w);
      } else if (linhas.isNotEmpty && soma + f <= 1.001) {
        linhas.last.add((w, f));
        soma += f;
      } else {
        fechar();
        linhas.add([(w, f)]);
        soma = f;
      }
    }
    fechar();

    return saida;
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

  static Widget? _bloco(BuildContext context, Map<String, dynamic> b, Uri? noSite) {
    // A imagem vem com o URL montado (`capa.url`, blocos `imagem`); o `uid` só
    // aparece nos exemplos do modo de demonstração.
    final urlImagem = b['url'] as String? ?? (b['uid'] is String ? Config.mediaUrl(b['uid'] as String) : null);
    final fotos = FotoCorpo.listaDe(b['imagens']);
    final ficheiros = _Ficheiros.listaDe(b['ficheiros']);

    return switch (b['tipo']) {
      'texto' => TextoHtml(b['html'] as String? ?? ''),
      'imagem' when urlImagem != null => _Imagem(b, urlImagem),
      'galeria' when fotos.isNotEmpty => _Galeria(fotos, legenda: _textoOuNulo(b['legenda'])),
      'video' when b['miniatura_url'] is String || b['url'] is String => _Video(b),
      'tabela' when b['linhas'] is List && (b['linhas'] as List).isNotEmpty => _Tabela(b),
      'mapa' when b['url'] is String => _Mapa(b),
      'publicacao' when b['url'] is String => _Publicacao(b),
      'ficheiros' when ficheiros.isNotEmpty => _Ficheiros(ficheiros, titulo: _textoOuNulo(b['titulo'])),
      'html' when noSite != null => _HtmlNoSite(noSite),
      'citacao' => _Citacao(b['texto'] as String? ?? ''),
      'separador' => const Divider(),
      _ => null,
    };
  }
}

String? _textoOuNulo(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Abre fora da app: o YouTube, o Instagram e o Google Maps caem nas suas
/// aplicações, se estiverem instaladas.
void _abrirFora(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Um cartão com contorno que abre alguma coisa — o mapa, a publicação, a
/// ligação para o site. Todos com a mesma forma, para se lerem como "toque
/// aqui" e não como texto.
class _CartaoLigacao extends StatelessWidget {
  const _CartaoLigacao({required this.icone, required this.titulo, required this.subtitulo, required this.onTap});

  final Widget icone;
  final String titulo, subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    return Material(
      color: c.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tema.raioPequeno),
        side: BorderSide(color: c.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              icone,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tema.textTheme.titleSmall),
                    Text(subtitulo, style: tema.textTheme.bodySmall),
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

/// Um post ou reel do Instagram (bloco `publicacao`, desde 2026-09-25).
///
/// Não há miniatura — o Instagram só a dá com uma chave de programador —, por
/// isso é um cartão que abre o `url`, na app do Instagram se estiver
/// instalada. Um `provedor` que a app não conheça é um link simples.
class _Publicacao extends StatelessWidget {
  const _Publicacao(this.b);

  final Map<String, dynamic> b;

  @override
  Widget build(BuildContext context) {
    final instagram = b['provedor'] == 'instagram';
    final legenda = _textoOuNulo(b['legenda']);
    return _CartaoLigacao(
      icone: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // As cores do logótipo do Instagram: o ícone oficial é uma marca,
          // e o Material não o traz.
          gradient: instagram
              ? const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Color(0xFFFEDA75),
                    Color(0xFFFA7E1E),
                    Color(0xFFD62976),
                    Color(0xFF962FBF),
                    Color(0xFF4F5BD5),
                  ],
                )
              : null,
          color: instagram ? null : Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Icon(
          instagram ? Icons.camera_alt_outlined : Icons.link_rounded,
          color: instagram ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      titulo: legenda ?? (instagram ? 'Publicação no Instagram' : 'Publicação'),
      subtitulo: instagram ? 'Ver no Instagram' : 'Abrir a publicação',
      onTap: () => _abrirFora(b['url'] as String),
    );
  }
}

/// O bloco `html` (HTML livre, com o CSS e os scripts que trouxer). A app não
/// o desenha — não há `WebView`, e não passa pela lista branca do `texto` —:
/// abre a página no site, que o mostra isolado (guia público §6).
class _HtmlNoSite extends StatelessWidget {
  const _HtmlNoSite(this.noSite);

  final Uri noSite;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return _CartaoLigacao(
      icone: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
        child: Icon(Icons.public_rounded, color: c.onPrimaryContainer),
      ),
      titulo: 'Há mais nesta página',
      subtitulo: 'Parte do conteúdo só se vê no site',
      onTap: () => launchUrl(noSite, mode: LaunchMode.inAppBrowserView),
    );
  }
}

/// Uma fotografia da biblioteca como sai no corpo: a do bloco `imagem` e cada
/// uma das da `galeria`.
class FotoCorpo {
  final String url;
  final double? largura, altura;
  final String? credito, alt;

  const FotoCorpo({required this.url, this.largura, this.altura, this.credito, this.alt});

  static List<FotoCorpo> listaDe(Object? v) => [
    if (v is List)
      for (final f in v)
        if (f is Map && f['url'] is String)
          FotoCorpo(
            url: f['url'] as String,
            largura: (f['largura'] as num?)?.toDouble(),
            altura: (f['altura'] as num?)?.toDouble(),
            credito: _textoOuNulo(f['credito']),
            alt: _textoOuNulo(f['alt']),
          ),
  ];
}

/// Uma galeria (desde 2026-09-26): as fotos em grelha, e cada uma abre em ecrã
/// inteiro, onde se passa às outras arrastando.
class _Galeria extends StatelessWidget {
  const _Galeria(this.fotos, {this.legenda});

  final List<FotoCorpo> fotos;
  final String? legenda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, limites) {
            // Duas colunas num telemóvel, três a partir de um ecrã largo; uma
            // foto sozinha ocupa a largura toda.
            final colunas = fotos.length == 1 ? 1 : (limites.maxWidth >= 480 ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: colunas,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: colunas == 1 ? 4 / 3 : 1,
              ),
              itemCount: fotos.length,
              itemBuilder: (context, i) => Semantics(
                image: true,
                label: fotos[i].alt,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Tema.raioPequeno),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => _VisorFotos(fotos, inicial: i)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Tema.raioPequeno),
                    child: ImagemRede(fotos[i].url, larguraCache: 600),
                  ),
                ),
              ),
            );
          },
        ),
        if (legenda != null) ...[const SizedBox(height: 6), Text(legenda!, style: tema.textTheme.bodySmall)],
      ],
    );
  }
}

/// As fotos de uma galeria em ecrã inteiro, com zoom.
class _VisorFotos extends StatefulWidget {
  const _VisorFotos(this.fotos, {required this.inicial});

  final List<FotoCorpo> fotos;
  final int inicial;

  @override
  State<_VisorFotos> createState() => _VisorFotosState();
}

class _VisorFotosState extends State<_VisorFotos> {
  late final _pagina = PageController(initialPage: widget.inicial);
  late int _actual = widget.inicial;

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foto = widget.fotos[_actual];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.fotos.length > 1 ? Text('${_actual + 1} de ${widget.fotos.length}') : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pagina,
              itemCount: widget.fotos.length,
              onPageChanged: (i) => setState(() => _actual = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Semantics(
                    image: true,
                    label: widget.fotos[i].alt,
                    child: ImagemRede(widget.fotos[i].url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          if (foto.credito != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Fotografia: ${foto.credito}', style: const TextStyle(color: Colors.white70)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Documentos para descarregar (desde 2026-09-26): o regulamento, a ficha de
/// inscrição. Cada um abre o `download_url` fora da app — descarrega sempre,
/// com o nome certo.
class _Ficheiros extends StatelessWidget {
  const _Ficheiros(this.ficheiros, {this.titulo});

  final List<Map<String, dynamic>> ficheiros;
  final String? titulo;

  static List<Map<String, dynamic>> listaDe(Object? v) => [
    if (v is List)
      for (final f in v)
        if (f is Map && (f['download_url'] is String || f['url'] is String)) f.cast<String, dynamic>(),
  ];

  /// O ícone pela extensão (lista aberta: o resto é um documento).
  static IconData _icone(Object? extensao) => switch (extensao) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'xls' || 'xlsx' || 'csv' || 'ods' => Icons.table_chart_outlined,
    'ppt' || 'pptx' || 'odp' => Icons.slideshow_outlined,
    'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => Icons.image_outlined,
    _ => Icons.description_outlined,
  };

  /// 482133 → "471 KB".
  static String? _tamanho(Object? bytes) {
    if (bytes is! num || bytes <= 0) return null;
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titulo != null) ...[Text(titulo!, style: tema.textTheme.titleMedium), const SizedBox(height: 8)],
        Material(
          color: c.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tema.raioPequeno),
            side: BorderSide(color: c.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, f) in ficheiros.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.outlineVariant),
                ListTile(
                  leading: Icon(_icone(f['extensao']), color: c.primary),
                  title: Text(_textoOuNulo(f['nome']) ?? 'Documento'),
                  subtitle: switch ([?_textoOuNulo(f['tipo']), ?_tamanho(f['bytes'])]) {
                    [] => null,
                    final partes => Text(partes.join(' · ')),
                  },
                  trailing: Icon(Icons.download_rounded, color: c.onSurfaceVariant),
                  onTap: () => _abrirFora((f['download_url'] ?? f['url']) as String),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
        Semantics(
          image: true,
          label: _textoOuNulo(b['alt']) ?? _textoOuNulo(b['legenda']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tema.raioPequeno),
            child: ImagemRede(url, fit: BoxFit.fitWidth),
          ),
        ),
        if (legenda.isNotEmpty) ...[const SizedBox(height: 6), Text(legenda, style: tema.textTheme.bodySmall)],
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
        if (legenda != null) ...[const SizedBox(height: 6), Text(legenda, style: tema.textTheme.bodySmall)],
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
                          for (final (j, t) in l.indexed)
                            celula(t, cabecalho: i == 0 && comCabecalho, primeira: j == 0),
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
    final c = Theme.of(context).colorScheme;
    return _CartaoLigacao(
      icone: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
        child: Icon(Icons.place_outlined, color: c.onPrimaryContainer),
      ),
      titulo: _textoOuNulo(b['local']) ?? 'Ver no mapa',
      subtitulo: _textoOuNulo(b['legenda']) ?? 'Abrir no mapa',
      onTap: () => _abrirFora(b['url'] as String),
    );
  }
}
