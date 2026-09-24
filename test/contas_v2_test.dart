import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/auth/auth_interceptor.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/auth/token_store.dart';
import 'package:lpsapp/core/router.dart';
import 'package:lpsapp/features/auth/entrar_page.dart' show identificador;

/// Contas v2 (§2.9): a app entra pela conta, que pode ou não ter ficha de
/// sócio. O que estes testes protegem é o que dói quando falha — o refresh
/// rotativo, e uma conta sem sócio a ser tratada como sessão perdida.
class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};
  final pedidos = <RequestOptions>[];

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

Map<String, dynamic> _socio() => {'nr_socio': 16, 'nome_completo': 'JOÃO MENDES', 'estado': 1};

Map<String, dynamic> _conta({bool comSocio = false}) => {
  'email': 'joao@exemplo.pt',
  'email_verificado': true,
  'nome': 'João',
  'comunicacoes': false,
  'socio': comSocio ? _socio() : null,
};

void main() {
  group('estado da sessão', () {
    test('conta sem ficha não é anónima nem é sócia', () {
      final s = sessaoDaConta(_conta());
      expect(s, isA<SessaoConta>());
      expect(contaDe(s)?.email, 'joao@exemplo.pt');
    });

    test('conta com ficha abre a zona privada', () {
      final s = sessaoDaConta(_conta(comSocio: true));
      expect(s, isA<SessaoSocio>());
      expect((s as SessaoSocio).socio.nrSocio, 16);
      expect(s.conta.nome, 'João');
    });

    test('conta que entrou pelo número de sócio pode não ter email', () {
      final s = sessaoDaConta({'email': null, 'nome': 'JOÃO', 'socio': _socio()});
      expect(contaDe(s)?.email, isNull);
      expect(s, isA<SessaoSocio>());
    });

    test('anónimo não tem conta', () {
      expect(contaDe(const SessaoAnonima()), isNull);
    });
  });

  group('identificador de quem entra', () {
    test('só dígitos é número de sócio', () {
      expect(identificador('16'), (email: null, nrSocio: 16));
      expect(identificador('  16 '), (email: null, nrSocio: 16));
    });

    test('qualquer outra coisa é email', () {
      expect(identificador('ana@exemplo.pt'), (email: 'ana@exemplo.pt', nrSocio: null));
      expect(identificador(' ana@exemplo.pt '), (email: 'ana@exemplo.pt', nrSocio: null));
    });
  });

  group('tokens', () {
    late _Servidor servidor;
    late Dio dio;

    setUp(() {
      servidor = _Servidor();
      dio = Dio()..httpClientAdapter = servidor;
    });

    test('o refresh roda: o par novo substitui o antigo no armazenamento', () async {
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'access-1',
        'lps.refresh_token': 'refresh-1',
        'lps.conta': jsonEncode(_conta(comSocio: true)),
      });
      servidor.respostas['POST /auth/refresh'] = (
        200,
        {
          'status': 'success',
          'data': {'access_token': 'access-2', 'refresh_token': 'refresh-2'},
        },
      );

      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      await tokens.renovar();

      // Guardar só o access deixaria o refresh gasto no disco — e o servidor
      // lê um refresh já trocado como roubo.
      expect(tokens.accessToken, 'access-2');
      expect(await const FlutterSecureStorage().read(key: 'lps.refresh_token'), 'refresh-2');
      expect(servidor.pedidos.single.data, {'refresh_token': 'refresh-1'});
    });

    test('o refresh não traz `conta`, e a que estava mantém-se', () async {
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'a',
        'lps.refresh_token': 'r',
        'lps.conta': jsonEncode(_conta(comSocio: true)),
      });
      servidor.respostas['POST /auth/refresh'] = (
        200,
        {
          'status': 'success',
          'data': {'access_token': 'a2', 'refresh_token': 'r2'},
        },
      );

      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      await tokens.renovar();

      expect(tokens.socio?['nr_socio'], 16);
    });

    test('sessão deixada pela versão anterior descarta-se no arranque', () async {
      // Tokens da v1 não servem na v2 (`401 token_invalido`): mais vale
      // começar limpo do que bater com a cabeça no primeiro pedido.
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'v1',
        'lps.refresh_token': 'v1',
        'lps.socio': jsonEncode(_socio()),
      });

      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();

      expect(tokens.temSessao, isFalse);
      expect(await const FlutterSecureStorage().read(key: 'lps.socio'), isNull);
    });
  });

  group('conta sem sócio na zona privada', () {
    test('`403 conta_sem_socio` não termina a sessão', () async {
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'a',
        'lps.refresh_token': 'r',
        'lps.conta': jsonEncode(_conta()),
      });
      final servidor = _Servidor()
        ..respostas['GET /me/resumo'] = (
          403,
          {'status': 'error', 'erro': 'conta_sem_socio', 'message': 'Esta conta não está associada a um sócio.'},
        );
      final dio = Dio()..httpClientAdapter = servidor;

      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      dio.interceptors.add(AuthInterceptor(dio, tokens));

      await expectLater(dio.get<dynamic>('/me/resumo'), throwsA(isA<DioException>()));

      // Os tokens continuam bons para tudo o resto: bilhetes, interesses,
      // inscrições. O que falta é a ficha, não a sessão.
      expect(tokens.temSessao, isTrue);
      expect(tokens.accessToken, 'a');
    });

    test('`401 token_invalido` termina a sessão', () async {
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'a',
        'lps.refresh_token': 'r',
        'lps.conta': jsonEncode(_conta()),
      });
      final servidor = _Servidor()
        ..respostas['GET /me/conta'] = (401, {'status': 'error', 'erro': 'token_invalido'});
      final dio = Dio()..httpClientAdapter = servidor;

      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      dio.interceptors.add(AuthInterceptor(dio, tokens));

      await expectLater(dio.get<dynamic>('/me/conta'), throwsA(isA<DioException>()));
      expect(tokens.temSessao, isFalse);
    });
  });

  group('para onde vai quem não tem ficha', () {
    String? ir(String rota, {bool socio = false, bool temConta = false}) => destinoDoRedirect(
      Uri.parse(rota),
      versaoACarregar: false,
      bloquearVersao: false,
      socio: socio,
      bloqueada: false,
      temConta: temConta,
    );

    test('conta sem ficha na zona do sócio vai associar, não entrar', () {
      final destino = ir('/socio/quotas', temConta: true)!;
      expect(Uri.parse(destino).path, '/associar-socio');
      expect(Uri.parse(destino).queryParameters['voltar'], '/socio/quotas');
    });

    test('a conta tem sempre onde se gerir, mesmo sem ficha', () {
      // Sem isto, quem entrou só com email não tinha onde terminar sessão,
      // mudar a palavra-passe ou eliminar a conta — tudo vivia no sócio.
      expect(ir('/socio', temConta: true), isNull);
      expect(ir('/socio/conta/password', temConta: true), isNull);
    });

    test('sem sessão nenhuma, nem a raiz do separador abre', () {
      expect(Uri.parse(ir('/socio')!).path, '/entrar');
      expect(Uri.parse(ir('/socio/conta/password')!).path, '/entrar');
    });

    test('um sócio continua a ter a zona toda', () {
      expect(ir('/socio', socio: true), isNull);
      expect(ir('/socio/quotas', socio: true), isNull);
      expect(ir('/socio/conta/password', socio: true), isNull);
    });

    test('sem sessão nenhuma, a zona do sócio manda entrar', () {
      expect(Uri.parse(ir('/socio/quotas')!).path, '/entrar');
    });

    test('associar com ficha já associada não tem nada para fazer', () {
      expect(ir('/associar-socio', socio: true), '/socio');
      expect(ir('/associar-socio?voltar=/bilhetes/A', socio: true), '/bilhetes/A');
    });

    test('associar sem sessão manda entrar primeiro', () {
      expect(Uri.parse(ir('/associar-socio')!).path, '/entrar');
    });

    test('associar com conta sem ficha é o sítio certo: fica', () {
      expect(ir('/associar-socio', temConta: true), isNull);
    });

    test('o ecrã de entrar não se mostra a quem já entrou', () {
      expect(ir('/entrar', temConta: true), '/noticias');
      expect(ir('/entrar', socio: true), '/socio');
      expect(ir('/entrar?voltar=/bilhetes/A', temConta: true), '/bilhetes/A');
    });
  });
}
