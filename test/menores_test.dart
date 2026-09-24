/// Menores na app (guia §2.10): o servidor decide o que cada conta pode
/// fazer, e a app só lê `conta.permissoes` — **nunca calcula idades**.
///
/// O que estes testes fixam: a lista é aberta (o que falta conta como
/// permitido), as permissões chegam também no refresh, um token de um menor
/// de 16 é fim de sessão, e comprar fica fechado mesmo numa zona gratuita.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/auth_interceptor.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/auth/token_store.dart';
import 'package:lpsapp/features/comunidade/comunidade.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart' show BilheteComprado, Zona;
import 'package:lpsapp/features/publico/bilheteira/compra.dart';

class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
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

const _deMenor = {'pagar': false, 'comprar': false, 'contratar': false, 'comunidade': true, 'passatempos': true};

Map<String, dynamic> _conta({Map<String, bool>? permissoes, bool menor = false}) => {
  'email': 'rita@exemplo.pt',
  'email_verificado': true,
  'nome': 'Rita',
  'comunicacoes': false,
  'permissoes': ?permissoes,
  'menor': menor,
  'socio': {'nr_socio': 1924, 'nome_completo': 'RITA', 'estado': 1},
};

void main() {
  group('conta.permissoes', () {
    test('lê as permissões e o `menor`', () {
      final c = ContaSessao.fromJson(_conta(permissoes: _deMenor, menor: true));
      expect(c.menor, isTrue);
      expect(c.podePagar, isFalse);
      expect(c.podeComprar, isFalse);
      expect(c.podeContratar, isFalse);
      expect(c.podeComunidade, isTrue);
    });

    test('lista aberta: o que não vem conta como permitido', () {
      // Uma sessão guardada antes do §2.10 não tem `permissoes` nenhumas.
      final antiga = ContaSessao.fromJson(_conta());
      expect(antiga.podePagar, isTrue);
      expect(antiga.menor, isFalse);

      final c = ContaSessao.fromJson(_conta(permissoes: {'pagar': false}));
      expect(c.pode('uma_que_ainda_nao_existe'), isTrue);
      expect(c.podeComprar, isTrue);
    });

    test('um valor que não é booleano não fecha nada', () {
      final c = ContaSessao.fromJson({
        ..._conta(),
        'permissoes': {'pagar': 'nao', 'comprar': null},
      });
      expect(c.podePagar, isTrue);
      expect(c.podeComprar, isTrue);
    });

    test('sem sessão, a permissão não é o que falta', () {
      expect(sessaoPode(const SessaoAnonima(), 'comprar'), isTrue);
    });
  });

  group('refresh', () {
    late _Servidor servidor;
    late Dio dio;

    setUp(() {
      servidor = _Servidor();
      dio = Dio()..httpClientAdapter = servidor;
    });

    void refreshCom(Map<String, dynamic> conta) => servidor.respostas['POST /auth/refresh'] = (
      200,
      {
        'status': 'success',
        'data': {'access_token': 'a2', 'refresh_token': 'r2', 'conta': conta},
      },
    );

    test('as permissões do refresh chegam à sessão — a idade muda sem login', () async {
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'a',
        'lps.refresh_token': 'r',
        'lps.conta': jsonEncode(_conta(permissoes: _deMenor, menor: true)),
      });
      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      final c = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(tokens)]);
      addTearDown(c.dispose);

      expect(contaDe(c.read(sessaoProvider))!.podePagar, isFalse);

      // Fez 18 anos.
      refreshCom(_conta(permissoes: const {'pagar': true, 'comprar': true, 'contratar': true}));
      await tokens.renovar();
      await Future<void>.delayed(Duration.zero);

      final conta = contaDe(c.read(sessaoProvider))!;
      expect(conta.podePagar, isTrue);
      expect(conta.podeComprar, isTrue);
      expect(conta.menor, isFalse);
      // E fica guardada para o próximo arranque.
      final guardada = jsonDecode((await const FlutterSecureStorage().read(key: 'lps.conta'))!) as Map;
      expect((guardada['permissoes'] as Map)['pagar'], isTrue);
    });

    test('um refresh com a mesma conta não refaz a sessão', () async {
      final conta = _conta(permissoes: _deMenor, menor: true);
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'a',
        'lps.refresh_token': 'r',
        'lps.conta': jsonEncode(conta),
      });
      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();

      var avisos = 0;
      final sub = tokens.contaRenovada.listen((_) => avisos++);
      addTearDown(sub.cancel);

      refreshCom(conta);
      await tokens.renovar();
      await Future<void>.delayed(Duration.zero);

      // Tudo o que observa a sessão voltava a pedir os dados de hora a hora.
      expect(avisos, 0);
    });
  });

  test('`401 socio_menor` é fim de sessão', () async {
    FlutterSecureStorage.setMockInitialValues({
      'lps.access_token': 'a',
      'lps.refresh_token': 'r',
      'lps.conta': jsonEncode(_conta()),
    });
    final servidor = _Servidor()
      ..respostas['GET /me/resumo'] = (
        401,
        {'status': 'error', 'erro': 'socio_menor', 'message': 'Entre pela conta do encarregado de educação.'},
      );
    final dio = Dio()..httpClientAdapter = servidor;
    final tokens = TokenStore(const FlutterSecureStorage(), dio);
    await tokens.carregar();
    dio.interceptors.add(AuthInterceptor(dio, tokens));

    await expectLater(dio.get<dynamic>('/me/resumo'), throwsA(isA<DioException>()));
    expect(tokens.temSessao, isFalse);
  });

  group('comprar', () {
    final menorComFicha = sessaoDaConta(_conta(permissoes: _deMenor, menor: true));
    final menorSemFicha = sessaoDaConta({..._conta(permissoes: _deMenor, menor: true), 'socio': null});

    Zona zona({double preco = 5, bool exigeSocio = false, String venda = 'app'}) => Zona.fromJson({
      'id': 3,
      'nome': 'Bancada',
      'preco': preco,
      'disponivel': true,
      'exige_socio': exigeSocio,
      'venda': venda,
      'url_compra': venda == 'externa' ? 'https://www.bol.pt/x' : null,
    });

    test('um menor não compra, nem numa zona gratuita', () {
      expect(quemPodeComprar(menorComFicha, zona(), sessaoAVenda: true), QuemPode.soEncarregado);
      expect(quemPodeComprar(menorComFicha, zona(preco: 0), sessaoAVenda: true), QuemPode.soEncarregado);
    });

    test('sem ficha numa zona de sócios, associar não resolvia: é o encarregado', () {
      expect(quemPodeComprar(menorSemFicha, zona(exigeSocio: true), sessaoAVenda: true), QuemPode.soEncarregado);
    });

    test('esgotado e venda externa dizem-se como a toda a gente', () {
      expect(quemPodeComprar(menorComFicha, zona(), sessaoAVenda: false), QuemPode.indisponivel);
      expect(quemPodeComprar(menorComFicha, zona(venda: 'externa'), sessaoAVenda: true), QuemPode.foraDaApp);
    });
  });

  test('passatempo só para maiores', () {
    final p = Passatempo.fromJson({
      'uid': 'P1',
      'titulo': 'Bilhetes para o dérbi',
      'tipo': 'inscricao',
      'fase': 'a_decorrer',
      'so_maiores': true,
      'pode_participar': false,
      'motivo': 'so_maiores',
    });
    expect(p.soMaiores, isTrue);
    expect(p.motivo, 'so_maiores');
    expect(Passatempo.fromJson({'uid': 'P2', 'titulo': '', 'tipo': 'inscricao', 'fase': ''}).soMaiores, isFalse);
  });

  group('convites na carteira (§4.18)', () {
    Map<String, dynamic> bilhete(Object? convite) => {
      'id': 'B1',
      'codigo': 'LPS-1234-5678-9012',
      'titulo': 'Leões x Benfica',
      'zona': 'Central',
      'preco': 0,
      'convite': convite,
    };

    test('um convite traz a mensagem', () {
      final b = BilheteComprado.fromJson(bilhete({'mensagem': 'Prémio: passatempo do dérbi'}));
      expect(b.convite, isTrue);
      expect(b.conviteMensagem, 'Prémio: passatempo do dérbi');
    });

    test('a mensagem pode faltar, e continua a ser convite', () {
      final b = BilheteComprado.fromJson(bilhete({'mensagem': null}));
      expect(b.convite, isTrue);
      expect(b.conviteMensagem, isNull);
    });

    test('um bilhete comprado não é convite, mesmo gratuito', () {
      expect(BilheteComprado.fromJson(bilhete(null)).convite, isFalse);
    });
  });
}
