import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/envelope.dart';

/// Tokens da sessão da conta (v2), guardados só em `flutter_secure_storage`
/// (Keychain/Keystore) e espelhados em memória para os pedidos.
///
/// **O refresh roda** (guia §2.9): cada `/auth/refresh` devolve um par novo e
/// o anterior deixa de valer. Guarda-se sempre o último, e faz-se **um refresh
/// de cada vez** — um refresh já trocado, reutilizado mais de 30 segundos
/// depois, é tratado como roubo e o servidor revoga a sessão deste aparelho.
class TokenStore {
  TokenStore(this._storage, this._dioSemAuth, {Future<void> Function()? limparCaches}) : _limparCaches = limparCaches;

  final Future<void> Function()? _limparCaches;

  static const _kAccess = 'lps.access_token';
  static const _kRefresh = 'lps.refresh_token';
  static const _kConta = 'lps.conta';

  /// Chave da versão anterior da app, quando a sessão era do sócio e não da
  /// conta. Só se lê para a apagar: um token da v1 não serve na v2.
  static const _kSocioV1 = 'lps.socio';

  final FlutterSecureStorage _storage;

  /// Dio sem o interceptor de autenticação — um refresh não pode disparar outro.
  final Dio _dioSemAuth;

  String? _access;
  String? _refresh;
  Map<String, dynamic>? _conta;

  final _terminada = StreamController<void>.broadcast();
  final _contaRenovada = StreamController<Map<String, dynamic>>.broadcast();

  String? get accessToken => _access;
  bool get temSessao => _refresh != null;

  /// O bloco `conta` da sessão, para mostrar nome e sócio sem rede.
  Map<String, dynamic>? get conta => _conta;

  /// O `socio` da conta, ou `null` se a conta não tem ficha associada.
  Map<String, dynamic>? get socio =>
      _conta?['socio'] is Map ? (_conta!['socio'] as Map).cast<String, dynamic>() : null;

  /// Emite quando a sessão acaba sem ser pelo utilizador (refresh recusado,
  /// token inválido, conta eliminada).
  Stream<void> get sessaoTerminada => _terminada.stream;

  /// Emite a `conta` que um refresh trouxe — é aí que chegam as permissões
  /// novas quando a pessoa faz anos (§2.10).
  Stream<Map<String, dynamic>> get contaRenovada => _contaRenovada.stream;

  Future<void> carregar() async {
    try {
      _access = await _storage.read(key: _kAccess);
      _refresh = await _storage.read(key: _kRefresh);
      final c = await _storage.read(key: _kConta);
      _conta = c == null ? null : (jsonDecode(c) as Map).cast<String, dynamic>();

      // Sessão deixada pela versão anterior: os tokens da v1 não servem na v2
      // (`401 token_invalido`), por isso começa-se limpo em vez de deixar a
      // app bater com a cabeça no primeiro pedido.
      if (_conta == null && await _storage.read(key: _kSocioV1) != null) {
        await _apagar();
      }
    } catch (_) {
      // Keystore ilegível (ex.: backup restaurado noutro aparelho): começa sem sessão.
      await _apagar();
    }
  }

  /// Guarda uma sessão vinda do login, da confirmação do registo, de repor ou
  /// alterar a password, ou de associar/desassociar o sócio.
  ///
  /// Um refresh também traz a `conta` (desde §2.10); se não vier, mantém-se o
  /// que estava.
  Future<void> guardarSessao(Map<String, dynamic> data) async {
    _access = data['access_token'] as String;
    await _storage.write(key: _kAccess, value: _access);

    if (data['refresh_token'] case final String r) {
      _refresh = r;
      await _storage.write(key: _kRefresh, value: r);
    }

    if (data['conta'] is Map) {
      _conta = (data['conta'] as Map).cast<String, dynamic>();
      await _storage.write(key: _kConta, value: jsonEncode(_conta));
    }
  }

  /// `POST /api/v2/auth/refresh`. Lança se o refresh for recusado.
  ///
  /// O par novo substitui o antigo **antes** de qualquer pedido voltar a sair:
  /// guardar só o access deixaria o refresh gasto no disco, e o próximo
  /// arranque da app usava-o — que é precisamente o que o servidor lê como
  /// roubo.
  Future<void> renovar() async {
    final refresh = _refresh;
    if (refresh == null) throw StateError('Sem refresh token');
    final data = await dadosDe(_dioSemAuth.post('/auth/refresh', data: {'refresh_token': refresh}));
    final antes = jsonEncode(_conta);
    await guardarSessao(data);
    // Só avisa quando mudou: a sessão nova refaz tudo o que a observa.
    if (_conta case final conta? when data['conta'] is Map && jsonEncode(conta) != antes) {
      _contaRenovada.add(conta);
    }
  }

  /// Fim de sessão imposto pelo servidor: limpa e avisa quem estiver a ouvir.
  Future<void> terminar() async {
    final tinha = temSessao;
    await _apagar();
    if (tinha) _terminada.add(null);
  }

  /// Fim de sessão pedido pelo utilizador: só limpa.
  Future<void> limpar() => _apagar();

  Future<void> _apagar() async {
    _access = null;
    _refresh = null;
    _conta = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kConta);
    await _storage.delete(key: _kSocioV1);
    // Caches com dados do sócio morrem com a sessão.
    await _limparCaches?.call();
  }
}
