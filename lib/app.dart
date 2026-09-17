import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/tema/tema.dart';

/// Mensagens que têm de sobreviver a uma mudança de ecrã (ex.: conta eliminada).
final mensagensGlobais = GlobalKey<ScaffoldMessengerState>();

class LpsApp extends ConsumerWidget {
  const LpsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LPS Neo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: mensagensGlobais,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('pt', 'PT'),
      supportedLocales: const [Locale('pt', 'PT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: Tema.claro(),
      darkTheme: Tema.escuro(),
    );
  }
}
