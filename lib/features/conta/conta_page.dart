import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/sessao.dart';
import '../../core/formatos.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../socio/conta/contas.dart' show contaActivaProvider;
import '../socio/inicio_page.dart' show InicioPage;
import '../socio/perfil/perfil_page.dart' show confirmarEliminarConta;

/// O separador pessoal, conforme quem está a usar a app.
///
/// Com ficha de sócio é a área de sócio de sempre. Sem ficha é a conta — e
/// tem de existir: sem ela, quem entrou só com email não tinha onde mudar a
/// palavra-passe, terminar sessão ou eliminar a conta.
class ZonaPessoalPage extends ConsumerWidget {
  const ZonaPessoalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(sessaoProvider)) {
      SessaoSocio() => const InicioPage(),
      SessaoConta(:final conta) => ContaPage(conta: conta),
      // O router não deixa chegar aqui sem sessão; se chegar, não se inventa.
      SessaoAnonima() => const Scaffold(body: SizedBox.shrink()),
    };
  }
}

/// A conta de quem ainda não associou a ficha de sócio.
class ContaPage extends ConsumerWidget {
  const ContaPage({super.key, required this.conta});

  final ContaSessao conta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 20, AppSpacing.screen, AppSpacing.xxl),
          children: [
            Row(
              children: [
                Avatar(nome: conta.nome.isEmpty ? '?' : conta.nome, tamanho: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(conta.nome, style: t.textTheme.headlineSmall, maxLines: 2),
                      if (conta.email case final email?) ...[
                        const SizedBox(height: 2),
                        Text(email, style: t.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // O convite principal: é isto que abre o cartão, as quotas e os
            // pagamentos a quem é sócio e ainda não ligou a ficha.
            Bloco(
              padding: const EdgeInsets.all(16),
              onTap: () => context.push('/associar-socio'),
              child: Row(
                children: [
                  const IconePastilha(Icons.badge_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('É sócio do clube?', style: t.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Associe a ficha para ver o cartão, as quotas e os pagamentos.',
                          style: t.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            // Quem ainda não é sócio inscreve-se aqui (§4.21): o clube decide,
            // e depois assina-se e pagam-se as primeiras quotas.
            Bloco(
              padding: const EdgeInsets.all(16),
              onTap: () => context.push('/inscricoes'),
              child: Row(
                children: [
                  const IconePastilha(Icons.how_to_reg_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ainda não é sócio?', style: t.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text('Inscreva-se, ou inscreva um filho, pela app.', style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                ],
              ),
            ),

            // Encarregado sem ficha (§2.3.4): a conta de cada educando abre-se
            // daqui, com `X-Socio`.
            if (conta.dependentes.isNotEmpty) ...[
              const TituloSeccao('Os seus educandos'),
              Bloco(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final d in conta.dependentes)
                      ListTile(
                        leading: Avatar(nome: d.nome, tamanho: 40),
                        title: Text(primeiroNome(d.nome), style: t.textTheme.titleSmall),
                        subtitle: Text('Sócio n.º ${d.nrSocio}'),
                        trailing: Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                        onTap: () {
                          ref.read(contaActivaProvider.notifier).escolher(d.nrSocio);
                          context.push('/socio/educando');
                        },
                      ),
                  ],
                ),
              ),
            ],

            if (conta.tem(Capacidade.gerirDependentes) || conta.dependentes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              // Um pai ou uma mãe não precisam de ser sócios para acompanhar o
              // filho (§2.3.5). O pedido fica à espera da secretaria.
              Bloco(
                padding: const EdgeInsets.all(16),
                onTap: () => context.push('/socio/dependentes'),
                child: Row(
                  children: [
                    const IconePastilha(Icons.family_restroom_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conta.dependentes.isEmpty ? 'Acompanhar um filho sócio' : 'Educandos',
                            style: t.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text('Veja as quotas e o cartão de quem tem a seu cargo.', style: t.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],

            const TituloSeccao('A sua conta'),
            Bloco(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  // Pedidos por quem tem a cargo; para si, é preciso ser sócio.
                  if (conta.dependentes.isNotEmpty)
                    _Accao(
                      icone: Icons.how_to_reg_outlined,
                      titulo: 'Inscrições em modalidades',
                      onTap: () => context.push('/socio/conta/modalidades'),
                    ),
                  if (conta.tem(Capacidade.consentimentos))
                    _Accao(
                      icone: Icons.privacy_tip_outlined,
                      titulo: 'Privacidade',
                      onTap: () => context.push('/socio/conta/privacidade'),
                    ),
                  _Accao(
                    icone: Icons.lock_outline_rounded,
                    titulo: 'Alterar a palavra-passe',
                    onTap: () => context.push('/socio/conta/password'),
                  ),
                  _Accao(
                    icone: Icons.logout_rounded,
                    titulo: 'Terminar sessão',
                    onTap: () => ref.read(sessaoProvider.notifier).sair(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: t.colorScheme.error),
              onPressed: () => confirmarEliminarConta(context, ref),
              child: const Text('Eliminar a conta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Accao extends StatelessWidget {
  const _Accao({required this.icone, required this.titulo, required this.onTap});

  final IconData icone;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListTile(
      leading: Icon(icone, color: t.colorScheme.onSurfaceVariant),
      title: Text(titulo, style: t.textTheme.titleSmall),
      trailing: Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
