import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

/// Links partilháveis e a sua leitura quando chegam como deep link.
///
/// O caminho do link é o da rota na app (`/noticias/{slug}`,
/// `/bilhetes/{id}`), debaixo de [Config.linksRaiz] — o site oficial, que tem
/// a mesma página no mesmo caminho. Leva a barra no fim, que é o canónico do
/// site (sem ela, o site responde com um 301); o router tira-a.
abstract final class Links {
  static final _raiz = Uri.parse(Config.linksRaiz);

  /// Prefixo do caminho na raiz dos links, ou `''` (o site oficial não tem).
  static final prefixo = _raiz.path.endsWith('/') ? _raiz.path.substring(0, _raiz.path.length - 1) : _raiz.path;

  /// Os primeiros testes partilhavam `mylps…/lps/noticias/x`, no CISOC. Não há
  /// página por trás, mas quem os abrir na app continua a chegar à notícia.
  static const _prefixoAntigo = '/lps';

  /// Domínios do clube: uma ligação para eles, num artigo, abre por dentro se
  /// a app tiver o ecrã. O site novo está em `new.` até mudar de domínio.
  static final _hostsDoClube = {
    _raiz.host,
    'leoesdeportosalvo.pt',
    'www.leoesdeportosalvo.pt',
    'new.leoesdeportosalvo.pt',
    'mylps.leoesdeportosalvo.pt',
  };

  static Uri noticia(String slug) => _link('/noticias/${Uri.encodeComponent(slug)}/');

  /// Uma página do clube no site. É onde abre uma página em HTML livre, que a
  /// app não desenha (guia público §9).
  static Uri pagina(String slug) => _link('/paginas/${Uri.encodeComponent(slug)}/');

  /// A página de uma modalidade no site — para o bloco `html`, que só lá se vê.
  static Uri modalidade(String slug) => _link('/modalidades/${Uri.encodeComponent(slug)}/');

  /// Uma sessão da bilheteira (o catálogo). **Nunca um bilhete comprado**: um
  /// link para um bilhete seria um bilhete que se reencaminha sem limite.
  ///
  /// Enviar um bilhete a quem vai com ele faz-se no ecrã do bilhete, e envia
  /// só o texto com **um** código, com o aviso de que entra uma vez. Enquanto
  /// não houver `POST /me/bilhetes/{id}/transferir` (pedido
  /// `2026-09-22-transferir-bilhete`), é o mais longe que se vai.
  static Uri sessao(String id) => _link('/bilhetes/${Uri.encodeComponent(id)}/');

  static Uri _link(String caminho) => _raiz.replace(path: '$prefixo$caminho');

  /// Caminho de rota a partir de um link recebido: tira o prefixo do servidor
  /// e a barra do fim, que o site põe e as rotas da app não têm. `null` se não
  /// houver nada a tirar (já é uma rota da app).
  ///
  /// Um endereço com host é sempre um link: o Android entrega-o inteiro
  /// (`https://www…/noticias/x`) e o go_router já lhe tirou a barra. Com a raiz
  /// sem prefixo, ficava igual e ia inteiro para o `?para=` do arranque — que
  /// recusa o que tem `://` e caía nas notícias.
  static String? rotaDoLink(Uri uri) {
    var p = uri.path;
    var mudou = uri.hasAuthority;
    for (final pre in {prefixo, _prefixoAntigo}) {
      if (pre.isNotEmpty && (p == pre || p.startsWith('$pre/'))) {
        p = p.substring(pre.length);
        mudou = true;
        break;
      }
    }
    if (p.isEmpty) p = '/';
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
      mudou = true;
    }
    if (!mudou) return null;
    return uri.hasQuery ? '$p?${uri.query}' : p;
  }

  /// Destino de "voltar" aceite só se for uma rota da app (`/…`), nunca um
  /// endereço externo (`//outro.site`, `https://…`).
  static String? voltarSeguro(String? v) =>
      v != null && v.startsWith('/') && !v.startsWith('//') && !v.contains('://') ? v : null;

  /// Prefixos de rota que a app sabe abrir. Uma ligação escrita no editor de
  /// conteúdos pode apontar para qualquer sítio do site; só estas têm ecrã cá
  /// dentro, e o resto abre no navegador em vez de cair num 404 da app.
  static const _rotasConhecidas = ['/noticias', '/bilhetes', '/agenda'];

  /// Abre uma ligação vinda do corpo de um artigo (`<a href>` da lista branca
  /// do §4.20): dentro da app quando é uma rota que ela conhece, senão no
  /// navegador. `mailto:` e `tel:` vão para a aplicação do sistema.
  static Future<bool> abrir(BuildContext context, String href) async {
    if (href.isEmpty || href.startsWith('#')) return true; // âncora: não há para onde ir
    final uri = Uri.tryParse(href);
    if (uri == null) return false;

    if (uri.scheme == 'mailto' || uri.scheme == 'tel') return launchUrl(uri);

    final caminho = switch (uri.hasScheme) {
      true when _hostsDoClube.contains(uri.host) => rotaDoLink(uri) ?? uri.path,
      false when href.startsWith('/') => rotaDoLink(uri) ?? href,
      _ => null,
    };

    if (caminho != null && _rotasConhecidas.any((r) => caminho == r || caminho.startsWith('$r/'))) {
      context.push(caminho);
      return true;
    }

    // Caminho do site sem ecrã na app: abre-se onde ele existe mesmo.
    return launchUrl(uri.hasScheme ? uri : _link(href), mode: LaunchMode.externalApplication);
  }

  /// Abre a folha de partilha do sistema. [origem] é o widget que foi tocado:
  /// no iPad a folha precisa de saber de onde sai.
  static Future<void> partilhar(BuildContext origem, {required String titulo, required Uri link}) {
    final caixa = origem.findRenderObject() as RenderBox?;
    return SharePlus.instance.share(
      ShareParams(
        text: '$titulo\n$link',
        subject: titulo,
        sharePositionOrigin: caixa == null ? null : caixa.localToGlobal(Offset.zero) & caixa.size,
      ),
    );
  }
}
