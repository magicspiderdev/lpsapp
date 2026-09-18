import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api/clientes.dart';
import 'core/auth/biometria.dart';
import 'core/auth/token_store.dart';
import 'core/cache/cache_local.dart';
import 'core/config.dart';
import 'core/orientacao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');
  await fixarVertical();

  const storage = FlutterSecureStorage();
  final cache = CacheEmDisco(storage);
  final tokens = TokenStore(storage, novoDio(Config.socioBase), limparCaches: cache.limparSessao);
  final biometria = BiometriaStore(storage);
  await Future.wait([tokens.carregar(), biometria.carregar()]);

  runApp(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        biometriaStoreProvider.overrideWithValue(biometria),
        cacheProvider.overrideWithValue(cache),
      ],
      child: const LpsApp(),
    ),
  );
}
