import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/biometria.dart';
import '../../core/auth/sessao.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/blocos.dart';

/// Zona do sócio bloqueada: pede a biometria assim que aparece.
class DesbloquearPage extends ConsumerStatefulWidget {
  const DesbloquearPage({super.key});

  @override
  ConsumerState<DesbloquearPage> createState() => _DesbloquearPageState();
}

class _DesbloquearPageState extends ConsumerState<DesbloquearPage> {
  bool _aPedir = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  Future<void> _desbloquear() async {
    if (_aPedir) return;
    setState(() => _aPedir = true);
    // Com sucesso, o router sai daqui sozinho.
    await ref.read(biometriaProvider.notifier).desbloquear();
    if (mounted) setState(() => _aPedir = false);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sessao = ref.watch(sessaoProvider);
    final socio = sessao is SessaoSocio ? sessao.socio : null;
    final tipo = ref.watch(tipoBiometriaProvider).valueOrNull ?? TipoBiometria.digital;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 24, Tema.margem + 4, 16),
          child: Column(
            children: [
              const Spacer(),
              if (socio != null) ...[
                Avatar(nome: socio.nomeCompleto, url: socio.fotoUrl, tamanho: 88),
                const SizedBox(height: 20),
                Text('Olá de novo', style: tema.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Sócio n.º ${socio.nrSocio}',
                  style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              Material(
                color: tema.colorScheme.primaryContainer,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _aPedir ? null : _desbloquear,
                  child: SizedBox.square(
                    dimension: 88,
                    child: Icon(
                      tipo == TipoBiometria.facial ? Icons.face_retouching_natural : Icons.fingerprint_rounded,
                      size: 48,
                      color: tema.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Toque para entrar com ${tipo.nome}', style: tema.textTheme.bodyMedium),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(sessaoProvider.notifier).sair(),
                child: const Text('Entrar com a palavra-passe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
