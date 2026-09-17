import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/arranque/versao_app.dart';

/// Navegação principal: zona pública e zona do sócio.
class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key, required this.navegacao});

  final StatefulNavigationShell navegacao;

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  bool _avisoFechado = false;

  @override
  Widget build(BuildContext context) {
    final versao = ref.watch(estadoVersaoProvider).valueOrNull;
    final nav = widget.navegacao;

    return Scaffold(
      body: Column(
        children: [
          if ((versao?.sugerir ?? false) && !_avisoFechado)
            SafeArea(
              bottom: false,
              child: MaterialBanner(
                content: const Text('Há uma versão nova da app.'),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _avisoFechado = true),
                    child: const Text('Agora não'),
                  ),
                  if (versao?.urlLoja != null)
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(versao!.urlLoja!),
                          mode: LaunchMode.externalApplication),
                      child: const Text('Actualizar'),
                    ),
                ],
              ),
            ),
          Expanded(child: nav),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.currentIndex,
        onDestinationSelected: (i) => nav.goBranch(i, initialLocation: i == nav.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'Notícias'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'Sócio'),
        ],
      ),
    );
  }
}
