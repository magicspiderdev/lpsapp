import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api/clientes.dart';
import 'core/auth/token_store.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');

  final tokens = TokenStore(const FlutterSecureStorage(), novoDio(Config.socioBase));
  await tokens.carregar();

  runApp(ProviderScope(
    overrides: [tokenStoreProvider.overrideWithValue(tokens)],
    child: const LpsApp(),
  ));
}
