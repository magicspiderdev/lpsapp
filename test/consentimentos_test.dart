import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/features/conta/privacidade/consentimentos.dart';

/// Consentimentos (§2.11). O que estes testes protegem: a app mostra o que o
/// servidor manda (lista aberta), nunca abre um interruptor que ele fechou, e
/// cada escrita substitui o estado pela lista que vem na resposta.
class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};
  final pedidos = <RequestOptions>[];

  int contar(String metodo, String caminho) => pedidos.where((o) => o.method == metodo && o.path == caminho).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    final (status, corpo) = respostas['${o.method} ${o.path}'] ?? (404, {'status': 'error', 'erro': 'nao_encontrado'});
    return ResponseBody.fromString(
      jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Ligado extends LigacaoController {
  @override
  bool build() => true;
}

class _Quem extends SessaoController {
  _Quem(this.inicial);
  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

Map<String, dynamic> _c(
  String tipo, {
  bool ativo = true,
  bool pode = true,
  String? porque,
  bool renovar = false,
  String? dadoPor = 'proprio',
  String? rotulo,
}) => {
  'tipo': tipo,
  'rotulo': rotulo ?? 'Rótulo de $tipo',
  'ativo': ativo,
  'versao': '2026-09',
  'versao_actual': '2026-09',
  'precisa_renovar': renovar,
  'concedido_em': ativo ? '2026-09-24 18:00:00' : null,
  'dado_por': ativo ? dadoPor : null,
  'pode_alterar': pode,
  'porque_nao': porque,
};

Map<String, dynamic> _ok(List<Map<String, dynamic>> lista) => {
  'status': 'success',
  'data': {'consentimentos': lista},
};

ProviderContainer _container(_Servidor servidor) {
  final dio = Dio(BaseOptions(baseUrl: 'http://teste/api/v2'))..httpClientAdapter = servidor;
  final c = ProviderContainer(
    overrides: [
      dioContaProvider.overrideWithValue(dio),
      cacheProvider.overrideWithValue(CacheEmMemoria()),
      ligacaoProvider.overrideWith(_Ligado.new),
      sessaoProvider.overrideWith(() => _Quem(SessaoConta(const ContaSessao(nome: 'Ana')))),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ler a lista', () {
    test('um tipo que a app não conhece mostra-se na mesma, com o rótulo que vem', () {
      final l = lerConsentimentos({
        'consentimentos': [_c('image_use'), _c('newsletter_parceiros', rotulo: 'Ofertas de parceiros')],
      });
      expect(l.map((c) => c.tipo), ['image_use', 'newsletter_parceiros']);
      expect(l.last.rotulo, 'Ofertas de parceiros');
    });

    test('sem rótulo, fica o tipo — nunca uma linha em branco', () {
      final c = Consentimento.fromJson({'tipo': 'x_novo', 'ativo': false});
      expect(c.rotulo, 'x_novo');
    });

    test('sem pode_alterar, o interruptor fica fechado: quem abre é o servidor', () {
      final c = Consentimento.fromJson({'tipo': 'image_use', 'rotulo': 'Imagem', 'ativo': true});
      expect(c.podeAlterar, isFalse);
    });

    test('lê a data, quem deu e a renovação', () {
      final c = Consentimento.fromJson(_c('app_account', renovar: true, dadoPor: 'secretaria'));
      expect(c.concedidoEm, DateTime(2026, 9, 24, 18));
      expect(c.dadoPor, 'secretaria');
      expect(c.precisaRenovar, isTrue);
    });

    test('entradas sem tipo ignoram-se', () {
      expect(
        lerConsentimentos({
          'consentimentos': [
            {'rotulo': 'sem tipo'},
            _c('marketing'),
          ],
        }).length,
        1,
      );
    });
  });

  group('textos', () {
    test('cada porque_nao conhecido tem a sua frase; o resto uma genérica', () {
      expect(explicacaoPorqueNao('consentimento_indisponivel'), contains('menores de 18'));
      expect(explicacaoPorqueNao('consentimento_do_encarregado'), contains('encarregado de educação'));
      expect(explicacaoPorqueNao('sem_permissao'), contains('maior de idade'));
      expect(explicacaoPorqueNao('socio_nao_associado'), contains('Já não acompanha'));
      final generica = explicacaoPorqueNao('uma_regra_nova');
      expect(generica, isNotEmpty);
      expect(explicacaoPorqueNao(null), generica);
    });

    test('quem deu: discreto, e "o próprio" depende de quem está a ver', () {
      expect(textoDadoPor('proprio'), 'Dado por si');
      expect(textoDadoPor('proprio', deDependente: true), 'Dado pelo próprio');
      expect(textoDadoPor('encarregado'), 'Dado pelo encarregado de educação');
      expect(textoDadoPor('secretaria'), 'Registado na secretaria');
      expect(textoDadoPor(null), isNull);
      expect(textoDadoPor('outro_canal'), isNull);
    });

    test('caminhos: os da conta e os de um dependente', () {
      expect(caminhoConsentimentos(null), '/me/consentimentos');
      expect(caminhoConsentimentos(5643), '/me/dependentes/5643/consentimentos');
    });
  });

  group('pedidos', () {
    test('carrega os da conta', () async {
      final s = _Servidor()..respostas['GET /me/consentimentos'] = (200, _ok([_c('image_use')]));
      final c = _container(s);
      c.listen(consentimentosProvider(null), (_, _) {});

      final d = await c.read(consentimentosProvider(null).future);
      expect(d.valor.single.tipo, 'image_use');
    });

    test('mudar um interruptor envia só o ativo, e o estado passa a ser o que vem', () async {
      final s = _Servidor()
        ..respostas['GET /me/consentimentos'] = (200, _ok([_c('image_use'), _c('marketing', ativo: false)]))
        ..respostas['PUT /me/consentimentos/image_use'] = (
          200,
          _ok([_c('image_use', ativo: false), _c('marketing', ativo: false), _c('tipo_novo')]),
        );
      final c = _container(s);
      c.listen(consentimentosProvider(null), (_, _) {});
      await c.read(consentimentosProvider(null).future);

      await c.read(consentimentosProvider(null).notifier).alterar('image_use', ativo: false);

      final put = s.pedidos.singleWhere((o) => o.method == 'PUT');
      expect(put.data, {'ativo': false}, reason: 'sem politica_versao, fica a actual');
      final l = c.read(consentimentosProvider(null)).requireValue.valor;
      expect(l.first.ativo, isFalse);
      // A lista inteira da resposta, e não só a linha mexida.
      expect(l.map((x) => x.tipo), contains('tipo_novo'));
      expect(s.contar('GET', '/me/consentimentos'), 1, reason: 'a resposta já traz tudo');
    });

    test('aceitar de novo envia a versão do texto que se mostrou', () async {
      final s = _Servidor()
        ..respostas['GET /me/consentimentos'] = (200, _ok([_c('app_account', renovar: true)]))
        ..respostas['PUT /me/consentimentos/app_account'] = (200, _ok([_c('app_account')]));
      final c = _container(s);
      c.listen(consentimentosProvider(null), (_, _) {});
      await c.read(consentimentosProvider(null).future);

      await c
          .read(consentimentosProvider(null).notifier)
          .alterar('app_account', ativo: true, politicaVersao: '2026-09');

      expect(s.pedidos.singleWhere((o) => o.method == 'PUT').data, {'ativo': true, 'politica_versao': '2026-09'});
      expect(c.read(consentimentosProvider(null)).requireValue.valor.single.precisaRenovar, isFalse);
    });

    test('os de um dependente vão pelo caminho dele', () async {
      final s = _Servidor()
        ..respostas['GET /me/dependentes/5643/consentimentos'] = (
          200,
          _ok([_c('image_use', ativo: false, dadoPor: null)]),
        )
        ..respostas['PUT /me/dependentes/5643/consentimentos/image_use'] = (
          200,
          _ok([_c('image_use', dadoPor: 'encarregado')]),
        );
      final c = _container(s);
      c.listen(consentimentosProvider(5643), (_, _) {});
      await c.read(consentimentosProvider(5643).future);

      await c.read(consentimentosProvider(5643).notifier).alterar('image_use', ativo: true);

      final l = c.read(consentimentosProvider(5643)).requireValue.valor;
      expect(l.single.ativo, isTrue);
      expect(l.single.dadoPor, 'encarregado');
    });

    for (final erro in [
      'consentimento_indisponivel',
      'consentimento_do_encarregado',
      'sem_permissao',
      'socio_nao_associado',
    ]) {
      test('403 $erro: lança com a message e recarrega a lista', () async {
        final s = _Servidor()
          ..respostas['GET /me/dependentes/7/consentimentos'] = (200, _ok([_c('marketing', ativo: false)]))
          ..respostas['PUT /me/dependentes/7/consentimentos/marketing'] = (
            403,
            {'status': 'error', 'erro': erro, 'message': 'Mensagem do servidor.'},
          );
        final c = _container(s);
        c.listen(consentimentosProvider(7), (_, _) {});
        await c.read(consentimentosProvider(7).future);

        await expectLater(
          c.read(consentimentosProvider(7).notifier).alterar('marketing', ativo: true),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Mensagem do servidor.')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(s.contar('GET', '/me/dependentes/7/consentimentos'), 2);
      });
    }

    test('sem ligação, a escrita falha e o estado fica como estava', () async {
      final s = _Servidor()..respostas['GET /me/consentimentos'] = (200, _ok([_c('image_use')]));
      s.respostas['PUT /me/consentimentos/image_use'] = (
        503,
        {'status': 'error', 'erro': 'indisponivel', 'message': 'x'},
      );
      final c = _container(s);
      c.listen(consentimentosProvider(null), (_, _) {});
      await c.read(consentimentosProvider(null).future);

      await expectLater(
        c.read(consentimentosProvider(null).notifier).alterar('image_use', ativo: false),
        throwsA(isA<ApiException>()),
      );
      expect(c.read(consentimentosProvider(null)).requireValue.valor.single.ativo, isTrue);
      expect(s.contar('GET', '/me/consentimentos'), 1, reason: 'erro de serviço não é mudança de estado');
    });
  });
}
