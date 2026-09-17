import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'token_store.dart';

/// Põe o Bearer nos pedidos e trata os erros de autenticação (guia §2.7–2.8).
///
/// Só `401 token_expirado` justifica refresh automático; tratar
/// `token_invalido` da mesma forma entra em ciclo com um token corrompido.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._store);

  final Dio _dio;
  final TokenStore _store;

  /// Um único refresh partilhado por todos os pedidos que falharam juntos.
  Future<void>? _refreshEmCurso;

  static const _repetido = 'lps.repetido';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _store.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final corpo = err.response?.data;
    final erro = corpo is Map ? corpo['erro'] : null;
    final status = err.response?.statusCode;
    final comToken = err.requestOptions.headers.containsKey('Authorization');

    if (status == 401 && erro == 'token_expirado' && err.requestOptions.extra[_repetido] != true) {
      try {
        await (_refreshEmCurso ??= _store.renovar().whenComplete(() => _refreshEmCurso = null));
      } on ApiException catch (e) {
        // Só uma recusa do servidor acaba a sessão; sem rede, fica para depois.
        if (e.erro.startsWith('refresh_')) await _store.terminar();
        return handler.next(err);
      } catch (_) {
        return handler.next(err);
      }
      final r = err.requestOptions
        ..extra[_repetido] = true
        ..headers['Authorization'] = 'Bearer ${_store.accessToken}';
      try {
        return handler.resolve(await _dio.fetch(r));
      } on DioException catch (e2) {
        return handler.next(e2);
      }
    }

    final sessaoInvalida = (status == 401 &&
            (erro == 'token_invalido' || erro == 'token_ausente' || erro == 'conta_eliminada')) ||
        (status == 403 && erro == 'socio_inexistente');
    if (comToken && sessaoInvalida) {
      await _store.terminar();
    }
    handler.next(err);
  }
}
