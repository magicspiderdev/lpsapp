import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/arranque/versao_app.dart';
import '../../core/rede/ligacao.dart';

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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SemLigacao(),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant)),
            ),
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
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Agenda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.confirmation_number_outlined),
                  selectedIcon: Icon(Icons.confirmation_number),
                  label: 'Bilhetes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle),
                  label: 'Sócio',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _talvezAvisar(EstadoVersao? v) {
    if (_avisoMostrado || v == null || !v.sugerir) return;
    _avisoMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Há uma versão nova da app.'),
          duration: const Duration(seconds: 8),
          action: v.urlLoja == null
              ? null
              : SnackBarAction(
                  label: 'Actualizar',
                  onPressed: () => launchUrl(Uri.parse(v.urlLoja!), mode: LaunchMode.externalApplication),
                ),
        ),
      );
    });
  }
}

/// Faixa discreta por cima da navegação enquanto não há ligação ao servidor.
class _SemLigacao extends ConsumerWidget {
  const _SemLigacao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(ligacaoProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: online
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: const Color(0xFF16181C),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Sem ligação à internet · a mostrar a última informação',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
