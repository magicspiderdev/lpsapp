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
  bool _avisoMostrado = false;

  @override
  Widget build(BuildContext context) {
    final nav = widget.navegacao;
    final c = Theme.of(context).colorScheme;

    // Versão nova disponível: um aviso discreto, uma vez por arranque.
    ref.listen(estadoVersaoProvider, (_, v) => _talvezAvisar(v.valueOrNull));
    _talvezAvisar(ref.read(estadoVersaoProvider).valueOrNull);

    return Scaffold(
      body: nav,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant))),
        child: NavigationBar(
          selectedIndex: nav.currentIndex,
          onDestinationSelected: (i) => nav.goBranch(i, initialLocation: i == nav.currentIndex),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Clube',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: 'Sócio',
            ),
          ],
        ),
      ),
    );
  }

  void _talvezAvisar(EstadoVersao? v) {
    if (_avisoMostrado || v == null || !v.sugerir) return;
    _avisoMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Há uma versão nova da app.'),
        duration: const Duration(seconds: 8),
        action: v.urlLoja == null
            ? null
            : SnackBarAction(
                label: 'Actualizar',
                onPressed: () => launchUrl(Uri.parse(v.urlLoja!), mode: LaunchMode.externalApplication),
              ),
      ));
    });
  }
}
