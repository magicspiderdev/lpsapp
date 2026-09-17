import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/envelope.dart';

/// Tokens da sessão do sócio, guardados só em `flutter_secure_storage`
/// (Keychain/Keystore) e espelhados em memória para os pedidos.
///
/// O refresh **não é rotativo** (guia §2.2): o refresh token original serve
/// até expirar, por isso nunca se substitui a partir da resposta do refresh.
class TokenStore {
  TokenStore(this._storage, this._dioSemAuth);

  static const _kAccess = 'lps.access_token';
  static const _kRefresh = 'lps.refresh_token';
  static const _kSocio = 'lps.socio';

  final FlutterSecureStorage _storage;

  /// Dio sem o interceptor de autenticação — um refresh não pode disparar outro.
  final Dio _dioSemAuth;

  String? _access;
  String? _refresh;
  Map<String, dynamic>? _socio;

  final _terminada = StreamController<void>.broadcast();

  String? get accessToken => _access;
  bool get temSessao => _refresh != null;

  /// O bloco `socio` do login, para mostrar nome e foto sem rede.
  Map<String, dynamic>? get socio => _socio;

  /// Emite quando a sessão acaba sem ser pelo utilizador (refresh recusado,
  /// token inválido, conta eliminada).
  Stream<void> get sessaoTerminada => _terminada.stream;

  Future<void> carregar() async {
    try {
      _access = await _storage.read(key: _kAccess);
      _refresh = await _storage.read(key: _kRefresh);
      final s = await _storage.read(key: _kSocio);
      _socio = s == null ? null : (jsonDecode(s) as Map).cast<String, dynamic>();
    } catch (_) {
      // Keystore ilegível (ex.: backup restaurado noutro aparelho): começa sem sessão.
      await _apagar();
    }
  }

  /// Guarda a resposta de login, de `recuperar/confirmar` ou de `auth/password`.
  Future<void> guardarLogin(Map<String, dynamic> data) async {
    _access = data['access_token'] as String;
    _refresh = data['refresh_token'] as String;
    await _storage.write(key: _kAccess, value: _access);
    await _storage.write(key: _kRefresh, value: _refresh);
    if (data['socio'] is Map) {
      _socio = (data['socio'] as Map).cast<String, dynamic>();
      await _storage.write(key: _kSocio, value: jsonEncode(_socio));
    }
  }

  /// `POST /auth/refresh`. Lança se o refresh for recusado.
  Future<void> renovar() async {
    final refresh = _refresh;
    if (refresh == null) throw StateError('Sem refresh token');
    final data = await dadosDe(
      _dioSemAuth.post('/auth/refresh', data: {'refresh_token': refresh}),
    );
    _access = data['access_token'] as String;
    await _storage.write(key: _kAccess, value: _access);
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
    _socio = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kSocio);
    // Caches com dados do sócio (ex.: o cartão) morrem com a sessão.
    try {
      final chaves = (await _storage.readAll()).keys.where((k) => k.startsWith(prefixoCache));
      for (final k in chaves) {
        await _storage.delete(key: k);
      }
    } catch (_) {}
  }

  /// Prefixo das chaves de cache que pertencem à sessão e se apagam com ela.
  static const prefixoCache = 'lps.sessao.';
}
