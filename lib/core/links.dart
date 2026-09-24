import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

/// Links partilháveis e a sua leitura quando chegam como deep link.
///
/// O caminho do link é o da rota na app (`/noticias/{slug}`,
/// `/bilhetes/{id}`), debaixo de [Config.linksRaiz]. Assim o router abre-os tal
/// como vêm, tirando só o prefixo do servidor (`/lps`).
abstract final class Links {
  static final _raiz = Uri.parse(Config.linksRaiz);

  /// Prefixo do caminho na raiz dos links (`/lps`), ou `''`.
  static final prefixo = _raiz.path.endsWith('/') ? _raiz.path.substring(0, _raiz.path.length - 1) : _raiz.path;

  static Uri noticia(String slug) => _link('/noticias/${Uri.encodeComponent(slug)}');

  /// Uma sessão da bilheteira (o catálogo). **Nunca um bilhete comprado**: um
  /// link para um bilhete seria um bilhete que se reencaminha sem limite.
  ///
  /// Enviar um bilhete a quem vai com ele faz-se no ecrã do bilhete, e envia
  /// só o texto com **um** código, com o aviso de que entra uma vez. Enquanto
  /// não houver `POST /me/bilhetes/{id}/transferir` (pedido
  /// `2026-09-22-transferir-bilhete`), é o mais longe que se vai.
  static Uri sessao(String id) => _link('/bilhetes/${Uri.encodeComponent(id)}');

  static Uri _link(String caminho) => _raiz.replace(path: '$prefixo$caminho');

  /// Caminho de rota a partir de um link recebido: tira o prefixo do servidor.
  /// `null` se o caminho não tiver o prefixo (já é uma rota da app).
  static String? rotaDoLink(Uri uri) {
    if (prefixo.isEmpty) return null;
    final p = uri.path;
    if (p != prefixo && !p.startsWith('$prefixo/')) return null;
    final resto = p.substring(prefixo.length);
    final rota = resto.isEmpty ? '/' : resto;
    return uri.hasQuery ? '$rota?${uri.query}' : rota;
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
      true when uri.host == _raiz.host => rotaDoLink(uri) ?? uri.path,
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
