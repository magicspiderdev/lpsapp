import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'features/socio/notificacoes/notificacoes.dart';

/// Mensagens que têm de sobreviver a uma mudança de ecrã (ex.: conta eliminada).
final mensagensGlobais = GlobalKey<ScaffoldMessengerState>();

class LpsApp extends ConsumerStatefulWidget {
  const LpsApp({super.key});

  @override
  ConsumerState<LpsApp> createState() => _LpsAppState();
}

class _LpsAppState extends ConsumerState<LpsApp> {
  @override
  void initState() {
    super.initState();
    // Depois do primeiro fotograma: o `getInitialMessage` pode mandar navegar,
    // e o router ainda não existe enquanto o `build` não correu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final push = ref.read(pushProvider.notifier)
        ..aoReceber = _comAAppAberta
        ..aoTocar = _aoTocar;
      push.arrancar();
    });
  }

  /// Com a app aberta o sistema não mostra nada: a notificação seria uma
  /// interrupção em cima do que o sócio está a fazer. Mostra-se um aviso
  /// discreto e actualiza-se a lista, para o sino ficar com a marca.
  void _comAAppAberta(RemoteMessage m) {
    ref.invalidate(notificacoesProvider);
    final titulo = m.notification?.title ?? m.data['title'] as String?;
    if (titulo == null || titulo.isEmpty) return;

    mensagensGlobais.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
          action: SnackBarAction(label: 'Ver', onPressed: () => _abrir(m)),
        ),
      );
  }

  void _aoTocar(RemoteMessage m) {
    ref.invalidate(notificacoesProvider);
    _abrir(m);
  }

  /// Hoje o backoffice manda `route` a `null` e a notificação é só título e
  /// texto — abre-se o histórico. Quando passar a mandar um destino, é aqui
  /// que se acrescenta; destinos desconhecidos caem no histórico à mesma.
  void _abrir(RemoteMessage m) {
    final destino = m.data['route'];
    ref.read(routerProvider).go(destino is String && destino.startsWith('/') ? destino : '/socio/notificacoes');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LPS Neo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: mensagensGlobais,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('pt', 'PT'),
      supportedLocales: const [Locale('pt', 'PT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
    );
  }
}
