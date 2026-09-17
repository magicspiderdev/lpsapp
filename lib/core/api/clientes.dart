import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_interceptor.dart';
import '../auth/token_store.dart';
import '../config.dart';

Dio novoDio(String base) => Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ));

/// Preenchido em `main()`, depois de ler o armazenamento seguro.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider tem de ser sobreposto em main()'),
);

/// Zona privada: `/api/v1`, com Bearer e refresh automático.
final dioSocioProvider = Provider<Dio>((ref) {
  final dio = novoDio(Config.socioBase);
  dio.interceptors.add(AuthInterceptor(dio, ref.watch(tokenStoreProvider)));
  return dio;
});

/// Zona pública: `/api/v2/publico`, nunca leva o token.
final dioPublicoProvider = Provider<Dio>((ref) => novoDio(Config.publicoBase));
