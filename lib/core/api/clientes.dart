import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_interceptor.dart';
import '../auth/token_store.dart';
import '../config.dart';
import '../rede/ligacao.dart';

Dio novoDio(String base) => Dio(
  BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  ),
);

/// Preenchido em `main()`, depois de ler o armazenamento seguro.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider tem de ser sobreposto em main()'),
);

/// A conta: `/api/v2`, com Bearer e refresh automático. É por aqui que se
/// entra, se cria conta e se usa tudo o que é pessoal e não exige sócio
/// (bilhetes comprados, interesses, inscrições).
final dioContaProvider = Provider<Dio>((ref) {
  final dio = novoDio(Config.contaBase);
  dio.interceptors
    ..add(LigacaoInterceptor(ref))
    ..add(AuthInterceptor(dio, ref.watch(tokenStoreProvider)));
  return dio;
});

/// Zona privada: `/api/v1`, com o **mesmo token da conta**. Sem sócio
/// associado responde `403 conta_sem_socio` — esconder a zona, não deitar os
/// tokens fora.
final dioSocioProvider = Provider<Dio>((ref) {
  final dio = novoDio(Config.socioBase);
  dio.interceptors
    ..add(LigacaoInterceptor(ref))
    ..add(AuthInterceptor(dio, ref.watch(tokenStoreProvider)));
  return dio;
});

/// Zona pública: `/api/v2/publico`, nunca leva o token.
final dioPublicoProvider = Provider<Dio>((ref) {
  final dio = novoDio(Config.publicoBase);
  dio.interceptors.add(LigacaoInterceptor(ref));
  return dio;
});
