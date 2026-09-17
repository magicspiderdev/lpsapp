import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/biometria.dart';
import '../../core/auth/sessao.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/blocos.dart';
import 'conta/contas.dart';
import 'conta/seletor_conta.dart';
import 'inicio_page.dart';

/// Moldura da zona do sócio: a barra do sócio fica sempre no topo e só o
/// conteúdo por baixo muda, como nas apps bancárias.
class SocioShell extends StatelessWidget {
  const SocioShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            const BarraSocio(),
            // A barra já ocupa a zona da barra de estado: os ecrãs por baixo não a somam outra vez.
            Expanded(
              child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto (abre o perfil), de quem é a conta (abre o seletor, se houver
/// dependentes) e o chat com a secretaria.
class BarraSocio extends ConsumerWidget {
  const BarraSocio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    if (sessao is! SessaoSocio) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    final temDependentes = (ref.watch(dependentesProvider).valueOrNull?.valor ?? const []).isNotEmpty;
    final dependente = ref.watch(dependenteActivoProvider);
    final resumo = ref.watch(resumoProvider).valueOrNull?.valor;
    // Mensagens por ler são sempre da conta da app, mesmo a ver um dependente (guia §2.3.4).
    final mensagensNovas = (resumo?.mensagensNaoLidas ?? 0) > 0;

    final nome = dependente?.nomeCompleto ?? sessao.socio.nomeCompleto;
    final foto = dependente?.fotoUrl ?? resumo?.fotoUrl ?? sessao.socio.fotoUrl;
    final primeiro = _primeiroNome(nome);

    return Container(
      color: Tema.verde,
      padding: EdgeInsets.fromLTRB(Tema.margem, MediaQuery.paddingOf(context).top + 6, Tema.margem, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => mostrarPerfil(context, ref),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Avatar(nome: nome, url: foto, tamanho: 36),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // Com sócios a seu cargo, o nome abre o seletor de conta.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: temDependentes ? () => mostrarSeletorConta(context) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          dependente != null ? primeiro : 'Olá, $primeiro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                      if (temDependentes) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                      ],
                    ],
                  ),
                  Text(
                    dependente != null
                        ? 'Conta a seu cargo · N.º ${dependente.nrSocio}'
                        : 'Sócio n.º ${sessao.socio.nrSocio}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                  ),
                ],
              ),
            ),
          ),
          BotaoVidro(
            icone: Icons.chat_bubble_outline_rounded,
            marca: mensagensNovas,
            dica: 'Secretaria',
            onTap: () => context.push('/socio/suporte'),
          ),
        ],
      ),
    );
  }

  static String _primeiroNome(String nome) {
    final p = nome.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1);
  }
}

/// Botão redondo translúcido sobre o verde do clube, com marca de novidade.
class BotaoVidro extends StatelessWidget {
  const BotaoVidro({super.key, required this.icone, required this.onTap, this.marca = false, this.dica});

  final IconData icone;
  final VoidCallback onTap;
  final bool marca;
  final String? dica;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica ?? '',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.16),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(dimension: 40, child: Icon(icone, color: Colors.white, size: 20)),
            ),
          ),
          if (marca)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Tema.alerta,
                  shape: BoxShape.circle,
                  border: Border.all(color: Tema.verde, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Folha do perfil: é sempre a conta da sessão, mesmo a ver a de um dependente.
void mostrarPerfil(BuildContext context, WidgetRef ref) {
  final sessao = ref.read(sessaoProvider);
  if (sessao is! SessaoSocio) return;
  final s = sessao.socio;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Altura pelo conteúdo, com scroll: com letra grande ou ecrã pequeno não cabe na altura por omissão.
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(nome: s.nomeCompleto, url: s.fotoUrl, tamanho: 72),
            const SizedBox(height: 12),
            Text(s.nomeCompleto, textAlign: TextAlign.center, style: Theme.of(sheet).textTheme.titleLarge),
            Text('Sócio n.º ${s.nrSocio}', style: Theme.of(sheet).textTheme.bodySmall),
            const SizedBox(height: 24),
            ListTile(
              leading: const IconePastilha(Icons.person_outline_rounded),
              title: const Text('Dados pessoais'),
              subtitle: const Text('Contactos, fotografia, palavra-passe'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(sheet);
                context.push('/socio/perfil');
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final tipo = ref.watch(tipoBiometriaProvider).valueOrNull;
                if (tipo == null) return const SizedBox.shrink();
                return SwitchListTile(
                  secondary: IconePastilha(
                    tipo == TipoBiometria.facial ? Icons.face_retouching_natural : Icons.fingerprint_rounded,
                  ),
                  title: Text('Entrar com ${tipo.nome}'),
                  value: ref.watch(biometriaProvider.select((b) => b.activa)),
                  onChanged: (v) => ref.read(biometriaProvider.notifier).definir(v),
                );
              },
            ),
            ListTile(
              leading: IconePastilha(Icons.logout_rounded, cor: Theme.of(sheet).colorScheme.error),
              title: const Text('Terminar sessão'),
              onTap: () {
                Navigator.pop(sheet);
                ref.read(sessaoProvider.notifier).sair();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
