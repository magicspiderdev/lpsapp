import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/arranque/versao_app.dart';

/// Versão abaixo de `versao_minima`: a app não continua.
class ActualizarPage extends ConsumerWidget {
  const ActualizarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(estadoVersaoProvider).valueOrNull?.urlLoja;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 64),
              const SizedBox(height: 16),
              Text('Actualize a app', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Esta versão já não é suportada. Instale a versão mais recente para continuar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (url != null)
                FilledButton(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  child: const Text('Abrir a loja'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
