import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

class LpsApp extends ConsumerWidget {
  const LpsApp({super.key});

  static const verdeClube = Color(0xFF0B5D3B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LPS Neo',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('pt', 'PT'),
      supportedLocales: const [Locale('pt', 'PT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: verdeClube),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: verdeClube, brightness: Brightness.dark),
      ),
    );
  }
}
